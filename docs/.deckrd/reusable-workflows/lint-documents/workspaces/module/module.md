---
title: lint-documents
test_scope: LDC
owns:
  - .github/workflows/ru-lint-documents.yml
---

## lint-documents

再利用可能ワークフロー `ru-lint-documents.yml` を扱うモジュール。
変更された Markdown ファイルを取得し、textlint と markdownlint を別ジョブで実行する。
設定ファイルは `_ca-resolve-config` で解決する。
現時点でこのワークフロー専用の ShellSpec テストはない。検証は `jactionlint` と `yq` による静的検査で行う。
