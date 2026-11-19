---
title: "Design Specification: ca-validate-environment (Runner)"
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

`validate-git-runner.sh` の振る舞いを定義する。OS、アーキテクチャ、GitHub Actions 環境、実行時変数を検証する。

### 1.2 Scope

REQ-F-004 ～ REQ-F-009。成功時と失敗時の `status` / `message` の書き込みを含む。

## 2. Design Principles

### 2.1 Design Assumptions

- 検証は 1 本の直列な流れで行い、最初の失敗で終了する。
- OS とアーキテクチャの値は、テストのために引数で上書きできる (`detect_os`, `detect_architecture`)。

### 2.2 Behavioral Design Decisions

| ID        | Decision                                                                                 | Rationale                              |
| --------- | ---------------------------------------------------------------------------------------- | -------------------------------------- |
| DD-RUN-01 | `validate_os` は `SUCCESS:` / `ERROR:` を接頭辞にした文字列を標準出力に返す              | 呼び出し側がメッセージを取り出せる     |
| DD-RUN-02 | `normalize_architecture` が受け付ける別名は `x86_64`, `amd64`, `x64`, `aarch64`, `arm64` | 実機の `uname -m` と入力の表記を揃える |
| DD-RUN-03 | `REQUIRE_GITHUB_HOSTED` は文字列 `"true"` のときだけ有効とする                           | 他の値 (空を含む) は、検査しないと同義 |

## 3. Behavioral Specification

### 3.1 Input Domain

| 入力                 | 環境変数                | 既定 (スクリプト単体) |
| -------------------- | ----------------------- | --------------------- |
| 期待アーキテクチャ   | `EXPECTED_ARCHITECTURE` | `amd64`               |
| GitHub-hosted の要否 | `REQUIRE_GITHUB_HOSTED` | `true` (OQ-04)        |

### 3.2 Output Semantics

| 結果 | `status`  | `message`                               | 終了コード |
| ---- | --------- | --------------------------------------- | ---------- |
| 成功 | `success` | `GitHub runner validated: Linux <arch>` | 0          |
| 失敗 | `error`   | 失敗した検査に応じた文 (下表)           | 1          |

## 4. Decision Rules

評価は次の順序で行う。順序の入れ替えは許さない。

| Rule ID   | Step | Condition                                                                        | Outcome (`status=error` の message)                 |
| --------- | ---- | -------------------------------------------------------------------------------- | --------------------------------------------------- |
| R-RUN-001 | 1    | `detect_os` の結果が `linux` でない                                              | `Unsupported OS: <os> (Linux required)`             |
| R-RUN-002 | 2    | `EXPECTED_ARCH` が `amd64` / `arm64` でない                                      | `Invalid architecture input: <value>`               |
| R-RUN-003 | 3    | `uname -m` の値を正規化できない                                                  | `Unsupported architecture: <raw>`                   |
| R-RUN-004 | 4    | 正規化した値が `EXPECTED_ARCH` と異なる                                          | `Architecture mismatch: expected <exp>, got <norm>` |
| R-RUN-005 | 5    | `GITHUB_ACTIONS` が `true` でない                                                | `Not running in GitHub Actions environment`         |
| R-RUN-006 | 6    | `REQUIRE_GITHUB_HOSTED=true` かつ `RUNNER_ENVIRONMENT` が `github-hosted` でない | `Requires GitHub-hosted runner (not self-hosted)`   |
| R-RUN-007 | 7    | `RUNNER_TEMP`, `GITHUB_OUTPUT`, `GITHUB_PATH` のいずれかが空                     | `Missing required environment variables`            |
| R-RUN-008 | 8    | 上記すべてを通過                                                                 | `status=success`                                    |

<!-- impl-note: 単体実行時 (BASH_SOURCE == $0) に GITHUB_OUTPUT が空だと、警告を標準エラーに出す。出力自体は捨てられる -->

## 5. Edge Cases

| Input                                        | Classification  | REQ       | Rationale                             |
| -------------------------------------------- | --------------- | --------- | ------------------------------------- |
| `uname -m` が `x64`                          | 正常            | REQ-F-006 | `amd64` へ正規化する                  |
| `uname -s` が `Linux` (大文字)               | 正常            | REQ-F-004 | 小文字化して比較する                  |
| `EXPECTED_ARCHITECTURE` が `x86_64`          | エラー          | REQ-F-005 | 入力は正規化済みの値だけを受け付ける  |
| `REQUIRE_GITHUB_HOSTED` が `TRUE`            | 正常 (検査なし) | REQ-F-008 | `"true"` と完全一致のときだけ検査する |
| セルフホストで `REQUIRE_GITHUB_HOSTED=false` | 正常            | REQ-F-008 | `RUNNER_ENVIRONMENT` は見ない         |

## 6. Requirements Traceability

| REQ ID    | Rule ID              |
| --------- | -------------------- |
| REQ-F-004 | R-RUN-001            |
| REQ-F-005 | R-RUN-002            |
| REQ-F-006 | R-RUN-003, R-RUN-004 |
| REQ-F-007 | R-RUN-005            |
| REQ-F-008 | R-RUN-006            |
| REQ-F-009 | R-RUN-007, R-RUN-008 |

## 7. Open Questions

OQ-04 (スクリプト既定値と Action 既定値の食い違い) を参照する。

## 8. Change History

| Date       | Version | Description                     |
| ---------- | ------- | ------------------------------- |
| 2026-11-19 | 1.0.0   | Initial release: R-RUN-001..008 |
