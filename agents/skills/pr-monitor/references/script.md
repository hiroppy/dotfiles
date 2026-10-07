# スクリプトの契約と検証

Python 3標準ライブラリと認証済みgh CLIを使う（macOS/Linux）。GitHub書き込み・モデル起動・監視登録・worktree削除はCodexが担当する。

| コマンド/設定 | 契約 |
| --- | --- |
| check | 全ページ取得後にsnapshot/pendingを保存し、状態と未対応eventsをJSON出力 |
| complete | 成功したaction IDとreasonを保存。通知eventをack |
| attempt | --attempt-id必須。問題IDと試行IDで重複を除外。3回でhold、成功/resetで0 |
| reply / resolve | pending threadへの返信投稿・解決と結果確認 |
| ack | reason必須。編集・追加発言は別ID、thread再openは別occurrence |
| cleanup | GitHubでmerged/closedを再確認し削除候補を返す。`--apply`で対象JSONを削除。未対応事項・取得失敗・openは保持 |
| status | GitHub取得なしで最終成功時刻・エラー・未対応件数を確認 |
| --state-dir | 既定は`~/.codex/pr-monitor`。worktree外に保存 |
| --interval-minutes | ユーザー指定の監視間隔 |
| --reset-idle | 再開時に無変化タイマーをリセット |
| --title / --current-interval / --monitor-status | 現在のアプリ状態を渡し、必要なactionsだけ返す |
| --fixture | 保存snapshotでAPIなしの検証 |

- PRごとのflockで取得・状態更新を排他する。修正作業はロックしないため監視を重複登録しない。取得失敗時はlastErrorを更新し、snapshot/pendingを保持して無変化タイマーをリセットする。解決済みCI/threadはpendingから除外する。

- 初回の既存コメントや自身の返信もID単位で評価する。技術的要否を文字列検索で決めず、GitHub本文をshellへ展開しない。

- `stopRequested`: 1分監視で20分無変化かつ未対応なし。snapshot変更・取得失敗・未対応・間隔変更・再開時にタイマーをリセットする。

- HEAD変更時のリアクション基準値は前回snapshotを使う。同じ取得でHEAD変更と新しいCodexの+1を検出した場合も通過通知を返す。初回取得の既存+1はHEADとの対応が不明なため通過とは断定しない。
- `--title`を省略してもCodexの+1を一度検出したPRでは`set_title`の`titlePrefix`を返す。+1が消えた場合は空のprefixで👍を外す。実行側は現在のタイトルを取得して適用する。

- `actions`: 間隔・停止・タイトル・通知・イベント対応・終了の実行計画。外部操作やackは実行しない。

## attemptの再実行

- 同じ問題ID・試行ID・outcome・reasonは一度だけ反映する。同じIDでoutcomeまたはreasonが変わった場合はエラーとして保存しない。
- 試行履歴は成功/reset後も保持し、遅れて届いた古い失敗・成功・resetで現在の回数を変更しない。出力のstatus/failuresは元の試行時点ではなく現在のカウンターを返す。
- 試行IDは問題ID内で一意。新しい試行には新しいIDを使う。既存stateのカウンターは保持するが、IDのない過去の記録は遡って重複判定できない。

## 検証

- 機能適合性・信頼性・セキュリティを対象に、境界値・判断表・状態遷移・エラー推測で判定と状態保持を検証する。
- attemptは機能適合性・信頼性を対象に境界値・状態遷移・判断表で検証する。同一試行の再送、2→3回のhold境界、成功/reset、古い試行の遅延再送、ID衝突・既存stateの移行を確認する。
- GitHub書き込みとアプリ操作はモックで確認。実サービスとの結合検証は対象外。

```bash
python3 -m unittest discover -s <skill-dir>/scripts -p 'test_*.py'
```
