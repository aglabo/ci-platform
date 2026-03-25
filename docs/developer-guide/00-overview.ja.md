---
title: ci-platform 概要
description: ci-platform の定義・提供機能・設計思想の概要
slug: developer-guide/overview
sidebar_position: 0
tags:
  - ci-platform
  - developer-guide
---

## ci-platform 概要

ci-platform は、OSS プロジェクト向けの CI/CD 品質構築基盤です。
GitHub Actions 上で、セキュリティチェックやワークフロー検証を簡単に組み込める再利用コンポーネントを提供します。
導入するだけで、安全側に倒れる CI/CD を構築できることを目指しています。

---

## 🎯 目的とミッション

**ミッション**: OSS プロジェクトが CI/CD に組み込める安全なデフォルトを提供し、最小の設定で品質統制を実現できる基盤を構築する。

ci-platform は次の課題を解決します。

- CI/CD の品質設定を複数リポジトリで毎回コピーしている
- セキュリティポリシーを組織横断で標準化できていない
- ワークフローの構文ミス・ポリシー違反を CI 段階で検出したい
- 機密情報の漏洩リスクを CI 段階で防ぎたい

## 🧭 設計方針

ci-platform は、**利用者視点（外部）**と**実装視点（内部）**の二層で設計されています。

### 外部：利用者が得られる体験

- **組み込める** — 既存リポジトリへ最小手順で導入できる
- **拡張できる** — 設定ゼロで始め、追加設定でカスタマイズできる
- **安全なデフォルト** — 何もしなければ安全側に倒れる挙動が基本
- **OSS 向け** — パブリックリポジトリで使いやすい構成・権限設計

### 内部：実装を貫く設計原則

- **Gate** — CI の入口で実行環境を検証し、問題を早期に遮断する
- **Fail-fast** — 問題を検出したら即座に停止し、後続処理を実行させない
- **Policy** — 品質・セキュリティポリシーをコードとして定義し、強制する

設計思想の詳細は [コア哲学](./01-core-philosophy.ja.md) を参照してください。

---

## 📦 提供機能

ci-platform は GitHub Actions コンポーネントを **Gate / Security / Policy** の 3 レイヤーで提供します。

### Gate Layer — 実行環境の統制

CI パイプラインの入口で実行環境を検証し、不正な設定を強制停止します。

<!-- markdownlint-disable line-length MD060 -->

| コンポーネント       | 種別             | 状態       | 役割                                               |
| -------------------- | ---------------- | ---------- | -------------------------------------------------- |
| validate-environment | Composite Action | **提供中** | CI 実行環境の OS・権限・ツールを事前検証するゲート |

<!-- markdownlint-enable line-length MD060 -->

`validate-environment` は、ci-platform における Gate レイヤーの実装です。
Gate パターンの詳細は [ゲートパターン](./02-gate-pattern.ja.md) を参照してください。

### Security Layer — 機密情報の統制

リポジトリ全体の機密情報スキャンを実行します。

<!-- markdownlint-disable line-length MD060 -->

| コンポーネント | 種別            | 状態       | 役割                                 |
| -------------- | --------------- | ---------- | ------------------------------------ |
| gitleaks       | Caller Workflow | **提供中** | リポジトリ全体のシークレットスキャン |

<!-- markdownlint-enable line-length MD060 -->

### Policy Layer — ワークフロー品質の統制

GitHub Actions ワークフローの構文・ポリシーを検証します。

<!-- markdownlint-disable line-length MD060 -->

| コンポーネント | 種別              | 状態 | 役割                                  |
| -------------- | ----------------- | ---- | ------------------------------------- |
| actionlint     | Reusable Workflow | 予定 | GitHub Actions ワークフローの構文検証 |
| ghalint        | Reusable Workflow | 予定 | GitHub Actions ポリシー違反の検出     |

<!-- markdownlint-enable line-length MD060 -->

---

## 🗺️ ロードマップ

<!-- markdownlint-disable line-length MD060 -->

| バージョン | マイルストーン                             |
| ---------- | ------------------------------------------ |
| v0.1.0     | Gate Layer: validate-environment           |
| v0.2.0     | Security Layer: gitleaks (caller workflow) |

<!-- markdownlint-enable line-length MD060 -->

---

## 👥 対象読者と前提知識

このドキュメントは ci-platform の**内部実装を理解・拡張したい開発者**を対象としています。

<!-- textlint-disable ja-hiraku -->

**対象読者**:

- ci-platform のスクリプトや設定を拡張・修正したい方
- GitHub Actions の Composite Action / Reusable Workflow を改修したい方
- ShellSpec テストを追加・メンテナンスしたい方
- ci-platform をフォークして自組織向けに改修したい方

**前提知識**:

- Bash スクリプトの基礎
- GitHub Actions の基本的な理解 (ワークフロー・ジョブ・ステップ)
- Git の基本操作

<!-- textlint-enable ja-hiraku -->

ci-platform を**利用するだけ**の場合は [ユーザーガイド](../user-guide/index.ja.md) を参照してください。

---

## 🔧 技術スタック概要

<!-- markdownlint-disable line-length MD060 -->

| レイヤー                                        | 技術・ツール                                       |
| ----------------------------------------------- | -------------------------------------------------- |
| **Runtime Layer** (GitHub Actions 実行時)       | GitHub Actions, actionlint, ghalint, gitleaks      |
| **Dev Layer** (開発者・コントリビューター向け)  | lefthook, secretlint, commitlint, ShellSpec (Bash) |
| **Docs Layer** (開発者・コントリビューター向け) | textlint, markdownlint, dprint                     |

<!-- markdownlint-enable line-length MD060 -->

**責務別ディレクトリ構成**:

```
ci-platform/
├── .github/
│   ├── actions/                    # Gate Layer: Composite Actions
│   │   └── validate-environment/   # CI 実行環境の事前検証ゲート
│   └── workflows/                  # Security / Policy Layer: Caller Workflows
│       ├── ci-scan-secrets.yml     # 機密情報スキャン
│       └── ci-workflows-qa.yml     # ワークフロー QA (actionlint / ghalint)
├── configs/                        # 各レイヤーの品質ツール設定
├── scripts/                        # Dev Layer: テスト実行・環境セットアップ
│   └── __tests__/                  # ShellSpec テスト (開発者向け)
└── docs/                           # ドキュメント (Docusaurus)
```

---

## 📚 次のステップ

- [コア哲学](./01-core-philosophy.ja.md): ci-platform の設計思想と品質自動化の考え方
- [ゲートパターン](./02-gate-pattern.ja.md): ゲートチェックパターンと validate-environment の実装
- [アーキテクチャ](./03-architecture.ja.md): コンポーネント構成と CI/CD フロー全体像
- [デザインプリンシプル](./04-design-principles.ja.md): 実装の設計原則と拡張ガイドライン
