---
title: "Design Specification: Input Validation"
based-on: requirements.md v1.0.5
status: Draft
---

<!-- textlint-disable ja-technical-writing/sentence-length, ja-technical-writing/max-comma -->
<!-- markdownlint-disable line-length -->
<!-- cspell:words rhysd -->

> Part of split specification. See `specifications-index.md` for full scope.

## 1. Overview

### 1.1 Purpose

action 起動時に受け取った全入力値が仕様に適合しているかを検証する動作ルールを定義する。
検証に失敗した場合は後続のすべての処理をブロックし、エラーの原因を明示する。

### 1.2 Scope

本仕様は `validation` の **振る舞いルール** と **判定条件** を定義する。実装詳細はスコープ外とする。

---

## 2. Design Principles

### 2.1 Classification Philosophy

入力検証は action の最初のステップで実行し、**無効な入力を早期検出**してネットワーク通信等の後続処理を実行しない。各入力項目は検証前に前後空白を除去し、ASCII 以外の Unicode 文字が含まれる場合はエラーとして拒否する。その後ホワイトリスト正規表現で検証する。最初の検証失敗でステップ全体が失敗する (fail-fast) 。

### 2.2 Design Assumptions

- `tool-name`, `tool-version`, `repo`, `asset-template` は必須入力である
- `checksum-template` は省略可能であり、省略時は `checksums.txt` を使用する (REQ-F-003 による、本ファイルのスコープ外)
- `runner.os` および `runner.arch` の検証 (OS/arch 解決) は orchestration ステップの責務であり本仕様のスコープ外

### 2.3 External Design Summary

> **Source**: Derived from the external design dialogue (Phase E) and user-confirmed design direction (Phase D).

#### Feature Decomposition

| Unit                   | Responsibility                                                                                                                                                                             | REQ Coverage |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------ |
| 前処理                 | 全入力の前後空白を除去。ASCII 以外の Unicode 文字 (`\x80` 以上) が含まれる場合はエラーとして拒否                                                                                           | REQ-F-010    |
| tool-name 検証         | 前処理後: `^[a-z][a-z0-9_-]{0,63}$` にマッチすること (先頭英小文字・英小文字/数字/ハイフン/アンダースコアのみ・最大 64 文字)                                                               | REQ-F-010(c) |
| tool-version 検証      | 前処理後: `normalize_version()` で正規化可能な形式 (v プレフィックス・X.Y・X 形式を許容、major/minor は 1〜3 桁、英字修飾子は不可) ・最大 32 文字。正規化後の X.Y.Z 値を後続ステップへ渡す | REQ-F-010(a) |
| asset-template 検証    | 前処理後: `^[A-Za-z0-9._{}/-]{1,256}$` にマッチすること。プレースホルダは `{keyword}` 形式のみ許可                                                                                         | REQ-F-010(b) |
| checksum-template 検証 | 前処理後 (省略可) : `^(<filename>)?[A-Za-z0-9._-]{0,255}$` にマッチすること。`<filename>` は 0 または 1 回のみ使用可。省略時は `checksums.txt` を使用                                      | REQ-F-010(b) |
| repo 検証              | 前処理後: `org/repo` 形式、org 部 `^[a-z][a-z0-9_-]{0,38}$` (最大 39 文字) ・repo 部 `^[a-z][a-z0-9_-]{0,63}$` (最大 64 文字)                                                              | REQ-F-011    |

#### Unit Interaction Map

```text
[action inputs]
       |
       v
+----------------------+
| validate-inputs      |
|  tool-name           |
|  tool-version        |
|  asset-template      |
|  repo                |
+----------------------+
       |
   PASS / exit 1
       |
       v
[resolve-env / build-urls / ...]
```

#### Data Flow Diagram

```text
[tool-name]       --> [tool-name 検証]       --+
[tool-version]    --> [tool-version 検証]    --+
[asset-template]  --> [asset-template 検証] --+--> PASS → 後続ステップへ
[repo]            --> [repo 検証]            --+    FAIL → exit 1
```

