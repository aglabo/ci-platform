---
title: セキュリティモデル
description: ci-platform のセキュリティ設計・最小権限原則・シークレット検出・保護領域
slug: developer-guide/security-model
sidebar_position: 5
tags:
  - ci-platform
  - developer-guide
  - security
---

## セキュリティモデル

ci-platform のセキュリティ設計は**多層防御**と**最小権限原則**の 2 原則を基盤としています。
ローカル開発から CI パイプラインまで、複数のレイヤーで独立したセキュリティ検証を行います。

---

## 🔐 設計の 2 原則

### 最小権限原則

GitHub Actions のすべてのワークフロー・アクションは、必要最小限の権限のみを要求します。

<!-- textlint-disable ja-hiraku -->

- デフォルト権限: `contents: read` (読み取り専用)
- `contents: write`、`id-token: write` は明確な理由がある場合のみ追加
- `ghalint` によって権限設定を自動検証

<!-- textlint-enable ja-hiraku -->

### 多層防御

単一の検出ポイントへの依存を避け、ローカルと CI の 2 レイヤーで独立してセキュリティ検証を行います。
いずれか一方が機能しない状況でも、もう一方が問題を捕捉できる体制を維持します。

---

## 🛡️ シークレット検出の多層構造

<!-- markdownlint-disable line-length MD060 -->

| ツール     | 実行タイミング | 対象                               | 役割                                 |
| ---------- | -------------- | ---------------------------------- | ------------------------------------ |
| gitleaks   | ローカル       | コミット前の差分                   | コミット前のシークレット漏洩を阻止   |
| secretlint | ローカル       | コミット前のファイル               | 認証情報パターンの検出・阻止         |
| gitleaks   | CI             | リポジトリ全体 (全コミット履歴)    | ローカルを通過した漏洩を CI で捕捉   |

<!-- markdownlint-enable line-length MD060 -->

<!-- textlint-disable ja-hiraku -->

**ローカル検出 (gitleaks + secretlint)**:

lefthook の `pre-commit` フックで実行されます。
開発者がコミットを作成する前にシークレットを検出し、コミット自体を拒否します。

**CI 検出 (gitleaks)**:

GitHub Actions で実行されます。
リポジトリ全体の履歴をスキャンし、ローカル検出をすり抜けた漏洩を捕捉します。

<!-- textlint-enable ja-hiraku -->

---

## 🔑 権限管理

### ghalint による自動検証

`ghalint` は GitHub Actions ワークフローの権限設定を静的解析します。

<!-- textlint-disable ja-hiraku -->

- `permissions` セクションが未定義のジョブを検出する
- 過剰権限 (`write` 系の不必要な権限) を検出する
- CI パイプライン内で自動実行され、違反があれば失敗する

<!-- textlint-enable ja-hiraku -->

### validate-environment の動的権限検証

`validate-environment` は CI 実行時に権限設定を動的に検証します。

<!-- markdownlint-disable line-length MD060 -->

| 検証項目                    | 内容                                                           |
| --------------------------- | -------------------------------------------------------------- |
| `contents: write` の検出    | 書き込み権限が設定されている場合に警告・停止                   |
| `id-token: write` の検出    | OIDC トークン発行権限が不要な場面で使われていないかを確認      |

<!-- markdownlint-enable line-length MD060 -->

---

## 🗂️ レイヤー別セキュリティ施策

### ローカルレイヤー (Git Hooks)

<!-- textlint-disable ja-hiraku -->

| 施策                    | ツール     | タイミング    |
| ----------------------- | ---------- | ------------- |
| シークレット検出        | gitleaks   | pre-commit    |
| 認証情報パターン検出    | secretlint | pre-commit    |
| コミットメッセージ検証  | commitlint | commit-msg    |

<!-- textlint-enable ja-hiraku -->

### CI レイヤー (GitHub Actions)

<!-- textlint-disable ja-hiraku -->

| 施策                  | ツール               | タイミング      |
| --------------------- | -------------------- | --------------- |
| 環境検証ゲート        | validate-environment | パイプライン先頭 |
| ワークフロー構文検証  | actionlint           | Push / PR       |
| 権限ポリシー違反検出  | ghalint              | Push / PR       |
| リポジトリ全体スキャン | gitleaks            | Push / PR       |

<!-- textlint-enable ja-hiraku -->

---

## 🔒 保護領域

以下のファイルはセキュリティポリシーを定義しており、変更時は必ず理由を明記する必要があります。

<!-- markdownlint-disable line-length MD060 -->

| ファイル                         | 内容                             | 変更禁止事項                           |
| -------------------------------- | -------------------------------- | -------------------------------------- |
| `configs/gitleaks.toml`          | gitleaks のシークレット検出設定  | 除外設定 (allowlist) の追加            |
| `configs/secretlint.config.yaml` | secretlint の認証情報検出設定    | 除外設定の追加・検出ルールの無効化     |

<!-- markdownlint-enable line-length MD060 -->

<!-- textlint-disable ja-hiraku -->

**なぜ保護するか**:

除外設定を安易に追加すると、実際のシークレット漏洩が検出されなくなるリスクがあります。
変更が必要な場合は、PR に変更理由・影響範囲・代替手段を明記してレビューを受けてください。

<!-- textlint-enable ja-hiraku -->

---

## 🔧 セキュリティポリシーの拡張

新しいセキュリティルールを追加する手順です。

<!-- textlint-disable ja-hiraku -->

**gitleaks への新しい検出ルール追加**:

1. `configs/gitleaks.toml` に `[[rules]]` エントリを追加する
2. ローカルで `gitleaks detect --source . --verbose` を実行して検証する
3. テスト用のサンプルデータで誤検知がないことを確認する

**secretlint への新しい検出ルール追加**:

1. `configs/secretlint.config.yaml` に対応するルールを追加する
2. ローカルで `secretlint` を実行して検証する
3. 既存コードへの影響がないことを確認する

**ghalint ポリシーの追加**:

1. `configs/ghalint.yaml` にポリシーを追加する
2. ローカルで `ghalint run --config ./configs/ghalint.yaml` を実行して確認する

<!-- textlint-enable ja-hiraku -->

---

## 📚 次のステップ

- [デザインプリンシプル](./04-design-principles.ja.md): セキュリティ原則が反映された設計ガイドライン
- [バージョニングとリリース](./06-versioning-and-release.ja.md): セキュリティ変更を含むリリース管理方針
