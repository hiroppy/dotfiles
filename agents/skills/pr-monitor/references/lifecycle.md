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
| set_title | titleがあればset_thread_titleで適用。titlePrefixだけなら現在のチャットタイトルを取得し、先頭の重複した👍を除いてtitlePrefixを付けて適用。既に同じなら完了として記録 |
| notify | prepare-notificationがdispatchを返した場合だけ通知し、notification-resultで結果を記録 |
| reconcile_notification | 通知履歴等の証拠から送達を確認。不明なら再送せず後続を止める |
| handle_event | eventIdのイベントをresponse.mdで処理 |
| cleanup_worktree | cleanup-worktreeを実行。archive_requiredならアプリでarchive後、再実行して削除確認 |
| delete_monitor | 対象automationを削除 |
| cleanup_state | `check.py cleanup --repo OWNER/REPO --pr NUMBER --apply` |

- 通知以外の各操作の成功後に`check.py complete --repo OWNER/REPO --pr NUMBER --action ID --reason 結果`で記録する。通知は以下の専用手順でeventもackされる。
- handle_eventは対応後にeventをackする。cleanup_stateはJSONを削除するためcomplete不要。
- 順番に実行し、失敗したら後続を止めて報告する。
- actionsが空なら静かに終了する。PAUSEDの監視を自動再開しない。

## 通知

```bash
python3 <skill-dir>/scripts/check.py prepare-notification --repo OWNER/REPO --pr NUMBER --action ID
python3 <skill-dir>/scripts/check.py notification-result --repo OWNER/REPO --pr NUMBER --action ID --outcome succeeded --reason '送信先のメッセージID等の成功確認'
```

- prepareの`dispatch`で返されたmessageを一度だけ通知する。`completed`は送信済み、`delivery_unknown`は確認待ちなので再送しない。送信前に状態を保存するため、保存後に実行が中断した場合も確認待ちになる。
- 送信APIの成功結果や送信先の履歴を証拠に`succeeded`を記録する。確実に未送信と確認できた場合だけ`not_sent`を記録してprepareから再開する。証拠がなければ`unknown`を記録し、後続操作を止めてユーザーへ確認状況を示す。単なるエラー・タイムアウトは未送信の証拠ではない。
- 通知APIに送達照会・冪等キーがない場合、完全自動の送達保証はできない。モデルの推測で完了扱いや再送をしない。通知は既存の許可されたチャネルに限定する。

## 終了・cleanup

- MERGED/CLOSEDを確認したら、cleanup・通知より先に対象automationをPAUSEDにする。後続が失敗しても定期監視は再開しない。未完了の後片付けは現在のチャットで継続し、必要な判断を報告する。後片付け完了後にautomationを削除する。

- 指定されたdisposeを実行し、list_artifacts/list_threads等で対象worktreeの管理・共有・pin・他タスク使用状況を確認する。不明な値をfalseとして扱わない。通常のworktreeは関連づけの記録と実行中タスクから確認する。
- 確認した証拠をworktree外のJSONへ保存する。`observedAt`はタイムゾーン付きISO時刻、他の項目は確認済みboolean。`inUse`はdispose後の他タスクによる使用を表す。スクリプトは60秒以内の証拠だけを受け付け、プロセスはlsofで別途確認する。

```json
{"worktree":"/absolute/path","observedAt":"2026-10-07T12:00:00+09:00","shared":false,"pinned":false,"inUse":false,"managed":true}
```

```bash
python3 <skill-dir>/scripts/check.py cleanup-worktree --repo OWNER/REPO --pr NUMBER --repository /separate/checkout --worktree /associated/worktree --branch BRANCH --ownership-file FILE --apply
```

- 対象worktreeの外から実行する。`eligible`はpreview、`retained`は保持、`completed`だけをcleanup成功とする。スクリプトがmerged・PRとの関連・primary/default branch・HEAD・未保存/ignoredファイル・プロセス・ロック・他worktreeの使用を検査する。
- `archive_required`ならlist_artifactsの正確なidentityKeyで`archive_worktree`を実行する。成功後に証拠を更新し、同じcleanup-worktreeを再実行する。アプリの保護を迂回してgitで削除しない。
- worktree削除とbranch削除の間で中断しても同じ対象で再開する。branchはPRのpush済みHEADと照合し、update-refの期待値付き削除を使う。再作成・追加commit・使用中の対象は保持する。
- 未マージcloseでは作業を保持する。cleanup・報告後に対象automationを削除する。停止指示では監視だけ解除、一時停止ではPAUSEDにする。
- 終了処理とautomation削除後、`check.py cleanup --repo OWNER/REPO --pr NUMBER --apply`で状態JSONを削除する。未確認通知・未完了cleanupは削除しない。停止・一時停止では保持し、排他制御用の.lockは残す。