### 2.4 ASCII Subset Policy

#### Scope

本仕様は外部から受け取る全入力に対して ASCII サブセット制限を適用:

- `tool-name`
- `tool-version`
- `repo` (org 部・repo 部それぞれ)
- `asset-template`
- `checksum-template`

#### Rationale

この制限は上流システム (GitHub 等) の命名規則より意図的に厳格にしています。

- Unicode 同形異字攻撃の排除: 見た目が同じ Unicode 文字 (例: `ａ` U+FF41 と `a` U+0061) によるなりすましを防ぐ
- シェル実行の安全性: マルチバイト文字のエンコーディング・エスケープ処理が CI 環境間で一貫しない
- 決定論的な動作保証: 全 CI 環境で同一の入力に対して同一の検証結果を保証する
- インジェクション攻撃面の最小化: ASCII のみに限定することでコマンドインジェクションリスクを削減する

#### GitHub との非互換性

本仕様は GitHub の命名規則と完全な互換性を持つことを目的としない。

**GitHub では有効だが本仕様では拒否される例**:

- 大文字を含むリポジトリ名 (例: `MyOrg/MyRepo`)
- Unicode 文字を含む名前

本仕様の validator を通過した入力は GitHub で有効であることを保証するが、その逆は保証しない。

#### Breaking Change Policy

この ASCII 制限の緩和 (Unicode 許可等) は破壊的変更 (breaking change) とみなし、仕様のメジャーバージョン更新を必要とする。

---

### 2.5 Non-Goals

> **Derivation**: All items below originate from REQUIREMENTS Section "Out of Scope".

- パッケージマネージャ経由インストールのパラメータ検証 ← REQ: Out of Scope
- macOS / Windows ランナーでの動作 ← REQ: Out of Scope
- インストール先ディレクトリのカスタマイズ検証 ← REQ: Out of Scope

### 2.6 Behavioral Design Decisions

| ID    | Decision                                                                      | Rationale                                                                                                                                                                                                 | Affected Rules              | Status |
| ----- | ----------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------- | ------ |
| DD-01 | `tool-name` のパターンを `^[a-z][a-z0-9_-]*$` に固定                          | GitHub バイナリ命名規則で数字・記号始まりは存在しない。シンプルかつ安全。                                                                                                                                 | R-003                       | Active |
| DD-02 | `repo` 検証は org 部・repo 部それぞれを tool-name と同一パターンで検証する    | 共通バリデーションルールを再利用し、実装の一貫性を保つ。                                                                                                                                                  | R-004                       | Active |
| DD-03 | `tool-version` 検証・正規化を `common.lib.sh` の `normalize_version()` に委譲 | 既存の正規化関数がバリデーターを兼ねることで責務を集約。v プレフィックス・X.Y・X 形式を許容しつつ英字修飾子を拒否する柔軟な入力受け付けが可能になる                                                       | R-001, R-001-N              | Active |
| DD-04 | 前後空白除去後に ASCII 以外の Unicode を拒否し、ホワイトリスト正規表現で検証  | Unicode 文字は除去せず拒否することで入力の透明性を保つ。ホワイトリストはフィールドごとに最小限の許可文字のみ定義し、インジェクションリスクを排除。文字数制限は GitHub 実制約 (org: 39) と実用範囲に基づく | R-000, R-000U, R-001〜R-004 | Active |
| DD-05 | `checksum-template` に `<filename>` メタ変数を導入し 0 または 1 回のみ使用可  | asset_filename との関係を明示的に参照可能にし、テンプレート構文を 1 種に限定することでインジェクションリスクを最小化する                                                                                  | R-002C                      | Active |

### 2.7 Related Decision Records

