---
title: "ci-platform Release Notes v0.8.0"
version: "0.8.0"
date: 2026-11-19
tags:
  - release
  - reusable-workflows
  - composite-actions
summary: >
  This release resolves tool configurations in the reusable workflows via
  _ca-resolve-config, adds validate_path for root-confined path validation,
  and aligns all composite actions, reusable workflows, and the package version to v0.8.0
---

## ci-platform v0.8.0 - 2026-11-19

再利用可能ワークフローが、ツールの設定ファイルを `_ca-resolve-config` で解決するようになりました。
パスの検証を共通化し、すべての Composite Action、再利用可能ワークフロー、パッケージのバージョンを v0.8.0 に揃えています。

## 主な変更

### ツール設定の解決

- `ru-lint-documents.yml` が textlint と markdownlint の設定を解決するようになりました。`ru-scan-secrets.yml` も betterleaks の設定を解決します。
- `ru-qa-actionlint.yml` (jactionlint) と `ru-qa-ghalint.yml` (ghalint) に、ローカル設定へのフォールバックを追加しました。

### パス検証の共通化

- `_libs/path.lib.sh` に `validate_path` を追加しました。ルート配下に収まるパスだけを受け付けます。
- 空の値、`..` を含むパス、空白を含むパス、ルートの外を指すパス (シンボリックリンク経由を含む) は拒否します。
- `_ca-resolve-config` のパス検証を `validate_path` に置き換えました。

### バージョンの統一

- すべての Composite Action の `# @version` ヘッダーを 0.8.0 に更新しました。
- 再利用可能ワークフロー (`ru-*.yml`) の `# @version` ヘッダーを 0.8.0 に更新しました。
- `package.json` のバージョンを 0.8.0 に更新しました。

## 移行時の注意

- 空白を含む設定ファイルのパスは、拒否されるようになりました。該当するパスを指定している場合は、空白を含まないパスに変更してください。
- ルートの外を指すシンボリックリンクの設定ファイルも、拒否されるようになりました。
- 参照タグを `v0.8.0` に更新してください。

## 開発者向けの改善

- `validate_path` と `_ca-resolve-config` に、シンボリックリンクや空白のパスを対象にした ShellSpec テストを追加しました。
- Composite Action のテストで、`ca-setup-tool` の検証対象を actionlint から jactionlint 2.6.0 に変更しました。
- `ca-setup-repo` の `action.yml` に、著作権表示と MIT ライセンスのヘッダーを追加しました。
- VS Code の設定で Markdown の検証を有効にし、cspell の辞書に `ACMR` を追加しました。
- Deckrd の設計ドキュメントを更新しました。
  追加分は `resolve-config`、`run-secretlint`、`validate-environment`、`actions-lock`、`lint-documents`、`secretlint` です。
