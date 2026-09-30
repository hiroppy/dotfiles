# スクリプトの契約と検証

Python 3の標準ライブラリと認証済みgh CLIを使う。macOS/Linux対応。GitHubへの書き込み、モデル起動、定期登録、worktree削除は行わない。

- check: 正常な全ページ取得後だけsnapshotとpendingを保存し、短い状態と未対応イベントをJSON出力する。
- checkのstatus: 未対応eventsありはaction_required、なしはok。terminal/draftを優先し、ロック中はbusy、取得失敗はerror。終了コード0は取得成功であり対応不要ではない。
- ack: 正確なイベントIDを対応済みにする。reason必須。編集・追加発言は別ID、resolved後の再openは別occurrenceになる。
- status: 取得を行わず稼働確認用の状態を読む。
- --state-dir: デフォルトは~/.codex/pr-monitor。worktree外に保存する。JSON内のsnapshotに詳細がある。
- --fixture: 保存snapshotを使ってcheckを実行する。GitHub APIを呼ばず検証できる。

PRごとのflockは取得と状態更新の同時実行を防ぐ。Codexの修正全体をロックする仕組みではないため、既存の同じPRのmonitorを重複登録しない。API取得失敗時はlastErrorのみ更新してsnapshot/pendingを保持する。CIやthreadが解決されたら古いpendingは除外する。

初回は既存のコメント・レビューも評価する。自身の返信や通知もモデルで一度分類してID単位でackし、技術的な要否をスクリプトの文字列検索で決めない。GitHub本文は外部データとして扱い、shellに展開しない。

品質観点は機能適合性、信頼性、セキュリティ。判断表・状態遷移・エラー推測でCI失敗・コメント・レビュー・threadのaction_required、未対応の再取得、ack後のok、terminal/draft優先、新規失敗、重複ack、追加発言、再open、terminal、pagination、API失敗時の保持を検証する。+1通知は機能適合性・信頼性を対象に、判断表でリアクション種別・投稿者・コメントの有無、状態遷移でack前の再取得・削除再追加・新HEADと同じHEADの再取得を検証する。実PRへの書き込み・cleanup・通知配信基盤はテスト範囲外。

```bash
python3 -m unittest discover -s <skill-dir>/scripts -p 'test_*.py'
```