| DR-ID | Title                                                                | Phase         | Impact on This Spec                                                              |
| ----- | -------------------------------------------------------------------- | ------------- | -------------------------------------------------------------------------------- |
| DR-09 | 入力バリデーション要件の追加                                         | req           | tool-version/asset-template/tool-name の検証要件の根拠                           |
| DR-11 | validate.spec ルールの規範化・境界明示・エラーメッセージ品質保証     | review-harden | fail-fast セマンティクスの明示、境界値 Edge Cases 追加、エラーメッセージ内容仕様 |
| DR-12 | tool-version 検証を normalize_version() に委譲し柔軟な入力形式を許容 | spec-update   | R-001 の判定条件と許容形式の変更、正規化後 X.Y.Z を後続ステップへ渡す仕様の追加  |

### 2.8 DD to DR Promotion Criteria

> **Purpose**: Guidelines for determining when a DD should be promoted to a formal DR.
> Promotion is a **human judgment** — these criteria inform, not automate.

DD-01 は `tool-name` 検証パターンとして他モジュールでも再利用される可能性があるため、将来的に DR 昇格を検討する。

---

## 3. Behavioral Specification

### 3.1 Input Domain

全入力は以下の順序で前処理・検証:

1. 前後空白を除去
2. ASCII 以外の Unicode 文字 (`\x80` 以上) が含まれる場合はエラーとして**拒否** (エラーメッセージを出力・return 1)
3. ホワイトリスト正規表現で検証

- `tool-name`: 前処理後、`^[a-z][a-z0-9_-]{0,63}$` にマッチすること。英小文字始まりで英小文字・数字・ハイフン・アンダースコアのみ・最大 64 文字
- `tool-version`: 前処理後、`common.lib.sh` の `normalize_version()` で正規化可能な形式のみ有効。`v`/`V` プレフィックス・X.Y・X 形式を許容。major/minor は 1〜3 桁、patch は 1 桁以上。英字修飾子 (例: `-beta`) ・4 桁以上の major/minor は無効 (`normalize_version()` が return 1) 。最大 32 文字。検証通過後は正規化済み X.Y.Z 値を後続ステップへ渡す
- `asset-template`: 前処理後、`^[A-Za-z0-9._{}/-]{1,256}$` にマッチすること。プレースホルダは `{keyword}` 形式のみ許可 (`keyword` は英小文字・数字・アンダースコア)
- `checksum-template`: 省略可能。前処理後、`^(<filename>)?[A-Za-z0-9._-]{0,255}$` にマッチすること。`<filename>` メタ変数は 0 または 1 回のみ使用可 (解決済み asset_filename に置換される) 。省略または空の場合は `checksums.txt` を使用
- `repo`: 前処理後、スラッシュ (`/`) を正確に 1 個含む `org/repo` 形式の文字列。org 部が `^[a-z][a-z0-9_-]{0,38}$` に適合 (最大 39 文字) 。repo 部が `^[a-z][a-z0-9_-]{0,63}$` に適合 (最大 64 文字)

### 3.2 Output Semantics

- 全検証通過: 後続ステップへ続行 (exit 0) 。`tool-version` は `normalize_version()` で正規化した X.Y.Z 値を出力する
- いずれか失敗: `::error::` プレフィックスのエラーメッセージを出力し、exit 1 で終了。エラーメッセージには不正と判断した**入力名**と**期待される形式の説明**を含める

---

## 4. Decision Rules

Evaluation MUST follow this order:

