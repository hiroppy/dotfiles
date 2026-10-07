# 継続監視・終了処理

## 監視

- 既定の`check`はスケジューラなし（`--monitor-status NONE`）。PR取得・イベント対応・マージ判定は定期実行ツールがなくても進める。タイトルを渡さなければタイトル変更も要求しない。
- 継続監視は実行環境が提供する定期実行機能、cron、CI、またはエージェントの待機・再確認で行う。スケジューラは次の実行を起動するための任意の連携であり、PR対応の前提ではない。待機する場合は各回のcheck後にactionsを処理し、推奨間隔で再確認する。単にcheckをcron実行しても修正エージェントは起動しない。
- PRごとに実行主体を1つにし、既存監視を再利用する。「1回だけ」は登録しない。登録可能な機能がなければ、定期監視が未登録であることを明示し、その場のPR対応を続ける。登録したと推測しない。
- スケジューラ連携時だけ`--monitor-status ACTIVE|PAUSED`と`--current-interval`を渡す。タイトル連携時は`--title`を渡す。ユーザー指定間隔は`--interval-minutes`。停止済み監視はユーザー指示で再開し、最初のcheckに`--reset-idle`を付ける。
- 登録・変更後に対象・間隔・有効状態を確認する。実行指示にはPR URL、repo/number、worktree、承認範囲と「checkのactionsを順番に実行する」を記載する。
- 待機・再確認では`stopRequested`で停止し、MERGED/CLOSEDでは次のcheckを予約しない。外部スケジューラを実際に使っている場合はNONEで隠さず、停止を確認してから終了処理へ進む。

## actionsの実行

| type | 操作 |
| --- | --- |
| set_interval | 選択したスケジューラでminutes（またはrrule）を適用。他の設定は保持 |
| pause_monitor | 選択したスケジューラの実行を停止する |
| set_title | 実行環境の任意のタイトル変更機能でtitleを適用。既に同じなら完了として記録。古いtitlePrefix形式は連携中の場合だけ現在のタイトルから適用 |
| notify | prepare-notificationがdispatchを返した場合だけ通知し、notification-resultで結果を記録 |
| reconcile_notification | 通知履歴等の証拠から送達を確認。不明なら再送せず後続を止める |
| handle_event | eventIdのイベントをresponse.mdで処理 |
| cleanup_worktree | cleanup-worktreeを実行。archive_requiredなら管理元の機能でarchive後、再実行して削除確認 |
| delete_monitor | 対象スケジューラの登録を削除 |
| cleanup_state | `check.py cleanup --repo OWNER/REPO --pr NUMBER --apply` |

- 通知以外の各操作の成功後に`check.py complete --repo OWNER/REPO --pr NUMBER --action ID --reason 結果`で記録する。通知は以下の専用手順でeventもackされる。
- handle_eventは対応後にeventをackする。cleanup_stateはJSONを削除するためcomplete不要。
- 順番に実行する。実際のスケジューラ停止失敗、通知送達不明、GitHub操作やcleanupの失敗は後続を止めて報告する。未登録のスケジューラ・未使用のタイトル連携の古いactionは、未使用の根拠を記録してcompleteし、PR対応を続ける。実在する監視を停止済みと推測しない。
- actionsが空なら静かに終了する。PAUSEDの監視を自動再開しない。

## 通知

```bash
python3 <skill-dir>/scripts/check.py prepare-notification --repo OWNER/REPO --pr NUMBER --action ID
python3 <skill-dir>/scripts/check.py notification-result --repo OWNER/REPO --pr NUMBER --action ID --outcome succeeded --reason '送信先のメッセージID等の成功確認'
```

- prepareの`dispatch`で返されたmessageを一度だけ通知する。`completed`は送信済み、`delivery_unknown`は確認待ちなので再送しない。送信前に状態を保存するため、保存後に実行が中断した場合も確認待ちになる。
- 送信APIの成功結果や送信先の履歴を証拠に`succeeded`を記録する。確実に未送信と確認できた場合だけ`not_sent`を記録してprepareから再開する。証拠がなければ`unknown`を記録し、後続操作を止めてユーザーへ確認状況を示す。単なるエラー・タイムアウトは未送信の証拠ではない。
- 通知先は現在の会話も使える。専用の通知APIは必須ではない。会話に結果を表示し、表示した内容・対象・時刻をreasonに記録する。
- 通知APIに送達照会・冪等キーがない場合、完全自動の送達保証はできない。モデルの推測で完了扱いや再送をしない。通知は既存の許可されたチャネルに限定する。

## 終了・cleanup

- MERGED/CLOSEDを確認したら、cleanup・通知より先に使用中のスケジューラを停止する（NONEなら停止操作は不要）。後続が失敗しても定期監視は再開しない。未完了の後片付けは現在のチャットで継続し、必要な判断を報告する。後片付け完了後にスケジューラ登録を削除する。

- disposeが指定されている場合は実行し、実行環境のタスク管理機能、Git worktree一覧、関連づけの記録等で対象worktreeの管理・共有・pin・他タスク使用状況を確認する。アプリ管理外の通常worktreeはmanaged=false、pin機能がない環境はpinned=falseの根拠を記録する。不明な値をfalseとして扱わない。通常のworktreeは関連づけの記録と実行中タスクから確認する。
- 確認した証拠をworktree外のJSONへ保存する。`observedAt`はタイムゾーン付きISO時刻、他の項目は確認済みboolean。`inUse`はdispose後の他タスクによる使用を表す。スクリプトは60秒以内の証拠だけを受け付け、プロセスはlsofで別途確認する。

```json
{"worktree":"/absolute/path","observedAt":"2026-10-07T12:00:00+09:00","shared":false,"pinned":false,"inUse":false,"managed":true}
```

```bash
python3 <skill-dir>/scripts/check.py cleanup-worktree --repo OWNER/REPO --pr NUMBER --repository /separate/checkout --worktree /associated/worktree --branch BRANCH --ownership-file FILE --apply
```

- 対象worktreeの外から実行する。`eligible`はpreview、`retained`は保持、`completed`だけをcleanup成功とする。スクリプトがmerged・PRとの関連・primary/default branch・HEAD・未保存/ignoredファイル・プロセス・ロック・他worktreeの使用を検査する。
- `archive_required`なら管理元が提供する正確な識別子とarchive操作を使う。成功後に証拠を更新し、同じcleanup-worktreeを再実行する。アプリの保護を迂回してgitで削除しない。
- worktree削除とbranch削除の間で中断しても同じ対象で再開する。branchはPRのpush済みHEADと照合し、update-refの期待値付き削除を使う。再作成・追加commit・使用中の対象は保持する。
- 未マージcloseでは作業を保持する。cleanup・報告後に対象スケジューラの登録を削除する。停止指示では監視だけ解除、一時停止ではPAUSEDにする。
- 終了処理とスケジューラ登録削除後、`check.py cleanup --repo OWNER/REPO --pr NUMBER --apply`で状態JSONを削除する。未確認通知・未完了cleanupは削除しない。停止・一時停止では保持し、排他制御用の.lockは残す。
