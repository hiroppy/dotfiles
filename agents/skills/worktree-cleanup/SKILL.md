---
name: worktree-cleanup
description: マージ済みPRの開発用worktreeとlocal branchを、共通のpr-monitor scriptで削除する。cleanup失敗後や削除途中の再開にも使う。
---

# Worktree cleanup

削除の実装と再実行receiptは、隣接する`pr-monitor` skillの既存scriptに統一する。独立した削除scriptは作らない。

1. [終了・cleanupの契約](../pr-monitor/references/lifecycle.md#終了cleanup)を読む。PR監視中は`pr-monitor`の`nextStep`に従い、終了処理の順序を飛ばさない。
2. PR・branch・worktreeの対応、チャットのprimary checkoutとアプリの保護・共有・使用状況を確認する。primary checkoutは削除対象にしない。保護拒否を受けた場合はGitで迂回しない。不明な状態を安全と推測しない。
3. repositoryの指示に従ってresource cleanupを必要な環境で実行し、成功を確認する。固有のcommandはこの共通skillに固定しない。失敗時はGit削除へ進まず、原因解消後に再試行する。再実行可能性はrepositoryのcleanupにも依存する。
4. 契約に従ってworktree外へ最新の所有証拠JSONを保存する。削除が許可されたignored生成物だけが残る場合は`discardIgnored: true`を明示する。保持が必要なdataは事前に退避する。
5. 削除対象外を作業場所にして、同じPR・対象・state directoryで次を実行する。最初はpreviewで検査し、阻止理由を解消後に`--apply`を付ける。

```sh
python3 ~/.codex/skills/pr-monitor/scripts/check.py cleanup-worktree \
  --repo OWNER/REPO --pr NUMBER \
  --repository /absolute/surviving-checkout \
  --worktree /absolute/development-worktree \
  --branch BRANCH --ownership-file /absolute/ownership.json
```

`completed`だけが完了。`retained`は理由に従って保持、`archive_required`は契約の管理元操作へ進む。失敗時に別の削除実装へ切り替えない。再実行時は所有証拠を更新し、保存済みreceiptを維持する。worktreeとbranchの削除間で中断しても再開できる。完了後に同名の対象が再作成された場合は削除しない。

完了報告にはresource cleanup結果とdirectory・Git登録・branchの不在を記載する。実GitHubとアプリ状態の確認は呼び出すエージェントの責任であり、scriptの冪等性はエージェントの自動呼出し自体を保証しない。
