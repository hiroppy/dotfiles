---
name: pr-monitor
description: Monitor GitHub PRs using a bundled check script; fix CI failures, merge conflicts, and review feedback. Use for PR監視, watch pr, fix ci, コンフリクト解消, and レビュー対応.
---

# PR Monitor

Python 3・認証済みgh CLI・Gitを使う。

```bash
python3 <skill-dir>/scripts/check.py check --repo OWNER/REPO --pr NUMBER
```

`check` の `nextStep` と `next` の出力を、どちらも次の手順として扱う。
`action_required` は操作と結果の記録を済ませて `next`、`check_required` は指定された `command` を実行する。

`continue_required` が返ったら、その場で待機ツールを呼び、`waitSeconds` 秒後に出力の `command`（`check`）を実行する。シェルで待つ場合は `sleep <waitSeconds> && <command>` を実行し、セッションが返ったら結果が出るまで待つ。新しい `check` の `nextStep` を読み、同じ手順を繰り返す。

最終回答を出すのは `canEndTurn: true` が返ってから。CI 成功や `canMerge: true` の報告は、監視を継続する間は進捗として伝える。

コマンド契約・実装の検証は[script.md](references/script.md)を参照する。
