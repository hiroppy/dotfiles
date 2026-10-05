# 継続監視・終了処理

## 監視

- PRごとにheartbeatを1本使い、既存監視を再利用する。「1回だけ」は登録しない。
- 停止済み監視はユーザー指示で再開し、最初のcheckに`--reset-idle`を付ける。
- 間隔は`recommendedIntervalMinutes`に従う。ユーザー指定がある場合はcheckへ`--interval-minutes N`を渡す。
- 登録・変更後に対象・間隔・有効状態を確認する。

promptに以下を入れ、既存監視にも反映する。

- PR URL、repo/number、worktree、承認範囲・保留事項。
- 毎回checkを1回実行し、未対応イベントを処理する。進められなければ理由と必要な判断を通知する。
- `stopRequested: true`ならPAUSEDにし、PRと「20分間変化なしで監視停止」を一度通知する。worktree・ブランチは保持する。
- 未対応イベントも通知すべき変化もなければ静かに終了する。

## Codexの+1

- `codex_passed`を受けたらPRとHEADを添えて `Codexの 👍` を通知後、ackする。検出・HEADごとの重複防止はスクリプトに任せる。+1をマージ許可と扱わない。

- 毎回`codexReactionPresent`に合わせてチャットタイトル先頭の `👍 ` を1つ付け外しする。残りのタイトルは保持する。

## 終了・cleanup

- mergedなら未commit/未push変更、実行中プロセス、共有/pin状態を確認する。指定されたdisposeを実行後、安全なworktreeとローカルブランチを削除する。

- Codex管理worktreeは`archive_worktree`、通常のworktreeは別ディレクトリから`git worktree remove`と`git branch -d`を使う。未保存・未push・使用中の作業は保持し、cleanup失敗を通知する。

- 未マージcloseでは作業を保持する。cleanup・報告後に対象automationを削除する。停止指示では監視だけ解除、一時停止ではPAUSEDにする。
