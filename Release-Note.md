---
title: "ci-platform Release Notes v0.6.0"
version: "0.6.0"
date: 2026-11-03
tags:
  - release
  - documentation
summary: >
  This release adds reusable workflows for document linting and action lock
  verification, and switches the default lint configuration to aglabo/global-configs
---

## ci-platform v0.6.0 - 2026-11-03

Markdown ドキュメントの lint と、Action ロックファイルを検証する再利用可能ワークフローを追加しました。
あわせて、lint とシークレットスキャンの再利用可能ワークフローが、既定で `aglabo/global-configs` の設定を使用するようになりました。

## 主な変更

### ドキュメント lint 用の再利用可能ワークフローを追加

- `ru-lint-documents.yml` を追加しました。変更された Markdown ファイルに対して textlint と markdownlint を実行し、
  失敗時はレポートを出力します。
- `pattern` 入力で対象ファイルを絞り込めます。push / pull_request 以外のイベントでは、`commit-count` 入力で差分の範囲を指定できます。

### Action ロックファイルの検証用ワークフローを追加

- `ru-qa-actions-lock.yml` を追加しました。`.github/workflows/actions.lock` とワークフローの Action 参照が一致しているかを検証し、
  失敗時はレポートをアップロードします。

### lint 設定の取得元を `aglabo/global-configs` に変更

- lint とシークレットスキャンの再利用可能ワークフローは、既定で `aglabo/global-configs` の設定を使用します。
  対象は `ru-qa-actionlint.yml`、`ru-qa-ghalint.yml`、`ru-scan-betterleaks.yml` です。
- 既定の設定ファイルのパスが `./shared/configs/` から `./global/configs/` に変わりました。

## 移行時の注意

- `config` 入力に `./shared/configs/...` を明示的に指定している場合は、`./global/configs/...` に変更してください。
- `ru-scan-betterleaks.yml` で `config-repo` を指定していない場合は、設定の取得元が変わります。
  変更前は `aglabo/.github`、変更後は `aglabo/global-configs` です。

## 開発者向けの改善

- ドキュメント QA ワークフロー (`ci-docs-qa.yml`) を追加し、ワークフローの QA で Action ロックファイルを検証するようにしました。
- Dependabot で GitHub Actions の更新を毎日確認するようにしました。
