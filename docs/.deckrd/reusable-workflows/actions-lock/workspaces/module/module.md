---
title: actions-lock
test_scope: ALK
owns:
  - .github/workflows/ru-qa-actions-lock.yml
---

## actions-lock

再利用可能ワークフロー `ru-qa-actions-lock.yml` を扱うモジュール。
`gh actions-lock` 拡張をインストールし、`.github/workflows/actions.lock` が現在のワークフローと一致するかを `--verify` で検査する。
設定ファイルは使わないため、`_ca-resolve-config` も使わない。
現時点でこのワークフロー専用の ShellSpec テストはない。検証は `jactionlint` と `yq` による静的検査で行う。
