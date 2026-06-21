---
id: REQ
module: composite-action/get-changed-files
status: approved
---

# Requirements: ca-get-changed-files

## Functional Requirements

### REQ-F-001: SHA内部取得

- pushイベントの `github.event.before`（開始SHA）と `github.sha`（終了SHA）をaction内部で取得する
- 外部inputとしてSHAを公開しない（push専用として完全内部化）

### REQ-F-002: ゼロSHAフォールバック

- `before` SHAが40桁のゼロ（新ブランチpush時）の場合、git empty-tree SHA（`4b825dc642cb6eb9a060e54bf8d69288fbee4904`）を使用する

### REQ-F-003: 変更ファイル取得

- `git diff --name-only --diff-filter=ACMR` で変更ファイルを取得する
- diff-filter: A（追加）、C（コピー）、M（変更）、R（リネーム）のみ対象

### REQ-F-004: globパターンフィルター

- `pattern` inputでgit pathspec globを指定できる（例: `*.ts`, `src/**/*.sh`）
- デフォルト値は空文字（全ファイル対象）
- 空のとき `--` pathspec 引数を付けない

### REQ-F-005: files output

- 変更ファイルのパス一覧を改行区切りで `files` outputに書き出す
- `$GITHUB_OUTPUT` のmultiline形式（`files<<EOF…EOF`）で出力する

### REQ-F-006: count output

- 変更ファイル数を整数で `count` outputに書き出す

## Non-Functional Requirements

### REQ-NF-001: fetch-depth制約

- 正常動作には呼び出し元での `fetch-depth: 0` 設定が必須
- この制約をaction.ymlのdescriptionに明記する

### REQ-NF-002: 最小権限

- 必要な権限は `contents: read` のみ

## Constraints

### REQ-C-001: pushイベント専用

- このactionはpushイベントでのみ正常動作する
- PRイベント等では `github.event.before` が存在しない場合がある
