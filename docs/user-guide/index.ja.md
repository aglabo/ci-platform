---
title: ユーザーガイド
description: ci-platform の Composite Actions の使い方ガイド
slug: user-guide
sidebar_position: 1
tags:
  - ci-platform
  - composite-actions
  - setup
---

## ci-platform ユーザーガイド

ci-platform は、OSS 開発向けの **Composite Actions** を公開・配布するリポジトリです。
自分のリポジトリの GitHub Actions ワークフローからこれらのアクションを参照して利用します。

### 提供コンポーネント

<!-- markdownlint-disable line-length MD060 -->

| 種類             | コンポーネント       | 説明                                                             |
| ---------------- | -------------------- | ---------------------------------------------------------------- |
| Composite Action | validate-environment | GitHub Actions ランナーの OS・パーミッション・ツールを検証します |

<!-- markdownlint-enable line-length MD060 -->

### 利用者が得られるメリット

ワークフロー本体の実行前に OS・パーミッション・必要ツールを確認し、設定ミスによる失敗を早期に検知できます。

> GitHub Actions のワークフローは Linux ランナー専用です (`ubuntu-latest` など)。
> Windows と macOS はサポートしていません。

## 📚 ドキュメント構成

<!-- markdownlint-disable line-length MD060 -->

### ci-platform 関連

| 番号 | ファイル名                                       | 内容                                 |
| ---- | ------------------------------------------------ | ------------------------------------ |
| 00   | [ci-platform とは](./00-about-ci-platform.ja.md) | ci-platformについての説明            |
| 01   | [使い方](./01-how-to-use.ja.md)                  | 各種アクション、ワークフローの使い方 |

### validate-environment 関連

| 番号 | ファイル名                                                      | 内容                                               |
| ---- | --------------------------------------------------------------- | -------------------------------------------------- |
| 10   | [Validate Environment概要](10-about-validate-environment.ja.md) | "Validate-Environment"の概要                       |
| 11   | [クイックスタート](11-quickstart.ja.md)                         | 最小構成での利用手順                               |
| 12   | [基本シナリオ](12-basic-scenarios.ja.md)                        | 典型的な利用例 (read / commit / PR パーミッション) |
| 13   | [リファレンス](13-reference.ja.md)                              | 入出力パラメータ、設定値のリファレンス             |

### その他

| 番号 | ファイル名                                           | 内容                                       |
| ---- | ---------------------------------------------------- | ------------------------------------------ |
| 90   | [トラブルシューティング](./90-troubleshooting.ja.md) | よくある問題と解決方法                     |
| 91   | [フィードバック](./91-feedback.ja.md)                | Issue の建て方・ドキュメント改善の報告方法 |

<!-- markdownlint-enable line-length MD060 -->

### 🗺️ 読み方のガイドライン

- 順に読む: 初めてのほうは 10 アクション概要から順に読むことを推奨します。
- 参照として使う: 特定の設定やコマンドを調べたい場合は、各ページを直接参照してください。
- フィードバック歓迎: ドキュメントの改善提案や誤りは [Issue を作成](https://github.com/aglabo/ci-platform/issues/new?template=documentation.yml) してお知らせください。
