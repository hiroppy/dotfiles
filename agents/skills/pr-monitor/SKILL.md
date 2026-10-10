---
name: pr-monitor
description: Monitor GitHub PRs using a bundled check script; fix CI failures, merge conflicts, and review feedback. Use for PR監視, watch pr, fix ci, コンフリクト解消, and レビュー対応.
---

# PR Monitor

Python 3・認証済みgh CLI・Gitを使う。

```bash
python3 <skill-dir>/scripts/check.py check --repo OWNER/REPO --pr NUMBER
```

JSONの`nextStep`を実行し、結果記録後は同じ引数で`next`を呼ぶ。操作順・完了条件・再実行・継続監視はscriptが返す。`canEndTurn: false`では継続する。「1回だけ」の依頼は`check --once`。

コマンド契約・実装の検証は[script.md](references/script.md)を参照する。
