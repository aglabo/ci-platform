---
title: "Design Specification: ca-validate-environment (Apps)"
based-on: requirements.md v1.0.0
status: Draft
version: 1.0.0
created: "2026-11-19"
---

<!-- textlint-disable
  ja-technical-writing/sentence-length,
  ja-technical-writing/max-comma,
  ja-technical-writing/no-doubled-joshi,
  ja-technical-writing/no-mix-dearu-desumasu,
  ja-technical-writing/ja-no-redundant-expression,
  @textlint-ja/no-synonyms
  -->
<!-- markdownlint-disable line-length -->

> Part of split specification. See `specifications-index.md` for full scope.

## 1. Overview

### 1.1 Purpose

`validate-apps.sh` の振る舞いを定義する。必須アプリケーションの定義を検証し、存在・版・認証を確認する。

### 1.2 Scope

REQ-F-015 ～ REQ-F-022。標準入力からの追加定義の読み取りと、結果の出力を含む。

## 2. Design Principles

### 2.1 Design Assumptions

- 入力は信頼しない。`eval` を使わず、文字種を許可リストで制限する (DR-07)。
- 最初の失敗で止める (DR-06)。

### 2.2 Behavioral Design Decisions

| ID        | Decision                                                                                     | Rationale                            |
| --------- | -------------------------------------------------------------------------------------------- | ------------------------------------ |
| DD-APP-01 | アプリ定義の区切りは `\|` とする                                                             | 正規表現やコロンと衝突しない         |
| DD-APP-02 | `regex:` のキャプチャは最初のグループだけを使う                                              | 複数グループの曖昧さを避ける         |
| DD-APP-03 | 版は 1 回だけ取得し、`validate_app_version` に渡す                                           | `--version` の二重実行を避ける       |
| DD-APP-04 | 結果は JSON (`status`, `app`, `version`, `index`) として配列に蓄え、成功時に `jq` で整形する | 出力の組み立てをデータから導出できる |

## 3. Behavioral Specification

### 3.1 Input Domain

アプリ定義は 1 行 1 件で、次の 2 形式がある。

| 形式         | 書式                                            | 例                        |
| ------------ | ----------------------------------------------- | ------------------------- |
| 2 フィールド | `cmd\|app_name`                                 | `curl\|curl`              |
| 4 フィールド | `cmd\|app_name\|version_extractor\|min_version` | `git\|Git\|field:3\|2.30` |

既定の定義は `git|Git|field:3|2.30` と `curl|curl||` とする。標準入力の定義は、既定の後ろに加える。

### 3.2 Output Semantics

| 結果 | `status`  | `message`                                                                               | 終了コード |
| ---- | --------- | --------------------------------------------------------------------------------------- | ---------- |
| 成功 | `success` | `Applications validated:` に続けて `<app> <version>` を 2 スペースで字下げして 1 行ずつ | 0          |
| 失敗 | `error`   | 失敗の原因 (1 行)                                                                       | 1          |

## 4. Decision Rules

評価は次の順序で行う。順序の入れ替えは許さない。

| Rule ID   | Step | Condition                                                     | Outcome                                                    |
| --------- | ---- | ------------------------------------------------------------- | ---------------------------------------------------------- |
| R-APP-001 | 1    | `jq` が無い                                                   | `::error::jq is required...`、終了コード 1 (`status` なし) |
| R-APP-002 | 2    | 既定と標準入力の定義を読み、行内コメント・空白・空行を除く    | 残った行を定義として検証する                               |
| R-APP-003 | 3    | 定義のフィールド数が 2 でも 4 でもない                        | `Invalid app definition format` で失敗                     |
| R-APP-004 | 3    | `cmd` に制御文字・相対パス・シェルメタ文字がある              | 該当の `Invalid command name ...` で失敗                   |
| R-APP-005 | 3    | `app_name` に改行・CR・タブがある                             | `Invalid app name contains control characters` で失敗      |
| R-APP-006 | 4    | 定義の件数が 30 を超える                                      | `Too many apps specified (max: 30)` で失敗                 |
| R-APP-007 | 5    | `command -v <cmd>` が失敗する                                 | `<app> is not installed` で失敗                            |
| R-APP-008 | 6    | `min_version` が空                                            | 警告を出して版の比較を省略する                             |
| R-APP-009 | 6    | 版の抽出に失敗する                                            | `Version extraction failed for <app>` で失敗               |
| R-APP-010 | 6    | 抽出した版が `min_version` 未満                               | `<app> version <v> is below minimum required <min>` で失敗 |
| R-APP-011 | 7    | コマンド名 (basename) が `gh` で、`gh auth status` が失敗する | `<app> is not authenticated` で失敗                        |
| R-APP-012 | 8    | 全定義が通過                                                  | `status=success` と版の一覧を書く                          |

