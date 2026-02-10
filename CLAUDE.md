# CLAUDE.md - AI協働ガイド

<!-- textlint-disable ja-technical-writing/max-comma -->

## コア原則 (第1層)

### プロジェクト哲学

**ミッション**: OSS 開発のための包括的 CI/品質管理基盤を提供します。

このプロジェクトは、GitHub Actions と Git Hooks を統合した品質管理テンプレートを提供します。

**コア機能**:

- ローカル品質管理: lefthook による Git Hook 統合（gitleaks/secretlint/commitlint/AI 生成コミットメッセージ）
- CI/CD 基盤: GitHub Actions 再利用可能ワークフロー（actionlint/ghalint/gitleaks）
- ドキュメント品質: textlint/markdownlint/dprint による自動検証
- 開発環境: セットアップスクリプトと ShellSpec テストフレームワーク

### AI協働の絶対ルール

**即座に実行**:

- 特定箇所の編集指示→即実行（探索不要）
- 明確な指示→質問せず最もシンプルなアプローチで実行
- テスト実行→必ず `./scripts/run-specs.sh` を使用（`shellspec` 直接実行禁止）

**IDD Framework スキル使用**:

Issue/PR/コミット管理には必ず IDD Framework スキルを使用:

- Issue 作成: `/idd:issue:new` (タイトル指定で自動生成)
- Issue 編集: `/idd:issue:edit` (対話的編集)
- Issue 一覧: `/idd:issue:list` (選択可能)
- Issue Push: `/idd:issue:push` (GitHub 登録)
- PR 作成: `/idd-pr new` (pr-generator エージェント起動)
- PR Push: `/idd-pr push` (GitHub PR 作成)
- コミット: `/idd-commit-message` (Conventional Commits 準拠)

