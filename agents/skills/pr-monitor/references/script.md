# スクリプトの契約と検証

Python 3標準ライブラリ、認証済みgh CLI、Gitを使う（macOS/Linux）。通常worktreeのプロセス確認にはlsofが必要。レビュー・マージ・Git cleanupはスクリプト、アプリ操作・実際の通知送信・managed worktreeのarchiveはCodexが担当する。

| コマンド/設定 | 契約 |
| --- | --- |
| check | 全ページ取得後にsnapshot/pendingを保存し、状態と未対応eventsをJSON出力 |
| complete | 成功したaction IDとreasonを保存。再実行は成功扱い。通知はprepare済みの送信成功確認時だけ記録 |
| attempt | --attempt-id必須。問題IDと試行IDで重複を除外。3回でhold、成功/resetで0 |
| finish-review | 解決したthreadの返信・resolve・ackを再開可能な単一処理で実行。`--event`、`--body-file`、`--reason`必須 |
| reply / resolve | 保留・反論用。finish-reviewと同じ実状態照合・再開処理を使い、ackはしない |
| merge | 再取得・判定・HEAD照合・マージ・実状態確認。previewが既定、書き込みは--apply・--expected-head・許可根拠の--reasonが必要。--method squash（既定）/merge |
| cleanup-worktree | merged PRの関連worktreeとbranchの安全確認・削除・中断再開。アプリ証拠が必要。managedはarchive_requiredを返す |
| prepare-notification | action IDの送信前記録。初回はdispatch、再実行はdelivery_unknown、完了済みはcompleted |
| notification-result | 送達証拠の--reasonと--outcome succeeded/not_sent/unknownを記録。succeededで対応eventをack |
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

- checkの`actions`: 間隔・停止・タイトル・通知・イベント対応・終了の実行計画。check自体は外部操作やackを実行しない。通知のaction IDはcheck時刻が変わっても固定し、未確認の送達はPR状態が変わってもreconcile_notificationとして返す。MERGED/CLOSED時のpause_monitorは送達確認より先に返し、確認待ちでも監視を停止する。

## レビュー対応の再実行

- `reviewCompletions`にevent IDごとの元thread・HEAD・本文・reasonを投稿前に保存する。途中失敗はackせず、同じ入力で再開する。
- 全ページのコメントを取得し、認証ユーザーの返信本文と非表示識別子を照合する。返信・解決済みなら外部操作を省略する。通信切断後の成功もGitHubの状態から回復する。
- thread event IDにはHEADを含め、push後のcheckで新しい対応単位に切り替える。別PR・HEAD変更・コメント変更・完了後の再open・再実行入力変更はエラー。返信と解決を確認するまでackしない。PR単位の既存flockを共有する。
- 別ホストの同時実行やGitHub読み取りと書き込みの間の変更に対する原子的保証はない。同じPRの実行主体を重複させない。

## マージ判定

- `canMerge` / `blockingReasons`は現在のsnapshotと未対応events・失敗回数から毎回計算する。同じ入力なら同じ結果を返す。マージ許可は別途必要で、判定の保存・ackだけでマージしない。
- PR本体のEYESリアクション、非open・draft、競合・UNKNOWN、GitHubのmergeStateStatus、reviewDecision、失敗・実行中CI、未解決thread、未対応コメント・レビュー等、3回失敗のholdを阻止理由に含める。文章中の👀やコメントへのリアクションは対象外。
- コメント・レビューは要否をモデルが評価してackする。ackしても未解決thread・CI・競合・GitHubのレビュー要件は解除しない。過去のCHANGES_REQUESTED単体ではなくGitHubの集約reviewDecisionを使う。
- `mergeBlockedByEyes`は互換用。取得失敗・busyは有効な判定ではない。マージは以下の単一コマンドを使う。GraphQLのexpectedHeadOidを指定し、GitHub側の保護条件に従う。force/admin/自動マージ設定は使わない。

```bash
python3 <skill-dir>/scripts/check.py merge --repo OWNER/REPO --pr NUMBER
python3 <skill-dir>/scripts/check.py merge --repo OWNER/REPO --pr NUMBER --apply --expected-head SHA --reason '既存のユーザー許可の根拠' --method squash
```

- previewはeligible/blocked、実行成功・再実行時の既マージ確認はmergedを返す。マージ応答が失われてもGitHubでmergedを確認できれば成功。確認不能時はエラーとして次回に再取得する。receiptと異なるHEAD・方式の再試行は停止する。
- cleanup・通知の詳細は[lifecycle.md](lifecycle.md)。Git操作や送達の不明状態をモデルの判断で成功に上書きしない。

## attemptの再実行

- 同じ問題ID・試行ID・outcome・reasonは一度だけ反映する。同じIDでoutcomeまたはreasonが変わった場合はエラーとして保存しない。
- 試行履歴は成功/reset後も保持し、遅れて届いた古い失敗・成功・resetで現在の回数を変更しない。出力のstatus/failuresは元の試行時点ではなく現在のカウンターを返す。
- 試行IDは問題ID内で一意。新しい試行には新しいIDを使う。既存stateのカウンターは保持するが、IDのない過去の記録は遡って重複判定できない。

## 検証

- 機能適合性・信頼性・セキュリティを対象に、境界値・判断表・状態遷移・エラー推測で判定と状態保持を検証する。
- マージ判定は機能適合性・信頼性を対象に判断表で各阻止条件、境界値でEYES件数と失敗回数、状態遷移でack・thread解決・CI完了後の解除を確認する。取得後の外部変更は再取得とHEAD照合で軽減するが、GitHub側のbranch protectionによる最終検証が必要。
- レビュー完了は状態遷移・エラー推測で、返信/resolve成功直後の通信切断、再実行、未確認resolve、HEAD/コメント変更、再openを検証する。返信・resolve各1回、確認前のack禁止を受け入れ条件とする。
- マージは判断表・状態遷移・エラー推測で新規コメント・HEAD不一致・👀・応答消失・既マージを確認する。阻止時の書き込み禁止、再実行時のマージmutation省略が受け入れ条件。
- cleanupは一時Gitリポジトリで削除・再実行・worktree削除直後の中断を検証する。未保存/ignored・追加commit・使用中/共有・証拠の鮮度・再作成を保持することが受け入れ条件。
- 通知は送信前記録・送達不明・証拠付き未送信/成功・PR状態変更の状態遷移を検証する。未確認通知の再dispatch・ack・状態削除を禁止する。
- attemptは機能適合性・信頼性を対象に境界値・状態遷移・判断表で検証する。同一試行の再送、2→3回のhold境界、成功/reset、古い試行の遅延再送、ID衝突・既存stateの移行を確認する。
- GitHub書き込みとアプリ操作・lsof結果はモックで確認。実GitHub・アプリとの結合、別ホストの同時操作、API読み書き間の外部変更に対する原子的保証は対象外。

```bash
python3 -m unittest discover -s <skill-dir>/scripts -p 'test_*.py'
```
