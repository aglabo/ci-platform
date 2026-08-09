---
id: REQ
module: composite-action/get-changed-files
status: approved
---

<!-- cspell:words ACMR -->

# Requirements: ca-get-changed-files

## Functional Requirements

### REQ-F-001: SHA内部取得

- push イベントの `github.event.before` (開始 SHA) と `github.sha` (終了 SHA) を action 内部で取得する
- 外部 input として SHA を公開しない (push 専用として完全内部化)

### REQ-F-002: ゼロSHAフォールバック

- `before` SHA が 40桁のゼロ (新ブランチ push 時) の場合、git empty-tree SHA を使用する

### REQ-F-003: 変更ファイル取得

- `git diff --name-only --diff-filter=ACMR` で変更ファイルを取得する
- diff-filter: A (追加) 、C (コピー) 、M (変更) 、R (リネーム) のみ対象

### REQ-F-004: globパターンフィルター

- `pattern` input で git pathspec glob を指定できる (例: `*.ts`, `src/**/*.sh`)
- デフォルト値は空文字 (全ファイル対象)
- 空のとき `--` pathspec 引数を付けない

### REQ-F-005: files output

- 変更ファイルのパス一覧を改行区切りで `files` output に書き出す
- `$GITHUB_OUTPUT` の multiline 形式 (`files<<EOF…EOF`) で出力する

### REQ-F-006: count output

- 変更ファイル数を整数で `count` output に書き出す

## Non-Functional Requirements

### REQ-NF-001: fetch-depth制約

- 正常動作には呼び出し元での `fetch-depth: 0` 設定が必須
- この制約を action.yml の description に明記する

### REQ-NF-002: 最小権限

- 必要な権限は `contents: read` のみ

## Constraints

### REQ-C-001: pushイベント専用

- この action は push イベントでのみ正常動作する
- PR イベント等では `github.event.before` が存在しない場合がある
