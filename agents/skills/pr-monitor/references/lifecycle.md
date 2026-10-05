# 継続監視・終了処理

## 監視

- PRごとにheartbeatを1本使い、既存監視を再利用する。「1回だけ」は登録しない。
- 停止済み監視はユーザー指示で再開し、最初のcheckに`--reset-idle`を付ける。
- checkへ現在のチャットタイトル・監視間隔・有効状態を`--title`、`--current-interval`、`--monitor-status`で渡す。ユーザー指定間隔は`--interval-minutes`。
- 登録・変更後に対象・間隔・有効状態を確認する。
- promptはPR URL、repo/number、worktree、承認範囲と「checkのactionsを順番に実行する」を記載する。

## actionsの実行

| type | 操作 |
| --- | --- |
| set_interval | automation_updateで返されたrruleを適用。他の設定は保持 |
| pause_monitor | automation_updateでPAUSEDにする |
| set_title | set_thread_titleで返されたtitleを適用 |
| notify | messageを通知。eventIdがあれば通知成功後にack |
| handle_event | eventIdのイベントをresponse.mdで処理 |
| finish_monitor | mergedに従い以下のcleanup・報告後、automationを削除 |

- 実行失敗は未完了として報告し、成功前にackしない。
- actionsが空なら静かに終了する。PAUSEDの監視を自動再開しない。

## 終了・cleanup

- mergedなら未commit/未push変更、実行中プロセス、共有/pin状態を確認する。指定されたdisposeを実行後、安全なworktreeとローカルブランチを削除する。

- Codex管理worktreeは`archive_worktree`、通常のworktreeは別ディレクトリから`git worktree remove`と`git branch -d`を使う。未保存・未push・使用中の作業は保持し、cleanup失敗を通知する。

- 未マージcloseでは作業を保持する。cleanup・報告後に対象automationを削除する。停止指示では監視だけ解除、一時停止ではPAUSEDにする。
