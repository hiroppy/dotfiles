# 継続監視・終了処理

監視の登録/変更、終了、+1通知のときだけ読む。

## 継続監視

「1回だけ」「ループ不要」は設定しない。継続監視にはCodexのheartbeat automationを使い、既存の同じPRの監視があれば更新・再利用する。明示的に停止/一時停止された監視は勝手に再開しない。

promptにはPR URL、repo/number、作業worktree、承認範囲・保留事項を入れ、毎回の最初に上のcheckコマンドを1回実行して結果だけを見ることを指定する。全GitHub履歴の再取得をpromptへ書かない。通常1分、Draft5分を目安に、ユーザー指定を優先する。登録後は対象、間隔、有効状態を確認する。

CI greenやreview通過だけで終了せずmerged/closedまで続ける。未対応イベントがなく、通知すべき変化もない場合だけ通知しない。未対応イベントが残る場合は前回と同じ状態でも対応を続け、進められない場合は理由と必要な判断を通知する。この条件をautomationのpromptにも明記する。状態確認は `check.py status --repo OWNER/REPO --pr NUMBER` で最終取得成功時刻、エラー、未対応件数を見られる。

この方式でもheartbeatごとのモデル起動は残る。節約するのは毎回のコマンド選択・大量の取得結果の読解であり、待機中の消費がゼロになるとは説明しない。既存automationのpromptはskill変更だけでは置き換わらない。

## +1通知

`thumbs_up`イベントは、PRに付いた+1を投稿者とPR URLとともに通知してからackする。Codexの+1もコメントやHEADの状態に依存せず通知する。同じリアクションは一度だけ通知する。+1だけをreview通過やマージ許可として扱わない。

## 終了・cleanup

mergedなら、実行中プロセス、未commit/未push変更、共有/pin状態を確認する。リポジトリに明示されたdisposeだけを実行し、成功または不要を確認してworktreeを退役させ、安全に削除できるローカルブランチを削除する。

Codex管理worktreeはarchive_worktreeを使う。通常のGit worktreeは安全な別ディレクトリからgit worktree removeとgit branch -dを使う。未保存・未push・使用中の作業を削除しない。cleanup失敗ならworktreeと状態を保持して通知し、未完了作業を再開できるようにする。

未マージcloseはコード・worktree・ブランチを残す。必要なcleanup・報告完了後、対象の監視automationを削除する。停止指示では監視だけ解除、一時停止だけPAUSEDを使う。他のPRやタスク履歴は変更しない。