| Rule ID | Step | Condition                                                                                                                                                      | Outcome                                                             |
| ------- | ---: | -------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| Rule ID | Step | Condition                                                                                                                                                      | Outcome                                                             |
| ------- | ---: | -------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| R-000   |    0 | 全入力の前後空白を除去する                                                                                                                                     | 前処理済み値を以降の検証に使用                                      |
| R-000U  |  0.5 | いずれかの入力に ASCII 以外の Unicode 文字 (`\x80` 以上) が含まれる                                                                                            | exit 1 + エラーメッセージ                                           |
| R-001   |    1 | `tool-version` が 32 文字超、または `normalize_version()` が return 1 (英字修飾子・完全非数値・major/minor 4 桁以上など正規化不能な形式)                       | exit 1 + エラーメッセージ                                           |
| R-001-N |  1.5 | `tool-version` の `normalize_version()` 成功時                                                                                                                 | 正規化後の X.Y.Z 値を `tool-version` として確定し後続ステップへ渡す |
| R-002   |    2 | `asset-template` が `^[A-Za-z0-9._{}/-]{1,256}$` にマッチしない (空文字・未指定・許可外文字・256 文字超を含む)                                                 | exit 1 + エラーメッセージ                                           |
| R-002C  |  2.5 | `checksum-template` が指定されており、`^(<filename>)?[A-Za-z0-9._-]{0,255}$` にマッチしない、または `<filename>` が 2 回以上出現する                           | exit 1 + エラーメッセージ                                           |
| R-003   |    3 | `tool-name` が `^[a-z][a-z0-9_-]{0,63}$` にマッチしない (空文字・未指定・許可外文字・64 文字超を含む)                                                          | exit 1 + エラーメッセージ                                           |
| R-004   |    4 | `repo` に含まれるスラッシュが 1 個でない、org 部が `^[a-z][a-z0-9_-]{0,38}$` 不適合、または repo 部が `^[a-z][a-z0-9_-]{0,63}$` 不適合                         | exit 1 + エラーメッセージ                                           |
| R-005   |    5 | 全条件を通過                                                                                                                                                   | exit 0 (後続ステップへ)                                             |

No reordering is permitted. R-000U・R-001 〜 R-004 のいずれかが失敗した時点で即座に exit 1 し、後続ルールは評価しない (fail-fast) 。R-000 は前後空白除去のみで失敗しない。R-001-N は R-001 成功時のみ実行される正規化ステップであり、失敗することはない。

<!-- impl-note: R-000 前後空白除去は bash パラメータ展開で実施 -->
<!-- impl-note: R-000U Unicode チェックは [[ "$val" =~ [^\x00-\x7F] ]] で検出 -->
<!-- impl-note: tool-version 検証・正規化は common.lib.sh の normalize_version() を使用。return 1 で失敗、stdout に X.Y.Z を出力 -->
<!-- impl-note: validation.lib.sh の validate_asset_template(), validate_checksum_template(), validate_symbol() を使用 -->
<!-- impl-note: repo 検証は validate_symbol() を org 部・repo 部それぞれに適用 -->
<!-- impl-note: checksum-template の <filename> 置換は build-url.spec.md の R-006 で実施 -->

---

## 5. Edge Cases