### 4.1 バージョン抽出器

| 書式            | 動作                                                    | 失敗条件                                       |
| --------------- | ------------------------------------------------------- | ---------------------------------------------- |
| 空 / `auto`     | `grep -oE '[0-9]{1,3}\.[0-9]+(\.[0-9]+)?'` の最初の一致 | 一致なし                                       |
| `field:N`       | 空白区切りの N 番目 (`cut -d' ' -f N`)                  | N が数字でない、または該当フィールドが空       |
| `regex:PATTERN` | `[[ $v =~ PATTERN ]]` の `BASH_REMATCH[1]`              | `is_safe_regex` の拒否、不一致、キャプチャなし |
| その他          | -                                                       | `Unknown extraction method`                    |

### 4.2 `is_safe_regex` の終了コード

| 終了コード | 意味                                                                 |
| ---------- | -------------------------------------------------------------------- |
| 0          | 安全                                                                 |
| 1          | 空、または空白のみ                                                   |
| 2          | 制御文字を含む                                                       |
| 3          | 危険なメタ文字 (`; & \| " ' < > { } \`) を含む                       |
| 4          | 許可リスト (`A-Za-z0-9 . _ ( ) + ^ : [ ] -` と空白) の外の文字を含む |

`*` と `?` は ReDoS の面を減らすため、許可リストに含めない。`$` とバッククォートは許可リストで弾く。

### 4.3 `is_safe_command` の終了コード

| 終了コード | 意味                                                                                                                 |
| ---------- | -------------------------------------------------------------------------------------------------------------------- |
| 0          | 安全                                                                                                                 |
| 1          | 改行・CR・タブを含む                                                                                                 |
| 2          | 相対パス (`./`, `../`, `/./`, `/../`) を含む                                                                         |
| 3          | シェルメタ文字 (セミコロン、パイプ、アンパサンド、ドル記号、バッククォート、括弧、`*`、`?`、波括弧) または空白を含む |

## 5. Edge Cases

| Input                                     | Classification | REQ       | Rationale                                   |
| ----------------------------------------- | -------------- | --------- | ------------------------------------------- |
| `additional-apps` に `# comment` だけの行 | 正常           | REQ-F-016 | コメントを除くと空行になり、無視される      |
| `curl\|curl\|\|` (4 フィールド、空 2 つ)  | 正常           | REQ-F-018 | 版の比較を省略し、警告を出す                |
| `regex:` のパターンに `#` を含む          | エラー         | REQ-F-016 | `#` 以降が行内コメントとして除去される      |
| 定義が 31 件                              | エラー         | REQ-F-020 | 上限を超える                                |
| `/usr/bin/gh\|gh\|...`                    | 正常           | REQ-F-019 | `basename` で `gh` と判定し、認証を確認する |
| 抽出した版が `2.30` で `min_version=2.30` | 正常           | REQ-F-018 | `sort -V` で等しいため通過する              |

## 6. Requirements Traceability

| REQ ID    | Rule ID                                    |
| --------- | ------------------------------------------ |
| REQ-F-015 | R-APP-002, R-APP-007                       |
| REQ-F-016 | R-APP-002, R-APP-003, R-APP-004, R-APP-005 |
| REQ-F-017 | R-APP-009                                  |
| REQ-F-018 | R-APP-008, R-APP-010                       |
| REQ-F-019 | R-APP-011                                  |
| REQ-F-020 | R-APP-006                                  |
| REQ-F-021 | R-APP-012                                  |
| REQ-F-022 | R-APP-003 ～ R-APP-011 の各失敗            |

## 7. Open Questions

OQ-03 (`gh` を既定とする冒頭コメント) と OQ-05 (`status` を書かずに終了する経路) を参照する。

## 8. Change History

| Date       | Version | Description                     |
| ---------- | ------- | ------------------------------- |
| 2026-11-19 | 1.0.0   | Initial release: R-APP-001..012 |
