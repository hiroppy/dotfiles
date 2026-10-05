# スクリプトの契約と検証

Python 3標準ライブラリと認証済みgh CLIを使う（macOS/Linux）。GitHub書き込み・モデル起動・監視登録・worktree削除はCodexが担当する。

| コマンド/設定 | 契約 |
| --- | --- |
| check | 全ページ取得後にsnapshot/pendingを保存し、状態と未対応eventsをJSON出力 |
| ack | reason必須。編集・追加発言は別ID、thread再openは別occurrence |
| status | GitHub取得なしで最終成功時刻・エラー・未対応件数を確認 |
| --state-dir | 既定は`~/.codex/pr-monitor`。worktree外に保存 |
| --interval-minutes | ユーザー指定の監視間隔 |
| --reset-idle | 再開時に無変化タイマーをリセット |
| --fixture | 保存snapshotでAPIなしの検証 |

- PRごとのflockで取得・状態更新を排他する。修正作業はロックしないため監視を重複登録しない。取得失敗時はlastErrorを更新し、snapshot/pendingを保持して無変化タイマーをリセットする。解決済みCI/threadはpendingから除外する。

- 初回の既存コメントや自身の返信もID単位で評価する。技術的要否を文字列検索で決めず、GitHub本文をshellへ展開しない。

- `stopRequested`: 1分監視で20分無変化かつ未対応なし。snapshot変更・取得失敗・未対応・間隔変更・再開時にタイマーをリセットする。

## 検証

機能適合性・信頼性・セキュリティを対象に、判断表・状態遷移・エラー推測で以下を確認する。

- CI・コメント・レビュー・threadの検出、未対応の再取得、ack、追加発言、再open。
- terminal/draft優先、pagination、API失敗時の状態保持。
- 無変化停止の20分境界、状態変更、未対応、取得失敗、監視間隔、再開。
- Codex +1の作者判定、遅延到着、ack前の再取得、削除再追加、新HEAD、サマリーコメントへの非依存。

実PRへの書き込み・cleanup・通知配信基盤は対象外。

```bash
python3 -m unittest discover -s <skill-dir>/scripts -p 'test_*.py'
```
