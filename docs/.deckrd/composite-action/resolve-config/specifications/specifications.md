---
title: "Design Specification: _ca-resolve-config"
based-on: requirements.md v1.0.0
status: Draft
version: 1.0.0
created: "2026-11-19"
---

## 1. Overview

### 1.1 Purpose

`_ca-resolve-config` が、設定ファイルを 1 つに決める振る舞いを定義する。
入力、判定規則、出力、エラーの形式を扱う。実装の配置は implementation.md が定める。

### 1.2 Scope

- 3 つの入力から 1 つの設定ファイルを選ぶ判定
- パス検査の契約 (`validate_path`)
- 出力の書き出しと `::notice::`
- エラーの対象・問題・値

## 2. Design Principles

### 2.1 Design Assumptions

- 候補の数は 3 つに固定する。呼び出し元は、ツールごとに `local-config` と `global-config` を渡す。
- 相対パスは `GITHUB_WORKSPACE` を起点とする。
- 存在の確認は呼び出し元の探索側 (`_rc_try`) が行う。`validate_path` は存在を要求しない。

### 2.2 External Design Summary

| 単位             | 責務                                                              | 配置                                  |
| ---------------- | ----------------------------------------------------------------- | ------------------------------------- |
| `main`           | 環境変数を読み、成功時だけ `GITHUB_OUTPUT` と `::notice::` を書く | `scripts/resolve-config.sh`           |
| `resolve_config` | 探索順を実装し、`<path> <source>` を 1 行で返す                   | `scripts/_libs/resolve-config.lib.sh` |
| `_rc_try`        | 1 つの候補を検査する (空・拒否・不在・採用)                       | 同上                                  |
| `_rc_resolve`    | `validate_path` に `GITHUB_WORKSPACE` を渡す                      | 同上                                  |
| `validate_path`  | パスの絶対化と、字面・realpath の検査                             | `.github/actions/_libs/path.lib.sh`   |
| `write_output`   | key=value を `GITHUB_OUTPUT` に追記する                           | `.github/actions/_libs/output.lib.sh` |

データの流れ:

```text
INPUT_CONFIG / INPUT_LOCAL_CONFIG / INPUT_GLOBAL_CONFIG
   -> main -> resolve_config -> _rc_try -> _rc_resolve -> validate_path
   -> "<path> <source>" -> write_output (config-file, source) + ::notice::
```

### 2.3 Non-Goals

- 設定ファイルの内容検査
- 候補の追加 (4 つ目以降の候補)
- 存在しないパスの作成

## 3. Behavioral Specification

### 3.1 Input Domain

| 入力            | 型     | 既定 | 意味                             |
| --------------- | ------ | ---- | -------------------------------- |
| `config`        | string | ""   | 明示指定。空でなければ唯一の候補 |
| `local-config`  | string | ""   | リポジトリ内の設定のパス         |
| `global-config` | string | ""   | グローバル設定のパス             |

action.yml の入力名はハイフン区切り、スクリプトの環境変数は `INPUT_CONFIG` / `INPUT_LOCAL_CONFIG` / `INPUT_GLOBAL_CONFIG` とする。
未設定の環境変数は空として扱う (`${VAR:-}`)。

### 3.2 Output Semantics

| 出力          | 値                                            |
| ------------- | --------------------------------------------- |
| `config-file` | 採用したファイルの絶対パス (symlink は未解決) |
| `source`      | `input` / `local` / `global`                  |

`resolve_config` は、成功時に `<path> <source>` を標準出力へ 1 行出す。
パスに空白は含まれない (R-VAL-003)。このため、空白区切りで安全に分割できる。

### 3.3 Candidate Status

`_rc_try` の戻り値は、次の 3 値とする。

| 戻り値 | 意味                               |
| ------ | ---------------------------------- |
| 0      | 候補を採用した (標準出力に結果)    |
| 1      | パスを拒否した (エラー出力済み)    |
| 2      | 候補が空、または通常ファイルでない |

## 4. Decision Rules

評価は次の順序で行う。順序の入れ替えは認めない。

| Rule ID   | Step | Condition                             | Outcome                                                       |
| --------- | ---- | ------------------------------------- | ------------------------------------------------------------- |
| R-RES-001 | 1    | `GITHUB_WORKSPACE` が未設定または空   | エラー (対象 `GITHUB_WORKSPACE`)、終了コード 1                |
| R-RES-002 | 2    | `config` が空でない かつ 通常ファイル | 採用、source=input                                            |
| R-RES-003 | 2    | `config` が空でない かつ 拒否         | エラー、終了コード 1 (フォールバックなし)                     |
| R-RES-004 | 2    | `config` が空でない かつ 不在         | エラー `config: file not found (got: '<値>')`、終了コード 1   |
| R-RES-005 | 3    | `local-config` が通常ファイル         | 採用、source=local                                            |
| R-RES-006 | 3    | `local-config` が拒否                 | エラー、終了コード 1 (`global-config` へフォールバックしない) |
| R-RES-007 | 4    | `global-config` が通常ファイル        | 採用、source=global                                           |
| R-RES-008 | 4    | `global-config` が拒否                | エラー、終了コード 1                                          |
| R-RES-009 | 5    | 上のいずれにも当たらない              | エラー `config: no configuration file found`、終了コード 1    |

