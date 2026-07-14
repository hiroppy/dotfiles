---
name: pr-monitor
description: Monitor a GitHub PR for CI failures and review comments, then automatically fix issues. Use this skill when the user wants to watch a PR, fix CI, respond to review comments, or automate PR maintenance. Triggers on "PR監視", "PRを見て", "CIが落ちた", "レビュー対応", "pr monitor", "watch pr", "fix ci", or "pr fix".
---

# PR Monitor

GitHub PRのCIステータスとレビューコメントを監視し、自動で修正・対応するスキル。

## 前提

- `gh` CLIが認証済みであること
- 対象リポジトリのローカルクローン内で実行すること

## ワークフロー

### 1. PR特定

PRの特定方法（優先順位）:
- ユーザーがPR番号を指定した場合はそれを使う
- 指定がなければ現在のブランチに紐づくPRを `gh pr view --json number` で取得

### 2. CI監視と修正

```
gh pr checks <PR番号> --json name,state,description,link
```

failedなcheckがある場合:

1. **ログ取得**: `gh run view <run-id> --log-failed` でエラーログを取得
2. **原因分析**: エラーメッセージからlint/format/build/testのどれが失敗したか判別
3. **修正**: コードを読み、原因を特定して修正。修正は最小限に留める
4. **検証**: ローカルで同等のコマンドを実行して修正を確認（可能な場合）
5. **コミット&プッシュ**: 修正をコミットしてpush

コミットメッセージは `fix: <何を修正したか>` の形式で簡潔に。

push前にローカルで該当するlint/format/build/testを実行できる場合は、必ず先にローカルで通してからpushする。ローカル実行ができない場合は、その理由をユーザーへの報告に含める。

CIが全て通るまでこのループを繰り返す。ただし同じエラーが3回連続で解消しない場合は、ユーザーに報告して停止する。

### 3. レビューコメント対応

RESTのreview commentsだけでなく、GraphQLのreview threadも取得して `isResolved` を確認する。解決済みthreadは対象外にする。

```bash
OWNER_REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
OWNER=${OWNER_REPO%/*}
REPO=${OWNER_REPO#*/}
PR_NUMBER=<PR番号>

# issue comments（PR全体コメント）
gh api repos/$OWNER/$REPO/issues/$PR_NUMBER/comments

# review threads（inline comments / resolved状態つき）
gh api graphql -f owner="$OWNER" -f repo="$REPO" -F number="$PR_NUMBER" -f query='\
query($owner:String!, $repo:String!, $number:Int!) {
  repository(owner:$owner, name:$repo) {
    pullRequest(number:$number) {
      reviewThreads(first:100) {
        nodes {
          id
          isResolved
          path
          line
          comments(first:20) {
            nodes { id author { login } body url createdAt }
          }
        }
      }
    }
  }
}'
```

未対応コメントを検出する:
- **review threads（inline comments）**: `isResolved == false` かつエージェントがまだ返信していないスレッドを対象にする
- **issue comments（PR全体の通常コメント）**: 本文を読んで、指摘・修正依頼・質問・CI/QA報告など対応が必要な内容なら review thread と同様に対象にする。単なる通知、botの進捗ログ、既に対応済みと判断できるコメントは対象外

各コメントに対して:

1. **コンテキスト理解**: 指摘されたファイルと行を読み、周辺コードを把握
2. **指摘の評価**: 以下の観点で指摘が正当かを判断
   - **正確性**: コードにバグや誤りがあるか
   - **設計**: より良い設計パターンがあるか、責務の分離は適切か
   - **バグ**: エッジケースやエラーハンドリングの漏れがないか
3. **対応を決定**:

#### 指摘が正しく、修正方針に自信がある場合
- コードを修正してコミット&プッシュ
- push前にローカルで該当するlint/format/build/testを実行できる場合は、必ず先にローカルで通す
- 修正内容を該当コメントへ返信する。replyには「どのコミット/変更で直したか」「実行した検証」を短く含める
- review threadの場合は、**修正をpushし、ローカル検証またはCIで修正が確認できたら、そのreview threadをresolvedに変更する**
- issue comment（通常コメント）の場合はGitHub上にresolved状態がないため、返信で対応済みを明記するだけでよい

  ```bash
  gh api graphql -f threadId="<reviewThread.id>" -f query='\
  mutation($threadId: ID!) {
    resolveReviewThread(input: {threadId: $threadId}) {
      thread { id isResolved }
    }
  }'
  ```

  review thread resolved化後は同じthreadを再取得して `isResolved: true` を確認する。issue commentにはresolved化APIがないため、この手順は不要。

#### 指摘が正しいが、修正方針に自信がない場合
- pushせず、ユーザーに方針を確認する
- 何が不明確か、どういう選択肢があるかを提示する
- 自分で修正できていないため、threadはresolvedにしない

#### 指摘が正しくない場合
- 技術的な根拠を添えて、なぜ現状の実装が妥当かをスレッドに返信
- 攻撃的にならず、建設的に。コードや仕様を引用して具体的に説明する
- 判断に自信がない場合（60%未満）は、その旨も正直に伝えて議論を促す
- 反論や質問だけの場合は、レビュアー判断待ちとしてthreadはresolvedにしない

### 4. 報告

1回の実行で行った対応をまとめてユーザーに報告:
- CI: 修正した内容と結果
- レビュー: 対応したコメント数、修正/反論の内訳
- 未解決: 自動対応できなかった項目

## 継続監視

PR監視を求められた場合は、デフォルトで「PRがマージされるまで」監視を続ける。CIが一度greenになっただけ、またはレビューコメントを一通り処理しただけでは終了しない。

各ポーリングの最初にPR状態を確認する:

```bash
gh pr view <PR番号> --json state,mergedAt,isDraft,mergeable,mergeStateStatus,reviewDecision,statusCheckRollup,url
```

終了条件:
- `state == "MERGED"` または `mergedAt` が入ったら監視を終了し、マージ済みURL/時刻を報告する
- `state == "CLOSED"` かつ未マージなら、監視を終了し、close理由が分かる範囲で報告する
- ユーザーが「1回だけ」「ループ不要」「監視停止」と指示した場合は継続監視を設定しない/停止する

監視中の動作:
- デフォルトの間隔は5分
- 重複実行を避けるため、既存の監視ジョブやループがある場合は再登録しない
- CI失敗や未resolvedレビューコメントがあればワークフロー（1〜4）で対応する
- CIがgreenかつ未resolvedレビューコメントがない場合は、マージされるまで静かに待つ（不要な通知を出さない）
- 継続監視を設定した場合は、停止方法と「マージされるまで監視する」ことをユーザーに伝える

## 注意事項

- force pushはしない。常に新しいコミットで修正する
- push前にローカルで確認可能な検証コマンドがある場合は、必ずローカルで通してからpushする
- レビュアーとの議論が平行線になった場合（同じスレッドで2往復以上）は、ユーザーに判断を委ねる
- セキュリティに関わる変更（認証、暗号化、権限周り）は自動修正せず報告のみ
- 既存のコードスタイルやプロジェクトの規約に従う
