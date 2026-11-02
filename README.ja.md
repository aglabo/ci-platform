# 📦 OSS向けプロジェクトテンプレート(日本語版)

このテンプレートは、モダンな OSS 開発のための初期構成を素早く立ち上げられるように設計されています。

---

## 特徴

- `scripts/setup-dev-env.sh` による簡単な開発環境セットアップ
  - lefthook フック、ShellSpec、aglabo 開発/ドキュメントツールを導入 (`pnpm install` 時に自動実行)
- EditorConfig、.gitignore などプロジェクト開始時に必要なファイルを完備
  - ミニマムな設定で、後からの拡張も可能
- lefthook による軽量な Git Hook 環境
  - betterleaks や secretlint によって API キーなどの漏洩を未然に防止

## 使用方法

1. このテンプレートリポジトリを、自分の GitHub にフォークします。
2. 自分の環境に合わせて書き換えます(例: LICENSE の名前を自分のハンドル名に変更)。
3. GitHub 上で新規リポジトリを作成する際に、フォークしたテンプレートから生成します。
4. 必要な設定ファイルが揃ったリポジトリを自動で作成します。

## 含まれるツール一覧

| ツール名    | 説明                                           |
| ----------- | ---------------------------------------------- |
| lefthook    | Git コミットフックの管理                       |
| delta       | Git の差分を視覚的に表示するツール             |
| commitlint  | コミットメッセージ形式の検証                   |
| betterleaks | 機密情報の混入を検出するセキュリティツール     |
| secretlint  | シークレット情報の混入を検出する静的解析ツール |
| cspell      | スペルチェックツール(コード/ドキュメント向け)  |
| dprint      | 高速で拡張性のあるコードフォーマッター(任意)   |

> **注意事項**
> これらのツールは、パッケージマネージャーや pnpm によりプロジェクトとは独立にインストールされます。
> バージョン管理やアップデートは、利用者自身で行ってください。

## 公開アクション / ワークフロー

公開コンポーネントは、リリースタグを指定して参照します。
例: `aglabo/ci-platform/.github/actions/<action>@v0.5.0`

### Composite Actions

| アクション                             | 説明                                                                                                                           |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `ca-get-changed-files` (v0.5.0 で追加) | トリガーイベント (push / pull_request / HEAD~N) で変更されたファイルを取得し、glob パターンで絞り込む。出力は `files`、`count` |
| `ca-setup-repo`                        | ツールリポジトリを検証・チェックアウトし、`pnpm install` 後に `bin/` を `PATH` へ追加する                                      |
| `ca-setup-tool`                        | GitHub Releases からツールをダウンロード・検証・インストールする                                                               |
| `ca-validate-environment`              | ランナー環境 (Linux 限定、アーキテクチャ、権限) を検証する                                                                     |

### 再利用可能ワークフロー

| ワークフロー              | 説明                                                 |
| ------------------------- | ---------------------------------------------------- |
| `ru-qa-actionlint.yml`    | jactionlint で GitHub Actions ワークフローを検証する |
| `ru-qa-ghalint.yml`       | ghalint で GitHub Actions ワークフローを検証する     |
| `ru-scan-betterleaks.yml` | betterleaks でリポジトリのシークレット混入を検出する |

### 使用例: `ca-get-changed-files`

```yaml
steps:
  - uses: actions/checkout@v7.0.1
    with:
      fetch-depth: 0 # 必須
  - id: changed
    uses: aglabo/ci-platform/.github/actions/ca-get-changed-files@v0.5.0
    with:
      pattern: |
        **/*.md
        !docs/**
  - if: steps.changed.outputs.count != '0'
    env:
      CHANGED_FILES: ${{ steps.changed.outputs.files }}
    run: printf '%s\n' "$CHANGED_FILES"
```

## ライセンス

このテンプレートは MIT ライセンスのもとで提供されています。
詳細は [LICENSE](./LICENSE) をご確認ください。
