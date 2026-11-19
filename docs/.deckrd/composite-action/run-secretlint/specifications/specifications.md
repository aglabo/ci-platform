---
title: "Design Specification: ca-run-secretlint"
based-on: requirements.md v1.0.0
status: Draft
version: 1.0.0
created: "2026-11-19"
---

## 1. Overview

### 1.1 Purpose

`ca-run-secretlint` が、secretlint を実行する振る舞いを定義する。
入力の検証、実行するコマンド、終了コードの扱いを定める。配置は implementation.md が定める。

### 1.2 Scope

- 入力 `pnpm-version` / `secretlint-version`
- `secretlint-version` の判定規則
- 実行するコマンドと、終了コードの伝搬
- `action.yml` の静的な契約

## 2. Design Principles

### 2.1 Design Assumptions

- リポジトリは呼び出し元がチェックアウト済みである。
- secretlint の設定は同梱のものを使う。本 Action は設定を渡さない。
- 入力はすべて環境変数 (`INPUT_SECRETLINT_VERSION`) 経由でスクリプトへ届く。`pnpm-version` は `pnpm/action-setup` が直接受け取る。

### 2.2 External Design Summary

| 単位                          | 責務                                      | 配置                                 |
| ----------------------------- | ----------------------------------------- | ------------------------------------ |
| `setup-pnpm` ステップ         | `pnpm/action-setup` で pnpm を用意する    | `action.yml`                         |
| `Run secretlint` ステップ     | `run-secretlint.sh` を呼ぶ                | `action.yml`                         |
| `main`                        | 検証、続けて `pnpm dlx` を実行する        | `scripts/run-secretlint.sh`          |
| `validate_secretlint_version` | バージョンの形式と最小の major を判定する | `scripts/_libs/inputs.lib.sh`        |
| `gha_error`                   | `::error::` の 1 行を標準エラー出力へ出す | `.github/actions/_libs/error.lib.sh` |

データの流れ:

```text
inputs.pnpm-version     -> pnpm/action-setup (version)
inputs.secretlint-version -> env INPUT_SECRETLINT_VERSION -> main
   -> validate_secretlint_version -> pnpm dlx "secretlint@<version>" -> exit code
```

### 2.3 Non-Goals

- secretlint の設定、無視ファイル、出力形式の指定
- 検査対象のファイルの絞り込み (secretlint の既定に従う)
- バージョンの範囲指定、dist-tag

## 3. Behavioral Specification

### 3.1 Input Domain

| 入力                 | 型     | 既定     | 意味                                               |
| -------------------- | ------ | -------- | -------------------------------------------------- |
| `pnpm-version`       | string | ""       | 空なら `package.json` の `packageManager` で決める |
| `secretlint-version` | string | "14.0.1" | 実行する secretlint の版。major 14 以上の `X.Y.Z`  |

### 3.2 Output Semantics

本 Action に outputs は無い。結果は終了コードだけで表す。

| 終了コード | 意味                                                    |
| ---------- | ------------------------------------------------------- |
| 0          | 検出なし                                                |
| 1          | 検出あり、またはバージョンの検証に失敗した              |
| 2          | secretlint のツールエラー (pnpm の終了コードをそのまま) |

検証の失敗は、`::error::` を標準エラー出力へ出し、pnpm を呼ばずに 1 で終了する。

## 4. Decision Rules

評価は次の順序で行う。順序の入れ替えは認めない。

| Rule ID   | Step | Condition                                                                         | Outcome                                                |
| --------- | ---- | --------------------------------------------------------------------------------- | ------------------------------------------------------ |
| R-VER-001 | 1    | 値が `^(1[4-9]\|[2-9][0-9]\|[1-9][0-9]{2,})\.[0-9]+\.[0-9]+$` に一致              | 受理、終了コード 0、標準エラー出力は空                 |
| R-VER-002 | 1    | 上に一致しない (空、`v` 接頭辞、接尾辞、dist-tag、複数行、13 以下、先頭 0 を含む) | `::error::` を出し、終了コード 1                       |
| R-RUN-001 | 2    | 検証に失敗                                                                        | `main` は 1 を返し、pnpm を呼ばない                    |
| R-RUN-002 | 3    | 検証に成功                                                                        | `pnpm dlx "secretlint@<version>"` を引数なしで実行する |
| R-RUN-003 | 4    | pnpm が終了                                                                       | その終了コードを `main` の戻り値とする                 |

