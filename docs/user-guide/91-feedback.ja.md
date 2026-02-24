---
title: フィードバック
description: バグ報告・ドキュメント改善・機能要望の Issue 作成ガイド
slug: feedback
sidebar_position: 91
tags:
  - feedback
  - issue
  - contributing
---

<!-- markdownlint-disable no-duplicate-heading -->

本プロジェクト: <https://github.com/aglabo/ci-platform>

## 💬 フィードバックについて

ci-platform への不具合報告・ドキュメント改善提案・機能要望は GitHub Issue で受け付けています。
Issue を作成する際は、目的に合ったテンプレートを選択してください。

このドキュメントは、ci-platform を直接利用する開発者および公開 Reusable Workflow 経由で利用する外部利用者を対象としています。
すべてのフィードバックは再現可能性と検証可能性を重視します。

<!-- markdownlint-disable line-length -->

| 種別             | Issue 作成リンク                                                                                            |
| ---------------- | ----------------------------------------------------------------------------------------------------------- |
| バグ報告         | [Bug Report を作成する](https://github.com/aglabo/ci-platform/issues/new?template=bug_report.yml)           |
| ドキュメント改善 | [Documentation Issue を作成する](https://github.com/aglabo/ci-platform/issues/new?template=document.yml)    |
| 機能要望         | [Feature Request を作成する](https://github.com/aglabo/ci-platform/issues/new?template=feature_request.yml) |
| セキュリティ     | [Security Advisory を作成する](https://github.com/aglabo/ci-platform/security/advisories/new)               |

<!-- markdownlint-enable line-length -->

## 🐛 バグ報告

本リポジトリに含まれるアクション・スクリプトの動作が期待と異なる場合はバグ報告をお送りください。

[バグ報告の Issue を作成する](https://github.com/aglabo/ci-platform/issues/new?template=bug_report.yml)

### 記載する情報

| 項目                | 内容                                                        |
| ------------------- | ----------------------------------------------------------- |
| Severity            | 重大度 (Critical / Major / Minor / Cosmetic)                |
| Bug Summary         | 問題の概要 (1〜2 文)                                        |
| Expected Behavior   | 期待していた動作                                            |
| Actual Behavior     | 実際に起きた動作                                            |
| Steps to Reproduce  | 再現手順 (番号付きリスト)                                   |
| Environment         | ランナー OS・アクションのバージョン・ワークフローの設定など |
| Screenshots or Logs | `::error::` メッセージやジョブログの抜粋 (任意)             |

**Severity の目安:**

各レベルは影響範囲（CI の停止・破綻・回避可否）を基準とします。

| レベル   | 基準                                  |
| -------- | ------------------------------------- |
| Critical | CI が完全停止、ワークフローが実行不可 |
| Major    | 一部ワークフローが破綻、回避策なし    |
| Minor    | 動作に問題があるが回避策あり          |
| Cosmetic | 表示・ログのみ、機能への影響なし      |

## 📝 ドキュメント改善

誤字・誤記・説明のわかりにくさ・内容の不足などはドキュメント Issue でお知らせください。

[ドキュメント改善の Issue を作成する](https://github.com/aglabo/ci-platform/issues/new?template=document.yml)

### 記載する情報

| 項目                | 内容                                                          |
| ------------------- | ------------------------------------------------------------- |
| Document Type       | 種別 (Tutorial / How-to Guide / Reference / Explanation など) |
| Documentation Goal  | 読んだあとに読者が理解・実施できるようになること              |
| Target Audience     | 想定読者と前提知識                                            |
| References          | 参照すべきドキュメントや関連 Issue                            |
| Acceptance Criteria | 完了条件 (チェックボックス形式)                               |

> Document Type は [Diátaxis](https://diataxis.fr/) 分類に基づきます。

## 🚀 機能要望

新機能の追加や既存機能の改善を要望する場合は機能要望 Issue を使用してください。

[機能要望の Issue を作成する](https://github.com/aglabo/ci-platform/issues/new?template=feature_request.yml)

### 記載する情報

| 項目                    | 内容                                                |
| ----------------------- | --------------------------------------------------- |
| Observed Facts          | 現在の動作・制約の事実 (意見や解決策は含めない)     |
| Expected Behavior       | 望む結果・体験 (「何を」であり「どう実装」ではない) |
| Proposed Solution       | 具体的な提案 (任意)                                 |
| Alternatives Considered | 検討した代替案                                      |
| Acceptance Criteria     | 完了を確認できる検証可能な条件                      |

> Observed Facts に意見や解決策を含めないのは、事実と提案を分離することで実装論争を避け、本質的な問題定義に集中するためです。

## 🔒 セキュリティ脆弱性の報告

セキュリティ上の問題は **公開 Issue として報告しないでください**。
GitHub Security Advisories を通じてプライベートに報告してください。
セキュリティ修正は公開前に coordinated disclosure を行います。

報告時の注意事項:

- PoC や exploit コードを Issue に含めないでください。
- 影響範囲（対象バージョン・再現条件・影響を受ける機能）を明記してください。
- 修正が公開されるまでは脆弱性の詳細を公開しないようご協力ください。

[Security Advisory を作成する](https://github.com/aglabo/ci-platform/security/advisories/new)

---

## 📚 関連ドキュメント

- [トラブルシューティング](./90-troubleshooting.ja.md): よくあるエラーと解決方法
- [リファレンス](./13-reference.ja.md): 全入力パラメータ・出力の詳細