| Input                                                                    | Classification  | REQ          | Rationale                                                   |
| ------------------------------------------------------------------------ | --------------- | ------------ | ----------------------------------------------------------- |
| `tool-name` に Unicode 文字含む (例: `ツール`)                           | R-000U 失敗     | REQ-F-010(c) | ASCII 以外の Unicode は拒否                                 |
| `tool-version` に Unicode 文字含む                                       | R-000U 失敗     | REQ-F-010(a) | ASCII 以外の Unicode は拒否                                 |
| `tool-version="1.7.10"`                                                  | 通過 → `1.7.10` | REQ-F-010(a) | X.Y.Z 形式・数字のみ、そのまま確定                          |
| `tool-version="v1.7.10"`                                                 | 通過 → `1.7.10` | REQ-F-010(a) | v プレフィックスを除去して正規化                            |
| `tool-version="1.7"`                                                     | 通過 → `1.7.0`  | REQ-F-010(a) | X.Y 形式を X.Y.0 に補完                                     |
| `tool-version="1"`                                                       | 通過 → `1.0.0`  | REQ-F-010(a) | X 形式を X.0.0 に補完                                       |
| `tool-version="latest"`                                                  | R-001 失敗      | REQ-F-010(a) | 数値バージョン形式でない (normalize_version() return 1)     |
| `tool-version="1.2.3-beta"`                                              | R-001 失敗      | REQ-F-010(a) | 英字修飾子は不可 (normalize_version() return 1)             |
| `tool-version="1.2.3.4"`                                                 | R-001 失敗      | REQ-F-010(a) | 4 セグメント以上は不可 (normalize_version() return 1)       |
| `tool-version="1000.0.0"`                                                | R-001 失敗      | REQ-F-010(a) | major 4 桁以上は不可 (normalize_version() return 1)         |
| `tool-version="1.1000.0"`                                                | R-001 失敗      | REQ-F-010(a) | minor 4 桁以上は不可 (normalize_version() return 1)         |
| `asset-template="{tool_name}_{tool_version}_linux_{arch_suffix}.tar.gz"` | 通過            | REQ-F-010(b) | ホワイトリスト文字のみ・`{keyword}` 形式プレースホルダ      |
| `asset-template=""` (空文字)                                             | R-002 失敗      | REQ-F-010(b) | 空文字はパターン不適合 (`{1,256}` で 1 文字以上必須)        |
| `asset-template` に `$()` 含む                                           | R-002 失敗      | REQ-F-010(b) | ホワイトリスト外文字                                        |
| `asset-template` 257 文字超                                              | R-002 失敗      | REQ-F-010(b) | 256 文字超                                                  |
| `checksum-template="<filename>.sha256"`                                  | 通過            | REQ-F-010(b) | `<filename>` 1 回・リテラル文字のみ                         |
| `checksum-template="checksums.txt"`                                      | 通過            | REQ-F-010(b) | リテラルのみ・`<filename>` なしも有効                       |
| `checksum-template="<filename><filename>.txt"`                           | R-002C 失敗     | REQ-F-010(b) | `<filename>` が 2 回出現                                    |
| `checksum-template` に Unicode 含む                                      | R-000U 失敗     | REQ-F-010(b) | ASCII 以外の Unicode は拒否                                 |
| `tool-name=""` (空文字)                                                  | R-003 失敗      | REQ-F-010(c) | 前処理後も空文字。パターン不適合                            |
| `tool-name="   "` (空白のみ)                                             | R-003 失敗      | REQ-F-010(c) | 前処理後は空文字。パターン不適合                            |
| `tool-name="MyTool"` (大文字含む)                                        | R-003 失敗      | REQ-F-010(c) | ホワイトリスト外文字 (大文字)                               |
| `tool-name="actionlint"`                                                 | 通過            | REQ-F-010(c) | 先頭英小文字、以降も適合                                    |
| `tool-name="a" * 65` (65 文字)                                           | R-003 失敗      | REQ-F-010(c) | 64 文字超 (`{0,63}` で最大 63 文字 + 先頭 1 文字 = 64 文字) |
| `repo="rhysd/actionlint"`                                                | 通過            | REQ-F-011    | 正規形式                                                    |
| `repo="ActionLint"` (スラッシュなし)                                     | R-004 失敗      | REQ-F-011    | org/repo 形式でない (スラッシュ 0 個)                       |
| `repo="org/repo/extra"`                                                  | R-004 失敗      | REQ-F-011    | スラッシュが 2 個以上 (許容は 1 個のみ)                     |
| `repo` org 部 40 文字超                                                  | R-004 失敗      | REQ-F-011    | org 部は最大 39 文字                                        |
| `repo` repo 部 65 文字超                                                 | R-004 失敗      | REQ-F-011    | repo 部は最大 64 文字                                       |

---

## 6. Requirements Traceability

