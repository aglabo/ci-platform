---
title: "Requirements: ca-get-changed-files"
module: "composite-action/get-changed-files"
status: approved
version: 2.2.0
created: "2026-10-29"
---

<!-- cspell:words ACMR -->

> **Normative Statement**
> This document defines binding requirements.
> Implementations MUST conform to this document.
> RFC 2119 keywords apply to this document only.

## 1. Overview

### 1.1 Purpose

公開 Composite Action `ca-get-changed-files` を組み直す (Issue #134)。
内部 Action `_ca-resolve-sha` (#135) と `_ca-filter-files` (#136) を土台にする。
SHA の解決と glob による絞り込みは内部 Action に任せ、本 Action は差分範囲の変更ファイルの一覧の取得だけを持つ。

改訂前の Action には次の制約がある。

- 差分範囲を 2 つの SHA 入力 (`before-sha` / `after-sha`) で受け取る。
- SHA 解決ロジック (`resolve_sha_for_event`) を自前で持ち、push と pull_request 以外のイベントでは `Unsupported event` で失敗する。
- `pattern` は `git diff` に渡す git pathspec であり、1 つしか指定できず、除外もできない。

改訂後は、入力を `commit-count` と `pattern` (glob、複数行、`!` で除外) とし、出力 `files` / `count` は従来どおりとする。

### 1.2 Scope

- `action.yml` の入力の変更: `before-sha` / `after-sha` の削除、`commit-count` の追加、`pattern` の意味の変更 (git pathspec から glob へ)
- `_ca-resolve-sha` のスクリプトによる差分範囲の SHA 解決
- `git diff` による変更ファイルの一覧の取得 (pathspec なし)
- `_ca-filter-files` のスクリプトによる絞り込みと、出力 `files` / `count` の書き出し
- `scripts/_libs/filter.lib.sh` とそのテストの削除 (DR-09)
- ShellSpec テストと `_tests_ca_composite-actions.yml` の `test-get-changed-files` ジョブの改訂
- `CHANGELOG.md` への破壊的変更と移行方法の記載

**Out of Scope**:

- SHA 解決の規則そのもの (`_ca-resolve-sha` の要件に従う)
- glob の照合規則そのもの (`_ca-filter-files` の要件に従う)
- `_ca-resolve-sha` / `_ca-filter-files` / `.github/actions/_libs/` の変更
- 出力 `files` / `count` の形式の変更、出力の追加 (`resolution` を含む。DR-08)
- `actions/checkout` の `fetch-depth: 0` 要件の緩和
- 3000 件または 120000 バイトを超える差分の取得 (DR-07)
- `git diff` の `--diff-filter` の変更 (A/C/M/R のまま)

## 2. Context

- Target Environment: GitHub Actions ubuntu runner の Bash (Composite Action の `run` step)。macOS / Windows runner は対象外とする。
- Related Components:
  - `.github/actions/ca-get-changed-files/` (本モジュール)
  - `.github/actions/_ca-resolve-sha/` (`scripts/resolve-sha.sh`)
  - `.github/actions/_ca-filter-files/` (`scripts/filter-files.sh`)
  - `.github/workflows/_tests_ca_composite-actions.yml` (`test-get-changed-files` ジョブ)
  - `CHANGELOG.md`
- Assumptions:
  - 本 Action の利用者は、`aglabo/ci-platform/.github/actions/ca-get-changed-files@<ref>` の形で外部リポジトリから参照する。
  - GitHub Actions は、`uses:` で参照した Action のリポジトリ全体を同じ ref で取得する。
    このため、`${GITHUB_ACTION_PATH}/..` から兄弟の内部 Action のスクリプトに到達できる (DR-05)。
  - 現在の呼び出し元は、`_tests_ca_composite-actions.yml` の `test-get-changed-files` ジョブだけである。
    本番の `ci-*` / `ru-*` ワークフローは本 Action を使っていない。
  - `git diff` は既定 (`core.quotePath=true`) で、非 ASCII 文字を含むパスを `"..."` の引用表記で出力する。
    `_ca-filter-files` はダブルクオートを含む行をエラーにする (`_ca-filter-files` REQ-F-017)。
  - `core.quotePath=false` でも、`"`・`\`・制御文字 (タブ、改行など) を含むパスは引用表記で出力される。
  - pull_request の範囲は base 先頭と head の二点比較であり、PR が持ち込んだ変更と一致するとは限らない。
    分岐後に base 側だけで変更されたファイルも含まれ得る (`_ca-resolve-sha` DR-04, DR-13)。
  - `_ca-resolve-sha` と `git diff` は作業ディレクトリ (`$PWD`) で実行される。対象リポジトリをそこへ checkout する義務は REQ-C-003 に定める (DR-10)。
    Composite Action の `run` step は、`working-directory` を指定しない限り `$GITHUB_WORKSPACE` で実行される。
    本 Action は `working-directory` を指定しない。
  - 変更ファイルのパスは UTF-8 として正しい (DR-11)。
    ランナーは step 出力を文字列として読むため、不正なバイト列は置き換えられ、`_ca-filter-files` で検出できないことがある。
  - 入力 `pattern` の値は、環境変数 1 つ分の上限 (約 131072 バイト) に収まる (DR-11)。
    超えた場合は絞り込みの段が起動できず、`::error::` が出ないまま失敗する。
  - リネームの検出は、リポジトリの `diff.renames` の設定に従う。
    リネームが R でも D と A の組でも、`--name-only` と ACMR の組み合わせでは新しいパスだけが出る。
    コピー (C) は `-C` を付けないため検出されない。
  - サブモジュール (gitlink) の更新は、ファイルと同じくパスとして `files` に含まれる。除外したい場合は `pattern` の `!` で除外する。
  - `commit-count` の HEAD~N は、第一親 (first parent) を N 世代たどった祖先である (`_ca-resolve-sha` REQ-F-007)。
    結果は両端のツリーの差分であり、期間中に一度でも変更されたファイルの和集合ではない。途中で追加して削除したファイルは含まれない。
  - push の `before` が不在 (force push 等) で HEAD~N にフォールバックした場合、範囲は push の全コミットを含むとは限らない。
    本 Action は解決経路 (`resolution`) を公開しないため、呼び出し元はフォールバックを区別できない (DR-08、`_ca-resolve-sha` DR-13)。
  - 内部 Action のスクリプトの位置 (`scripts/*.sh`) と、それが読む環境変数の名前は、モジュール間の契約として扱う (DR-05)。
    内部 Action の側でこれらを変える場合は、本 Action を同時に改訂する。
  - 本書の「段」は、本 Action の step (SHA の解決、変更ファイルの取得、絞り込み) を指す。
  - 本書の「加工せずに渡す」は、GitHub Actions が YAML として解釈した後の文字列を、そのまま次の段に渡すことを指す。

### System Context Diagram

```text
[Caller workflow inputs:         +----------------------------------------+
 commit-count, pattern]      --> |  ca-get-changed-files                  | --> [Caller: files / count]
[GitHub Event env]           --> |                                        | --> [$GITHUB_OUTPUT]
                                 |  1. _ca-resolve-sha/scripts            | --> [::error:: / exit code]
                                 |       resolve-sha.sh                   |
                                 |       (before-sha / after-sha)         |
                                 |  2. scripts/get-changed-files.sh       |
                                 |       git diff --name-only (no spec)   |
                                 |  3. _ca-filter-files/scripts           |
                                 |       filter-files.sh (files / count)  |
[Git repository (checkout)] <--> |                                        |
                                 +----------------------------------------+
```

## 3. Design Decisions (Summary)

| ID    | Decision                                                                                   | Linked Record          |
| ----- | ------------------------------------------------------------------------------------------ | ---------------------- |
| DR-01 | 差分範囲の SHA 解決を `_ca-resolve-sha` に任せる                                           | ../decision-records.md |
| DR-02 | 変更ファイルの絞り込みを `_ca-filter-files` に任せる                                       | ../decision-records.md |
| DR-03 | 入力 `before-sha` / `after-sha` を削除し、`commit-count` に置き換える                      | ../decision-records.md |
| DR-04 | 入力名 `pattern` を維持し、意味だけを glob に変える                                        | ../decision-records.md |
| DR-05 | 内部 Action は `uses:` ではなく、`${GITHUB_ACTION_PATH}/..` のスクリプトを直接実行して使う | ../decision-records.md |
| DR-06 | `git diff` は `core.quotePath=false` で実行する                                            | ../decision-records.md |
| DR-07 | `pattern` の有無に関わらず常に `_ca-filter-files` を通し、上限超過はエラーとする           | ../decision-records.md |
| DR-08 | 出力は `files` / `count` だけとし、`resolution` は公開しない                               | ../decision-records.md |
| DR-09 | 旧ライブラリ `filter.lib.sh` はファイルごと削除する                                        | ../decision-records.md |
| DR-10 | 対象リポジトリを作業ディレクトリに checkout することを呼び出し元の義務とする               | ../decision-records.md |
| DR-11 | `pattern` のサイズと非 UTF-8 のパスは前提とし、検査しない                                  | ../decision-records.md |

## 4. Functional Requirements

### REQ-F-001: commit-count の受け渡し

- EARS Type: WHEN (event-driven)

```text
GIVEN ca-get-changed-files が呼び出し元のワークフローから利用される
  WHEN 本 Action が SHA の解決を行う
THEN the system SHALL 入力 commit-count (未指定時は "1") を、加工せずに _ca-resolve-sha の commit-count として渡す.
```

`commit-count` の検証 (先頭ゼロなしの正整数、上限 1000) は `_ca-resolve-sha` が行う (`_ca-resolve-sha` REQ-F-002)。本 Action は独自に検証しない。

**Rationale**: SHA の解決と入力検証を 1 か所にまとめる (DR-01)。
`commit-count` は push の通常解決と pull_request では使われず、`before` が使えない push とその他イベントの HEAD~N だけに効く。

**Acceptance Criteria**:

| AC ID  | Scenario                                                        |
| ------ | --------------------------------------------------------------- |
| AC-003 | その他イベントで HEAD~N..HEAD の変更ファイルを返す              |
| AC-004 | commit-count 未指定のその他イベントで HEAD~1..HEAD の変更を返す |
| AC-005 | 不正な commit-count でエラー終了し、files / count を出力しない  |

### REQ-F-002: 差分範囲の SHA 解決

- EARS Type: WHEN (event-driven)

```text
GIVEN ca-get-changed-files が任意のイベントで実行される
  WHEN 変更ファイルの取得の前に差分範囲を決める
THEN the system SHALL _ca-resolve-sha のスクリプトで before-sha / after-sha を解決し、
     オーバーライド入力 (before-sha / after-sha) には step の env で空文字列を明示して渡す.
```

解決規則は `_ca-resolve-sha` の要件に従う。主な経路は次のとおりとする。

| イベント                           | before-sha              | after-sha               |
| ---------------------------------- | ----------------------- | ----------------------- |
| push (通常)                        | `github.event.before`   | `github.sha`            |
| push (`before` が空・全ゼロ・不在) | HEAD~N                  | HEAD                    |
| pull_request                       | `pull_request.base.sha` | `pull_request.head.sha` |
| その他イベント                     | HEAD~N                  | HEAD                    |

push の通常解決では、`github.sha` がコミットとして存在しない場合はエラーとなる (`_ca-resolve-sha` REQ-F-013)。
push のフォールバックとその他イベントでは、before / after とも checkout 済みの HEAD を基準とする (`_ca-resolve-sha` DR-09)。
履歴が N+1 コミットに満たない場合、before-sha は空ツリー SHA となる (`_ca-resolve-sha` REQ-F-007)。

**Rationale**: SHA 解決の規則を `_ca-resolve-sha` だけに置き、本 Action からイベント別の分岐をなくす (DR-01)。オーバーライド入力は公開しないため、常に空で渡す (DR-03)。
step は呼び出し元のジョブの env を引き継ぐため、空文字列を明示しないと、ジョブ env の値でオーバーライドが有効になり得る。

**Acceptance Criteria**:

| AC ID  | Scenario                                               |
| ------ | ------------------------------------------------------ |
| AC-001 | push で before..after の変更ファイルを返す             |
| AC-002 | pull_request で base..head の変更ファイルを返す        |
| AC-003 | その他イベントで HEAD~N..HEAD の変更ファイルを返す     |
| AC-013 | 履歴が足りない場合は HEAD の全ファイルを追加として返す |

### REQ-F-003: 変更ファイルの取得

- EARS Type: WHEN (event-driven)

```text
GIVEN 解決済みの before-sha と after-sha がある
  WHEN 変更ファイルの一覧を取得する
THEN the system SHALL git -c core.quotePath=false diff --name-only --diff-filter=ACMR <before-sha> <after-sha> を
     pathspec なしで実行し、その出力を 1 行 1 パスの一覧として扱う.
```

`--diff-filter=ACMR` は改訂前のまま、追加・コピー・変更・リネームを対象とし、削除を含めない。
before-sha が空ツリー SHA の場合も、同じ 2 引数の形で実行する。

**Rationale**: 絞り込みを `_ca-filter-files` に移すため、`git diff` には pathspec を渡さない (DR-02)。
`core.quotePath=false` により、非 ASCII 文字 (日本語など) を含むパスを引用表記にせず、そのまま渡す (DR-06)。

**Acceptance Criteria**:

| AC ID  | Scenario                                                 |
| ------ | -------------------------------------------------------- |
| AC-001 | push で before..after の変更ファイルを返す               |
| AC-009 | 削除されたファイルは files に含めない                    |
| AC-010 | 非 ASCII 文字を含むパスを引用表記にせずに返す            |
| AC-015 | 変更が無い差分は、空の files と count "0" で正常終了する |

### REQ-F-004: pattern による絞り込み

- EARS Type: WHEN (event-driven)

```text
GIVEN 変更ファイルの一覧を取得している
  WHEN 一覧を呼び出し元へ返す前に絞り込む
THEN the system SHALL 一覧を _ca-filter-files の files として、入力 pattern を加工せずに _ca-filter-files の patterns として渡し、
     その結果を本 Action の結果とする.
```

`pattern` は 1 行 1 個の glob パターンとし、`!` で始まる行は除外とする。
照合規則 (`**` / `*` / `?`、後に一致したパターンの優先、空パターンでの全件保持) は `_ca-filter-files` の要件に従う。
`pattern` が空でも `_ca-filter-files` を通す (DR-07)。
空とは、空文字列、または `_ca-filter-files` REQ-F-001 で無視される行 (空行・空白だけの行) だけからなる値を指す。
このとき `_ca-filter-files` は全件を保持する (`_ca-filter-files` REQ-F-004)。

**Rationale**: 複数パターンと除外を 1 つの入力で表せるようにする (Issue #134)。入力名は変えずに意味だけを変え、呼び出し元の書き換えを最小にする (DR-04)。

**Acceptance Criteria**:

| AC ID  | Scenario                                                         |
| ------ | ---------------------------------------------------------------- |
| AC-006 | 複数行の pattern と除外で変更ファイルを絞り込む                  |
| AC-007 | pattern が空なら変更ファイルをすべて返す                         |
| AC-008 | 一致するファイルが無ければ空の files と count "0" で正常終了する |

### REQ-F-005: 出力

- EARS Type: WHEN (event-driven)

```text
GIVEN _ca-filter-files による絞り込みが成功している
  WHEN 結果を呼び出し元へ返す
THEN the system SHALL _ca-filter-files の files と count を、本 Action の出力 files と count としてそのまま公開する.
```

`files` は 1 行 1 パス、入力 (git diff の出力) の順とする。`count` は先頭ゼロなしの 10 進整数とする。
`_ca-resolve-sha` の `resolution` は公開しない (DR-08)。

**Rationale**: 出力の書式を `_ca-filter-files` に一本化し、本 Action では出力を書き出す処理を持たない (DR-02)。出力の名前と意味は従来どおりとする (Issue #134 Non-Goals)。

**Acceptance Criteria**:

| AC ID  | Scenario                                                         |
| ------ | ---------------------------------------------------------------- |
| AC-001 | push で before..after の変更ファイルを返す                       |
| AC-008 | 一致するファイルが無ければ空の files と count "0" で正常終了する |
| AC-015 | 変更が無い差分は、空の files と count "0" で正常終了する         |

### REQ-F-006: 途中の段の失敗

- EARS Type: NOT DO (unwanted behavior)

```text
GIVEN SHA の解決、git diff、絞り込みのいずれかが非ゼロで終了した
  NOT DO 後続の段を実行する
THEN the system SHALL "::error::" を出力し、非ゼロ終了コードで終了する.
```

各段のエラーメッセージは、その段のスクリプトが出す `::error::` をそのまま使う。
次の場合が該当する。

内部 Action のスクリプトが `::error::` を出すもの:

- `commit-count` が不正である (`_ca-resolve-sha` REQ-F-002)
- 不在コミット、partial clone、push のブランチ削除・タグ等、`_ca-resolve-sha` がエラーとする条件
- 変更ファイルの一覧が引用表記の行を含む。`"`・`\`・制御文字を含むパスが該当する (`_ca-filter-files` REQ-F-017、DR-06)
- 変更ファイルの一覧が LF を伴わない CR を含む (`_ca-filter-files` REQ-F-017)
- 変更ファイルの一覧が 3000 行を超える (`_ca-filter-files` REQ-F-018、DR-07)
- `pattern` が 100 行または 120000 バイトを超える (`_ca-filter-files` REQ-F-018)
- `pattern` に不正なパターン (`!` だけの行など) がある、または LF を伴わない CR を含む (`_ca-filter-files` REQ-F-017、DR-14)
- `$GITHUB_OUTPUT` に書き出せない

本 Action のスクリプト (変更ファイルの取得の段) が `::error::` を出すもの:

- 解決済みの before-sha / after-sha が空である
- `$GITHUB_OUTPUT` が空、または書き込めない
- `git diff` が失敗する
- 変更ファイルの一覧が 120000 バイトを超える (DR-07)。
  変更ファイルの一覧は、環境変数で絞り込みの段へ渡す。環境変数の上限を超えると、絞り込みの段は起動できず `::error::` も出ない。
  このため、絞り込みの段と同じ上限を、変更ファイルの取得の段で先に検査する。

出力の扱いは `_ca-filter-files` REQ-F-015 に合わせる。

- 書き出し前の検証 (入力の検査、出力先の検証) で失敗した場合は、files / count を一切出力しない。
- 書き出し開始後の I/O 障害では、先に書いた出力 (例: files) が残り得る。
- 呼び出し元は、本 Action が非ゼロで終了した場合の出力を利用してはならない。

**Rationale**: 途中の段の失敗を無視して進むと、誤った範囲の一覧や空の一覧が成功として返り、呼び出し元が変更なしと誤認する。
出力の書き出しは `_ca-filter-files` に任せるため (DR-02)、書き出し開始後の部分出力をなくす保証は本 Action では持たない。

**Acceptance Criteria**:

| AC ID  | Scenario                                                       |
| ------ | -------------------------------------------------------------- |
| AC-005 | 不正な commit-count でエラー終了し、files / count を出力しない |
| AC-011 | ダブルクオートを含むパスがある差分はエラー終了する             |
| AC-012 | 上限を超える差分はエラー終了する                               |
| AC-018 | 不正な pattern でエラー終了し、files / count を出力しない      |

### REQ-F-007: 内部 Action の実行方法

- EARS Type: NOT DO (unwanted behavior)

```text
GIVEN ca-get-changed-files が外部リポジトリのワークフローから参照されている
  NOT DO uses: ./.github/actions/_ca-* で内部 Action を参照する
THEN the system SHALL 本 Action と同じ ref で取得された次の 2 つのスクリプトを run step で実行する:
     ${GITHUB_ACTION_PATH}/../_ca-resolve-sha/scripts/resolve-sha.sh
     ${GITHUB_ACTION_PATH}/../_ca-filter-files/scripts/filter-files.sh
     .
```

内部 Action の `action.yml` が step の `env` で行っている入力・イベント値と環境変数の対応付けは、本 Action の `action.yml` で同じ名前で行う。

**Rationale**: `uses: ./...` は呼び出し元リポジトリの checkout を基準に解決されるため、ci-platform 以外のリポジトリでは失敗する。
SHA による自己参照は、リリースごとに pin を更新する必要があり、PR 中は古い版でテストされる (DR-05)。

**Acceptance Criteria**:

| AC ID  | Scenario                                                 |
| ------ | -------------------------------------------------------- |
| AC-014 | 内部 Action を checkout していないリポジトリでも動作する |

### REQ-F-008: 自前のロジックを持たない

- EARS Type: NOT DO (unwanted behavior)

```text
GIVEN SHA の解決、glob の照合、出力の書き出しを内部 Action が提供している
  NOT DO 同じ処理を本 Action のスクリプトやライブラリに実装する
THEN the system SHALL resolve_sha_for_event、resolve_before_sha、ローカルの write_multiline_output を定義する
     scripts/_libs/filter.lib.sh を、そのテスト scripts/_libs/__tests__/unit/filter.unit.spec.sh とともにファイルごと削除する.
```

3 つの関数を削除すると `filter.lib.sh` に残る関数は無いため、空のライブラリとして残さない (DR-09)。

**Rationale**: 同じ処理を 2 か所に置くと、規則が食い違ったときにどちらが正しいか判断できない (DR-01, DR-02)。
ローカルの `write_multiline_output` は、共有ライブラリの同名関数と引数が異なり、同じプロセスで読み込むと定義が衝突する (`_ca-filter-files` DR-07)。

**Acceptance Criteria**:

| AC ID  | Scenario                             |
| ------ | ------------------------------------ |
| AC-016 | 旧ライブラリとその関数が残っていない |

## 5. Non-Functional Requirements

### REQ-NF-001: Testability

すべての REQ-F は、ShellSpec (unit / functional) または `_tests_ca_composite-actions.yml` のテストジョブで 1 件以上検証しなければならない (MUST)。
`bash ./runners/run-shellspec.sh all` が `not ok` 0 件で完了しなければならない (MUST)。

`git diff` の取得は、実 git リポジトリ fixture で検証しなければならない (MUST)。非 ASCII 文字を含むパスを fixture に含めなければならない (MUST)。

### REQ-NF-002: 出力の互換性

出力 `files` / `count` の名前と書式 (改行区切りのパス一覧、10 進整数の件数) は、改訂前と同じでなければならない (MUST)。
`pattern` が空で、差分が上限以下の場合を考える。
このとき `files` は `git diff --name-only --diff-filter=ACMR <before-sha> <after-sha>` の結果と一致し、
`count` はその行数と一致しなければならない (MUST)。
改訂前の Action は同じコマンドで一覧を取得していたため、この一致をもって改訂前との互換とみなす。
ただし、次の差は互換性の例外とする。

- 非 ASCII 文字を含むパス: 改訂前は引用表記で返し、改訂後はそのまま返す (DR-06)
- `"`・`\`・制御文字を含むパス: 改訂前は引用表記で返し、改訂後はエラー終了する (REQ-F-006)
- 範囲そのものの違い: push の `before` が全ゼロの場合など、SHA の解決規則の変更による (REQ-C-008)

## 6. Constraints

### REQ-C-001: スクリプトインジェクション防止

入力とイベント値は env 経由でのみスクリプトに渡さなければならない (MUST)。
`run` 内に `${{ }}` を記述してはならない (MUST NOT)。`${{ github.action_path }}` も含め、パスは `${GITHUB_ACTION_PATH}` で参照する。

### REQ-C-002: 最小権限

Composite Action は `permissions` を宣言できない。
本 Action は、`contents: read` 以外の権限を必要としてはならない (MUST NOT)。`permissions` を `contents: read` とする責務は呼び出し元の workflow / job が負う。

### REQ-C-003: checkout 前提

呼び出し元は、`actions/checkout` を `fetch-depth: 0` で実行しなければならない (MUST)。この前提を `action.yml` の description に明記する (MUST, AC-017)。
`fetch-depth: 0` は、`_ca-resolve-sha` REQ-C-003 の取得の深さの前提 (push / その他イベントは N+1 以上、pull_request は base と head を含む) を満たす。
深さを満たしても、両端のコミットが存在することは保証しない。
force push で push の `before` が到達不能な場合は、`_ca-resolve-sha` REQ-F-006 に従い HEAD~N へフォールバックする。
pull_request の base / head が存在しない場合は、`_ca-resolve-sha` REQ-F-013 に従いエラーとなる。

呼び出し元は、対象リポジトリを作業ディレクトリ (`$GITHUB_WORKSPACE`) に checkout しなければならない (MUST, DR-10)。
`actions/checkout` の `path` で別の場所に取得してはならない (MUST NOT)。この前提も `action.yml` の description に明記する (AC-017)。
本 Action には、対象リポジトリの場所を受け取る入力が無い。

あわせて、`_ca-resolve-sha` REQ-C-003 の次の前提を呼び出し元に課す (MUST)。

- partial clone (`filter` を指定した checkout) を使わない
- push で使う場合は、ブランチ削除とタグの push を `branches:` での絞り込み、または `if: ${{ !github.event.deleted }}` 等で除外する

### REQ-C-004: 静的解析

`actionlint` および `ghalint` を通過しなければならない (MUST)。

### REQ-C-005: インターフェース

- 配置先: `.github/actions/ca-get-changed-files/` (公開 Action、`_` プレフィックスなし)
- 入力 (kebab-case、明示デフォルト):
  - `commit-count` (required: false, default "1")
  - `pattern` (required: false, default ""): glob パターン、1 行 1 個、`!` で除外
- 出力:
  - `files`: 変更ファイルのパス、1 行 1 件
  - `count`: 変更ファイル数
- スクリプト: `.github/actions/ca-get-changed-files/scripts/get-changed-files.sh` (環境変数 `BEFORE_SHA` / `AFTER_SHA` を読む)
- 削除する入力: `before-sha`, `after-sha`

上記を満たさなければならない (MUST)。

### REQ-C-006: 内部 Action と _libs/ を変更しない

`.github/actions/_ca-resolve-sha/`、`.github/actions/_ca-filter-files/`、`.github/actions/_libs/` を変更してはならない (MUST NOT)。
内部 Action の契約に不足がある場合は、本モジュールでは対処せず、各モジュールの要件の改訂として扱う。

### REQ-C-007: CI テストジョブ

`.github/workflows/_tests_ca_composite-actions.yml` の `test-get-changed-files` ジョブを、新しい入力で動くように改訂しなければならない (MUST)。
`before-sha` / `after-sha` を渡すステップと、git pathspec を前提とした `*.txt` パターンのステップを書き換える (`_ca-filter-files` DR-06)。
同ファイルは保護領域であるため、PR に変更理由を明記しなければならない (MUST)。

### REQ-C-008: 破壊的変更の記載

`CHANGELOG.md` に次の破壊的変更と移行方法を記載しなければならない (MUST)。
記載は、本改訂を含む次のマイナーリリースの release PR で行う。本改訂の PR では、PR 本文に同じ内容を記載する。

- 入力 `before-sha` / `after-sha` の削除。呼び出し元は両入力を削除し、必要なら `commit-count` を指定する。
  任意の SHA の組を指定する利用 (例: リリースタグ間の比較) には代替手段がない。その場合は `git diff` を直接使う。
- `pattern` の git pathspec から glob への変更。pathspec 固有の書き方 (例: パスの途中に一致する `*.txt`) は glob に書き換える。
- push のブランチ削除・タグの push と、push / pull_request 以外のイベントでの挙動の変更 (`_ca-resolve-sha` の規則による)。
- push の `before` が全ゼロ (新規ブランチ) の場合の範囲の変更。改訂前は空ツリーとの比較 (全ファイル) とし、改訂後は HEAD~N との比較とする。
  既存ブランチから新規ブランチを作って push すると、改訂前は全ファイルを返し、改訂後は直近 N コミットの変更だけを返す。
- 非 ASCII 文字を含むパスの返し方の変更。改訂後は引用表記を使わずそのまま返す。`"`・`\`・制御文字を含むパスがある差分は、エラー終了する。

互換性の方針は次のとおりとする。

- ci-platform は 0.x 系であり、マイナーバージョンで互換性のない変更を含めてよい。本改訂は次のマイナーリリース (0.5.0) に含める。
- 外部の利用者は、本 Action を SHA またはタグで固定して参照する。固定した参照を更新するときに、本節の移行方法に従う。
- 旧インターフェースを別名や別バージョンとして並行して提供しない (DR-03)。

### REQ-C-009: テストファイルの変更

本モジュールの改訂では、`.github/actions/ca-get-changed-files/` 配下の `__tests__/**/*.spec.sh` を変更・削除してよい (Issue #134 による明示的な指示)。
本モジュールの所有範囲 (`workspaces/module/module.md` の `owns`) 外のテストファイルを変更してはならない (MUST NOT)。

## 7. User Stories

| Story ID | Role                         | Goal                                                                  | Reason                                               | Related Requirements            |
| -------- | ---------------------------- | --------------------------------------------------------------------- | ---------------------------------------------------- | ------------------------------- |
| US-001   | ワークフローの作成者         | SHA を渡さずに、どのイベントでも変更ファイルを取得したい              | イベントごとに SHA を組み立てる記述をなくすため      | REQ-F-001, REQ-F-002, REQ-F-003 |
| US-002   | ワークフローの作成者         | 複数の glob と除外で、検査対象のファイルだけを取得したい              | 1 つの pathspec では対象を表しきれないため           | REQ-F-004, REQ-F-005            |
| US-003   | 外部ツールリポジトリの管理者 | ci-platform を checkout せずに、`uses:` の 1 行で本 Action を使いたい | 内部 Action の配置を意識せずに再利用するため         | REQ-F-007                       |
| US-004   | リポジトリメンテナー         | 取得できない差分を成功扱いにせず、エラーとして検出したい              | 空の一覧を「変更なし」と誤認して検査を飛ばさないため | REQ-F-006                       |
| US-005   | リポジトリメンテナー         | SHA 解決と絞り込みの規則を 1 か所だけで保守したい                     | 規則の食い違いをなくすため                           | REQ-F-008                       |

## 8. Acceptance Criteria

```gherkin
# AC-001: push で before..after の変更ファイルを返す
# Requirement: REQ-F-002, REQ-F-003, REQ-F-005
Scenario: push で before..after の変更ファイルを返す
  Given イベントが push で、github.event.before がコミットとして存在する
  And   before から github.sha までに "a.sh" が変更され、"b.md" が追加されている
  And   pattern が空である
  When  ca-get-changed-files を実行する
  Then  files 出力は "a.sh" と "b.md" の 2 行である
  And   count 出力は "2" である

# AC-002: pull_request で base..head の変更ファイルを返す
# Requirement: REQ-F-002
Scenario: pull_request で base..head の変更ファイルを返す
  Given イベントが pull_request で、base と head がコミットとして存在する
  When  ca-get-changed-files を実行する
  Then  files 出力は git diff --name-only --diff-filter=ACMR <base> <head> の結果と一致する

# AC-003: その他イベントで HEAD~N..HEAD の変更ファイルを返す
# Requirement: REQ-F-001, REQ-F-002
Scenario: その他イベントで HEAD~N..HEAD の変更ファイルを返す
  Given イベントが workflow_dispatch で、commit-count が "2" である
  And   直近 2 コミットで "a.sh" と "c.sh" が変更されている
  When  ca-get-changed-files を実行する
  Then  files 出力は "a.sh" と "c.sh" を含む
  And   files 出力は HEAD~2 より前にだけ変更されたファイルを含まない

# AC-004: commit-count 未指定のその他イベントで HEAD~1..HEAD の変更を返す
# Requirement: REQ-F-001
Scenario: commit-count 未指定のその他イベントで HEAD~1..HEAD の変更を返す
  Given イベントが workflow_dispatch で、commit-count が未指定である
  When  ca-get-changed-files を実行する
  Then  files 出力は git diff --name-only --diff-filter=ACMR HEAD~1 HEAD の結果と一致する

# AC-005: 不正な commit-count でエラー終了し、files / count を出力しない
# Requirement: REQ-F-001, REQ-F-006
Scenario Outline: 不正な commit-count でエラー終了し、files / count を出力しない
  Given commit-count が "<value>" である
  When  ca-get-changed-files を実行する
  Then  "::error::" が出力される
  And   終了コードは非ゼロである
  And   files / count は出力されない

  Examples:
    | value |
    | 0     |
    | -1    |
    | abc   |

# AC-006: 複数行の pattern と除外で変更ファイルを絞り込む
# Requirement: REQ-F-004
Scenario: 複数行の pattern と除外で変更ファイルを絞り込む
  Given 変更ファイルが "src/a.sh", "src/gen/b.sh", "README.md" である
  And   pattern が "src/**" と "!src/gen/**" の 2 行である
  When  ca-get-changed-files を実行する
  Then  files 出力は "src/a.sh" のみである
  And   count 出力は "1" である

# AC-007: pattern が空なら変更ファイルをすべて返す
# Requirement: REQ-F-004
Scenario: pattern が空なら変更ファイルをすべて返す
  Given 変更ファイルが "a.sh", "dir/b.md" である
  And   pattern が空文字列である
  When  ca-get-changed-files を実行する
  Then  files 出力は "a.sh", "dir/b.md" の 2 行である
  And   count 出力は "2" である

# AC-008: 一致するファイルが無ければ空の files と count "0" で正常終了する
# Requirement: REQ-F-004, REQ-F-005
Scenario: 一致するファイルが無ければ空の files と count "0" で正常終了する
  Given 変更ファイルが "a.sh" である
  And   pattern が "*.yml" である
  When  ca-get-changed-files を実行する
  Then  files 出力は空文字列である
  And   count 出力は "0" である
  And   終了コードは 0 である

# AC-009: 削除されたファイルは files に含めない
# Requirement: REQ-F-003
Scenario: 削除されたファイルは files に含めない
  Given 差分範囲で "old.sh" が削除され、"new.sh" が追加されている
  When  ca-get-changed-files を実行する
  Then  files 出力は "new.sh" を含む
  And   files 出力は "old.sh" を含まない

# AC-010: 非 ASCII 文字を含むパスを引用表記にせずに返す
# Requirement: REQ-F-003
Scenario: 非 ASCII 文字を含むパスを引用表記にせずに返す
  Given 差分範囲で "docs/日本語.md" が追加されている
  When  ca-get-changed-files を実行する
  Then  files 出力は "docs/日本語.md" をそのまま含む
  And   終了コードは 0 である

# AC-011: ダブルクオートを含むパスがある差分はエラー終了する
# Requirement: REQ-F-006
Scenario: ダブルクオートを含むパスがある差分はエラー終了する
  Given 差分範囲で 'a"b.sh' が追加されている
  When  ca-get-changed-files を実行する
  Then  "::error::" が出力される
  And   終了コードは非ゼロである
  And   files / count は出力されない

# AC-012: 上限を超える差分はエラー終了する
# Requirement: REQ-F-006
Scenario Outline: 上限を超える差分はエラー終了する
  Given 差分範囲で <added> が追加されている
  When  ca-get-changed-files を実行する
  Then  "::error::" が出力される
  And   終了コードは非ゼロである
  And   files / count は出力されない

  Examples:
    | added                                          |
    | 3001 個のファイル (合計 120000 バイト以下)     |
    | 変更ファイルの一覧が合計 120001 バイトになるファイル |

# AC-013: 履歴が足りない場合は HEAD の全ファイルを追加として返す
# Requirement: REQ-F-002, REQ-F-003
Scenario: 履歴が足りない場合は HEAD の全ファイルを追加として返す
  Given イベントが workflow_dispatch で、リポジトリの履歴が 1 コミットだけである
  And   そのコミットが "a.sh" と "b.sh" を持つ
  When  ca-get-changed-files を実行する
  Then  files 出力は "a.sh" と "b.sh" の 2 行である
  And   終了コードは 0 である

# AC-014: 内部 Action を checkout していないリポジトリでも動作する
# Requirement: REQ-F-007
Scenario: 内部 Action を checkout していないリポジトリでも動作する
  Given 作業ディレクトリのリポジトリに .github/actions/_ca-resolve-sha と _ca-filter-files が存在しない
  And   ca-get-changed-files が別の場所 (GITHUB_ACTION_PATH) に内部 Action とともに置かれている
  When  ca-get-changed-files を実行する
  Then  内部 Action のスクリプトは GITHUB_ACTION_PATH を基準に実行される
  And   終了コードは 0 である

# AC-015: 変更が無い差分は、空の files と count "0" で正常終了する
# Requirement: REQ-F-003, REQ-F-005
Scenario Outline: 変更が無い差分は、空の files と count "0" で正常終了する
  Given 差分範囲が <range> である
  When  ca-get-changed-files を実行する
  Then  files 出力は空文字列である
  And   count 出力は "0" である
  And   終了コードは 0 である

  Examples:
    | range                        |
    | before と after が同じツリー |
    | ファイルの削除だけを含む     |

# AC-016: 旧ライブラリとその関数が残っていない
# Requirement: REQ-F-008
Scenario: 旧ライブラリとその関数が残っていない
  Given 改訂後の .github/actions/ca-get-changed-files/ である
  When  配下のスクリプトとライブラリを検査する
  Then  resolve_sha_for_event、resolve_before_sha の定義は無い
  And   ローカルの write_multiline_output の定義は無い

# AC-017: action.yml の description に checkout の前提が書かれている
# Requirement: REQ-C-003
Scenario: action.yml の description に checkout の前提が書かれている
  Given 改訂後の action.yml である
  When  description を検査する
  Then  fetch-depth: 0 の必要が書かれている
  And   partial clone を使えないことが書かれている
  And   push のブランチ削除・タグの push を除外することが書かれている
  And   対象リポジトリを作業ディレクトリに checkout し、path を使わないことが書かれている

# AC-018: 不正な pattern でエラー終了し、files / count を出力しない
# Requirement: REQ-F-006
Scenario Outline: 不正な pattern でエラー終了し、files / count を出力しない
  Given pattern が <value> である
  When  ca-get-changed-files を実行する
  Then  "::error::" が出力される
  And   終了コードは非ゼロである
  And   files / count は出力されない

  Examples:
    | value                 |
    | "!" だけの 1 行       |
    | 101 行のパターン      |
```

## 9. Open Questions

Owner が spec / impl の項目は、spec で解決した。各行の括弧内に解決先を示す。

| Question                                                                                           | Type        | Impact Area             | Owner |
| -------------------------------------------------------------------------------------------------- | ----------- | ----------------------- | ----- |
| AC-014 の検証方法 (Resolved in spec: 配置をコピーした functional テスト RUNF。index 7)             | Spec detail | REQ-F-007               | spec  |
| step の構成と段の間でのファイル一覧の受け渡し方法 (Resolved in spec: 3 step、step 出力。DD-ACT-01) | Spec detail | REQ-F-002〜F-005, F-007 | spec  |
| 内部 Action の `action.yml` との env の対応付けの検査 (Resolved in spec: R-ACT-040, R-ACT-041)     | Spec detail | REQ-F-007               | spec  |
| `test-get-changed-files` ジョブの改訂方法 (Resolved in spec: R-IDX-001〜R-IDX-006)                 | Spec detail | REQ-C-007               | spec  |
| 既存テストの ID の扱い (Resolved in spec: 削除して `T-GCF-*` で書き直す。DD-IDX-03)                | Spec detail | REQ-NF-001              | spec  |
| `filter.lib.sh` をファイルごと削除するか (Resolved: 削除する。spec R-DIF-030、DR-09)               | Impl detail | REQ-F-008               | impl  |

## 10. Traceability

| REQ ID     | AC IDs                                 | Type           |
| ---------- | -------------------------------------- | -------------- |
| REQ-F-001  | AC-003, AC-004, AC-005                 | Functional     |
| REQ-F-002  | AC-001, AC-002, AC-003, AC-013         | Functional     |
| REQ-F-003  | AC-001, AC-009, AC-010, AC-013, AC-015 | Functional     |
| REQ-F-004  | AC-006, AC-007, AC-008                 | Functional     |
| REQ-F-005  | AC-001, AC-008, AC-015                 | Functional     |
| REQ-F-006  | AC-005, AC-011, AC-012, AC-018         | Functional     |
| REQ-F-007  | AC-014                                 | Functional     |
| REQ-F-008  | AC-016                                 | Functional     |
| REQ-NF-001 | N/A                                    | Non-Functional |
| REQ-NF-002 | AC-001, AC-007                         | Non-Functional |
| REQ-C-001  | N/A                                    | Constraint     |
| REQ-C-002  | N/A                                    | Constraint     |
| REQ-C-003  | AC-017                                 | Constraint     |
| REQ-C-004  | N/A                                    | Constraint     |
| REQ-C-005  | N/A                                    | Constraint     |
| REQ-C-006  | N/A                                    | Constraint     |
| REQ-C-007  | N/A                                    | Constraint     |
| REQ-C-008  | N/A                                    | Constraint     |
| REQ-C-009  | N/A                                    | Constraint     |

## 11. Change History

| Date       | Version | Description                                                                                                                                                                                                                                                                          |
| ---------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 2026-06-22 | 1.0.0   | Initial release (unversioned, push only, git pathspec pattern)                                                                                                                                                                                                                       |
| 2026-10-29 | 2.0.0   | Rewrite for Issue #134: use `_ca-resolve-sha` and `_ca-filter-files`, replace SHA inputs with commit-count, approve                                                                                                                                                                  |
| 2026-10-29 | 2.0.1   | Apply req second opinion: align failure output with filter-files (F-006), list compatibility exceptions (NF-002), clarify checkout guarantee (C-003), add migration notes (C-008), PR range assumption, AC-014 open question                                                         |
| 2026-10-29 | 2.0.2   | Clarify REQ-C-008: write the CHANGELOG entry in the next minor release PR, and the same text in the #134 PR body                                                                                                                                                                     |
| 2026-10-29 | 2.0.3   | Apply req explore review: list this action's own errors (F-006), explicit empty override env (F-002), compatibility checked against git diff (NF-002), add assumptions (cwd, UTF-8, pattern size, renames, submodules, terms), add AC-015..AC-017, mark spec-resolved open questions |
| 2026-10-29 | 2.1.0   | Apply req harden review: delete filter.lib.sh and its test (F-008, DR-09), checkout to the workspace is a caller obligation (C-003, AC-017, DR-10), define empty pattern (F-004), cite DR-11 in assumptions                                                                          |
| 2026-10-29 | 2.1.1   | Apply req second opinion: split push rows in F-002 (normal / fallback, HEAD-based), add pattern errors to F-006, compatibility policy for external users (C-008), assumptions (cwd guarantee, first-parent tree diff, fallback range, internal script contract)                      |
| 2026-10-29 | 2.1.2   | Apply req fix review: unify terms (変更ファイルの一覧, 絞り込みの段, 改訂前, 解決済み), AC-012 covers both limits, add AC-018 (invalid pattern), move AC-015 to F-003/F-005, reorder C-008, cite filter-files REQ-F-017/DR-14, scope cites DR-09                                     |
| 2026-10-30 | 2.2.0   | Unify document versions to 2.2.0 and approve                                                                                                                                                                                                                                         |
