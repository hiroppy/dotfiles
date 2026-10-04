# 継続監視・終了処理

監視の登録/変更、終了、通過通知のときだけ読む。

## 継続監視

「1回だけ」「ループ不要」は設定しない。継続監視にはCodexのheartbeat automationを使い、既存の同じPRの監視があれば更新・再利用する。明示的に停止/一時停止された監視は勝手に再開しない。

promptにはPR URL、repo/number、作業worktree、承認範囲・保留事項を入れ、毎回の最初に上のcheckコマンドを1回実行して結果だけを見ることを指定する。全GitHub履歴の再取得をpromptへ書かない。監視はPRごとにheartbeatを1本使う。通常は1分間隔とし、checkの`recommendedIntervalMinutes`が変わったらそのheartbeatを更新する。現在のHEADにCodex botの新しい+1が付いたら20分間隔、新しいHEADを検知したら1分間隔へ戻す。時間帯では切り替えない。Draftは5分を目安にし、ユーザーの個別指定を優先する。登録・変更後は対象、間隔、有効状態を確認する。明示的に一時停止された監視は設定変更しても再開しない。

CI greenやreview通過だけで終了せずmerged/closedまで続ける。未対応イベントがなく、通知すべき変化もない場合だけ通知しない。未対応イベントが残る場合は前回と同じ状態でも対応を続け、進められない場合は理由と必要な判断を通知する。この条件をautomationのpromptにも明記する。状態確認は `check.py status --repo OWNER/REPO --pr NUMBER` で最終取得成功時刻、エラー、未対応件数を見られる。

この方式でもheartbeatごとのモデル起動は残る。節約するのは毎回のコマンド選択・大量の取得結果の読解であり、待機中の消費がゼロになるとは説明しない。既存automationのpromptはskill変更だけでは置き換わらない。

## Codexの+1通知

check.pyの`codex_passed`イベントを受けたら、対象PRとHEADを添えて `Codexの 👍` をユーザーへ通知し、通知後にackする。判定にはPRへのCodex botの+1だけを使い、サマリーコメントには依存しない。HEAD変更時に既存のリアクションIDを基準として記録し、その後の新しい+1だけを現在のHEADの通過として扱う。通知済みHEADはリアクションの削除・再追加後も再通知しない。+1をレビュー完了やマージ許可と断定しない。

監視を実行するたびにcheck結果の`recommendedIntervalMinutes`に合わせ、20なら監視対象チャットのタイトルの先頭に `👍 ` を1つ付け、それ以外なら監視が付けた先頭の `👍 ` を外す。タイトルの残りは変えない。

## 終了・cleanup

mergedなら、実行中プロセス、未commit/未push変更、共有/pin状態を確認する。リポジトリに明示されたdisposeだけを実行し、成功または不要を確認してworktreeを退役させ、安全に削除できるローカルブランチを削除する。

Codex管理worktreeはarchive_worktreeを使う。通常のGit worktreeは安全な別ディレクトリからgit worktree removeとgit branch -dを使う。未保存・未push・使用中の作業を削除しない。cleanup失敗ならworktreeと状態を保持して通知し、未完了作業を再開できるようにする。

未マージcloseはコード・worktree・ブランチを残す。必要なcleanup・報告完了後、対象の監視automationを削除する。停止指示では監視だけ解除、一時停止だけPAUSEDを使う。他のPRやタスク履歴は変更しない。
