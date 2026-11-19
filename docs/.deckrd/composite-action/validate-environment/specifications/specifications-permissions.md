---
title: "Design Specification: ca-validate-environment (Permissions)"
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

`validate-permissions.sh` の振る舞いを定義する。`actions-type` に応じて、トークンの存在と書き込み権限を検証する。

### 1.2 Scope

REQ-F-010 ～ REQ-F-014。`curl` で GitHub API を呼ぶプローブを含む。

## 2. Design Principles

### 2.1 Design Assumptions

- 権限の有無は、実際の書き込みではなく、無効なペイロードへの API の応答で判定する (DR-03)。
- `read` では確認できない項目を確認したと見なさない (DR-04)。

### 2.2 Behavioral Design Decisions

| ID        | Decision                                                                            | Rationale                                        |
| --------- | ----------------------------------------------------------------------------------- | ------------------------------------------------ |
| DD-PRM-01 | プローブの対象名は、ブランチ参照 `permission-probe-<epoch秒>`                       | 既存のブランチ名と衝突しない                     |
| DD-PRM-02 | `github_api_post` は HTTP ステータスだけを返し、curl の失敗は `000` とする          | 呼び出し側が応答を `case` で分類できる           |
| DD-PRM-03 | `validate_id_token_permissions` は実装にあるが、`validate_permissions` から呼ばない | 再利用のために残された関数で、本 Action の範囲外 |

## 3. Behavioral Specification

### 3.1 Input Domain

| 入力                | 取得元                                         | 既定   |
| ------------------- | ---------------------------------------------- | ------ |
| `actions-type`      | 第 1 引数、なければ環境変数 `ACTIONS_TYPE`     | `read` |
| `GITHUB_TOKEN`      | 環境変数                                       | (必須) |
| `GITHUB_REPOSITORY` | 環境変数 (commit / pr のみ)                    | (必須) |
| `GITHUB_BASE_REF`   | 環境変数 (pr のみ。なければ `GITHUB_REF_NAME`) | -      |

### 3.2 Output Semantics

| 結果                | `status`  | `message`                                      | 終了コード |
| ------------------- | --------- | ---------------------------------------------- | ---------- |
| 成功 (全タイプ)     | `success` | `GitHub permissions validated`                 | 0          |
| 無効な actions-type | `error`   | `Invalid actions-type: <value>`                | 1          |
| トークンなし        | `error`   | `GITHUB_TOKEN environment variable is not set` | 1          |
| commit 権限なし     | `error`   | `Missing commit permissions: contents: write`  | 1          |
| pr 権限なし         | `error`   | `Missing PR permissions: pull-requests: write` | 1          |

エントリーポイントは、`curl` が無いとき `::error::` を出して終了コード 1 で終了する (`status` は書かない)。

## 4. Decision Rules

評価は次の順序で行う。順序の入れ替えは許さない。

| Rule ID   | Step | Condition                                                            | Outcome                                           |
| --------- | ---- | -------------------------------------------------------------------- | ------------------------------------------------- |
| R-PRM-001 | 1    | `check_curl` が失敗する (エントリーポイント)                         | `::error::curl is not installed...`、終了コード 1 |
| R-PRM-002 | 2    | 小文字化した actions-type が `read` / `commit` / `pr` / `any` でない | `status=error`、終了コード 1                      |
| R-PRM-003 | 3    | `GITHUB_TOKEN` が空または未設定                                      | `status=error`、終了コード 1                      |
| R-PRM-004 | 4    | タイプが `any` または `read`                                         | API を呼ばず `status=success`                     |
| R-PRM-005 | 5    | タイプが `commit` で、`git/refs` のプローブが拒否される              | `status=error` (commit)                           |
| R-PRM-006 | 5    | タイプが `pr` で、`pulls` のプローブが拒否される                     | `status=error` (pr)                               |
| R-PRM-007 | 6    | 上記のどれにも当たらない                                             | `status=success`                                  |

プローブの応答判定 (R-PRM-005 / R-PRM-006 の内部) は次の表による。

| HTTP 応答           | 判定                                 |
| ------------------- | ------------------------------------ |
| 403                 | 拒否 (`Permission denied (403)`)     |
| 201 / 409 / 422     | 受理                                 |
| 401                 | 拒否 (`Authentication failed (401)`) |
| `000` (curl の失敗) | 拒否 (`Network error`)               |
| その他              | 拒否 (`Unexpected HTTP response`)    |

プローブの送信内容は次のとおり。

| タイプ   | エンドポイント                | ペイロード                                                               |
| -------- | ----------------------------- | ------------------------------------------------------------------------ |
| `commit` | `POST /repos/{repo}/git/refs` | `ref=refs/heads/permission-probe-<epoch>`, `sha=0000...0000` (40 桁)     |
| `pr`     | `POST /repos/{repo}/pulls`    | `title=permission-probe`, `head=permission-probe-<epoch>`, `base=<base>` |

<!-- impl-note: github_api_post は curl -w "%{http_status}" を使う。http_status は curl の書式変数ではなく、OQ-01 に記録した。表の判定は、HTTP ステータスが取得できる前提で定義する -->

## 5. Edge Cases

| Input                                                 | Classification | REQ       | Rationale                                             |
| ----------------------------------------------------- | -------------- | --------- | ----------------------------------------------------- |
| `actions-type=COMMIT`                                 | 正常           | REQ-F-010 | 小文字化してから判定する                              |
| `pr` で `GITHUB_BASE_REF` も `GITHUB_REF_NAME` も無い | エラー         | REQ-F-013 | "Cannot determine base branch" で拒否する             |
| `commit` で `GITHUB_REPOSITORY` が未設定              | エラー         | REQ-F-012 | `set -u` により "unbound variable" で終了する (OQ-02) |
| `read` でトークンのみ存在                             | 正常           | REQ-F-014 | API を呼ばない                                        |

## 6. Requirements Traceability

| REQ ID    | Rule ID              |
| --------- | -------------------- |
| REQ-F-010 | R-PRM-002            |
| REQ-F-011 | R-PRM-003            |
| REQ-F-012 | R-PRM-005            |
| REQ-F-013 | R-PRM-006            |
| REQ-F-014 | R-PRM-004, R-PRM-007 |

## 7. Open Questions

OQ-01 (`%{http_status}`) と OQ-02 (`GITHUB_REPOSITORY` の未設定) を参照する。

## 8. Change History

| Date       | Version | Description                     |
| ---------- | ------- | ------------------------------- |
| 2026-11-19 | 1.0.0   | Initial release: R-PRM-001..007 |
