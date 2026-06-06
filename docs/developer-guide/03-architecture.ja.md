---
title: アーキテクチャ
description: ci-platform のコンポーネント構成・ディレクトリ構造・CI/CD フロー・Git Hooks フロー
slug: developer-guide/architecture
sidebar_position: 3
tags:
  - ci-platform
  - developer-guide
---

## アーキテクチャ

ci-platform のコンポーネント構成・ディレクトリ構造・各フローを解説します。

---

## 🏗️ コンポーネント構成

ci-platform は 3 つのレイヤーで構成されています。

```mermaid
graph TB
    subgraph local["ローカルレイヤー (Git Hooks)"]
        lh["lefthook"]
        gl["gitleaks"]
        sl["secretlint"]
        cl["commitlint"]
        ai["AI コミットメッセージ"]
        lh --> gl
        lh --> sl
        lh --> cl
        lh --> ai
    end

    subgraph ci["CI レイヤー (GitHub Actions)"]
        subgraph ca["Composite Actions"]
            ve["validate-environment"]
        end
        subgraph rw["Reusable Workflows (予定)"]
            al["scan-actionlint"]
            gh["scan-ghalint"]
            gs["scan-gitleaks"]
        end
    end

    subgraph doc["ドキュメントレイヤー"]
        tl["textlint"]
        ml["markdownlint"]
        dp["dprint"]
    end

    local -->|"push/PR"| ci
```

---

## 📁 ディレクトリ構造

```bash
ci-platform/
├── .github/
│   ├── actions/
│   │   └── validate-environment/   # Composite Action
│   │       └── action.yml
│   └── workflows/
│       ├── ci-scan-secrets.yml     # 機密情報スキャン
│       └── ci-workflows-qa.yml     # ワークフロー QA
├── configs/                        # 品質ツール設定
│   ├── actionlint.yaml
│   ├── ghalint.yaml
│   ├── gitleaks.toml
│   ├── secretlint.config.yaml
│   ├── .markdownlint.yaml
│   └── textlintrc.yaml
├── scripts/                        # 開発スクリプト
│   ├── run-specs.sh                # ShellSpec 実行ラッパー
│   ├── setup-dev-env.sh            # 開発環境セットアップ
│   ├── prepare-commit-msg.sh       # AI コミットメッセージ生成
│   └── __tests__/                  # ShellSpec テスト
├── docs/                           # Docusaurus ドキュメント
│   ├── user-guide/
│   └── developer-guide/
├── lefthook.yml                    # Git Hooks 定義
└── package.json
```

---

## 🔄 CI/CD フロー

Push または PR 時に `ci-scan-secrets.yml` と `ci-workflows-qa.yml` が並行して実行されます。

```mermaid
sequenceDiagram
    participant dev as 開発者
    participant gh as GitHub
    participant sec as ci-scan-secrets.yml
    participant qa as ci-workflows-qa.yml

    dev->>gh: Push / PR
    gh->>sec: ワークフロー起動
    gh->>qa: ワークフロー起動

    sec->>sec: gitleaks
    Note right of sec: シークレットスキャン

    qa->>qa: actionlint
    Note right of qa: ワークフロー構文検証

    qa->>qa: ghalint
    Note right of qa: ポリシー違反検出
```

### validate-environment の役割

`validate-environment` は CI パイプラインの**強制停止ゲート**です。
次の 3 つを検証し、いずれかが失敗した場合は即座に後続ジョブを停止します。

<!-- markdownlint-disable line-length MD060 -->

| 検証項目         | 内容                                           |
| ---------------- | ---------------------------------------------- |
| OS 検証          | Linux ランナー (ubuntu-*) であることを確認     |
| permissions 検証 | `contents: write` など過剰権限がないことを確認 |
| ツール確認       | 必要なツールがランナーに存在することを確認     |

<!-- markdownlint-enable line-length MD060 -->

---

## 🪝 Git Hooks フロー

lefthook が Git イベントに応じて品質チェックを自動実行します。

```mermaid
sequenceDiagram
    participant dev as 開発者
    participant lh as lefthook
    participant gl as gitleaks
    participant sl as secretlint
    participant cl as commitlint

    dev->>lh: git commit
    lh->>gl: pre-commit: シークレット検出
    lh->>sl: pre-commit: 認証情報パターン検出
    gl-->>lh: OK / NG
    sl-->>lh: OK / NG

    alt NG あり
        lh-->>dev: コミット拒否 + エラー表示
    else 全 OK
        lh->>cl: commit-msg: メッセージ形式検証
        cl-->>lh: OK / NG
        lh-->>dev: コミット完了 / 拒否
    end
```

---

## 🔗 コンポーネント間の関係

### 設定ファイルと各コンポーネントの対応

<!-- markdownlint-disable line-length MD060 -->

| 設定ファイル                     | 参照コンポーネント              |
| -------------------------------- | ------------------------------- |
| `configs/gitleaks.toml`          | gitleaks (CI + Git Hooks)       |
| `configs/secretlint.config.yaml` | secretlint (Git Hooks)          |
| `configs/actionlint.yaml`        | actionlint (CI)                 |
| `configs/ghalint.yaml`           | ghalint (CI)                    |
| `configs/textlintrc.yaml`        | textlint (ドキュメント品質)     |
| `configs/.markdownlint.yaml`     | markdownlint (ドキュメント品質) |
| `lefthook.yml`                   | lefthook (Git Hooks 全体定義)   |

<!-- markdownlint-enable line-length MD060 -->

### 外部リポジトリからの参照方式

利用者のリポジトリは ci-platform を**バージョン固定で参照**します。
ci-platform のリポジトリをフォークする必要はありません。

```yaml
# 利用者のワークフロー例
steps:
  - uses: aglabo/ci-platform/.github/actions/validate-environment@v0.1.0
```

---

## 📚 次のステップ

- [デザインプリンシプル](./04-design-principles.ja.md): アーキテクチャを支える設計原則と実装方針
- GitHub Actions 設計 (準備中): Composite Action / Reusable Workflow の詳細
- スクリプトリファレンス (準備中): scripts/ 配下の詳細リファレンス
