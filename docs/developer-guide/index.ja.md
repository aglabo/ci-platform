---
title: 開発者ガイド
description: ci-platform の内部構造・スクリプト・設定・テストを理解したい開発者向けリファレンス
slug: developer-guide
sidebar_position: 1
tags:
  - ci-platform
  - developer-guide
  - architecture
---

## ci-platform 開発者ガイド

このガイドは、ci-platform の**内部構造・設計・拡張方法を理解したい開発者向け**のリファレンスです。
スクリプト・GitHub Actions・品質ツール設定・テストの仕組みを体系的に解説します。

<!-- textlint-disable ja-hiraku -->

ci-platform を外部から利用する方は [ユーザーガイド](../user-guide/index.ja.md) を、
開発環境のセットアップ手順は [オンボーディングガイド](../onboarding/index.ja.md) を参照してください。

### 対象読者

- ci-platform の内部実装・アーキテクチャを理解したい方
- scripts/ 配下のスクリプトを拡張・修正したい方
- GitHub Actions の Composite Action / Reusable Workflow を改修したい方
- ShellSpec テストを追加・メンテナンスしたい方

<!-- textlint-enable ja-hiraku -->

---

## 📚 ドキュメント構成

<!-- markdownlint-disable line-length MD060 -->

### 概要・アーキテクチャ

| 番号 | ファイル名                                                  | 内容                                                     |
| ---- | ----------------------------------------------------------- | -------------------------------------------------------- |
| 00   | [ci-platform 概要](00-overview.ja.md)                       | ci-platform の目的・機能・対象範囲                       |
| 01   | [コア哲学](01-core-philosophy.ja.md)                        | 設計思想・品質自動化の考え方                             |
| 02   | [ゲートパターン](02-gate-pattern.ja.md)                     | ゲートチェックパターン・validate-environment             |
| 03   | [アーキテクチャ](03-architecture.ja.md)                     | コンポーネント構成・CI/CD フロー・Git Hooks フロー全体像 |
| 04   | [デザインプリンシプル](04-design-principles.ja.md)          | 設計原則・実装方針・拡張ガイドライン                     |
| 05   | [セキュリティモデル](05-security-model.ja.md)               | 最小権限・シークレット検出・保護領域                     |
| 06   | [バージョニングとリリース](06-versioning-and-release.ja.md) | SemVer・ロードマップ・リリース方針                       |

### 実装リファレンス

| 番号 | ファイル名                                           | 内容                                                  |
| ---- | ---------------------------------------------------- | ----------------------------------------------------- |
| 20   | [スクリプトリファレンス](20-scripts-reference.ja.md) | scripts/ 配下の関数・引数・使用方法リファレンス       |
| 30   | [GitHub Actions 設計](30-github-actions.ja.md)       | Composite Action / Reusable Workflow の設計と拡張方法 |

### 設定・品質管理

| 番号 | ファイル名                                    | 内容                                                       |
| ---- | --------------------------------------------- | ---------------------------------------------------------- |
| 40   | [設定ガイド](40-configuration.ja.md)          | 品質ツール設定ガイド (commitlint / gitleaks / textlint 等) |
| 60   | [品質パイプライン](60-quality-pipeline.ja.md) | ローカル品質管理 + CI パイプライン全体説明                 |

### テスト

| 番号 | ファイル名                           | 内容                                                   |
| ---- | ------------------------------------ | ------------------------------------------------------ |
| 50   | [テスト開発ガイド](50-testing.ja.md) | ShellSpec テスト開発パターン・規約・ベストプラクティス |

<!-- markdownlint-enable line-length MD060 -->

---

## 🗺️ 読み方のガイドライン

<!-- textlint-disable ja-hiraku -->

- 初めて読む場合: 00 → 01 → 02 → 03 → 04 の順に読み、全体のアーキテクチャを把握してから目的のセクションへ進んでください。
- 特定の情報を調べる場合: 上記テーブルから対象ページを直接参照してください。
- フィードバック歓迎: ドキュメントの改善提案や誤りは [Issue を作成](https://github.com/aglabo/ci-platform/issues/new) してお知らせください。

<!-- textlint-enable ja-hiraku -->
