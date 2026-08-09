---
title: "ci-platform Release Notes v0.3.4"
version: "0.3.4"
date: 2026-08-09
tags:
  - release
  - documentation
summary: >
  v0.3.4 では、dprint・markdownlint の MDX 対応、ドキュメントサイトの脆弱な依存関係の修正、
  開発環境設定とランナースクリプトの標準化を行いました。
---

## [0.3.4] - 2026-08-09

### Overview

このリリースでは、ドキュメント整形ツールチェーンの MDX 対応を追加しました。

あわせてドキュメントサイトの脆弱な依存関係を修正し、
開発環境設定・ランナースクリプト・セットアップスクリプトを標準化しています。

コンポジットアクションおよび再利用可能ワークフローのインターフェースに変更はありません。
`action.yml`・`ru-*.yml` は v0.3.3 から変更がないため、
外部から利用する場合は完全な後方互換性を保っています。

---

### Added

#### ドキュメントツール

- `dprint`: `.mdx` ファイルの整形に対応しました。
- `markdownlint`: ネストした `siblings_only` オプションと MDX の強調表現に対応しました。
- VS Code: `.mdx` ファイル向けの Markdown 整形設定を追加しました。

---

### Fixed

- `dprint`: markdown associations キーのタイポを修正しました。
  これにより、意図したファイルパターンがマッチしない不具合を解消しています。
- ドキュメントサイトの脆弱な依存関係を更新しました。

---

### Changed

#### ドキュメント

- Docusaurus サイトを `aglabo.github.io` へ移行しました。
- すべてのドキュメントで文体を統一しました。

#### 開発環境

- 開発環境設定・ランナースクリプト・`setup-dev-env.sh` を標準化しました。
- `commitlint.config.cjs` を `commitlint.config.mjs` にリネームしました。
- ランナーライブラリのテストを `runners/libs/__tests__/` へ移動しました。
- 使われなくなった PowerShell セットアップスクリプトを削除しました。
  対象は `install-dev-tools.ps1`・`install-doc-tools.ps1`・`libs/AgInstaller.ps1`・`common/init.ps1` です。
- 役割を終えた `scripts/run-specs.sh`・`scripts/lint-actionlint.sh` を削除しました。

---

### Notes

- 本リリースの `.github/actions/**/scripts/` 配下の変更は `shfmt` による整形のみです。
  リダイレクトの空白・`case` のインデント・文の分割が対象で、動作の変更はありません。
- 削除した PowerShell スクリプトおよび改修した `runners/` 配下のスクリプトは、
  リポジトリ内部の開発用ツールであり、バージョニングの対象範囲外です。
