---
id: TASKS
module: composite-action/get-changed-files
status: approved
refs: [IMPL]
---

# Tasks: ca-get-changed-files

## Implementation Tasks

### T-01: filter.lib.sh の実装（BDD）

**対象ファイル:**

- `scripts/_libs/filter.lib.sh`
- `scripts/__tests__/unit/filter.unit.spec.sh`

**テストケース:**

#### resolve_before_sha()

- `[nrm-01]` 正常SHA → そのまま返す
- `[nrm-02]` ゼロSHA（40桁）→ empty-tree SHAを返す
- `[edg-01]` 空文字 → empty-tree SHAを返す
- `[edg-02]` 短いゼロ列 → そのまま返す（40桁のみフォールバック対象）

#### write_multiline_output()

- `[nrm-01]` 単行値 → `key<<EOF\nvalue\nEOF\n` 形式で出力
- `[nrm-02]` 複数行値 → 全行を含む形式で出力
- `[edg-01]` 空値 → `key<<EOF\n\nEOF\n` 形式で出力

### T-02: get-changed-files.sh の実装（BDD）

**対象ファイル:**

- `scripts/get-changed-files.sh`
- `scripts/__tests__/functional/get-changed-files.functional.spec.sh`

**テストケース:**

- `[nrm-01]` 正常なBEFORE/AFTER SHA → 変更ファイル一覧を出力
- `[nrm-02]` pattern指定あり → フィルターされたファイルのみ出力
- `[nrm-03]` pattern空（デフォルト）→ 全ファイルを出力
- `[edg-01]` ゼロSHA → empty-treeとdiffして正常動作
- `[err-01]` BEFORE_SHA未設定 → エラー終了

### T-03: action.yml の作成

**対象ファイル:**

- `action.yml`

**内容:** SPEC記載のaction.yml構造に従って作成（BDDサイクル対象外、ドキュメント作成）

## Execution Order

1. T-01: filter.lib.sh（bdd-coderで実装）
2. T-02: get-changed-files.sh（bdd-coderで実装）
3. T-03: action.yml（直接作成）

## BDD Coder Handoff

T-01, T-02はbdd-coderエージェントに委譲する。
引き継ぎ情報:

- 作業種別: 新機能追加
- テストフレームワーク: ShellSpec
- テストコマンド: `bash ./scripts/run-specs.sh <spec-path> --format tap --no-color`
- プロジェクトルート: `/c/Users/atsushifx/workspaces/develop/ci-platform`
