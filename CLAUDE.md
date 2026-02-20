# CLAUDE.md - AI協働ガイド

<!-- textlint-disable ja-technical-writing/max-comma -->

## プロジェクト概要

**ミッション**: OSS 開発のための包括的 CI/品質管理基盤テンプレート。

GitHub Actions と Git Hooks を統合した品質管理テンプレートを提供する。

**コア機能**:

- ローカル品質管理: lefthook (gitleaks/secretlint/commitlint/AI コミットメッセージ)
- CI/CD 基盤: GitHub Actions 再利用可能ワークフロー (actionlint/ghalint/gitleaks)
- ドキュメント品質: textlint/markdownlint/dprint
- テストフレームワーク: ShellSpec (Bash)

## AI協働ルール

**即座に実行**:

- 特定箇所の編集指示→即実行 (探索不要)
- 明確な指示→質問せず最もシンプルなアプローチで実行

**IDD Framework スキル** (Issue/PR/コミット管理は必ずスキル経由):

参照先: `C:\Users\atsushifx\.claude\plugins\marketplaces\claude-idd-framework-marketplace`

- Issue 作成: `/claude-idd-framework:\idd\issue:new`
- Issue 編集: `/claude-idd-framework:\idd\issue:edit`
- Issue 一覧: `/claude-idd-framework:\idd\issue:list`
- Issue Push: `/claude-idd-framework:\idd\issue:push`
- PR 作成/Push: `/claude-idd-framework:idd-pr new` / `/claude-idd-framework:idd-pr push`
- コミットメッセージ: `/claude-idd-framework:idd-commit-message`

**絶対禁止**:

- テストファイル (`__tests__/**/*.spec.sh`) の変更 (明示的指示がない限り)
- IDD スキルを使わずに手動で Issue/PR/コミット作成
- `contents: write`、`id-token: write` の安易な追加
- gitleaks/secretlint 除外設定の追加

**保護領域** (変更時は理由明記):

`configs/gitleaks.toml`, `configs/secretlint.config.yaml`, `lefthook.yml`, `.github/workflows/*.yml`

## 技術スタック

**コア**: GitHub Actions (再利用可能ワークフロー), lefthook (Git Hook 統合), ShellSpec (Bash テスト)

**品質ツール**: actionlint, ghalint, gitleaks, secretlint, textlint, markdownlint, dprint, commitlint

**ディレクトリ構成**:

```bash
.github/workflows/      # GitHub Actions ワークフロー (ci-scan-all.yml)
.github/actions/        # Composite Actions (validate-environment)
configs/                # 品質ツール設定ファイル
scripts/                # 開発スクリプト (run-specs/setup/prepare-commit-msg)
.serena/memories/       # Serena MCP 技術メモリー
```

## Claude Code から ShellSpec を実行する方法

**Bash tool の制約 (Windows 環境)**:

- `cd` を使うと後続コマンドが失敗する → **`cd` 禁止**
- `C:/...` 形式のパスは shellspec が `C.` と誤解釈する → **Unix 形式 `/c/...` を使用**
- ShellSpec のデフォルト出力は TTY に直接書き込む → `2>&1 | cat` では捕捉不可
- `pnpm run test:sh` 経由ではサブプロセスの出力が見えない

**正しい実行パターン** (Bash tool からテスト結果を確認する唯一の方法):

```bash
# 1. mktemp で一意ファイルを作成してテスト実行 (Unix/Windows パスを両方出力)
_spec_out=$(mktemp)
PROJECT_ROOT="/c/Users/atsushifx/workspaces/develop/ci-platform" \
bash "/c/Users/atsushifx/workspaces/develop/ci-platform/scripts/run-specs.sh" \
  "<relative-spec-path>" --format tap --no-color > "$_spec_out" 2>&1
echo "exit:$?"; echo "win:$(cygpath -w "$_spec_out")"; echo "unix:$_spec_out"

# 2. Read ツールで結果を確認 (win: 行の Windows パスを使用)
# Read: W:\temp\tmp.XXXXXXXXXX

# 3. 確認後に削除 (unix: 行の Unix パスを使用)
rm /w/temp/tmp.XXXXXXXXXX
```

**確認ポイント**: `ok N - ...` が全件並び、`not ok` がなければ PASS。

---

## 主要コマンド

```bash
# 開発環境セットアップ
bash ./scripts/setup-dev-env.sh           # lefthook + ShellSpec インストール

# テスト実行 (shellspec 直接呼び出し禁止、run-specs.sh 経由のみ)
bash ./scripts/run-specs.sh               # 全テスト
bash ./scripts/run-specs.sh --focus       # フォーカスモード
bash ./scripts/run-specs.sh scripts/__tests__  # ディレクトリ指定
pnpm test:sh                              # pnpm 経由

# ドキュメント検証
pnpm run lint:text                        # textlint 検証
pnpm run lint:text -- --fix               # 自動修正
dprint fmt                                # フォーマット

# CI 検証 (ローカル)
actionlint -config-file ./configs/actionlint.yaml .github/workflows/*.yml
ghalint run --config ./configs/ghalint.yaml
gitleaks detect --source . --verbose

# トラブルシューティング
lefthook uninstall && lefthook install    # lefthook 再設定
```

## コーディング規約

**GitHub Actions**:

- `permissions` セクション必須 (最小権限: `contents: read`)
- Validation: `if: steps.X.outcome == 'success'` (`outputs.status != 'error'` は禁止)
- 入力パラメータは明示的デフォルト値設定

**コミット形式**: Conventional Commits (ヘッダー 72 文字以内)

- 型: `feat`, `fix`, `docs`, `test`, `refactor`, `perf`, `ci`, `config`, `release`, `merge`, `build`, `style`, `deps`, `chore`

**ブランチ戦略**: `main` (安定), `releases` (リリース), `feature/*`, `fix/*`, `docs/*`, `refactor/*`, `test/*`

**テスト配置**: `<script_dir>/__tests__/<name>.<tier>.spec.sh`

- ティア: `unit`, `functional`, `integration`, `e2e`
- インポートパターン: `Include ../script.sh` (相対パス)
- グローバル配列使用時: `BeforeEach`/`AfterEach` による setup/teardown 必須

## ドキュメント参照

- `README.md` / `README.ja.md` - プロジェクト概要・セットアップガイド
- `.serena/memories/` - Serena MCP 技術メモリー (構造・テスト・スクリプト・設定)
- `configs/*` - 品質ツール設定ファイル
- `lefthook.yml` - Git Hook 統合設定
- `.claude/agents/*.md` - AI エージェント設定

**情報探索優先順位**: CLAUDE.md → `.serena/memories/` → `README.md` → `configs/`
