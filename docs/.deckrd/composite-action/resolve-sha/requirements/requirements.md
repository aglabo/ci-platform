---
title: "Requirements: _ca-resolve-sha"
module: "composite-action/resolve-sha"
status: Draft
version: 1.2.0
created: "2026-10-25"
---

> **Normative Statement**
> This document defines binding requirements.
> Implementations MUST conform to this document.
> RFC 2119 keywords apply to this document only.

## 1. Overview

### 1.1 Purpose

`ca-get-changed-files` 内にある base/head SHA 解決ロジックを、独立した内部 Composite Action `.github/actions/_ca-resolve-sha/` に切り出す。
切り出した Action は、他の Action から再利用可能にする (Issue #135, 親 #134)。

あわせて、従来の実装で未対応だった次のケースを解決する。

- force push
- 履歴が N+1 コミットに満たない場合 (HEAD~N を解決できない場合)
- shallow clone による履歴不足

push とその他イベントでは、`actions/checkout` の `fetch-depth` を N+1 (N は commit-count) とする前提を置く。
リポジトリの履歴が N+1 コミットに満たず HEAD~N を解決できない場合は、エラーにせず空ツリー SHA へフォールバックする。
pull_request では、base を含む履歴の取得 (`fetch-depth: 0` 等) を前提とする。

また、呼び出し元が解決経路を判別できるよう、出力 `resolution` で経路を通知する。

本 Action は二点比較の基準 SHA を返す SHA 解決器であり、イベント全体の変更を網羅することは保証しない。
`resolution` が `event` / `override` 以外の場合に全件検査等へ切り替えるかは、呼び出し元が判断する (DR-13)。

### 1.2 Scope

- `.github/actions/_ca-resolve-sha/` Composite Action の新設
- 入力 `commit-count` (required: false, default "1") の受け取りと検証
- 入力 `before-sha` / `after-sha` (required: false, default "") による明示オーバーライド
- 出力 `before-sha` / `after-sha` / `resolution` の算出と `$GITHUB_OUTPUT` への書き出し
- スクリプト `.github/actions/_ca-resolve-sha/scripts/resolve-sha.sh` の実装
- push / pull_request / その他イベントごとの SHA 解決
- 異常系 (新規ブランチ、force push、履歴不足、不在コミット、HEAD 解決不能) の扱い
- `.github/actions/_libs/` への追加 (汎用 key=value 出力関数、正整数検証関数、ロードガード)

**Out of Scope**:

- merge-base 計算
- `ca-get-changed-files` 側の置き換え (別タスク)
- ファイルフィルタリング (#136)
- イベント全体の変更網羅の保証 (`resolution` に応じた対応は呼び出し元の責務)
- `_libs/` の既存関数のシグネチャおよび挙動の変更
- SHA-256 オブジェクト形式のリポジトリ (DR-19)
- before-sha が after-sha の祖先であることの検証 (DR-19)
- 対象リポジトリのパス入力、および近似経路での `::notice::` 出力 (DR-19)
- 旧形式の graft ファイルを持つリポジトリ (DR-21)
- `GIT_NO_LAZY_FETCH` に未対応の git での partial clone (DR-22)

## 2. Context

- Target Environment: GitHub Actions (Composite Action)。checkout の `fetch-depth` 前提は REQ-C-003 に従う。
- Related Components:
  - `.github/actions/ca-get-changed-files/action.yml` (resolve-sha ステップ)
  - `.github/actions/ca-get-changed-files/scripts/_libs/filter.lib.sh` (`resolve_sha_for_event` / `resolve_before_sha`)
  - `.github/actions/_libs/` (`output.lib.sh`, `validation.lib.sh`, `env.lib.sh`)
  - `.github/actions/ca-setup-repo`, `ca-setup-tool`, `ca-validate-environment` (`_libs/` の既存利用元)
- Assumptions:
  - 現行ロジックは、空または全ゼロの SHA を空ツリー SHA `4b825dc642cb6eb9a060e54bf8d69288fbee4904` に置換している。
  - 現行実装では push と pull_request のみ対応し、その他イベントは `Unsupported event` エラーとなる。
  - 現行実装は入力 `before-sha` / `after-sha` による明示オーバーライドを持つ。
  - ステークホルダーは、内部の呼び出し元 Action (`ca-get-changed-files`、将来の内部 Action) とリポジトリメンテナーである。
  - 対象リポジトリのオブジェクト形式は SHA-1 とする (DR-19)。
  - `GITHUB_EVENT_NAME` は、GitHub Actions ランナーが常に設定する既定の環境変数である。

### System Context Diagram

```text
                                 +-----------------------------------+
[Caller inputs:              --> |  _ca-resolve-sha                  | --> [Caller: ca-get-changed-files]
 commit-count,                   |   scripts/resolve-sha.sh          |     (before-sha / after-sha / resolution)
 before-sha, after-sha]          |        |                          | --> [$GITHUB_OUTPUT]
[GitHub Event env]           --> |        v                          | --> [::error:: / exit code]
                                 |  .github/actions/_libs/           |
                                 |   (output / validation / env)     | <-- [Other actions using _libs:
[Git repository (HEAD)]     <--> |                                   |      ca-setup-repo / ca-setup-tool /
                                 +-----------------------------------+      ca-validate-environment]
```

## 3. Design Decisions (Summary)

| ID    | Decision                                                                                            | Linked Record          |
| ----- | --------------------------------------------------------------------------------------------------- | ---------------------- |
| DR-01 | SHA 解決ロジックを内部 Composite Action `_ca-resolve-sha` に切り出す                                | ../decision-records.md |
| DR-02 | push の `before` が空・全ゼロ・コミットとして存在しない場合は HEAD~N にフォールバックする           | ../decision-records.md |
| DR-03 | HEAD~N が解決できない (履歴 < N+1) 場合は空ツリー SHA を `before-sha` とする                        | ../decision-records.md |
| DR-04 | pull_request の `before-sha` は `pull_request.base.sha` をそのまま使う (merge-base は対象外)        | ../decision-records.md |
| DR-05 | `commit-count` の検証はイベントに関わらず常に先頭で行う (fail-first)                                | ../decision-records.md |
| DR-06 | その他イベントは `Unsupported event` エラーとせず HEAD~N / HEAD で解決する                          | ../decision-records.md |
| DR-07 | 明示オーバーライド入力 `before-sha` / `after-sha` を継承する                                        | ../decision-records.md |
| DR-08 | 解決経路を出力 `resolution` で通知する                                                              | ../decision-records.md |
| DR-09 | フォールバックとその他イベントの基準は checkout 済み HEAD とする                                    | ../decision-records.md |
| DR-10 | 出力 SHA のコミット実在検証と git エラーを区別する                                                  | ../decision-records.md |
| DR-11 | スコープとインターフェース (権限の責務、入力形式、`_libs/` 拡張、環境変数名) を明確化する           | ../decision-records.md |
| DR-12 | push / その他イベントの checkout は `fetch-depth: N+1`、pull_request は base を含む履歴を前提とする | ../decision-records.md |
| DR-13 | 本 Action は二点比較の基準 SHA を返す SHA 解決器とし、変更網羅は保証しない                          | ../decision-records.md |
| DR-14 | 入力形式・git 障害の分類・checkout と出力の契約を厳格化する                                         | ../decision-records.md |
| DR-15 | イベント由来の SHA にも完全長 OID の形式検証を適用する                                              | ../decision-records.md |
| DR-16 | push の通常解決は after に github.sha を使い続ける                                                  | ../decision-records.md |
| DR-17 | GITHUB_EVENT_NAME はオーバーライドの有無に関わらず検証する                                          | ../decision-records.md |
| DR-18 | 書き出し中の I/O 失敗による部分出力は、呼び出し元の契約で扱う                                       | ../decision-records.md |
| DR-19 | 前提と非保証を明記し、追加の入出力は設けない                                                        | ../decision-records.md |
| DR-20 | push の before の検査障害は近似解決の例外とし、遅延取得を抑止する                                   | ../decision-records.md |
| DR-21 | コミット実在検証を OID 自体の型検査とし、replace refs を無効にする                                  | ../decision-records.md |
| DR-22 | 遅延取得抑止に未対応の git での partial clone は対象外とし、AC-017 を全経路に広げる                 | ../decision-records.md |

## 4. Functional Requirements

### REQ-F-001: commit-count の既定値

- EARS Type: WHEN (event-driven)

```text
GIVEN _ca-resolve-sha が呼び出し元 Action から利用される
  WHEN 呼び出し元が commit-count を指定しない
THEN the system SHALL commit-count を "1" として扱う.
```

**Rationale**: 入力 `commit-count` は required: false, default "1" と定められている。

**Acceptance Criteria**:

| AC ID  | Scenario                                      |
| ------ | --------------------------------------------- |
| AC-003 | workflow_dispatch で HEAD~1 / HEAD を解決する |

### REQ-F-002: commit-count の検証

- EARS Type: WHEN (event-driven)

```text
GIVEN _ca-resolve-sha が任意のイベントで実行される
  WHEN commit-count が正規表現 ^[1-9][0-9]*$ に一致しない、または 1000 を超える
THEN the system SHALL "::error::" を出力し、非ゼロ終了コードで終了する.
```

許容する形式は、先頭ゼロなしの正整数のみとする。
0、負数、非数値、前後の空白、先頭ゼロ (例: "01") は不正とする。
上限は 1000 とする (DR-14)。

**Rationale**: 不正な `commit-count` で後続の git 操作が誤った結果を返すことを防ぐ。

**Acceptance Criteria**:

| AC ID  | Scenario                             |
| ------ | ------------------------------------ |
| AC-004 | 不正な commit-count でエラー終了する |

### REQ-F-003: 検証の先行実行 (fail-first)

- EARS Type: NOT DO (unwanted behavior)

```text
GIVEN _ca-resolve-sha が任意のイベントで実行される
  NOT DO commit-count の検証完了前にイベント別の SHA 解決を行う
THEN the system SHALL イベント種別の判定より先に commit-count を検証し、検証失敗時は SHA 解決を行わずに終了する.
```

オーバーライド入力 (REQ-F-011) の処理も、commit-count の検証より後に行う。

評価順序は、commit-count の検証、オーバーライドの検証、イベント名の検証 (REQ-F-018)、SHA の解決、出力の書き出しとする (DR-17)。

**Rationale**: 検証をイベントに依存させず、全イベントで同一の入力契約を保証する。

**Acceptance Criteria**:

| AC ID  | Scenario                             |
| ------ | ------------------------------------ |
| AC-004 | 不正な commit-count でエラー終了する |

### REQ-F-004: push における通常解決

- EARS Type: WHEN (event-driven)

```text
GIVEN イベントが push である
  WHEN github.event.before が ^[0-9a-f]{40}$ に一致して全ゼロではなく、かつコミットとして存在すると確認できる
THEN the system SHALL before-sha に github.event.before を、after-sha に github.sha を設定する.
```

after-sha は、checkout 済み HEAD ではなく github.sha とする。
github.sha のコミットを checkout することは、呼び出し元の責務とする (DR-16)。
checkout の `ref` が github.sha と異なる場合、フォールバック経路 (HEAD 基準) とは after-sha が異なり得る。この差は許容する。

**Rationale**: 通常の push では、イベントが提供する前後の SHA がそのまま差分の基準になる。

**Acceptance Criteria**:

| AC ID  | Scenario                        |
| ------ | ------------------------------- |
| AC-001 | push で before/after を解決する |
| AC-008 | resolution 出力値を設定する     |

### REQ-F-005: push における before が空・全ゼロ・形式不正の場合

- EARS Type: WHEN (event-driven)

```text
GIVEN イベントが push である
  WHEN github.event.before が空、全ゼロ (40 桁の 0)、または ^[0-9a-f]{40}$ に一致しない (新規ブランチ等)
THEN the system SHALL before-sha を HEAD~N (N は commit-count) として、after-sha を HEAD として解決する.
```

形式に一致しない before は、エラーにせず無効な before として扱う (DR-15)。

**Rationale**: 新規ブランチでは比較対象となる before が存在しないため、直近 N コミットを基準にする。
before と after は、checkout 済みの同一履歴上の HEAD を基準にそろえる (DR-09)。

**Acceptance Criteria**:

| AC ID  | Scenario                                                  |
| ------ | --------------------------------------------------------- |
| AC-005 | push の before が無効な場合に HEAD~N へフォールバックする |
| AC-008 | resolution 出力値を設定する                               |

### REQ-F-006: push における before が存在しない場合

- EARS Type: WHEN (event-driven)

```text
GIVEN イベントが push である
  WHEN github.event.before が REQ-F-013 の検査でコミットとして存在すると確認できない (force push 等)
THEN the system SHALL before-sha を HEAD~N (N は commit-count) として、after-sha を HEAD として解決する.
```

検査の失敗は、原因を問わず (コミットの不在、オブジェクトの破損・読み取り障害) この要件の対象とする。
git はこれらに同じ終了コードを返し区別できないため、旧コミット側の障害は検出しない。これを保証の例外とする (DR-20)。
HEAD 側の障害は REQ-F-014 で検出する。

**Rationale**: force push では旧 SHA がリポジトリから失われ、そのままでは diff が失敗するため。

**Acceptance Criteria**:

| AC ID  | Scenario                                                  |
| ------ | --------------------------------------------------------- |
| AC-005 | push の before が無効な場合に HEAD~N へフォールバックする |
| AC-008 | resolution 出力値を設定する                               |

### REQ-F-007: 履歴不足時の空ツリー SHA

- EARS Type: WHEN (event-driven)

```text
GIVEN before-sha を HEAD~N として解決する必要がある
  WHEN HEAD がコミットとして解決でき、HEAD~N^{commit} を解決できず、かつその原因が履歴終端 (root コミット) または shallow 境界への到達である
THEN the system SHALL before-sha に空ツリー SHA 4b825dc642cb6eb9a060e54bf8d69288fbee4904 を、after-sha に HEAD を設定する.
```

履歴が N+1 コミットに満たない場合が該当する。一部の不足 (例: commit-count=3 で履歴 2 コミット) も対象とする。
shallow 境界を越える場合も対象とする。
HEAD~N は、第一親 (first parent) を N 世代たどった祖先とする。
原因が履歴終端・shallow 境界であると確認できない場合は、REQ-F-014 に従いエラーとする (DR-14)。

本 Action の責務は、空ツリー SHA を基準として返すことまでとする。空ツリー SHA との差分を計算できるようにすることは、呼び出し元の責務とする。

**Rationale**: 初回コミットや履歴不足でも、全ファイルを追加扱いとする差分基準を与えてエラー終了を避ける。
HEAD 自体が解決できない場合は、履歴不足ではなく異常として REQ-F-014 で扱う。

**Acceptance Criteria**:

| AC ID  | Scenario                               |
| ------ | -------------------------------------- |
| AC-006 | 履歴不足時に空ツリー SHA を返す        |
| AC-008 | resolution 出力値を設定する            |
| AC-011 | 部分的な履歴不足で空ツリー SHA を返す  |
| AC-012 | fetch-depth に応じて HEAD~N を解決する |

### REQ-F-008: pull_request における解決

- EARS Type: WHEN (event-driven)

```text
GIVEN イベントが pull_request である
  WHEN SHA の解決が要求される
THEN the system SHALL before-sha に pull_request.base.sha を、after-sha に pull_request.head.sha をそのまま設定する.
```

**Rationale**: merge-base 計算はスコープ外であり、イベントが提供する base/head を使う。
base/head の実在検証は REQ-F-013 で扱う。
出力は base 先頭と head の二点差の基準であり、PR が導入した変更と一致するとは限らない (DR-04, DR-13)。

**Acceptance Criteria**:

| AC ID  | Scenario                             |
| ------ | ------------------------------------ |
| AC-002 | pull_request で base/head を解決する |
| AC-008 | resolution 出力値を設定する          |

### REQ-F-009: その他イベントにおける解決

- EARS Type: WHEN (event-driven)

```text
GIVEN イベントが push でも pull_request でもない (workflow_dispatch, pull_request_target 等)
  WHEN SHA の解決が要求される
THEN the system SHALL before-sha を HEAD~N (N は commit-count) として、after-sha を HEAD として解決する.
```

`pull_request_target`、`pull_request_review`、`merge_group` 等は `pull_request` と同一視せず、その他イベントとして扱う (DR-06, DR-19)。
このため `pull_request_target` の出力は checkout 済み HEAD の直近 N 世代の比較であり、PR の変更検査には使えない。

**Rationale**: 従来は `Unsupported event` エラーであったが、再利用性のため全イベントで解決可能にする。

**Acceptance Criteria**:

| AC ID  | Scenario                                      |
| ------ | --------------------------------------------- |
| AC-003 | workflow_dispatch で HEAD~1 / HEAD を解決する |
| AC-008 | resolution 出力値を設定する                   |

### REQ-F-010: 出力の書き出し

- EARS Type: WHEN (event-driven)

```text
GIVEN before-sha と after-sha の解決が完了している
  WHEN 結果を呼び出し元へ返す
THEN the system SHALL before-sha、after-sha、resolution を $GITHUB_OUTPUT に出力する.
```

出力の経路は REQ-C-007 に従い、`output.lib.sh` に追加する汎用 key=value 出力関数を使う。

出力は、すべての検証が成功した後にまとめて書き出す。
検証に失敗した場合は、出力を一切書き出さずに `::error::` を出力し、非ゼロで終了する。
`$GITHUB_OUTPUT` が未設定または書き込み不能の場合も、`::error::` を出力し、非ゼロで終了する。
書き出し前の検査 (出力先、書き込み可否、改行、resolution の値) は、最初の行を書く前にすべて終える。
書き出し開始後に I/O 障害で書き込みに失敗した場合は、`::error::` を出力し、非ゼロで終了する。
このとき先に書いた行が残る部分出力は許容する (DR-18)。
呼び出し元は、非ゼロ終了時の出力を利用してはならない (DR-14, DR-18)。

**Rationale**: 出力は共有ライブラリ経由とする既存規約に従う。
現行の `output.lib.sh` は汎用の key=value 出力関数を持たないため、追加が必要となる。

**Acceptance Criteria**:

| AC ID  | Scenario                             |
| ------ | ------------------------------------ |
| AC-001 | push で before/after を解決する      |
| AC-002 | pull_request で base/head を解決する |
| AC-008 | resolution 出力値を設定する          |

### REQ-F-011: 明示オーバーライド

- EARS Type: WHEN (event-driven)

```text
GIVEN commit-count の検証に成功している
  WHEN 入力 before-sha と after-sha の両方が空でない値で指定されている
THEN the system SHALL イベント別解決を行わず、指定された値を出力 SHA として採用し、resolution に override を設定する.
```

オーバーライド値にも、REQ-F-013 のコミット実在検証を適用する。
オーバーライド値の形式は REQ-F-016 で検証する。

**Rationale**: 現行の `ca-get-changed-files` が持つ入力契約を継承し、置き換えタスクを単純な置換にする (DR-07)。

**Acceptance Criteria**:

| AC ID  | Scenario                                           |
| ------ | -------------------------------------------------- |
| AC-007 | オーバーライドは両方指定で採用し片方のみで拒否する |
| AC-008 | resolution 出力値を設定する                        |

### REQ-F-012: resolution 出力

- EARS Type: WHEN (event-driven)

```text
GIVEN SHA の解決が正常に完了している
  WHEN 結果を呼び出し元へ返す
THEN the system SHALL resolution に override、event、fallback-head-n、empty-tree のいずれか 1 つを設定する.
```

値は、次の対応表に従って設定する。

| resolution      | 設定する経路                                                            |
| --------------- | ----------------------------------------------------------------------- |
| override        | 入力 before-sha / after-sha の両方指定 (REQ-F-011)                      |
| event           | push の通常解決 (REQ-F-004)、pull_request (REQ-F-008)                   |
| fallback-head-n | before-sha を HEAD~N で解決できた経路 (REQ-F-005, REQ-F-006, REQ-F-009) |
| empty-tree      | before-sha が空ツリー SHA となった経路 (REQ-F-007)                      |

resolution は解決経路を示すだけであり、比較範囲が呼び出し元の目的に適していることは示さない (DR-13)。

**Rationale**: フォールバック時も正常終了するため、通知がなければ呼び出し元はどの経路で解決したかを区別できない。
値で通知すれば、呼び出し元は全件検査への切り替え等を判断できる (DR-08)。

**Acceptance Criteria**:

| AC ID  | Scenario                    |
| ------ | --------------------------- |
| AC-008 | resolution 出力値を設定する |

### REQ-F-013: 出力 SHA のコミット実在検証

- EARS Type: WHEN (event-driven)

```text
GIVEN 出力しようとする SHA が、before-sha 側の空ツリー SHA ではない
  WHEN オーバーライド値、pull_request の base/head、または push の after (github.sha) が空、あるいはコミットとして存在しない
THEN the system SHALL "::error::" を出力し、非ゼロ終了コードで終了する.
```

本書で「コミットとして存在する」とは、指定された OID 自体が commit 型のオブジェクトとしてローカルに存在することを指す (DR-21)。

- 検査は、修飾なしの完全長 OID に対して `git cat-file -t <oid>` を実行し、終了コード 0 かつ出力 `commit` の場合にのみ成功とする (MUST)。
- 終了コードが 0 以外の場合は、値を問わず検査失敗とする。特定の終了コードだけを不在と判定してはならない (MUST NOT)。
- 注釈付きタグのオブジェクトは、参照先がコミットであっても受理してはならない (MUST NOT)。
- `^{commit}` による参照解除の成功を、指定 OID 自体の型検査として使ってはならない (MUST NOT)。
- lightweight tag の参照先として得た OID はコミット OID そのものであり、受理する。
- 本検査は、オブジェクト本文全体の整合性や、参照先オブジェクトの完全性は保証しない。

空ツリー SHA の検証免除は before-sha に限る。
after-sha が空ツリー SHA の場合は、コミットとして存在しない場合と同様にエラーとする (DR-14)。

`pull_request.base.sha` / `pull_request.head.sha` が空の場合も、同様にエラーとする。
push の after (`github.sha`) は、通常解決 (REQ-F-004) で出力する場合に検証する。

push の `github.event.before` が空、またはコミットとして存在しない場合は、エラーにせず REQ-F-005 / REQ-F-006 の HEAD~N へフォールバックする。

**Rationale**: 不在コミットを出力すると、Action は成功して呼び出し元の `git diff` で失敗する。
fail-first 原則に従い、異常を発生源で検出する (DR-10)。

**Acceptance Criteria**:

| AC ID  | Scenario                                         |
| ------ | ------------------------------------------------ |
| AC-009 | 不在コミットまたは空のイベント値でエラー終了する |

### REQ-F-014: HEAD 解決不能・git 障害時のエラー

- EARS Type: WHEN (event-driven)

```text
GIVEN HEAD を基準とする経路 (REQ-F-005, REQ-F-006, REQ-F-007, REQ-F-009) で SHA を解決する必要がある
  WHEN HEAD がコミットとして解決できない (git リポジトリでない等)、または HEAD~N の解決失敗の原因が履歴終端・shallow 境界以外である (祖先オブジェクトの欠損等)
THEN the system SHALL "::error::" を出力し、非ゼロ終了コードで終了する.
```

この場合、空ツリー SHA へのフォールバックを行ってはならない。

**Rationale**: HEAD~N の解決失敗をすべて履歴不足と扱うと、リポジトリ不在等の異常が空ツリーで隠れる (DR-10)。

**Acceptance Criteria**:

| AC ID  | Scenario                                |
| ------ | --------------------------------------- |
| AC-010 | HEAD を解決できない場合はエラー終了する |

### REQ-F-015: オーバーライドの片方のみ指定

- EARS Type: WHEN (event-driven)

```text
GIVEN commit-count の検証に成功している
  WHEN 入力 before-sha と after-sha のうち一方のみが空でない値で指定されている
THEN the system SHALL "::error::" を出力し、非ゼロ終了コードで終了する.
```

**Rationale**: 片方のみの指定は意図が不明であり、イベント別解決へ黙って切り替えると誤った基準を返し得る (DR-07)。

**Acceptance Criteria**:

| AC ID  | Scenario                                           |
| ------ | -------------------------------------------------- |
| AC-007 | オーバーライドは両方指定で採用し片方のみで拒否する |

### REQ-F-016: オーバーライド値の形式検証

- EARS Type: WHEN (event-driven)

```text
GIVEN 入力 before-sha と after-sha の両方が空でない値で指定されている
  WHEN いずれかの値が正規表現 ^[0-9a-f]{40}$ に一致しない
THEN the system SHALL "::error::" を出力し、非ゼロ終了コードで終了する.
```

`HEAD~1` 等のリビジョン式、短縮 SHA、大文字を含む値は不正とする。

**Rationale**: リビジョン式はコミット検証を通過しても、出力が固定 SHA という契約にならない (DR-14)。

**Acceptance Criteria**:

| AC ID  | Scenario                         |
| ------ | -------------------------------- |
| AC-013 | オーバーライド値の形式を検証する |

### REQ-F-017: イベント由来 SHA の形式検証

- EARS Type: WHEN (event-driven)

```text
GIVEN オーバーライドが指定されておらず、イベント由来の SHA を出力しようとしている
  WHEN push の通常解決における github.sha、または pull_request の base.sha / head.sha が空でなく、かつ ^[0-9a-f]{40}$ に一致しない
THEN the system SHALL "::error::" を出力し、非ゼロ終了コードで終了する.
```

形式検証は、REQ-F-013 のコミット実在検証より先に行う。
push で github.event.before が不正な形式であれば、エラーとせず REQ-F-005 のフォールバックを適用する。

**Rationale**: コミット実在検証はリビジョン式やブランチ名も受理する。
出力が常に固定 SHA であるという契約を、オーバーライド経路以外にも適用する (DR-15)。

**Acceptance Criteria**:

| AC ID  | Scenario                          |
| ------ | --------------------------------- |
| AC-015 | イベント由来 SHA の形式を検証する |

### REQ-F-018: イベント名の必須検証

- EARS Type: WHEN (event-driven)

```text
GIVEN commit-count とオーバーライドの検証に成功している
  WHEN GITHUB_EVENT_NAME が空または未設定である
THEN the system SHALL オーバーライドの有無に関わらず "::error::" を出力し、非ゼロ終了コードで終了する.
```

**Rationale**: イベント名が不明なまま、その他イベントとして扱うと誤った基準を返し得る。
すべての実行で同じ環境の契約を保つ (DR-17)。

**Acceptance Criteria**:

| AC ID  | Scenario                             |
| ------ | ------------------------------------ |
| AC-016 | イベント名が空の場合はエラー終了する |

## 5. Non-Functional Requirements

### REQ-NF-001: Testability

すべての REQ-F は、ShellSpec (unit / functional) のテストケースを 1 件以上持たなければならない (MUST)。
`bash ./runners/run-shellspec.sh all` が `not ok` 0 件で完了しなければならない (MUST)。

HEAD~N、`git cat-file`、空ツリー、shallow 境界の検証は、実 git リポジトリ fixture で行わなければならない (MUST)。
fixture の作成方法は spec / impl で定める。

### REQ-NF-002: Locality

SHA 解決はローカルの git コマンド (`git rev-parse`, `git cat-file`, `git rev-list`) のみで行わなければならない (MUST)。
GitHub API 呼び出しやネットワークアクセス (`git fetch` を含む) を行ってはならない (MUST NOT)。

- すべての git 操作に `GIT_NO_LAZY_FETCH=1` を適用し、partial clone の遅延取得を抑止しなければならない (MUST, DR-20)。
- すべての git 操作に `GIT_NO_REPLACE_OBJECTS=1` を適用し、replace refs によるオブジェクト置換を無効にしなければならない (MUST, DR-21)。
  旧形式の graft ファイル (`.git/info/grafts`) は、この設定では無効にならない。graft ファイルを持つリポジトリは対象外とする。
- partial clone は許容する。各経路で必要なコミットは、呼び出し元が事前に取得しておく。
- 遅延取得の抑止によるコミット不在は既存の規則で扱い、shallow 境界と同一視してはならない (MUST NOT)。
- `GIT_NO_LAZY_FETCH` に未対応の git と partial clone の組み合わせは対象外とし、呼び出し元の責務とする (DR-22)。
  未対応の git では、push の before の存在検査自体が遅延取得を起動し得るため、事前取得では本要件を担保できない。

**Acceptance Criteria**:

| AC ID  | Scenario                                     |
| ------ | -------------------------------------------- |
| AC-017 | partial clone で欠損コミットを遅延取得しない |

## 6. Constraints

### REQ-C-001: スクリプトインジェクション防止

イベント値は env 経由でのみスクリプトに渡さなければならない (MUST)。`run` 内に `${{ }}` を記述してはならない (MUST NOT)。

### REQ-C-002: 最小権限

Composite Action は `permissions` を宣言できない。
このため、`permissions` を `contents: read` のみとする責務は、呼び出し元の workflow / job が負う (MUST)。
`_ca-resolve-sha` は、`contents: read` 以外の権限を必要としてはならない (MUST NOT)。

### REQ-C-003: checkout 前提

呼び出し元は、次の `fetch-depth` で `actions/checkout` を実行しなければならない (MUST)。

| イベント              | fetch-depth                                                                 | 理由                                          |
| --------------------- | --------------------------------------------------------------------------- | --------------------------------------------- |
| push / その他イベント | N+1 以上 (N は commit-count)                                                | HEAD~N を解決するには N+1 コミットが必要      |
| pull_request          | `0` 等、`pull_request.base.sha` と `pull_request.head.sha` の両方を含む深さ | base / head が不在の場合は REQ-F-013 でエラー |

- `_ca-resolve-sha` は履歴を取得しない (REQ-NF-002)。
- 対象リポジトリは、スクリプトの作業ディレクトリにある checkout 済みリポジトリとする。
- `fetch-depth` が N+1 未満の場合 (契約違反) の挙動は、REQ-F-007 の空ツリーへのフォールバックとして定義する (AC-012)。
- HEAD~N が shallow 境界やリポジトリの先頭を越える場合は、空ツリー SHA へフォールバックしなければならない (MUST, REQ-F-007)。
- push で `github.event.before` が shallow 範囲外にある場合は、HEAD~N へフォールバックする (REQ-F-006)。
- push では、github.sha のコミットを checkout しなければならない (MUST, DR-16)。
- partial clone を使う場合は、各経路で必要なコミットを取得済みにしなければならない (MUST, REQ-NF-002)。

### REQ-C-004: 内部専用

Action 名は `_` プレフィックス (`_ca-resolve-sha`) とし、内部専用としなければならない (MUST)。

### REQ-C-005: 静的解析

`actionlint` および `ghalint` を通過しなければならない (MUST)。

### REQ-C-006: インターフェース

- 配置先: `.github/actions/_ca-resolve-sha/`
- 入力 (kebab-case、明示デフォルト):
  - `commit-count` (required: false, default "1")
  - `before-sha` (required: false, default "")
  - `after-sha` (required: false, default "")
- 出力: `before-sha`, `after-sha`, `resolution`
- スクリプト: `.github/actions/_ca-resolve-sha/scripts/resolve-sha.sh`
- スクリプトが env 経由で受け取る値:
  - `GITHUB_EVENT_NAME` (イベント名)
  - `GITHUB_BEFORE_SHA` (`github.event.before`)
  - `GITHUB_AFTER_SHA` (`github.sha`)
  - `GITHUB_BASE_SHA` (`pull_request.base.sha`)
  - `GITHUB_HEAD_SHA` (`pull_request.head.sha`)
  - `INPUT_COMMIT_COUNT`, `INPUT_BEFORE_SHA`, `INPUT_AFTER_SHA` (入力)
- Composite Action は `INPUT_*` を自動設定しない。`action.yml` は、各入力とイベントコンテキストの値を、上記の環境変数へ step の `env` で明示的に対応付ける。

上記を満たさなければならない (MUST)。

### REQ-C-007: スクリプト規約

`resolve-sha.sh` は次の規約に従わなければならない (MUST)。

- `set -euo pipefail` を宣言する。
- ライブラリのロードガードを持つ。
- `BASH_SOURCE` ガード下で main を実行する。
- エラーは `::error::` を stderr に出力して非ゼロで終了する。
- 共有ライブラリ `.github/actions/_libs/` (`output.lib.sh`, `validation.lib.sh`, `env.lib.sh`) を利用する。
- 汎用の key=value 出力と正整数検証は、`_libs/` に追加した関数を使う (スクリプト内では実装しない)。

### REQ-C-008: _libs/ の変更方針

`.github/actions/_libs/` の変更は、追加のみとしなければならない (MUST)。

- 追加してよいもの:
  - `output.lib.sh` への汎用 key=value 出力関数
  - `validation.lib.sh` への正整数検証関数
  - `validation.lib.sh` へのロードガード
- 既存関数のシグネチャおよび挙動は変更してはならない (MUST NOT)。
- 既存利用元 (`ca-setup-repo`, `ca-setup-tool`, `ca-validate-environment`) の既存テストは、引き続き PASS しなければならない (MUST)。

## 7. User Stories

| Story ID | Role                                           | Goal                                                              | Reason                                                 | Related Requirements                           |
| -------- | ---------------------------------------------- | ----------------------------------------------------------------- | ------------------------------------------------------ | ---------------------------------------------- |
| US-001   | 内部の呼び出し元 Action (ca-get-changed-files) | イベント種別に依存せず before-sha / after-sha を取得したい        | SHA 解決ロジックを自前で持たずに差分取得へ集中するため | REQ-F-004, REQ-F-008, REQ-F-009, REQ-F-010     |
| US-002   | 将来の内部 Action の開発者                     | commit-count を指定するだけで差分基準 SHA を得たい                | 同一ロジックの重複実装を避けるため                     | REQ-F-001, REQ-F-009                           |
| US-003   | リポジトリメンテナー                           | force push や新規ブランチでもワークフローが失敗しないようにしたい | 履歴操作のたびに CI を手当てする運用負荷をなくすため   | REQ-F-005, REQ-F-006, REQ-F-007                |
| US-004   | リポジトリメンテナー                           | 不正な入力や不在コミットを早期にエラーとして検出したい            | 後続の git diff で原因不明の失敗になるのを避けるため   | REQ-F-002, REQ-F-003, REQ-F-013 から REQ-F-018 |
| US-005   | 内部の呼び出し元 Action (ca-get-changed-files) | 現行の before-sha / after-sha 明示指定を引き続き使いたい          | 置き換え時に入力契約を失わず移行コストを抑えるため     | REQ-F-011, REQ-F-015                           |
| US-006   | 内部の呼び出し元 Action (ca-get-changed-files) | どの経路で SHA を解決したかを resolution で判別したい             | フォールバック時に全件検査へ切り替える判断をするため   | REQ-F-012                                      |

## 8. Acceptance Criteria

```gherkin
# AC-001: push で before/after を解決する
# Requirement: REQ-F-004, REQ-F-010
Scenario: push で before/after を解決する
  Given イベントが push で、github.event.before がコミットとして存在する SHA である
  When  _ca-resolve-sha を実行する
  Then  before-sha は github.event.before と一致する
  And   after-sha は github.sha と一致する
  And   resolution は event である
  And   3 つの出力すべてが $GITHUB_OUTPUT に出力される

# AC-002: pull_request で base/head を解決する
# Requirement: REQ-F-008, REQ-F-010
Scenario: pull_request で base/head を解決する
  Given イベントが pull_request で、base と head がコミットとして存在する
  When  _ca-resolve-sha を実行する
  Then  before-sha は pull_request.base.sha と一致する
  And   after-sha は pull_request.head.sha と一致する
  And   resolution は event である

# AC-003: workflow_dispatch で HEAD~1 / HEAD を解決する
# Requirement: REQ-F-001, REQ-F-009
Scenario: workflow_dispatch で HEAD~1 / HEAD を解決する
  Given イベントが workflow_dispatch で、commit-count が未指定である
  When  _ca-resolve-sha を実行する
  Then  before-sha は HEAD~1 の SHA と一致する
  And   after-sha は HEAD の SHA と一致する
  And   resolution は fallback-head-n である

# AC-004: 不正な commit-count でエラー終了する
# Requirement: REQ-F-002, REQ-F-003
Scenario Outline: 不正な commit-count でエラー終了する
  Given イベントが <event> で、commit-count が "<value>" である
  When  _ca-resolve-sha を実行する
  Then  "::error::" が出力される
  And   終了コードは非ゼロである
  And   before-sha / after-sha / resolution は出力されない

  Examples:
    | event             | value |
    | push              | 0     |
    | pull_request      | -1    |
    | workflow_dispatch | abc   |
    | workflow_dispatch | 01    |
    | push              | " 2"  |
    | push              | 1001  |

# AC-005: push の before が無効な場合に HEAD~N へフォールバックする
# Requirement: REQ-F-005, REQ-F-006
Scenario Outline: push の before が無効な場合に HEAD~N へフォールバックする
  Given イベントが push で、commit-count が 2 である
  And   github.event.before が <before_state> である
  When  _ca-resolve-sha を実行する
  Then  before-sha は HEAD~2 の SHA と一致する
  And   after-sha は HEAD の SHA と一致する
  And   resolution は fallback-head-n である

  Examples:
    | before_state                                              |
    | 空文字列                                                  |
    | 全ゼロ SHA                                                |
    | 形式に一致しない値 (例: main)                             |
    | コミットとして存在しない SHA                              |
    | 注釈付きタグのオブジェクト OID                            |

# AC-006: 履歴不足時に空ツリー SHA を返す
# Requirement: REQ-F-007
Scenario Outline: 履歴不足時に空ツリー SHA を返す
  Given イベントが <trigger> である
  And   履歴が初回コミットのみで、commit-count が 3 である
  When  _ca-resolve-sha を実行する
  Then  before-sha は 4b825dc642cb6eb9a060e54bf8d69288fbee4904 である
  And   after-sha は HEAD の SHA と一致する
  And   resolution は empty-tree である
  And   終了コードは 0 である

  Examples:
    | trigger                              |
    | workflow_dispatch 等のその他イベント |
    | push で github.event.before が無効   |

# AC-007: オーバーライドは両方指定で採用し片方のみで拒否する
# Requirement: REQ-F-011, REQ-F-015
Scenario: before-sha と after-sha の両方を指定する
  Given 入力 before-sha と after-sha がどちらもコミットとして存在する SHA である
  When  _ca-resolve-sha を任意のイベントで実行する
  Then  before-sha / after-sha は指定値と一致する
  And   resolution は override である

Scenario Outline: 片方のみを指定する
  Given 入力 before-sha が "<before>" で、after-sha が "<after>" である
  When  _ca-resolve-sha を任意のイベントで実行する
  Then  "::error::" が出力される
  And   終了コードは非ゼロである
  And   before-sha / after-sha / resolution は出力されない

  Examples:
    | before   | after    |
    | 有効 SHA | 空文字列 |
    | 空文字列 | 有効 SHA |

# AC-008: resolution 出力値を設定する
# Requirement: REQ-F-012
Scenario Outline: 解決経路ごとに resolution を設定する
  Given <condition>
  When  _ca-resolve-sha を実行する
  Then  resolution は <resolution> である

  Examples:
    | condition                                   | resolution      |
    | 入力 before-sha / after-sha を両方指定      | override        |
    | push で before がコミットとして存在する     | event           |
    | pull_request                                | event           |
    | push で before が無効で HEAD~N を解決できる | fallback-head-n |
    | workflow_dispatch で HEAD~N を解決できる    | fallback-head-n |
    | HEAD~N を解決できない                       | empty-tree      |

# AC-009: 不在コミットまたは空のイベント値でエラー終了する
# Requirement: REQ-F-013
Scenario Outline: 不在コミットまたは空のイベント値でエラー終了する
  Given <condition>
  When  _ca-resolve-sha を実行する
  Then  "::error::" が出力される
  And   終了コードは非ゼロである
  And   before-sha / after-sha / resolution は出力されない

  Examples:
    | condition                                               |
    | オーバーライド値の一方がコミットとして存在しない        |
    | pull_request.base.sha がコミットとして存在しない        |
    | pull_request.head.sha がコミットとして存在しない        |
    | pull_request.base.sha が空                              |
    | pull_request.head.sha が空                              |
    | push の通常解決で github.sha が空                       |
    | push の通常解決で github.sha がコミットとして存在しない |
    | オーバーライドの after-sha が空ツリー SHA               |
    | オーバーライドの after-sha が注釈付きタグのオブジェクト OID |
    | pull_request.head.sha が、タグを指す注釈付きタグの OID   |
    | pull_request.base.sha が、replace ref でコミットに置換された注釈付きタグの OID |

Scenario: lightweight tag の参照先 OID を受理する
  Given 入力 before-sha と after-sha が、lightweight tag の参照先として得たコミット OID である
  When  _ca-resolve-sha を実行する
  Then  before-sha / after-sha は指定値と一致する
  And   resolution は override である

# AC-010: HEAD を解決できない場合はエラー終了する
# Requirement: REQ-F-014
Scenario Outline: HEAD 解決不能または git 障害でエラー終了する
  Given イベントが workflow_dispatch で、<condition>
  When  _ca-resolve-sha を実行する
  Then  "::error::" が出力される
  And   終了コードは非ゼロである
  And   before-sha / after-sha / resolution は出力されない

  Examples:
    | condition                                 |
    | 作業ディレクトリが git リポジトリではない |
    | HEAD~N の祖先オブジェクトが欠損している   |

# AC-011: 部分的な履歴不足で空ツリー SHA を返す
# Requirement: REQ-F-007
Scenario: 部分的な履歴不足で空ツリー SHA を返す
  Given 履歴が 2 コミットで、commit-count が 3 である
  And   イベントが workflow_dispatch である
  When  _ca-resolve-sha を実行する
  Then  before-sha は 4b825dc642cb6eb9a060e54bf8d69288fbee4904 である
  And   after-sha は HEAD の SHA と一致する
  And   resolution は empty-tree である
  And   終了コードは 0 である

# AC-012: fetch-depth に応じて HEAD~N を解決する
# Requirement: REQ-F-007, REQ-C-003
# depth=2 は REQ-C-003 違反時の定義済み挙動を検証する
Scenario Outline: shallow clone の深さに応じて HEAD~N を解決する
  Given 元リポジトリの履歴が 5 コミットで、commit-count が 2 である
  And   作業リポジトリが fetch-depth <depth> の shallow clone である
  And   イベントが workflow_dispatch である
  When  _ca-resolve-sha を実行する
  Then  before-sha は <before> である
  And   after-sha は HEAD の SHA と一致する
  And   resolution は <resolution> である
  And   終了コードは 0 である

  Examples:
    | depth | before                                   | resolution      |
    | 3     | HEAD~2 の SHA                            | fallback-head-n |
    | 2     | 4b825dc642cb6eb9a060e54bf8d69288fbee4904 | empty-tree      |

# AC-013: オーバーライド値の形式を検証する
# Requirement: REQ-F-016
Scenario Outline: 完全長 SHA 以外のオーバーライド値でエラー終了する
  Given 入力 before-sha が "<value>" で、after-sha がコミットとして存在する完全長 SHA である
  When  _ca-resolve-sha を実行する
  Then  "::error::" が出力される
  And   終了コードは非ゼロである
  And   before-sha / after-sha / resolution は出力されない

  Examples:
    | value              |
    | HEAD~1             |
    | 7 桁の短縮 SHA     |
    | 大文字を含む 40 桁 |

# AC-014: HEAD~N は第一親をたどる
# Requirement: REQ-F-007, REQ-F-009
Scenario: merge コミットを含む履歴で第一親をたどる
  Given HEAD が merge コミットで、その第一親が P1 である
  And   イベントが workflow_dispatch で、commit-count が 1 である
  When  _ca-resolve-sha を実行する
  Then  before-sha は P1 の SHA と一致する
  And   resolution は fallback-head-n である

# AC-015: イベント由来 SHA の形式を検証する
# Requirement: REQ-F-017
Scenario Outline: 完全長 SHA 以外のイベント値でエラー終了する
  Given オーバーライドが指定されておらず、<condition>
  When  _ca-resolve-sha を実行する
  Then  "::error::" が出力される
  And   終了コードは非ゼロである
  And   before-sha / after-sha / resolution は出力されない

  Examples:
    | condition                                                             |
    | イベントが pull_request で、pull_request.head.sha が "main" である    |
    | イベントが pull_request で、pull_request.base.sha が 7 桁の短縮 SHA   |
    | イベントが push で before がコミットとして存在し、github.sha が HEAD~1 |

# AC-016: イベント名が空の場合はエラー終了する
# Requirement: REQ-F-018
Scenario Outline: GITHUB_EVENT_NAME が空の場合はエラー終了する
  Given GITHUB_EVENT_NAME が <state> で、<override> である
  When  _ca-resolve-sha を実行する
  Then  "::error::" が出力される
  And   終了コードは非ゼロである
  And   before-sha / after-sha / resolution は出力されない

  Examples:
    | state  | override                       |
    | 空     | オーバーライドが指定されていない |
    | 未設定 | オーバーライドが指定されていない |
    | 空     | オーバーライドが両方指定されている |

# AC-017: partial clone で欠損コミットを遅延取得しない
# Requirement: REQ-NF-002
# GIT_NO_LAZY_FETCH に対応した git で実行する (DR-22)
Scenario Outline: partial clone で欠損コミットを遅延取得しない
  Given 作業リポジトリが promisor remote を持つ partial clone で、HEAD から N+1 世代のコミットを取得済みである
  And   <missing> だけがローカルに存在しない
  When  _ca-resolve-sha を実行する
  Then  git fetch の子プロセスは起動されない
  And   結果は <outcome> である

  Examples:
    | missing                                                 | outcome                                                 |
    | push の github.event.before のコミット                  | before-sha が HEAD~N の SHA で、resolution が fallback-head-n |
    | pull_request.base.sha のコミット                        | "::error::" を出力し、非ゼロ終了する                    |
    | オーバーライドの before-sha のコミット                  | "::error::" を出力し、非ゼロ終了する                    |
    | HEAD~N に至る途中の祖先コミット (shallow 境界ではない) | "::error::" を出力し、非ゼロ終了する (empty-tree としない) |
```

## 9. Open Questions

| Question                                                                                                        | Type      | Impact Area | Owner |
| --------------------------------------------------------------------------------------------------------------- | --------- | ----------- | ----- |
| REQ-F-002, REQ-F-013 から REQ-F-018: エラーメッセージの文言・形式 (spec で形式を決定済み、文言は spec が定める) | EARS/THEN | FR outcome  | spec  |

## 10. Traceability

| REQ ID     | AC IDs                                 | Type           |
| ---------- | -------------------------------------- | -------------- |
| REQ-F-001  | AC-003                                 | Functional     |
| REQ-F-002  | AC-004                                 | Functional     |
| REQ-F-003  | AC-004                                 | Functional     |
| REQ-F-004  | AC-001, AC-008                         | Functional     |
| REQ-F-005  | AC-005, AC-008                         | Functional     |
| REQ-F-006  | AC-005, AC-008                         | Functional     |
| REQ-F-007  | AC-006, AC-008, AC-011, AC-012, AC-014 | Functional     |
| REQ-F-008  | AC-002, AC-008                         | Functional     |
| REQ-F-009  | AC-003, AC-008, AC-014                 | Functional     |
| REQ-F-010  | AC-001, AC-002, AC-008                 | Functional     |
| REQ-F-011  | AC-007, AC-008                         | Functional     |
| REQ-F-012  | AC-008                                 | Functional     |
| REQ-F-013  | AC-009                                 | Functional     |
| REQ-F-014  | AC-010                                 | Functional     |
| REQ-F-015  | AC-007                                 | Functional     |
| REQ-F-016  | AC-013                                 | Functional     |
| REQ-F-017  | AC-015                                 | Functional     |
| REQ-F-018  | AC-016                                 | Functional     |
| REQ-NF-001 | N/A                                    | Non-Functional |
| REQ-NF-002 | AC-017                                 | Non-Functional |
| REQ-C-001  | N/A                                    | Constraint     |
| REQ-C-002  | N/A                                    | Constraint     |
| REQ-C-003  | AC-012                                 | Constraint     |
| REQ-C-004  | N/A                                    | Constraint     |
| REQ-C-005  | N/A                                    | Constraint     |
| REQ-C-006  | N/A                                    | Constraint     |
| REQ-C-007  | N/A                                    | Constraint     |
| REQ-C-008  | N/A                                    | Constraint     |

## 11. Change History

| Date       | Version | Description                                                                                                                 |
| ---------- | ------- | --------------------------------------------------------------------------------------------------------------------------- |
| 2026-10-25 | 1.0.0   | Initial release                                                                                                             |
| 2026-10-25 | 1.1.0   | Apply DR-07..DR-14: add REQ-F-011..016, REQ-C-008, AC-007..014; revise REQ-F-002/005/006/007/010/013/014, REQ-C-002/003/006 |
| 2026-10-25 | 1.2.0   | Apply DR-15..DR-22: add REQ-F-017/018, AC-015..017; revise REQ-F-003..007/009/010/012/013, REQ-NF-002, REQ-C-003/006        |
