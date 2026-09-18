---
title: "ci-platform Release Notes v0.3.5"
version: "0.3.5"
date: 2026-09-18
tags:
  - release
  - documentation
summary: >
  v0.3.5 では、ドキュメントサイトの脆弱な依存関係をすべて解消し、pnpm・Node.js の
  バージョン要件を統一しました。あわせて textlint の MDX 対応と、リポジトリ設定の
  allowlist 化を行っています。
---

## [0.3.5] - 2026-09-18

### Overview

このリリースでは、ドキュメントサイトに残っていた Dependabot アラートをすべて解消しました。

あわせて pnpm・Node.js のバージョン要件をリポジトリ全体で統一し、
`.gitignore` を allowlist 方式へ切り替えています。
ドキュメント側では textlint の MDX 対応を追加しました。

コンポジットアクションおよび再利用可能ワークフローのインターフェースに変更はありません。
`action.yml`・`ru-*.yml` の `on`・`inputs`・`outputs` のキーは v0.3.4 と同一であり、
呼び出し側の修正は不要です。

ただし `ca-setup-repo` の入力 `pnpm-version` の既定値を `"10"` から `"11.22.0"` に変更しています。
本入力を明示的に指定していない利用者は、pnpm 11.22.0 で動作する点にご留意ください。

---

### Added

#### ドキュメントツール

- `textlint`: MDX プラグインを有効化しました。これにより `.mdx` ファイルを検証対象に含められます。
- `run-textlint.sh`: キャッシュを有効化しました。キャッシュは `.cache/textlint/textlintCache` に保存されます。

---

### Fixed

- ドキュメントサイトの脆弱な依存関係をすべて更新し、Dependabot アラートを解消しました。
  対象は `joi` (18.2.9)・`react` / `react-dom` (19.3.0)・`nanoid` (3.3.18)・`js-yaml`・`fast-uri` です。

---

### Changed

#### GitHub Actions

- `ca-setup-repo`: 入力 `pnpm-version` の既定値を `"10"` から `"11.22.0"` に変更しました。
- `pnpm/action-setup` を v6.0.10 から v6.1.0 に更新しました。
- `actions/deploy-pages` を v5.0.0 から v5.0.1 に更新しました。
- 再利用可能ワークフローおよびコンポジットアクションの参照 SHA を、
  v0.3.4 のコミット (`d49d965`) に統一しました。
- `ci-publish-docs.yml`: pnpm のバージョン指定を削除し、`package.json` の `packageManager` に委譲しました。

#### 開発環境

- `package.json`: `packageManager` に `pnpm@12.4.2` を追加し、`engines` に `node >=24`・`pnpm >=12` を追加しました。
- `aglabo.github.io/package.json`: 同様に pnpm 12.4.2 と Node.js 24 以降を要求するよう統一しました。
- `.gitignore` を allowlist 方式に変更しました。
  既定ですべてを無視し、リポジトリの構成要素を明示的に許可する方式です。
- `.claude/.gitignore`: `.git*` の許可パターンを `.gitignore` のみに絞り込みました。
- `aglabo.github.io/.gitignore`: `versioned_sidebars` ディレクトリを追跡対象に追加しました。
- `dprint`: TypeScript・JSON・Markdown・YAML・TOML の各プラグインを npm パッケージ形式へ移行しました。
  あわせて JSON・Markdown プラグインを 0.24.0 に、TOML プラグインを 0.8.0 に更新しています。
- `.editorconfig`: shell・PowerShell の整形設定を専用セクションへ集約し、重複した shfmt 設定を削除しました。
- `lefthook.yml`: `prepare-commit-msg` のモデル指定を `gpt-5.4-mini` から `gpt-5.6-luna` に変更しました。

#### ドキュメント

- pnpm の既定バージョン表記を `11.22.0` に更新しました。
  対象はユーザーガイドおよび `docs/.deckrd/` 配下の設計ドキュメントです。
- 句読点・括弧表記を統一し、ネストした箇条書きのインデントを Markdown 形式に揃えました。

---

### Notes

- 本リリースにコンポジットアクション・再利用可能ワークフローのインターフェース変更は含まれません。
  変更はピン留め SHA の更新と、`ca-setup-repo` の `pnpm-version` 既定値の変更のみです。
- `.gitignore` の allowlist 化・`engines` の追加・`.editorconfig` の整理は、
  リポジトリ内部の開発環境に対する変更であり、バージョニングの対象範囲外です。
