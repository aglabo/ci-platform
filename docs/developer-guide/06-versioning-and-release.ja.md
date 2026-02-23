---
title: バージョニングとリリース
description: ci-platform のセマンティックバージョニング・バージョンロードマップ・後方互換性・リリースプロセス
slug: developer-guide/versioning-and-release
sidebar_position: 6
tags:
  - ci-platform
  - developer-guide
  - versioning
  - release
---

## バージョニングとリリース

ci-platform は**セマンティックバージョニング (SemVer)** を採用しています。
利用者は `@vX.Y.Z` 形式でバージョンを固定参照することで、予期しない破壊的変更から保護されます。

---

## 📦 セマンティックバージョニング

SemVer の `MAJOR.MINOR.PATCH` 形式に従って、変更の重要度を明示します。

<!-- markdownlint-disable line-length MD060 -->

| バージョン区分 | 形式例   | 変更内容                                                       |
| -------------- | -------- | -------------------------------------------------------------- |
| MAJOR          | `v1.0.0` | 後方互換性のない変更 (破壊的変更)                              |
| MINOR          | `v0.2.0` | 後方互換性を保った機能追加 (新しい inputs・コンポーネント追加) |
| PATCH          | `v0.1.1` | 後方互換性を保ったバグ修正・ドキュメント修正                   |

<!-- markdownlint-enable line-length MD060 -->

---

## 🗺️ バージョンロードマップ

### v0.1.x: Composite Actions 基盤

`validate-environment` Composite Action の提供と安定化を目的とするフェーズです。

<!-- textlint-disable ja-hiraku -->

- `v0.1.0`: `validate-environment` の初回リリース (OS・permissions・ツール検証)
- `v0.1.x`: バグ修正・ドキュメント改善・ShellSpec テスト拡充

<!-- textlint-enable ja-hiraku -->

### v0.2.x: Reusable Workflows 追加

GitHub Actions Reusable Workflows の提供フェーズです。

<!-- textlint-disable ja-hiraku -->

- `v0.2.0`: `scan-actionlint` Reusable Workflow 追加
- `v0.2.x`: `scan-ghalint`・`scan-gitleaks` Reusable Workflow 追加

<!-- textlint-enable ja-hiraku -->

### v0.3.x: 統合スキャンと組織標準テンプレート

複数コンポーネントを統合したスキャンワークフローと、組織横断での標準テンプレート提供フェーズです。

<!-- textlint-disable ja-hiraku -->

- `v0.3.0`: スキャン・QA ワークフロー分割 (`ci-scan-secrets` / `ci-workflows-qa` の外部参照対応)
- `v0.3.x`: 組織標準テンプレート・カスタマイズガイドの整備

<!-- textlint-enable ja-hiraku -->

---

## 🔄 後方互換性ポリシー

MINOR / PATCH リリースでは後方互換性を保証します。

<!-- markdownlint-disable line-length MD060 -->

| 変更対象         | 変更内容                                   | 互換性      |
| ---------------- | ------------------------------------------ | ----------- |
| `inputs`         | 新しい inputs の追加 (デフォルト値あり)    | 互換あり    |
| `inputs`         | 既存 inputs の削除・型変更                 | 破壊的変更  |
| `outputs`        | 新しい outputs の追加                      | 互換あり    |
| `outputs`        | 既存 outputs の削除・名前変更              | 破壊的変更  |
| 動作の変更       | バグ修正による動作変更                     | PATCH       |
| 動作の変更       | 意図的な動作変更 (仕様変更)                | 破壊的変更  |

<!-- markdownlint-enable line-length MD060 -->

---

## ⚠️ 破壊的変更の扱い

破壊的変更は必ず MAJOR バージョンの更新として扱い、明示的に通知します。

<!-- textlint-disable ja-hiraku -->

**コミットフッターの記法**:

```
feat: validate-environment に新しい検証を追加

BREAKING CHANGE: required-tools input が必須になりました。
既存の利用者は lefthook.yml に required-tools を追加する必要があります。
```

**GitHub ラベル**:

- `breaking-change`: 破壊的変更を含む PR に付与する
- `migration-guide`: マイグレーション手順が必要な場合に付与する

**CHANGELOG への記載**:

破壊的変更は CHANGELOG の `## Breaking Changes` セクションに記載し、
移行手順または代替手段を明示します。

<!-- textlint-enable ja-hiraku -->

---

## 🚀 リリースプロセス

リリースは次の手順で行います。

<!-- textlint-disable ja-hiraku -->

1. **テスト実行**: `bash ./scripts/run-specs.sh` で全テストが PASS することを確認する
2. **CI 検証**: ローカルで `actionlint`・`ghalint`・`gitleaks` を実行して問題がないことを確認する
3. **CHANGELOG 更新**: `CHANGELOG.md` に変更内容・影響範囲を記載する
4. **バージョンタグ**: `git tag v0.X.Y` でタグを作成する
5. **GitHub リリース**: GitHub Releases にリリースノートを作成する

<!-- textlint-enable ja-hiraku -->

---

## 📌 バージョン参照方法 (利用者向け)

利用者がワークフローで ci-platform を参照する方法と推奨度の一覧です。

<!-- markdownlint-disable line-length MD060 -->

| 参照方法          | 例                                                              | 推奨度           | 備考                                         |
| ----------------- | --------------------------------------------------------------- | ---------------- | -------------------------------------------- |
| バージョンタグ    | `@v0.1.0`                                                       | ★★★ 推奨        | 再現性が高く、変更の影響を受けない           |
| メジャータグ      | `@v0`                                                           | ★★☆ 許容        | MINOR/PATCH を自動追従する                   |
| コミット SHA      | `@abc1234`                                                      | ★★☆ 許容        | 完全固定だがメンテナンスが煩雑               |
| ブランチ名        | `@main`                                                         | ★☆☆ 非推奨      | 最新コミットを追従するため予期しない変更あり |

<!-- markdownlint-enable line-length MD060 -->

```yaml
# 推奨: バージョンタグ固定
- uses: aglabo/ci-platform/.github/actions/validate-environment@v0.1.0
```

---

## 📚 次のステップ

- [コア哲学](./01-core-philosophy.ja.md): バージョニング戦略の背景にある設計思想
- [セキュリティモデル](./05-security-model.ja.md): リリースプロセスに組み込まれたセキュリティ検証
