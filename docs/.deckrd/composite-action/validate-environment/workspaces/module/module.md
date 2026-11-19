---
title: validate-environment
test_scope: VEN
owns:
  - .github/actions/ca-validate-environment/**
---

<!-- textlint-disable
  ja-technical-writing/sentence-length,
  ja-technical-writing/max-comma,
  ja-technical-writing/no-doubled-joshi,
  ja-technical-writing/no-mix-dearu-desumasu,
  ja-technical-writing/ja-no-redundant-expression,
  @textlint-ja/no-synonyms
  -->
<!-- markdownlint-disable line-length -->

## validate-environment

公開 Composite Action `ca-validate-environment` の実行環境検証を扱うモジュール。
ランナー環境 (OS・アーキテクチャ・GitHub Actions 環境変数)、GitHub トークンの権限、必須アプリケーションの 3 領域を、
3 本のスクリプトで検証する。ワークフローの最初のジョブステップから呼び出され、後続ステップの前提を保証するゲートとして働く。

共有ライブラリ `.github/actions/_libs/` のテストは、本モジュールの所有ではない。
ただし、`check_env_var` (`env.lib.sh`) は `validate-git-runner` のユニットテストが本モジュール側で検証している。

## テスト対象の略語

テストコードのグループ ID に使う `target` 略語の対応表。
既存のスペックファイルはテスト ID を付与していない。付与は別タスクとし、付与時は本表の略語を使う。

| 略語   | 対象                                           |
| ------ | ---------------------------------------------- |
| `DOS`  | `detect_os`                                    |
| `DAR`  | `detect_architecture`                          |
| `NAR`  | `normalize_architecture`                       |
| `VOS`  | `validate_os`                                  |
| `VEA`  | `validate_expected_arch`                       |
| `ISA`  | `is_supported_architecture`                    |
| `VAM`  | `validate_arch_match`                          |
| `VGA`  | `validate_github_actions_env`                  |
| `VGH`  | `validate_github_hosted_runner`                |
| `VRV`  | `validate_runtime_variables`                   |
| `VGR`  | `validate_git_runner`                          |
| `CEV`  | `check_env_var` (共有ライブラリ)               |
| `CCU`  | `check_curl`                                   |
| `DBB`  | `determine_base_branch`                        |
| `GAP`  | `github_api_post`                              |
| `PGW`  | `probe_github_write_permission`                |
| `CGT`  | `check_github_token`                           |
| `VPM`  | `validate_permissions`                         |
| `ISR`  | `is_safe_regex`                                |
| `EVR`  | `extract_version_by_regex`                     |
| `EVN`  | `extract_version_number`                       |
| `CKV`  | `check_version`                                |
| `GAV`  | `get_app_version`                              |
| `ISC`  | `is_safe_command`                              |
| `VAF`  | `validate_app_format`                          |
| `VAE`  | `validate_app_exists`                          |
| `VAV`  | `validate_app_version`                         |
| `VAS`  | `validate_app_special`                         |
| `CJQ`  | `check_jq`                                     |
| `CGA`  | `check_gh_authentication`                      |
| `HVE`  | `handle_validation_error`                      |
| `IAL`  | `initialize_apps_list`                         |
| `VAP`  | `validate_apps`                                |
| `MAIN` | `validate-apps.sh` の `main`                   |
| `ACT`  | `action.yml` (static checks)                   |
