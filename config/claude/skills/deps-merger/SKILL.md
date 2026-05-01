---
name: deps-merger
description: Merge all open dependency-update PRs (Dependabot / Renovate) in the current repository. Auto-fixes failing CI (lockfile regen, lint/format/type/test errors), squash-merges minor/patch updates automatically, and pauses for user approval on major updates after CI is green. Use this skill whenever the user asks to handle dependency PRs, deps PRs, dependabot PRs, renovate PRs, "deps全部マージ", "依存更新マージ", "deps PR対応", "depsまとめてマージ", or wants to bulk-process bot-authored upgrade PRs.
---

# Deps Merger

リポジトリに出ているDependabot / Renovate由来のPRを一括処理するskill。

- **minor / patch**: CIが通れば自動でsquash merge
- **major**: CIを通したうえで、マージ前に必ずユーザーに確認
- **CIが落ちている場合**: lockfile再生成、lint/format/type/test errorなど自動で修正を試みる
- **修正不可能なPR**: スキップして最後にまとめて報告

## 前提

- `gh` CLIが認証済みであること
- Claude Codeが起動しているディレクトリのリポジトリを対象とする
- 対象リポジトリのデフォルトブランチに最新のローカルチェックアウトがあること（force pushはしないので、軽く確認する程度でよい）

## ワークフロー

### 1. 対象PRの取得

DependabotとRenovateの両方をauthorで絞り込んで一覧取得する。両botのGitHub上のloginは `dependabot[bot]` / `renovate[bot]` だが、`gh pr list` のauthor指定は `app/dependabot` / `app/renovate` を使う。

```bash
gh pr list --state open --author "app/dependabot" --json number,title,headRefName,labels,url
gh pr list --state open --author "app/renovate"   --json number,title,headRefName,labels,url
```

両方の結果をマージし、後続の処理対象とする。1件もない場合はその旨を伝えて終了。

### 2. major / minor / patch の分類

PRごとにバージョン更新の種別を判定する。判定ロジックは以下の優先順位:

1. **labels から判定**: dependabotは `version: major` / `version: minor` / `version: patch` のようなラベルを付けることがある（リポジトリ設定に依存）
2. **タイトルから semver を抽出**: 多くの場合タイトルに `from X.Y.Z to A.B.C` の形でバージョン情報がある
   - dependabot例: `Bump react from 18.2.0 to 19.0.0` → major
   - renovate例: `chore(deps): update dependency react to v19` → major（明らかに `to vN` の形ならmajor扱い）
   - renovate例: `chore(deps): update dependency react to v18.3.1` → titleから旧バージョンが取れない場合がある。その場合は `gh pr diff <番号>` でlockfileやpackage.jsonの差分を見て判定する
3. 判定が曖昧な場合は **安全側に倒してmajor扱い**（ユーザー確認を経るため事故が起きにくい）

判定基準（semver `X.Y.Z` → `A.B.C`）:
- `X != A` → major
- `X == A && Y != B` → minor
- それ以外 → patch

### 3. 処理順序

- まず **minor / patch** をすべて処理して片付ける（自動マージで終わるので速い）
- そのあと **major** を1つずつ処理する（CI green後にユーザー確認）

依存関係がぶつかってrebaseが必要になることがあるので、1つマージしたら次のPRに進む前に他のPRが古くなっていないか軽く意識する。コンフリクトや「out of date with base branch」を検知したら、botに応じてrebaseを依頼する:

- **Dependabot**: PRにコメント `@dependabot rebase` を投稿
  ```bash
  gh pr comment <番号> --body "@dependabot rebase"
  ```
- **Renovate**: PR description内のrebaseチェックボックス(`- [ ] If you want to rebase/retry this PR, check this box`)を `[x]` に書き換える。または `gh pr edit <番号> --body "..."` でbody更新
  ```bash
  body=$(gh pr view <番号> --json body --jq .body)
  new_body=$(echo "$body" | sed 's/- \[ \] <!-- rebase-check -->/- [x] <!-- rebase-check -->/')
  gh pr edit <番号> --body "$new_body"
  ```
  (チェックボックスのマーカーはRenovateのバージョンによって異なるので、実際のbody内容を見て適切な行を置換する)

rebaseを依頼したら数分待ってから再度CIをチェックする。

