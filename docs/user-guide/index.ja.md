---
title: ユーザーガイド
description: ci-platform の Composite Actions の使い方ガイド
slug: /user-guide
sidebar_position: 1
tags:
  - ci-platform
  - composite-actions
  - setup
---

## ci-platform ユーザーガイド

> CI を「安全な前提条件」から始めるためのゲート。

ci-platform は、GitHub Actions ワークフローの**実行前提条件を検証・標準化する** Composite Actions を提供するリポジトリです。
CI の入口ゲートとして機能し、ランナー環境・権限・ツールの整合性を明示的に検証することで、ワークフロー本体の品質と再現性の向上に寄与します。

**対象読者**: CI の再現性と権限管理を重視する開発者。複数リポジトリに共通の CI 基準を適用したい場合に特に有効です。

**今すぐ試す** → [クイックスタート](11-quickstart.ja.md)

### 提供価値

- ランナー OS・アーキテクチャ・ツールを事前検証し、一貫した実行環境の再現性を保証します。
- パーミッション・トークン権限を明示的に検証し、意図しない権限昇格を防ぎます。
- aglabo 系アクションで採用している実行基準を、外部プロジェクトでも利用可能な形で提供します。

> 現時点では Linux ランナー専用です（`ubuntu-latest` など）。
> Windows と macOS はサポートしていません。

### 提供コンポーネント

<!-- markdownlint-disable line-length MD060 -->

| 種類             | コンポーネント       | 説明                                                             |
| ---------------- | -------------------- | ---------------------------------------------------------------- |
| Composite Action | validate-environment | GitHub Actions ランナーの OS・パーミッション・ツールを検証します |

<!-- markdownlint-enable line-length MD060 -->

## 📚 ドキュメント構成

<!-- markdownlint-disable line-length MD060 -->

### ci-platform 関連

| 番号 | ファイル名                                     | 内容                                 |
| ---- | ---------------------------------------------- | ------------------------------------ |
| 00   | [ci-platform とは](00-platform-overview.ja.md) | 設計思想・背景・リスクシナリオ (Why) |
| 01   | [使い方](01-how-to-use.ja.md)                  | 各種アクション、ワークフローの使い方 |

### validate-environment 関連

| 番号 | ファイル名                                                      | 内容                                               |
| ---- | --------------------------------------------------------------- | -------------------------------------------------- |
| 10   | [Validate Environment概要](10-about-validate-environment.ja.md) | Validate Environmentの機能・仕組み (What / How)    |
| 11   | [クイックスタート](11-quickstart.ja.md)                         | 最小構成での利用手順                               |
| 12   | [基本シナリオ](12-basic-scenarios.ja.md)                        | 典型的な利用例 (read / commit / PR パーミッション) |
| 13   | [リファレンス](13-reference.ja.md)                              | 入出力パラメータ、設定値のリファレンス             |

### その他

| 番号 | ファイル名                                         | 内容                                       |
| ---- | -------------------------------------------------- | ------------------------------------------ |
| 90   | [トラブルシューティング](90-troubleshooting.ja.md) | よくある問題と解決方法                     |
| 91   | [フィードバック](91-feedback.ja.md)                | Issue の建て方・ドキュメント改善の報告方法 |

<!-- markdownlint-enable line-length MD060 -->

### 🗺️ 読み方のガイドライン

<!-- textlint-disable ja-hiraku -->

- 順に読む: 初めて読む方は [Validate-Environment概要](10-about-validate-environment.ja.md) から順に読むことを推奨します。
- 参照として使う: 特定の設定やコマンドを調べたい場合は、各ページを直接参照してください。
- フィードバック歓迎: 各種フィードバックについては、[フィードバック](91-feedback.ja.md) を参照してください。
  ドキュメントの改善提案や誤りは [Issue を作成](https://github.com/aglabo/ci-platform/issues/new?template=document.yml) してお知らせください。
