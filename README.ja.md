# 📦 OSS向けプロジェクトテンプレート（日本語版）

このテンプレートは、モダンな OSS 開発のための初期構成を素早く立ち上げられるように設計されています。

---

## 🛠 特徴

- PowerShell スクリプトによる簡単な開発環境セットアップ
  - Scoop & pnpm を使った、Windows での軽量なセットアップ
- EditorConfig、.gitignore などプロジェクト開始時に必要なファイルを完備
  - ミニマムな設定で、後からの拡張も可能
- lefthook による軽量な Git Hook 環境
  - gitleaks や secretlint によって API キーなどの漏洩を未然に防止

---

## 🚀 使用方法

1. このテンプレートリポジトリを、自分の GitHub にフォークします。
2. 自分の環境に合わせて書き換えます（例: LICENSE の名前を自分のハンドル名に変更）。
3. GitHub 上で新規リポジトリを作成する際に、フォークしたテンプレートから生成します。
4. 必要な設定ファイルを含んだリポジトリが自動で作成されます。

---

## 🧰 含まれるツール一覧

| ツール名   | 説明                                             |
| ---------- | ------------------------------------------------ |
| lefthook   | Git コミットフックの管理                         |
| delta      | Git の差分を視覚的に表示するツール               |
| commitlint | コミットメッセージ形式の検証                     |
| gitleaks   | 機密情報の混入を検出するセキュリティツール       |
| secretlint | シークレット情報の混入を検出する静的解析ツール   |
| cspell     | スペルチェックツール（コード／ドキュメント向け） |
| dprint     | 高速で拡張性のあるコードフォーマッター（任意）   |

> ⚠️ **注意事項**
> これらのツールは、Scoop や pnpm によりプロジェクトとは独立にインストールされます。
> バージョン管理やアップデートは、利用者自身で行ってください。

---

## 🧪 テスト

このプロジェクトは [ShellSpec](https://shellspec.info/) を使用してシェルスクリプトのテストを行います。

### テストの実行

```bash
# 開発環境のセットアップ（ShellSpecを含む）
./scripts/setup-dev-env.sh

# すべてのテストを実行
./scripts/run-specs.sh

# 特定のテストファイルを実行
./scripts/run-specs.sh scripts/__tests__/greeting.spec.sh

# フォーカスモードで実行
./scripts/run-specs.sh --focus
```

### テスト構造

テストは次のような `__tests__` サブディレクトリパターンに従います。

```text
scripts/
├── greeting.sh              # 実装スクリプト
├── __tests__/
│   └── greeting.spec.sh     # greeting.sh のテスト
├── setup-dev-env.sh         # 実装スクリプト
└── __tests__/
    └── setup-dev-env.spec.sh  # setup-dev-env.sh のテスト（将来）
```

### テストの書き方

参考実装として `scripts/__tests__/greeting.spec.sh` を確認してください。

主要パターンは次のとおりです。

- テストファイルの配置: `<script_dir>/__tests__/<name>.spec.sh`
- ソースのインポート: `Include ../script.sh`
- `Describe` → `Context` → `It` の階層構造を使用
- output、stderr、終了コードを検証

---

## 📄 ライセンス

このテンプレートは MIT ライセンスのもとで提供されています。
詳細は [LICENSE](./LICENSE) をご確認ください。
