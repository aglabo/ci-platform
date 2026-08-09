---
id: SPEC
module: composite-action/get-changed-files
status: approved
refs: [REQ-F-001, REQ-F-002, REQ-F-003, REQ-F-004, REQ-F-005, REQ-F-006]
---

# Specifications: ca-get-changed-files

## Action Interface

### action.yml

```yaml
name: "get-changed-files"
description: |
  Get changed files between push before/after commits.
  IMPORTANT: Requires fetch-depth: 0 in actions/checkout.

inputs:
  pattern:
    description: "Git pathspec glob filter (e.g. '*.ts', 'src/**/*.sh'). Empty = all files."
    required: false
    default: ""

outputs:
  files:
    description: "Newline-separated list of changed file paths"
    value: ${{ steps.get-changed-files.outputs.files }}
  count:
    description: "Number of changed files"
    value: ${{ steps.get-changed-files.outputs.count }}

runs:
  using: composite
  steps:
    - name: Get changed files
      id: get-changed-files
      shell: bash
      run: bash "${{ github.action_path }}/scripts/get-changed-files.sh"
      env:
        BEFORE_SHA: ${{ github.event.before }}
        AFTER_SHA: ${{ github.sha }}
        PATTERN: ${{ inputs.pattern }}
```

## Script Specifications

### get-changed-files.sh

**入力（環境変数）:**

- `BEFORE_SHA`: push イベント前の SHA（`github.event.before` から注入）
- `AFTER_SHA`: push イベント後の SHA（`github.sha` から注入）
- `PATTERN`: glob パターン（空可）

**処理フロー:**

1. `BEFORE_SHA`/`AFTER_SHA` の存在確認
2. `resolve_before_sha()`: ゼロ SHA を empty-tree に置換
3. PATTERN が空でなければ pathspec 引数を構築
4. `git diff --name-only --diff-filter=ACMR $BEFORE $AFTER [-- $PATTERN]` を実行
5. `write_multiline_output "files" "$result"` で GITHUB_OUTPUT に書き出し
6. `echo "count=$count" >> $GITHUB_OUTPUT` で count 書き出し

### filter.lib.sh（ライブラリ関数）

#### resolve_before_sha(sha)

- 入力: SHA 文字列
- 出力: 解決済み SHA（ゼロ SHA の場合は empty-tree SHA）
- 空 SHA の場合も empty-tree を返す

#### write_multiline_output(key, value)

- `$GITHUB_OUTPUT` に multiline 形式で書き出す
- フォーマット: `key<<EOF\nvalue\nEOF\n`
- fallback: `${GITHUB_OUTPUT:-/dev/null}`

## Test Scope

| spec                   | test type  | 対象                  |
| ---------------------- | ---------- | --------------------- |
| resolve_before_sha     | unit       | 正常SHA/ゼロSHA/空SHA |
| write_multiline_output | unit       | 単行/複数行/空値      |
| get-changed-files.sh   | functional | 全体フロー            |
