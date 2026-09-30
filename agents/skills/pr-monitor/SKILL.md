---
name: pr-monitor
description: Monitor GitHub PRs using a bundled check script; fix CI failures, merge conflicts, and review feedback. Use for PR監視, watch pr, fix ci, コンフリクト解消, and レビュー対応.
---

# PR Monitor

GitHub取得・差分判定はスクリプト、未対応イベントの判断・修正はCodexが担当する。

## 確認

指定PRを使う。未指定なら `gh pr view --json number,url` と `gh repo view --json nameWithOwner` で特定する。`<skill-dir>`はこのskillのディレクトリ。

```bash
python3 <skill-dir>/scripts/check.py check --repo OWNER/REPO --pr NUMBER
```

| 結果 | 動作 |
| --- | --- |
| ok、eventsなし | 静かに終了 |
| action_required（eventsあり） | [response.md](references/response.md) で対応 |
| draft / busy | 修正せず次回確認 |
| error | 取得失敗として扱う。問題なしと判断しない |
| terminal | [lifecycle.md](references/lifecycle.md) で終了処理 |

終了コード0は取得成功を表し、対応不要を意味しない。`action_required`ではCI失敗・レビュー・コメントを評価し、必要な修正・検証・pushまで進める。前回と同じイベントでも未対応なら継続する。進められない場合は理由と必要な判断を通知し、黙って終了しない。

取得済みの全CI・全コメントを再取得せず、必要なファイル・失敗ログだけ読む。

## 対応済みの記録

対応と検証が完了したイベント、対応不要と判断したイベントだけackする。保留は理由を記録し、ユーザー回答後に再開する。

```bash
python3 <skill-dir>/scripts/check.py ack --repo OWNER/REPO --pr NUMBER \
  --event EVENT_ID --reason 'commit・検証・返信ID、対応不要または保留の理由'
```

取得しただけでackしない。自身の返信もIDごとに評価し、作者単位で全発言を無視しない。

## 制約と参照

- 👀がPR上のどこかにあればマージ禁止。UNKNOWNは競合なしの証拠にしない。
- 監視依頼から自動マージの許可を推測しない。force push/rebaseはしない。
- 同じ問題3回失敗、レビュー2往復以上の平行線、重要な不確実性は保留して報告する。
- 継続監視・停止・cleanup・Codexの+1通知: [lifecycle.md](references/lifecycle.md)。heartbeatを使い、launchdや別Codexプロセスは登録しない。「1回だけ」は監視登録しない。
- 状態調査・スクリプト変更/検証: [script.md](references/script.md)。
