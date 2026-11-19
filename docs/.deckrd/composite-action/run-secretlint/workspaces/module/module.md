---
title: run-secretlint
test_scope: RSL
owns:
  - .github/actions/ca-run-secretlint/**
---

## run-secretlint

公開 Composite Action `ca-run-secretlint` を扱うモジュール。
リポジトリはチェックアウト済みを前提とし、Action 自身が pnpm をセットアップする (`pnpm/action-setup`)。
続けて `pnpm dlx secretlint@<version>` を引数なしで実行する。
入力の検証を持つ。バージョンは major が 14 以上の X.Y.Z のみとする。
secretlint v14 以降は設定を同梱するため、設定ファイルは指定しない。
チェックアウトと Node.js のセットアップは行わない (Node.js は GitHub-hosted ランナーのものを使う)。

## テスト対象の略語

| 略語  | 対象                                 |
| ----- | ------------------------------------ |
| `VER` | `validate_secretlint_version`        |
| `RUN` | `run-secretlint.sh` の `main`        |
| `ACT` | `action.yml` (静的検査)              |