詳細は以下ディレクトリ配下を参照してください。
`C:\Users\atsushifx\.claude\plugins\marketplaces\claude-idd-framework-marketplace\.claude\commands\`

**絶対禁止**:

- テストファイル (`spec/**/*_spec.sh`) の変更（明示的指示がない限り）
- Issue/PR 作成時のコード実装（ドキュメント作成のみ）
- IDD スキル使用せずに手動で Issue/PR/コミット作成
- セキュリティパーミッション (`contents: write`, `id-token: write`) の安易な追加
- gitleaks/secretlint 除外設定の追加（真に必要な場合のみ）

**保護領域** (変更時は理由明記):

- `configs/gitleaks.toml`
- `configs/secretlint.config.yaml`
- `lefthook.yml`
- `.github/workflows/*.yml`

### ShellSpec固有ルール

**構文**:

- グロブパターン使用（正規表現ではない）
- `#|` は ShellSpec 固有コメント
- `.shellspecrc` 設定必ず確認

**テスト修正禁止**:

- ソースコード修正でテスト通過させる
- テストは変更しない
- グローバル配列使用時は BeforeEach/AfterEach による setup/teardown 必須

**テストパターン**:

```bash
#shellcheck shell=sh

Describe 'script-name.sh'
  Include ../script-name.sh

  Describe 'function_name()'
    Context 'with valid input'
      It 'describes expected behavior'
        When call function_name "arg"
        The output should eq "expected"
        The status should be success
      End
    End
  End
End
```

**グローバル配列の扱い**:

```bash
BeforeEach 'setup_globals'
AfterEach 'teardown_globals'

setup_globals() {
  declare -a MY_ARRAY=()
}

teardown_globals() {
  unset MY_ARRAY
}
```

### GitHub Actions必須パターン

**Validation Dependencies**:

```yaml
if: steps.previous_step.outcome == 'success'  # 正しい
if: steps.previous_step.outputs.status != 'error'  # 禁止（bypass可能）
```

**Note**: これは将来の Composite Actions 実装時の設計原則です。

## 技術コンテキスト (第2層)

### 技術スタック

```yaml
コア技術:
  - GitHub Actions (再利用可能ワークフロー)
  - lefthook (Git Hook統合)
  - ShellSpec (Bashテストフレームワーク)

品質ツール:
  - actionlint, ghalint (Actions検証)
  - gitleaks, secretlint (シークレット検出)
  - textlint, markdownlint (ドキュメント校正)
  - dprint (フォーマッター)
  - commitlint (コミットメッセージ検証)

将来の拡張:
  - Composite Actions開発
```

### アーキテクチャ

**アーキテクチャ構成**:

**現在の実装**:

1. **GitHub Actionsワークフロー**:
   - `ci-scan-all.yml` - 外部再利用可能ワークフローを呼び出し（actionlint/ghalint/gitleaks）
   - `aglabo/.github` リポジトリのワークフローを活用

2. **Git Hook統合** (lefthook):
   - `pre-commit`: gitleaks, secretlint
   - `prepare-commit-msg`: AI 自動生成（Claude/GPT 対応）
   - `commit-msg`: commitlint 検証

3. **開発ツール**:
   - `setup-dev-env.sh`: lefthook + ShellSpec 環境構築
   - `prepare-commit-msg.sh`: AI 駆動コミットメッセージ生成
   - `run-specs.sh`: ShellSpec テスト実行

**ディレクトリ構成**:

```bash
.github/workflows/        # GitHub Actionsワークフロー
configs/                  # 品質ツール設定ファイル
scripts/                  # 開発環境セットアップスクリプト
.claude/agents/           # AI協働エージェント設定
```

### 開発ワークフロー

**セットアップ**:

```bash
./scripts/setup-dev-env.sh  # 開発環境セットアップ（lefthook + ShellSpec）
```

**コミットフロー**:

```bash
git add .
git commit
  → [pre-commit] gitleaks + secretlint
  → [prepare-commit-msg] AI自動生成（Claude/GPT対応）
  → [commit-msg] commitlint検証
```

**ブランチ戦略**: `main` (安定), `releases` (リリース), `feature/*`, `fix/*`, `docs/*`, `refactor/*`, `test/*`

**コミット形式**: Conventional Commits (`feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `ci`)

**テスト実行**:

```bash
# すべてのテストを実行
./scripts/run-specs.sh

# 特定のテストファイルを実行
./scripts/run-specs.sh scripts/__tests__/greeting.spec.sh

# フォーカスモード（f-prefixed examples のみ）
./scripts/run-specs.sh --focus
```

**テスト構造**:

- テストファイルの配置: `<script_dir>/__tests__/<name>.spec.sh`
- 設定ファイル: `configs/.shellspecrc`
- インポートパターン: `Include ../script.sh` (相対パス)
- グローバル配列使用時: `BeforeEach`/`AfterEach` による setup/teardown 必須

### 主要コマンド

```bash
# ShellSpec テスト実行
./scripts/run-specs.sh                    # すべてのテストを実行
./scripts/run-specs.sh --focus            # フォーカスモード（focused examples のみ）
./scripts/run-specs.sh scripts/__tests__  # 明示的にディレクトリ指定
pnpm test:sh                              # npm script 経由

# CI検証
actionlint -config-file ./configs/actionlint.yaml .github/workflows/*.yml
ghalint run --config ./configs/ghalint.yaml
gitleaks detect --source . --verbose

# ドキュメント検証
pnpm run lint:text  # textlint によるドキュメント品質チェック
pnpm run lint:text -- --fix  # 自動修正

# フォーマット
dprint fmt
```

### コードスタイル

**Actions設計**:

- 入力パラメータは明示的デフォルト値設定
- セキュリティパーミッション最小限
- エラーメッセージは具体的に

**YAML**:

- `permissions` セクション必須
- 依存関係は `needs` で明示

**日本語**:

- 一文 100 文字以内（textlint 検証）
- 技術用語統一

## ドキュメント参照 (第3層)

### 詳細仕様

- `README.md` / `README.ja.md` - プロジェクト概要とセットアップガイド
- `.github/SECURITY.md` - セキュリティポリシー
- `.claude/agents/*.md` - AI 協働エージェント設定
- `configs/*` - 品質ツール設定ファイル
- `lefthook.yml` - Git Hook 統合設定

**Note**: `.serena/memories/` および `CONTRIBUTING.md` は未作成（作成推奨）

### トラブルシューティング

```bash
# lefthook再設定
lefthook uninstall && lefthook install

# AI CLIデバッグ
scripts/prepare-commit-msg.sh
```

### 情報探索優先順位

1. この CLAUDE.md（協働ルール、禁止事項）
2. Actions README（パラメータ仕様）
3. Serena メモリー（詳細技術情報）
4. CONTRIBUTING（開発プロセス）
