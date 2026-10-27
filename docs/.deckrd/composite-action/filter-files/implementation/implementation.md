---
title: "Implementation Plan: _ca-filter-files"
based-on: specifications-index.md v1.3.1
status: Draft
version: 1.1.2
created: "2026-10-27"
---

## 1. Overview

### 1.1 Purpose

内部 Composite Action `.github/actions/_ca-filter-files/` を新設する (Issue #136、親 #134)。
この Action は、改行区切りのファイルリストを glob パターン (`**` / `*` / `?`、`!` で除外) で絞り込む。
入力は `files` (必須) と `patterns` (任意、既定値は空文字列) とする。
出力は `files` (保持行、入力順)、`count` (10 進整数文字列) の 2 つとする。
純粋なフィルタであり、git とファイルシステムを参照しない (REQ-F-012)。
評価順序は specifications-index.md §3.4 に従う。入力の検査・正規化 → パターンの分類 → 照合 → 出力先の検証 → files、count の書き出しの順とし、入力の検証をすべて終えてから出力先を検証する (DD-IDX-02)。

本計画の範囲は、Composite Action の作成と CI ジョブの追加までとする。`ca-get-changed-files` への組み込みは #134 の別タスクとする。

- 既存のワークフローとアクションは、`_tests_ca_composite-actions.yml` (REQ-C-008) を除いて変更しない。
- 共有ライブラリ `.github/actions/_libs/` への変更は、REQ-C-007 の追加 (`validate_output_file`、`write_multiline_output`) に限る。
- `ca-get-changed-files/scripts/_libs/filter.lib.sh` の旧 `write_multiline_output` の置き換えはスコープ外とする (DR-06、DR-07)。
- 完了条件は、次のすべてを満たすこととする。
  - actionlint / ghalint を通過する
  - ShellSpec の全テストに `not ok` が無い
  - `pnpm lint:sh` (shellcheck) と `pnpm check:sh` (shfmt) を通過する
  - テスト ID の機械検査 A〜D を通過する

PR は 2 つに分ける。

- PR-A: Phase 0〜1 (module.md の略語表と共有ライブラリ)
- PR-B: Phase 2〜6 (`_ca-filter-files` 本体と CI)。PR-A のマージ後に main から作る。

本 impl / tasks 文書は、現ブランチ (`docs-136/filter-files/add-spec-docs`) で作成する。

**実装品質基準 (全コミット共通):**

- 各コミットの中で BDD の RGR サイクルを回す。テストが FAIL することを確認してから実装し、PASS を確認してからコミットする。
- テストとその実装は同じコミットに含める。
- テスト ID は `T-FF-<略語>-NN` とする (functional は `T-FF-MAINF-NN`)。ケース名には `[Normal]` / `[Error]` / `[Edge]` を付ける。
- ShellSpec の `It` にはテスト ID をリテラルで書き、`Parameters` は使わない (テスト ID 検査 B / D が ID を読めるようにするため)。
- テストの実行は `runners/run-shellspec.sh` 経由で行う。
- 各コミットで `pnpm lint:sh` と `pnpm check:sh` を通す。
- テストを追加したコミットでは、テスト ID の機械検査 B / D を実行する。検査 A / C は、PR-A の最後 (Phase 1 の後) と PR-B の最後 (Phase 6 の後) に実行する。
- 内部シンボルは先頭アンダースコアで区別する。
- 環境変数を読むのは MAIN だけとし、`${VAR:-}` の形で読む (REQ-C-006)。

### 1.2 Reference

- Prior Art / Reference PR: PoC なし。
  - 構成は `_ca-resolve-sha` (action.yml → `scripts/resolve-sha.sh` → `scripts/_libs/resolve-sha.lib.sh`) に倣う。
  - resolve-sha は共有ライブラリを別 PR (#141) に分け、CI ジョブを後から (#144) 足した。
  - 本計画は、共有ライブラリを別 PR に分け、CI ジョブを最初から含める (REQ-C-008)。
- Specifications:
  - specifications-index.md v1.3.1
  - specifications-input.md v1.3.0
  - specifications-matching.md v1.0.4
  - specifications-output.md v1.0.3
- Requirements: requirements.md v1.3.0
- Decision Records: decision-records.md v1.3.2
  - DR-02、DR-04、DR-05、DR-06、DR-07、DR-08、DR-09
  - DR-12、DR-13、DR-14、DR-15、DR-16、DR-17、DR-18

### 1.3 Design Decisions

**実装単位と配置:**

| 単位                       | 略語 | 配置                                                 |
| -------------------------- | ---- | ---------------------------------------------------- |
| 出力先の検証               | VOF  | `.github/actions/_libs/output.lib.sh`                |
| 複数行値の出力             | WMO  | `.github/actions/_libs/output.lib.sh`                |
| ライブラリ骨格とエラー出力 | FE   | `_ca-filter-files/scripts/_libs/filter-files.lib.sh` |
| サイズの上限の検査         | CBL  | 同上                                                 |
| 行末 (CR) の検査           | CLE  | 同上                                                 |
| 行の分割と正規化           | PL   | 同上                                                 |
| 件数の上限の検査           | CLL  | 同上                                                 |
| パターンの分類             | CP   | 同上                                                 |
| glob から ERE への変換     | GTR  | 同上                                                 |
| フィルタ                   | FF   | 同上                                                 |
| 出力の書き出し             | EO   | 同上                                                 |
| 入口                       | MAIN | `_ca-filter-files/scripts/filter-files.sh`           |
| Action 定義                | ACT  | `_ca-filter-files/action.yml`                        |

関数名は次のとおりとする。

- VOF = `validate_output_file`、WMO = `write_multiline_output`、FE = `ff_error`
- CBL = `check_byte_limit`、CLE = `check_line_endings`、PL = `parse_lines`、CLL = `check_line_limit`、CP = `classify_patterns`
- GTR = `glob_to_regex`、FF = `filter_files`、EO = `emit_outputs`

関数のシグネチャは specifications-index.md §3.5 に従う (CBL・CLE・CLL を含む)。

**確定した判断:**

- 照合方式 (DR-17): DR-02 のとおり glob を ERE に変換し、`[[ =~ ]]` で照合する。
  `LC_ALL=C.UTF-8` は関数内で `local` に設定する。
  セグメント単位の照合は採用しない (specifications-index.md §7 #1)。
- 走査方式 (DR-17): ファイルごとの Bash ループで照合する。入力順と重複が自然に保たれる。`grep -E` の一括照合は採用しない (§7 #2)。
- 関数間の受け渡し形式と読み込み方法 (DR-18):
  - 複数行のデータは、LF 区切りの 1 つの文字列 (末尾に LF を付けない) として引数で渡し、結果も同じ形式で stdout に出す。
    0 件は空文字列で表す。グローバル配列を使わないため、テストに `BeforeEach` / `AfterEach` を要さない。
  - 呼び出し側は、コマンド置換で受け取り、終了コードを `|| return 1` で伝える (`_out=$(fn ...) || return 1`)。
    パイプラインとプロセス置換では、データを受け渡さない (出力した側の失敗を見落とすため)。
  - 配列への読み込みは `mapfile -t` (ヒアストリング) で行う。空文字列は空の配列として扱い、`mapfile` を呼ばない。
    `read` のループや、行ごとに外部コマンドを起動する方式は使わない。
  - コマンド置換の結果を受ける変数は `local` で先に宣言し、代入は別の行で行う (`local _x=$(fn)` は `fn` の終了コードを失うため。impl explore review A-04)。
  - データを stdout に出すのはコマンド置換の中だけとし、ログへ直接 echo しない (ファイル名によるワークフローコマンドの偽装を防ぐ)。
  - CP は 1 パターン 1 行の `I<TAB>pattern` / `E<TAB>pattern` を出す。
    種別は最初のタブより前 (`${_line%%$'\t'*}`)、パターンは最初のタブより後 (`${_line#*$'\t'}`) とし、パターン内のタブやバックスラッシュを変えない。
  - CP の出力は MAIN が 1 行ずつ種別とパターンに分け、包含と除外の 2 つの LF 区切り文字列にして FF に渡す。FF のシグネチャ (§3.5) は変えない (impl harden review GF-01)。
  - FF は、各パターンの ERE を照合ループの前に 1 回だけ生成して配列に持ち、ループ内では Bash の組み込み機能 (`[[ =~ ]]`) だけを使う。
- glob の変換順 (impl second opinion): GTR は 1 つの glob を先頭から書かれた順に読み、各位置で次の順に判定する (R-MAT-002〜R-MAT-008)。
  境界の期待値は specifications-matching.md §5 のエッジケース表を網羅する。
  1. パターン全体が `**`
  2. 先頭、または `/` の直後にある `**/`
  3. 末尾にある `/**`
  4. その他の `**`
  5. `*`、`?`
  6. その他の文字 (ERE のメタ文字はエスケープする)
- 除外の確定 (DR-05、R-MAT-011): 除外パターンに一致したファイルは、パターンの記述順によらずリストから除く。後のパターンでファイルを戻すことはできない。
- 件数の上限 (DR-16、REQ-F-018): `filter-files.lib.sh` に readonly 定数 `FF_MAX_FILES=3000`・`FF_MAX_PATTERNS=1000` を置く。
  CLL は空行を捨てた後の行数で判定し、上限ちょうどは受け付ける。
  エラーは `::error::files: exceeds the limit of 3000 lines (got: '3001')` の形式とする (DR-15)。
- サイズの上限 (DR-16、REQ-F-018): readonly 定数 `FF_MAX_FILES_BYTES=120000`・`FF_MAX_PATTERNS_BYTES=120000` を置く。
  CBL は変換・分割の前の値を、関数内で `local LC_ALL=C` にしてから `${#var}` で数える (外部コマンドを使わない)。
- CLE の新設: R-IN-011 (LF を伴わない CR を分割前に検査する) を担う関数として追加する。
  分割前の CR 検査は specifications-index.md §3.4 Step 1 と specifications-input.md の R-IN-011 に従う。
- 検査順 (DR-14): 次の順に検査し、最初の 1 件でエラー終了する。
  1. バイト数の上限 (files → patterns)
  2. CR (files) → CR (patterns)
  3. files 行 (UTF-8 → ダブルクオート) → patterns 行 (UTF-8)
  4. 件数の上限 (files → patterns)
  5. パターンの分類 (`!` だけ → 空白で始まる除外)
  6. 出力先の検証 → 書き出し
- エラー形式 (DR-15): FE は `_ca-resolve-sha` の `rs_error` と同じ形式とする。
  - 通常: `::error::<対象>: <問題> (got: '<値>')`
  - 空値: `::error::<対象>: value must not be empty`
  - 値の `%` / CR / LF は `%25` / `%0D` / `%0A` にエンコードする
- VOF は `_ca-resolve-sha` の `_rs_check_output_file` のロジックを共有化する (DR-12、R-OUT-020〜R-OUT-022)。
  終了コードは、書き込めれば 0、出力先が空なら 1、書き込めなければ 2 とし、ファイルは作らない。
- VOF と WMO は stdout / stderr に何も出さない (DR-13)。エラーは呼び出し側の EO が FE で出す。
- WMO の区切り文字は、`EOF`、`EOF_1`、`EOF_2` … のうち、値のどの行とも衝突しない最初の候補とする (R-OUT-010〜R-OUT-014)。引数不正は 1、書き込み失敗は 2 を返す。
- 共有関数のテストは、`_libs/__tests__/unit/` に新規ファイルとして置く (`write-output.unit.spec.sh` が手本)。
  ファイル名は `validate-output-file.unit.spec.sh`・`write-multiline-output.unit.spec.sh` の 2 つとする。
- UTF-8 の検査方式 (`iconv` か、`C.UTF-8` での `grep -ax '.*'` か) は、PL のタスクで決める。選ぶ方式は次をすべて満たす (impl harden review W-01)。
  - 行ごとに外部コマンドを起動しない
  - 最初の不正な行を特定し、FE に値として渡せる (R-IN-010)
  - ロケールは `C.UTF-8` だけを前提にする (specifications-index.md §2.2)
- `module.md` は `workspaces/module/module.md` に置いたまま、略語表を記入する。`test_scope` (FF) と `owns` は宣言済みである。
- 略語表にはレイヤサフィックスを除いたベース略語だけを書く。

**関数ごとの実装上の詳細:**

- CLE: `check_line_endings <target> <text>`。1 つの入力を検査し、最初に CR を見つけた 1 行だけを報告する。MAIN が files、patterns の順に呼ぶ。CRLF は検査の対象外とする (R-IN-013 が分割前に LF へ正規化するのは、LF を伴わない CR の検査を通過した後である)。
- PL: files の行は変更せず、長さ 0 の行だけを捨てる。patterns の行は両端のスペースとタブを除去してから、空行を捨てる (DR-08)。
- CBL: `check_byte_limit <target> <text> <max>`。バイト数が max を超えれば FE でエラーを出して 1 を返す。
- CLL: `check_line_limit <target> <lines> <max>`。行数が max を超えれば FE でエラーを出して 1 を返す。
- CP: `!` で始まる行を除外、それ以外を包含に分類する。`!` だけの行と、空白で始まる除外はエラーとする。パターンが 0 件の場合の扱い (全件) は FF が担う (R-IN-007)。
- GTR: `**` / `**/` / `/**` / `*` / `?` を変換し、ERE のメタ文字をエスケープして、全体一致のアンカーを付ける。ブラケットはリテラルとして扱う (R-MAT-008)。
- FF: 除外を優先し、包含が 0 件なら全件を対象にする。入力順と重複を保つ。`shopt` の状態に結果が依存しない。
- EO: 出力先を検証してから、files、count の順に書く。0 件の files は空で書く。書き込みの失敗はエラーとし、files が残り得る (DR-09、R-OUT-006)。

---

## 2. Implementation Plan

### Phase 0: Module Declaration (PR-A)

#### Commit 1: docs(filter-files/module): add test target abbreviations

- `module.md` の「テスト対象の略語」表に、VOF、WMO、FE、CBL、CLE、PL、CLL、CP、GTR、FF、EO、MAIN、ACT の 13 件を記載する

### Phase 1: Shared Output Library (PR-A)

Phase 1 の開始前、全テストを 1 回実行して結果をベースラインとして記録する (impl explore review G-02)。
ベースラインで既に FAIL しているテストは、本計画の変更と切り分けて報告する。
ベースラインで PASS していた既存のテストが 1 件でも FAIL した場合は、Phase 1 を中断し、次のコミットへ進まずに報告する (REQ-C-007)。
対象は、既存の `_libs` のテストと、既存の利用元 (`ca-setup-repo`、`ca-setup-tool`、`ca-validate-environment`、`_ca-resolve-sha`。REQ-C-007) のテストとする。

#### Commit 1: feat(libs): add validate_output_file to output.lib.sh

- VOF を追加する (R-OUT-020〜R-OUT-022)。空なら 1、書き込めなければ 2、ファイルを作らず、何も出力しない
- `_libs/__tests__/unit/validate-output-file.unit.spec.sh` (T-FF-VOF-*)

#### Commit 2: feat(libs): add write_multiline_output to output.lib.sh

- WMO を追加する (R-OUT-010〜R-OUT-014)。キー形式、CR の拒否、区切り文字の候補 (`EOF` / `EOF_n`)、空値、末尾 LF を扱う
- `_libs/__tests__/unit/write-multiline-output.unit.spec.sh` (T-FF-WMO-*)
- 既存の `_libs` と利用元のテストを全件実行し、ベースラインで PASS していたテストがすべて PASS することを確認する
- PR-A のマージ前に、テスト ID の機械検査 A / C を実行する (impl explore review A-05)

### Phase 2: Module Library Foundation (PR-B)

#### Commit 1: feat(filter-files): add library skeleton and ff_error

- `filter-files.lib.sh` の骨格を作る (ロードガード、`output.lib.sh` の読み込み、`declare -F` による関数の存在確認)
- FE を追加する。specifications-index.md §3.3 の形式、空値の形式、`%` / CR / LF のエンコードに対応する
- T-FF-FE-* (ロードガードのテストを含む)

### Phase 3: Input Processing (PR-B)

#### Commit 1: feat(filter-files): add check_line_endings

- CLE を追加する (R-IN-011)。LF を伴わない CR を検出してエラーにし、最初の 1 行を報告する
- T-FF-CLE-*

#### Commit 2: feat(filter-files): add parse_lines

- PL を追加する (R-IN-013、R-IN-001、R-IN-010、R-IN-012、R-IN-002、R-IN-003)
- files は変更せず、長さ 0 の行だけを捨てる。patterns は両端を除去する
- UTF-8 とダブルクオートを検査する
- T-FF-PL-*

#### Commit 3: feat(filter-files): add input size limit checks

- CBL と定数 `FF_MAX_FILES_BYTES`・`FF_MAX_PATTERNS_BYTES` (120000) を追加する (R-IN-016、R-IN-017)
  - 日本語を含む値を、文字数ではなくバイト数で数えることをテストする
- CLL と定数 `FF_MAX_FILES` (3000)・`FF_MAX_PATTERNS` (1000) を追加する (R-IN-014、R-IN-015)
- どちらも上限ちょうどは受け付け、超えたらエラーにする
- T-FF-CBL-*、T-FF-CLL-*

#### Commit 4: feat(filter-files): add classify_patterns

- CP を追加する (R-IN-004〜R-IN-009)
- `I<TAB>` / `E<TAB>` を stdout に出力する
- `!` だけの行と、空白で始まる除外をエラーにする
- T-FF-CP-*

### Phase 4: Matching (PR-B)

#### Commit 1: feat(filter-files): add glob_to_regex

- GTR を追加する (R-MAT-001〜R-MAT-009)
- `**` / `**/` / `/**` / `*` / `?` を変換し、メタ文字をエスケープして、全体一致のアンカーを付ける
- `**/`、ドット、ブラケット、非 ASCII を網羅する (REQ-NF-001)
- T-FF-GTR-*

#### Commit 2: feat(filter-files): add filter_files

- FF を追加する (R-MAT-010〜R-MAT-013)
- 除外を優先し、包含が 0 件なら全件とし、入力順と重複を保つ
- `LC_ALL=C.UTF-8` を関数内で `local` に設定する
- `shopt` を有効にしても結果が変わらないことをテストする (REQ-NF-002)
- T-FF-FF-*

### Phase 5: Output and Entry Point (PR-B)

#### Commit 1: feat(filter-files): add emit_outputs

- EO を追加する (R-OUT-001〜R-OUT-006)
- 出力先を検証してから、files、count の順に書く
- 0 件の場合と、書き込み失敗のエラーを扱う
- T-FF-EO-*

#### Commit 2: feat(filter-files): add filter-files.sh entry script

- MAIN (`scripts/filter-files.sh`) を追加する。環境変数を読む唯一の箇所とし、specifications-index.md §3.4 の評価順で関数を呼ぶ
- CP の出力を包含と除外に分けて FF に渡す (1.3 の受け渡し形式)
- 次の書き方は `_ca-resolve-sha/scripts/resolve-sha.sh` に合わせる (REQ-C-006)
  - `set -euo pipefail`、ライブラリの読み込み、`(return 0 2>/dev/null)` の main ガード
- T-FF-MAINF-* (functional): AC-001〜AC-018 を検証する
- 上限ちょうどの入力 (files 3000 行・patterns 1000 行、バイト数の上限以内) で実行し、実行時間を測って PR に記録する (impl explore review G-01)。記録するだけとし、合否の基準にはしない (要件に性能基準が無いため。impl harden review W-02)

### Phase 6: Action Definition and CI (PR-B)

#### Commit 1: feat(filter-files): add action.yml

- `_ca-filter-files/action.yml` を作成する
  - 入力: `files` (必須)、`patterns` (既定値 `""` を明示)。各入力を env に対応付ける
  - 出力: `files`、`count`
- `run` 内に `${{ }}` を書かない (REQ-C-001)
- T-FF-ACT-*: action.yml を grep で静的に検査する
- actionlint / ghalint を通過する (REQ-C-004)

#### Commit 2: ci(workflows): add test-filter-files job

- `.github/workflows/_tests_ca_composite-actions.yml` に `test-filter-files` ジョブを追加する。正常系と失敗系のケース、Verify ステップを含む
  - 次の設定は `test-resolve-sha` ジョブに合わせる
    - `needs: setup-foundation`、`permissions: contents: read`
    - checkout のピン留め、`uses: ./.github/actions/_ca-filter-files`
  - 失敗ケースは `continue-on-error` とし、Verify ステップで outcome と outputs を env 経由で検査する
- summary ジョブの 4 箇所 (`needs`、`RESULT_*`、表の行、失敗判定) を更新する
- 保護領域 (`.github/workflows/*.yml`) の変更のため、PR に変更理由を明記する
- 1.1 の完了条件をすべて確認する (テスト ID の機械検査 A / C を含む)

---

## 3. Change History

<!-- SemVer: MAJOR = approach discarded, MINOR = interface, contract, premise or design policy changed,
     PATCH = additions within the existing policy or clarification. Keep frontmatter `version` equal to the newest row.
     `based-on` must cite a three-part version that exists in specifications-index.md.
     See docs/.deckrd/rules/deckrd-rule-document-versioning.md -->

| Date       | Version | Description                                                                                                                                                                |
| ---------- | ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-10-27 | 1.0.0   | Initial implementation plan                                                                                                                                                |
| 2026-10-27 | 1.1.0   | Apply impl explore review: byte size limit check (CBL), local declaration and stdout rules, baseline run, ID checks before PR-A merge, upper-bound timing run, fix bullets |
| 2026-10-27 | 1.1.1   | Apply impl harden review: UTF-8 check criteria, timing run is record-only, MAIN splits CP output, cite DR-17 and DR-18, refresh based-on                                   |
| 2026-10-27 | 1.1.2   | Apply impl fix review: terminology, enumerate existing callers, full-form ID ranges, unit table order, cite DR-08, DR-09, DR-12, refresh DR version and history comment    |
