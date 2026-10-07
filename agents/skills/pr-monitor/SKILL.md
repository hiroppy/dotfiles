---
name: pr-monitor
description: Monitor GitHub PRs using a bundled check script; fix CI failures, merge conflicts, and review feedback. Use for PR監視, watch pr, fix ci, コンフリクト解消, and レビュー対応.
---

# PR Monitor

スクリプトでGitHub取得・差分判定、実行するエージェントが未対応イベントを処理する。Python 3・認証済みgh CLI・Gitが必要。特定のアプリやautomationツールは必須ではない。

## 確認

PR未指定なら `gh pr view --json number,url` と `gh repo view --json nameWithOwner` で特定する。

```bash
python3 <skill-dir>/scripts/check.py check --repo OWNER/REPO --pr NUMBER
```

- 既定はスケジューラなし（`--monitor-status NONE`）。継続監視は[lifecycle.md](references/lifecycle.md)に従い実行環境で設定する。
- checkの`actions`を[lifecycle.md](references/lifecycle.md)に従って順番に実行する。
- errorは取得失敗、busyは次回確認。
- 未対応イベントは前回と同じでも処理する。進められなければ理由と必要な判断を通知する。
- 追加取得は必要なファイル・ログだけにする。

## ack

対応・検証済み、対応不要、または保留理由を記録したイベントをID単位でackする。保留はユーザー回答後に再開する。

```bash
python3 <skill-dir>/scripts/check.py ack --repo OWNER/REPO --pr NUMBER \
  --event EVENT_ID --reason 'commit・検証・返信ID、不要または保留の理由'
```

- 解決したレビューthreadは`finish-review`で返信・resolve・ackを一括実行する。エラー時は同じevent ID・本文・reasonで再実行する。ackだけで対応完了にしない。詳細は[response.md](references/response.md)。
- 取得だけでackしない。
- 自身の返信も評価し、作者単位で除外しない。

## 制約・参照

- マージは許可済みの範囲で`merge`を使う。スクリプトが再取得・`canMerge`判定・HEAD照合・結果確認を行う。`blocked`なら`blockingReasons`に従い、モデル側で上書きしない。詳細は[script.md](references/script.md)。
- 監視依頼だけでは自動マージしない。force push/rebaseは禁止。
- 同じ問題で3回失敗、レビュー2往復以上の平行線、重要な不確実性は保留して報告する。
- 継続監視・通知・cleanup: [lifecycle.md](references/lifecycle.md)。
- 状態調査・スクリプト変更/検証: [script.md](references/script.md)。