補足:

- major の判定は正規表現で行う。2 桁は 14〜99、3 桁以上は先頭 0 なしの数字とする。
- minor と patch は数字 1 桁以上とし、先頭 0 を許す (`14.0.1`)。
- `secretlint-version` が未設定の環境変数 (`INPUT_SECRETLINT_VERSION` 未設定) は、空として検証する (`${VAR:-}`)。

### 4.1 action.yml の契約

| Rule ID   | 内容                                                                       |
| --------- | -------------------------------------------------------------------------- |
| R-ACT-001 | inputs は `pnpm-version` と `secretlint-version` の 2 つだけである         |
| R-ACT-002 | `secretlint-version` は任意で、既定が `X.Y.Z` 形式である                   |
| R-ACT-003 | `pnpm-version` は任意で、既定が空である                                    |
| R-ACT-004 | composite で、bash の run ステップは 1 つ、pnpm のステップに run が無い    |
| R-ACT-005 | pnpm のセットアップが secretlint の実行より前にあり、`pnpm-version` を渡す |
| R-ACT-006 | 入力は `env` 経由でスクリプトに渡す。`run` に式展開が無い                  |
| R-ACT-007 | `uses:` は `pnpm/action-setup` の v6.1.1 だけである                        |
| R-ACT-008 | チェックアウトと Node.js のセットアップをしない                            |
| R-ACT-009 | `contents` / `id-token` の write 権限を持たない                            |
| R-ACT-010 | `secretlintrc` や `config` の入力を持たない                                |

## 5. Edge Cases

| Input                               | Classification | REQ       | Rationale                     |
| ----------------------------------- | -------------- | --------- | ----------------------------- |
| `14.0.0; id`                        | 拒否           | REQ-F-004 | コマンド連結を実行に渡さない  |
| `14.0.0` と `15.0.0` の 2 行        | 拒否           | REQ-F-004 | 複数行は引数に混入する        |
| `latest`                            | 拒否           | REQ-F-004 | dist-tag は固定されない       |
| `014.0.0`、`00.1.2`                 | 拒否           | REQ-F-004 | major の先頭 0 は不正         |
| `100.0.0`                           | 受理           | REQ-F-004 | 3 桁の major も 14 以上である |
| pnpm が終了コード 1 / 2             | そのまま伝搬   | REQ-F-003 | 検出とツールエラーを区別する  |
| `INPUT_SECRETLINT_VERSION` が未設定 | 拒否           | REQ-F-004 | 空と同じ                      |

## 6. Output and Error Format

エラーは `gha_error` が、標準エラー出力へ 1 行を出す。

```text
::error::secretlint-version: must be in X.Y.Z format with major version 14 or later (got: '<値>')
```

- 値は `%` → `%25`、CR → `%0D`、LF → `%0A` にエンコードする。
- 本 Action は `GITHUB_OUTPUT` に書き出さない。

## 7. Requirements Traceability

| REQ        | Rules                           |
| ---------- | ------------------------------- |
| REQ-F-001  | R-ACT-005, R-ACT-003            |
| REQ-F-002  | R-RUN-002                       |
| REQ-F-003  | R-RUN-003, 3.2                  |
| REQ-F-004  | R-VER-001, R-VER-002, R-RUN-001 |
| REQ-NF-001 | R-ACT-006                       |
| REQ-NF-002 | R-ACT-009                       |
| REQ-NF-003 | 6                               |
| REQ-C-001  | R-ACT-004                       |
| REQ-C-002  | R-ACT-007, R-ACT-008            |
| REQ-C-003  | R-ACT-001, R-ACT-010            |

## 8. Open Questions

| Question                                            | Status |
| --------------------------------------------------- | ------ |
| 説明文の「14.0.0 or later」と既定 14.0.1 を揃えるか | Open   |

## 9. Change History

| Date       | Version | Description     |
| ---------- | ------- | --------------- |
| 2026-11-19 | 1.0.0   | Initial release |
