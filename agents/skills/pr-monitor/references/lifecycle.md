# 継続監視・終了処理

監視の登録/変更、終了、通過通知のときだけ読む。

## 継続監視

「1回だけ」「ループ不要」は設定しない。継続監視にはCodexのheartbeat automationを使い、既存の同じPRの監視があれば更新・再利用する。明示的に停止/一時停止された監視は勝手に再開しない。

promptにはPR URL、repo/number、作業worktree、承認範囲・保留事項を入れ、毎回の最初に上のcheckコマンドを1回実行して結果だけを見ることを指定する。全GitHub履歴の再取得をpromptへ書かない。通常1分、Draft5分を目安に、ユーザー指定を優先する。登録後は対象、間隔、有効状態を確認する。

CI greenやreview通過だけで終了せずmerged/closedまで続ける。変化なしでは通知しない。状態確認は `check.py status --repo OWNER/REPO --pr NUMBER` で最終取得成功時刻、エラー、未対応件数を見られる。

この方式でもheartbeatごとのモデル起動は残る。節約するのは毎回のコマンド選択・大量の取得結果の読解であり、待機中の消費がゼロになるとは説明しない。既存automationのpromptはskill変更だけでは置き換わらない。

## Codex reviewの通過通知

check.pyの`codex_passed`イベントを受けたら、対象PRとHEADを添えて `Codex reviewの 👍` をユーザーへ通知し、通知後にackする。check.pyがCodex作者のcompleted summaryと現在HEAD、PRへのbotの+1を照合する。通知済みHEADはリアクションの削除・再追加後も再通知しない。+1単独、別作者、古いHEAD、未対応のsummary形式では通知しない。通知からマージ許可を推測しない。

## 終了・cleanup

mergedなら、実行中プロセス、未commit/未push変更、共有/pin状態を確認する。リポジトリに明示されたdisposeだけを実行し、成功または不要を確認してworktreeを退役させ、安全に削除できるローカルブランチを削除する。

Codex管理worktreeはarchive_worktreeを使う。通常のGit worktreeは安全な別ディレクトリからgit worktree removeとgit branch -dを使う。未保存・未push・使用中の作業を削除しない。cleanup失敗ならworktreeと状態を保持して通知し、未完了作業を再開できるようにする。

未マージcloseはコード・worktree・ブランチを残す。必要なcleanup・報告完了後、対象の監視automationを削除する。停止指示では監視だけ解除、一時停止だけPAUSEDを使う。他のPRやタスク履歴は変更しない。