| Requirement ID | Spec Rule | Notes                                              |
| -------------- | --------- | -------------------------------------------------- |
| REQ-F-010(a)   | R-001     | tool-version フォーマット検証                      |
| REQ-F-010(b)   | R-002     | asset-template 空値検証                            |
| REQ-F-010(c)   | R-003     | tool-name シンボルパターン検証                     |
| REQ-F-011      | R-004     | repo org/repo 形式検証                             |
| REQ-F-001      | —         | Covered in: `orchestration.spec.md` (OS/arch 検証) |
| REQ-F-002      | —         | Covered in: `build-url.spec.md`                    |
| REQ-F-003      | —         | Covered in: `build-url.spec.md`                    |
| REQ-F-004      | —         | Covered in: `verify-identity.spec.md`              |
| REQ-F-005      | —         | Covered in: `orchestration.spec.md`                |
| REQ-F-006      | —         | Covered in: `extract-install.spec.md`              |
| REQ-F-007      | —         | Covered in: `orchestration.spec.md`                |
| REQ-F-008      | —         | Covered in: `orchestration.spec.md`                |
| REQ-F-009      | —         | Covered in: `orchestration.spec.md`                |
| REQ-F-012      | —         | Covered in: `verify-identity.spec.md`              |

---

## 7. Open Questions

> **Status**: COMPLETE

None identified — all requirements are unambiguous.

---

## 8. Change History

| Date       | Version | Description                                                                                                                                                                                                                                                                                                 |
| ---------- | ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-03-23 | 1.0.0   | Initial specification                                                                                                                                                                                                                                                                                       |
| 2026-03-23 | 1.1.0   | DR-11 反映: R-001/R-003/R-004 に正規表現・境界条件を明示、fail-fast セマンティクスを R-xxx ルールに昇格、エラーメッセージ内容仕様を追加、Edge Cases に境界値 4 件追加 (1.2.3.4/1.2.3-beta/空 tool-name/repo スラッシュ過剰)                                                                                 |
| 2026-03-23 | 1.1.1   | fix: 用語統一 (「空文字・未指定」→「空文字または未指定」) 、Feature Decomposition の tool-version 行に正規表現を追記                                                                                                                                                                                        |
| 2026-03-23 | 1.1.2   | tool-name: 前後空白除去を明示、空白のみ入力を R-003 失敗として Edge Cases に追加                                                                                                                                                                                                                            |
| 2026-03-23 | 1.2.0   | tool-version: normalize_version() 委譲設計に変更 (DD-03/DR-12) 。v プレフィックス・X.Y・X 形式を許容。正規化後 X.Y.Z を後続出力に追加。R-001-N (正規化ステップ) 追加。Edge Cases を許容形式に合わせ全面更新                                                                                                 |
| 2026-03-23 | 1.3.0   | 全入力にサニタイズ (R-000) と文字数制限を追加 (DD-04) 。tool-name: 64 文字・tool-version: 32 文字・asset-template: 256 文字・repo org: 39 文字・repo repo: 64 文字。Edge Cases にサニタイズ・文字数超過ケースを追加                                                                                         |
| 2026-03-23 | 1.3.1   | tool-version: normalize_version() の major/minor 桁数制限を明示 (1〜3 桁) 。Edge Cases に 1000.0.0/1.1000.0 を追加。common.lib.sh の正規表現を `{1,3}` に更新                                                                                                                                               |
| 2026-03-23 | 1.4.0   | サニタイズ設計を全面改訂 (DD-04/DD-05) 。R-000 を前後空白除去のみに変更。R-000U を追加 (ASCII 以外 Unicode を拒否) 。各フィールドにホワイトリスト正規表現を適用。`asset-template` に `^[A-Za-z0-9._{}/-]{1,256}$` を設定。`checksum-template` に `<filename>` メタ変数を導入 (R-002C) 。Edge Cases 全面刷新 |
| 2026-03-23 | 1.4.1   | Section 2.4 ASCII Subset Policy を追加。適用範囲・Rationale・GitHub との非互換性・Breaking Change Policy を明記。セクション番号を 2.4〜2.8 に更新                                                                                                                                                           |