### 4. 各PRの処理

各PRに対して以下を実行する:

#### 4.1 CIステータスを確認

```bash
gh pr checks <番号> --json name,state,description,link
```

- **すべてsuccess** → 4.3 (マージ判定) へ
- **pending / in_progress がある** → 5分ごとに再チェックして完了を待つ。極端に長いCI(30分以上)が続く場合のみユーザーに「待つ？スキップする？」と聞く
- **failed がある** → 4.2 (自動修正) へ

#### 4.2 CI失敗時の自動修正

ローカルにそのPRのブランチをチェックアウトして修正する。

```bash
gh pr checkout <番号>
```

failしたcheckのログを取得して原因を分類:

```bash
gh pr checks <番号> --json name,state,link --jq '.[] | select(.state == "FAILURE")'
# 各failure に対して
gh run view <run-id> --log-failed
```

**修正パターン**:

| 症状 | 対応 |
|---|---|
| lockfile conflict / out of sync | パッケージマネージャを判定して再生成: npm→`npm install`、yarn→`yarn install`、pnpm→`pnpm install`、bun→`bun install`、cargo→`cargo update -p <pkg>`、go→`go mod tidy` など |
| lint / format error | プロジェクトのlinter/formatterを実行（package.jsonのscripts、Makefile、pre-commitなどから推定）。修正後の差分のみコミット |
| type error | エラー箇所を読んで修正。型定義の変更が原因なら、プロダクションコード側を新APIに合わせて修正してよい(型エラーは挙動変更ではなく形式調整なので積極的に直す) |
| test failure | テスト本体の修正で済むケースのみ自動対応（assertionの軽微なずれ、mock/snapshot更新など）。プロダクションコードの挙動そのものを変える必要がある場合は不可能扱い |
| build error | importパスの変更、削除されたAPIの差し替えなど機械的なものは対応 |

修正したらcommit & pushする:

```bash
git add -A
git commit -m "fix: <何を直したか>"
git push
```

その後、再度CIが流れるのを待つ。**同じcheckが2回連続で同じ理由で落ちる**、または **明らかにbreaking changeでアプリ側の大規模改修が必要** な場合は「修正不可能」として後段の報告に回す。

force pushは絶対にしない。常に新しいcommitを積む。

#### 4.3 マージ判定

CIがすべてgreenになったら:

- **minor / patch** → そのままsquash merge:
  ```bash
  gh pr merge <番号> --squash --delete-branch
  ```
- **major** → ユーザーに確認:
  > PR #123 (Bump react from 18.2.0 to 19.0.0) はCIが通りました。マージしますか?
  
  ユーザーが「yes」「マージして」「OK」等で返したらsquash merge。「skip」「あとで」等なら保留して次へ。

### 5. 最終報告

すべてのPRを処理し終わったら、サマリを出す:

```
=== Deps PR 処理結果 ===
✅ Merged (auto): 5件
  - #101 Bump lodash from 4.17.20 to 4.17.21
  - ...
⏸  Awaiting approval (major): 2件
  - #110 Bump react from 18.2.0 to 19.0.0 [CI green]
  - ...
❌ Could not auto-fix: 1件
  - #115 Bump webpack from 4.x to 5.x
    理由: webpack5でconfig APIが大幅変更されており、自動対応の範囲を超える
```

修正不可能だったPRについては、何をしたら通るかの方針を1〜2行で添える。

## 注意事項

- **force pushしない**。修正は常に新しいcommitで積む
- **PR本体のコメント欄は触らない**。bot間の自動コメントが大量にある領域なので、人間/Claudeのノイズを増やさない
- **ユーザーが「全部マージしていいよ」と明示した場合のみ**、majorも確認なしで進める。デフォルトは確認必須
- **セキュリティ更新の判別**: Dependabotがsecurity updateとしてラベル付けしている場合（`security` label等）は、majorでも優先度を上げてユーザーに通知する
- **リポジトリのCI設定が独特なケース** (例: 手動承認が必要なworkflow): ユーザーに状況を伝えて判断を仰ぐ
- **ロックファイル再生成のときに別パッケージまで更新しないよう注意**: `npm install --no-save` ではなく、PR元のbotがlockfileを更新する流儀に合わせる（dependabot/renovateそれぞれ慣習が異なる）
