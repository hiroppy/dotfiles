---
name: pr-monitor
description: Monitor GitHub PRs using a bundled check script; fix CI failures, merge conflicts, and review feedback. Use for PR監視, watch pr, fix ci, コンフリクト解消, and レビュー対応.
---

# PR Monitor

スクリプトでGitHub取得・差分判定、Codexで未対応イベントを処理する。

## 確認

PR未指定なら `gh pr view --json number,url` と `gh repo view --json nameWithOwner` で特定する。

```bash
python3 <skill-dir>/scripts/check.py check --repo OWNER/REPO --pr NUMBER
```

| 結果 | 動作 |
| --- | --- |
| ok | 通知すべき変化がなければ静かに終了 |
| action_required | [response.md](references/response.md) で対応 |
| draft / busy | 次回確認 |
| error | 取得失敗として扱う |
| terminal | [lifecycle.md](references/lifecycle.md) で終了処理 |

- 終了コード0は取得成功。
- 未対応イベントは前回と同じでも処理する。進められなければ理由と必要な判断を通知する。
- 追加取得は必要なファイル・ログだけにする。

## ack

対応・検証済み、対応不要、または保留理由を記録したイベントをID単位でackする。保留はユーザー回答後に再開する。

```bash
python3 <skill-dir>/scripts/check.py ack --repo OWNER/REPO --pr NUMBER \
  --event EVENT_ID --reason 'commit・検証・返信ID、不要または保留の理由'
```

- 取得だけでackしない。
- 自身の返信も評価し、作者単位で除外しない。

## 制約・参照

- PR上のどこかに👀があればマージ禁止。UNKNOWNを競合なしと判断しない。
- 監視依頼だけでは自動マージしない。force push/rebaseは禁止。
- 同じ問題で3回失敗、レビュー2往復以上の平行線、重要な不確実性は保留して報告する。
- 継続監視・通知・cleanup: [lifecycle.md](references/lifecycle.md)。
- 状態調査・スクリプト変更/検証: [script.md](references/script.md)。