R-RES-004 と R-RES-009 の「値」は、R-RES-009 では `local-config`、空なら `global-config` の値とする。

パス検査 (`validate_path`) の規則:

| Rule ID   | Step | Condition                                               | Outcome                                        |
| --------- | ---- | ------------------------------------------------------- | ---------------------------------------------- |
| R-VAL-001 | 1    | 値が空                                                  | エラー (空の形式)、終了コード 1                |
| R-VAL-002 | 2    | 値に ".." のセグメントがある                            | エラー `must not contain '..'`                 |
| R-VAL-003 | 3    | 値に空白がある                                          | エラー `must not contain whitespace`           |
| R-VAL-004 | 4    | 絶対化した結果が `<root>/` の下に無い (root 自体を含む) | エラー `must be inside the root`               |
| R-VAL-005 | 5    | realpath が解決でき、実体が root の実体の下に無い       | エラー `must not resolve outside the root`     |
| R-VAL-006 | 6    | 上のいずれにも当たらない                                | 未解決の絶対パスを標準出力へ出す、終了コード 0 |

補足:

- 絶対パスは、そのまま使う。相対パスは `<root>/<値>` にする。root 末尾の `/` は無視する。
- realpath を解決できないパス (不在、dangling symlink) は拒否しない。存在の判定は `_rc_try` が行う。
- `..` を部分文字列に持つ名前 (`a..b`) はセグメントではないので受理する。
- root の空白は許す。空白の検査は値だけに掛ける。
- 兄弟ディレクトリ (`ws-evil`) は、接頭辞が同じでも root の外と判定する。

## 5. Edge Cases

| Input                                     | Classification      | REQ        | Rationale                            |
| ----------------------------------------- | ------------------- | ---------- | ------------------------------------ |
| `config` が workspace 内の絶対パス        | 採用 (input)        | REQ-F-001  | workspace の下なので許す             |
| `GITHUB_WORKSPACE` 自体が symlink         | 採用                | REQ-F-004  | 実体同士で比べるため                 |
| workspace 内の symlink チェーン           | 採用                | REQ-F-004  | 実体が workspace の下にある          |
| 接頭辞が同じ兄弟 (`ws-evil`) への symlink | 拒否                | REQ-F-004  | 接頭辞の一致だけでは内側と判定しない |
| `config` がディレクトリ                   | エラー (不在)       | REQ-F-006  | 通常ファイルのみ採用                 |
| dangling symlink                          | エラー (不在)       | REQ-F-006  | 実体がない                           |
| `..` を含み workspace 内で完結するパス    | 拒否                | REQ-F-004  | 字面で拒否する                       |
| 値にコマンド置換 (`$(...)`)               | 文字列として扱う    | REQ-NF-002 | 評価しない                           |
| 同じライブラリを 2 回 source              | 再定義しない        | REQ-C-002  | ロードガード                         |
| `resolve-config.sh` を source             | `main` を実行しない | REQ-C-001  | 実行時だけ `main` を呼ぶ             |

## 6. Output and Error Format

### 6.1 エラーの形式

`gha_error <対象> <問題> <値>` が、標準エラー出力へ 1 行を出す。

```text
::error::<対象>: <問題> (got: '<値>')
```

- 値は `%` → `%25`、CR → `%0D`、LF → `%0A` にエンコードする。
- 引数が 3 つ未満の場合は `::error::<対象>: value must not be empty` を出す。
- `gha_error` は常に 0 を返す。呼び出し側が終了コードを決める。

R-ERR-001: エラー時、標準出力と `GITHUB_OUTPUT` には何も書かない。

### 6.2 成功時の出力

`main` は `resolve_config` が成功した後、次の順に書く。

1. `config-file=<path>` を `GITHUB_OUTPUT` に追記する
2. `source=<source>` を `GITHUB_OUTPUT` に追記する
3. `::notice::Using <source> config: <path>` を標準出力へ 1 行出す

`write_output` が失敗した場合 (`GITHUB_OUTPUT` が空など) は、終了コード 1 を返す。

## 7. Requirements Traceability

| REQ        | Rules                                      |
| ---------- | ------------------------------------------ |
| REQ-F-001  | R-RES-002, R-RES-004                       |
| REQ-F-002  | R-RES-005, R-RES-007                       |
| REQ-F-003  | 3.2, 6.2                                   |
| REQ-F-004  | R-VAL-001..R-VAL-006, R-RES-003, R-RES-008 |
| REQ-F-005  | R-RES-006                                  |
| REQ-F-006  | 3.3, R-RES-004                             |
| REQ-F-007  | R-RES-009                                  |
| REQ-F-008  | R-RES-001                                  |
| REQ-F-009  | 6.1 (R-ERR-001), 6.2                       |
| REQ-NF-003 | 6.1                                        |

## 8. Open Questions

| Question                                            | Status |
| --------------------------------------------------- | ------ |
| dangling symlink を「不在」ではなく「拒否」にするか | Open   |

## 9. Change History

| Date       | Version | Description     |
| ---------- | ------- | --------------- |
| 2026-11-19 | 1.0.0   | Initial release |
