---
title: デザインプリンシプル
description: ci-platform の設計原則・実装方針・拡張ガイドライン
slug: developer-guide/design-principles
sidebar_position: 4
tags:
  - ci-platform
  - developer-guide
---

## デザインプリンシプル

ci-platform の実装・拡張・設定変更を行う際に従うべき設計原則を定義します。
コードレビューや変更判断の基準としても活用してください。

---

## 🔐 最小権限原則

GitHub Actions のすべてのワークフロー・アクションは**最小限の権限のみ**を要求します。

**必須ルール**:

- すべてのジョブに `permissions` セクションを明示する
- デフォルト権限は `contents: read` (読み取り専用)
- `contents: write`、`id-token: write` は明確な理由がある場合のみ追加する

```yaml
# 正しい例
jobs:
  validate:
    runs-on: ubuntu-latest
    permissions:
      contents: read # 最小権限

# 禁止パターン
jobs:
  validate:
    runs-on: ubuntu-latest
    # permissions が未定義 → デフォルト write 権限が付与される
```

この原則は `ghalint` によって自動検証されます。

---

## ♻️ 再利用可能ワークフローの設計方針

<!-- textlint-disable ja-hiraku -->

Reusable Workflows および Composite Actions は次の方針で設計します。

**単一責任**: 1 つのコンポーネントは 1 つのツール・機能のみ担当する。

```
scan-actionlint.yml  → actionlint のみ
scan-ghalint.yml     → ghalint のみ
scan-gitleaks.yml    → gitleaks のみ
```

**入力の明示化**: すべての `inputs` にデフォルト値を設定し、利用者が最小設定で使えるようにする。

```yaml
inputs:
  config-file:
    description: "設定ファイルのパス"
    required: false
    default: "./configs/actionlint.yaml"
```

**Validation パターン**: ステップの条件分岐には `outcome` を使用する。

```yaml
# 正しい例
- name: Validate result
  if: steps.scan.outcome == 'success'

# 禁止パターン
- name: Validate result
  if: steps.scan.outputs.status != 'error'
```

<!-- textlint-enable ja-hiraku -->

---

## 📁 設定の分離 (configs/ ディレクトリ)

ツール設定はすべて `configs/` ディレクトリに集約します。

<!-- markdownlint-disable line-length MD060 -->

| ファイル                         | 役割                          |
| -------------------------------- | ----------------------------- |
| `configs/actionlint.yaml`        | actionlint 設定               |
| `configs/ghalint.yaml`           | ghalint ポリシー設定          |
| `configs/gitleaks.toml`          | gitleaks シークレット検出設定 |
| `configs/secretlint.config.yaml` | secretlint 設定               |
| `configs/.markdownlint.yaml`     | markdownlint ルール設定       |

<!-- markdownlint-enable line-length MD060 -->

**分離の目的**:

- 設定ファイルの場所が予測可能であり、変更時の影響範囲が明確
- ツールの設定変更とロジックの変更を独立して管理できる
- 外部から参照する際に設定のオーバーライドが容易

**保護領域**: `configs/gitleaks.toml`、`configs/secretlint.config.yaml` はセキュリティポリシーを定義するため、変更時は必ず理由を明記してください。

---

## ✅ テストファースト・自動化優先

ci-platform のスクリプト変更はすべてテストが先行します。

<!-- textlint-disable ja-hiraku -->

**テスト配置規約**:

```
scripts/
├── prepare-commit-msg.sh
└── __tests__/
    ├── prepare-commit-msg.unit.spec.sh
    └── prepare-commit-msg.functional.spec.sh
```

**ティア定義**:

| ティア        | 対象                                 |
| ------------- | ------------------------------------ |
| `unit`        | 個別関数の入出力検証                 |
| `functional`  | 複数関数の組み合わせ動作             |
| `integration` | 外部ツール・ファイルシステムとの統合 |
| `e2e`         | エンドツーエンドのシナリオ検証       |

<!-- textlint-enable ja-hiraku -->

**禁止事項**: テストファイル (`__tests__/**/*.spec.sh`) を明示的な指示なしに変更しない。

---

## 🛡️ 拡張時のガイドライン

ci-platform を拡張する際のチェックリストです。

### 新しい Composite Action / Reusable Workflow を追加する

<!-- textlint-disable ja-hiraku -->

1. `permissions` セクションを `contents: read` で明示する
2. すべての `inputs` にデフォルト値を設定する
3. `actionlint` と `ghalint` の検証をローカルで実行する
4. `validate-environment` を CI の最初のステップとして配置する

<!-- textlint-enable ja-hiraku -->

### 新しいスクリプトを追加する

<!-- textlint-disable ja-hiraku -->

1. `scripts/` 配下に配置する
2. `__tests__/` に対応するテストファイルを作成する
3. `bash ./scripts/run-specs.sh` でテストが全件パスすることを確認する
4. 関数の入出力を `unit` テストで検証する

<!-- textlint-enable ja-hiraku -->

### 設定ファイルを変更する

<!-- textlint-disable ja-hiraku -->

1. 変更理由を PR / コミットメッセージに明記する
2. `gitleaks.toml`、`secretlint.config.yaml` の除外設定追加は**禁止**
3. 変更後に対応するリントツールをローカルで実行して確認する

<!-- textlint-enable ja-hiraku -->

---

## 📚 次のステップ

- [アーキテクチャ](./03-architecture.ja.md): 設計原則が実装に反映されたコンポーネント全体図
- [GitHub Actions 設計](./30-github-actions.ja.md): Composite Action / Reusable Workflow の詳細設計
- [設定ガイド](./40-configuration.ja.md): 各品質ツール設定の詳細リファレンス
