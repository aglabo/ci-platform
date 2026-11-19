---
title: secretlint
test_scope: SLW
owns:
  - .github/workflows/ru-scan-secrets.yml
---

## secretlint

再利用可能ワークフロー `ru-scan-secrets.yml` のうち、`scan-secretlint` ジョブを扱うモジュール。
同じファイルの `scan-betterleaks` ジョブは `reusable-workflows/betterleaks` が扱う。
`owns` のワークフローファイルは、両モジュールが共有するファイルを指す。
`test_scope` を宣言するモジュールは本モジュールだけであり、betterleaks 側には `module.md` がない。

`scan-secretlint` は、対象リポジトリをチェックアウトし、Composite Action `ca-run-secretlint` を呼び出す。
secretlint のバージョンと pnpm のバージョンは入力で受け取る。
現時点でこのワークフロー専用の ShellSpec テストはない。検証は `jactionlint` と `yq` による静的検査で行う。
Action 側のテストは `composite-action/run-secretlint` が所有する。
