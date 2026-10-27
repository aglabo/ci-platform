---
title: "Implementation Plan: _ca-filter-files"
based-on: specifications-index.md v1.3.2
status: Draft
version: 1.2.0
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

- PR-A: Phase 1 (共有ライブラリ)
- PR-B: Phase 2〜6 (`_ca-filter-files` 本体と CI)。PR-A のマージ後に main から作る。

本 impl / tasks 文書は、現ブランチ (`docs-136/filter-files/add-spec-docs`) で作成する。

**実装品質基準 (全コミット共通):**

- 各コミットの中で BDD の RGR サイクルを回す。テストが FAIL することを確認してから実装し、PASS を確認してからコミットする。
- テストとその実装は同じコミットに含める。
- テスト ID は `T-FF-<略語>-NN` とする。略語は `module.md` の「関数一覧」に従う (functional は `T-FF-MAINF-NN`)。ケース名には `[Normal]` / `[Error]` / `[Edge]` を付ける。
- テストを追加したコミットでは、そのテストが使う略語を `module.md` の「テスト対象の略語」表に追記する (テスト ID 検査 D)。
- ShellSpec の `It` にはテスト ID をリテラルで書き、`Parameters` は使わない (テスト ID 検査 B / D が ID を読めるようにするため)。
- テストの実行は `runners/run-shellspec.sh` 経由で行う。
- 各コミットで `pnpm lint:sh` と `pnpm check:sh` を通す。
- テストを追加したコミットでは、テスト ID の機械検査 B / D を実行する。検査 A / C は、PR-A の最後 (Phase 1 の後) と PR-B の最後 (Phase 6 の後) に実行する。
- 内部シンボルは先頭アンダースコアで区別する。
- 環境変数を読むのは MAIN だけとし、`${VAR:-}` の形で読む (REQ-C-006)。
  ライブラリのロードガード変数 (`*_LIB_LOADED`) は例外とし、Phase 2 の `declare -F` による関数の存在確認と組み合わせる。
- 失敗系のテストは、`set -e` が効かない文脈 (ShellSpec の `When call`) で終了コードとエラー出力を確認する。関数内のコマンドの失敗が、`set -e` なしでも呼び出し元へ返ることを確かめるため (impl second opinion)。

### 1.2 Reference

- Prior Art / Reference PR: PoC なし。
  - 構成は `_ca-resolve-sha` (action.yml → `scripts/resolve-sha.sh` → `scripts/_libs/resolve-sha.lib.sh`) に倣う。
  - resolve-sha は共有ライブラリを別 PR (#141) に分け、CI ジョブを後から (#144) 足した。
  - 本計画は、共有ライブラリを別 PR に分け、CI ジョブを最初から含める (REQ-C-008)。
- Specifications:
  - specifications-index.md v1.3.2
  - specifications-input.md v1.3.1
  - specifications-matching.md v1.0.4
  - specifications-output.md v1.0.3
- Requirements: requirements.md v1.3.1
- Decision Records: decision-records.md v1.3.2
  - DR-02、DR-04、DR-05、DR-06、DR-07、DR-08、DR-09
  - DR-12、DR-13、DR-14、DR-15、DR-16、DR-17、DR-18

### 1.3 Design Decisions

**実装単位と配置:**

実装単位 (関数)、テストの略語、シグネチャ、所在は、`workspaces/module/module.md` の「関数一覧」を正とする。本書では再掲しない。

- 入力によって検査と正規化が異なるため、行の分割と正規化を PFL と PPT に分ける (impl second opinion)。
  `<target>` による分岐を持たないので、想定外の target を扱う必要がない。
- 両者に共通する CRLF から LF への変換と行の分割は、内部関数 `_ff_split_lines <text>` にまとめる。
  内部関数にはテスト ID を割り当てず、PFL と PPT のテストで検証する。

**確定した判断:**

- 照合方式 (DR-17): DR-02 のとおり glob を ERE に変換し、`[[ =~ ]]` で照合する。
  `LC_ALL=C.UTF-8` は FF のサブシェル本体の中で設定する (呼び出し元に影響しない)。
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
  - CP の出力は MAIN が 1 行ずつ種別とパターンに分け、包含と除外の 2 つの LF 区切り文字列にして FF に渡す。FF のシグネチャ (module.md の「関数一覧」) は変えない (impl harden review GF-01)。
  - FF は、各パターンの ERE を照合ループの前に 1 回だけ生成して配列に持ち、ループ内では Bash の組み込み機能 (`[[ =~ ]]`) だけを使う。
- glob の変換順 (impl second opinion): GTR は 1 つの glob を先頭から書かれた順に読み、各位置で次の順に判定する (R-MAT-002〜R-MAT-008)。
  境界の期待値は specifications-matching.md §5 のエッジケース表を網羅する。
  変換先は specifications-matching.md §3.2 の impl-note に従い、全体を `^...$` で囲む。

  | 順 | glob の位置                     | ERE                                              |
  | -: | ------------------------------- | ------------------------------------------------ |
  |  1 | パターン全体が `**`             | `.*`                                             |
  |  2 | 先頭、または `/` の直後の `**/` | `(.*/)?`                                         |
  |  3 | 末尾の `/**`                    | `/.+`                                            |
  |  4 | その他の `**`                   | `[^/]*`                                          |
  |  5 | `*` / `?`                       | `[^/]*` / `[^/]`                                 |
  |  6 | その他の文字                    | ERE のメタ文字はバックスラッシュでエスケープする |

  - `**/` を変換した直後の位置は「`/` の直後」として扱い、続く `**` を改めて 2〜4 で判定する (`**/**`、`a/**/**/b`)。
  - 判定は `**` を `*` より先に行う (最長一致)。`***.sh` は `**` (4) と `*` (5) になる。
- 除外の確定 (DR-05、R-MAT-011): 除外パターンに一致したファイルは、パターンの記述順によらずリストから除く。後のパターンでファイルを戻すことはできない。
- 件数の上限 (DR-16、REQ-F-018): `filter-files.lib.sh` に readonly 定数 `FF_MAX_FILES=3000`・`FF_MAX_PATTERNS=1000` を置く。
  CLL は空行を捨てた後の行数で判定し、上限ちょうどは受け付ける。
  エラーは `::error::files: exceeds the limit of 3000 lines (got: '3001')` の形式とする (DR-15。文言は下の「エラーの文言」)。
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
- MAIN の関数の呼び出し順 (DR-14、specifications-index.md §3.4): 次の順に呼び、失敗したら以降を呼ばずに非 0 で終了する。
  1. CBL (files) → CBL (patterns)
  2. CLE (files) → CLE (patterns)
  3. PFL → PPT
  4. CLL (files、PFL の結果) → CLL (patterns、PPT の結果)
  5. CP → 包含と除外への分離
  6. FF
  7. EO (`${GITHUB_OUTPUT:-}` と FF の結果を渡す)
- エラーの文言 (DR-15、specifications-input.md §4、specifications-output.md §4):
  - 文言 (`<問題>` の部分) は、コーディング時に `filter-files.lib.sh` のエラーメッセージテーブルにまとめて定義する。
    キーは Rule ID とし、各関数はテーブルを参照して FE に渡す。関数の中に文言を直接書かない。
  - 英語の文言は、spec が定めているもの (R-IN-014〜R-IN-017 の `exceeds the limit of ...`) はそれに従い、それ以外はコーディング時に決める。
  - テーブルの値は完成した固定の文字列とする。printf の書式は使わない (値の `%` が書式として解釈されるのを防ぐため)。
  - 上限の値 (3000・1000・120000) は文言に直接書かず、ライブラリの読み込み時に定数を展開して組み込む (`rs_error` の `_RS_MAX_COMMIT_COUNT` と同じ書き方)。
  - 実行時の値 (行・行数・パス) は、FE の `<value>` で渡す。
  - ユニットテストは、期待値をテーブルの参照で組み立てるか、文言の一部 (対象・値など) で照合する。文言をテストに重ねて書かない。
  - 対象と値は次のとおりとする (spec の規則で決まる部分)。

  | Rule ID             | 対象                 | 値                 |
  | ------------------- | -------------------- | ------------------ |
  | R-IN-016 / R-IN-017 | `files` / `patterns` | バイト数           |
  | R-IN-011            | `files` / `patterns` | CR を含む行        |
  | R-IN-010            | `files` / `patterns` | その行             |
  | R-IN-012            | `files`              | その行             |
  | R-IN-014 / R-IN-015 | `files` / `patterns` | 行数               |
  | R-IN-005            | `patterns`           | 空白を除いた行 `!` |
  | R-IN-009            | `patterns`           | その行             |
  | R-OUT-001           | `GITHUB_OUTPUT`      | なし (空値の形式)  |
  | R-OUT-002           | `GITHUB_OUTPUT`      | パス               |
  | R-OUT-006           | `files` / `count`    | 出力先のパス       |
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
- UTF-8 の検査方式 (`iconv` か、`C.UTF-8` での `grep -ax '.*'` か) は、PFL のタスクで決め、PPT も同じ方式を使う。選ぶ方式は次をすべて満たす (impl harden review W-01)。
  - 行ごとに外部コマンドを起動しない
  - 最初の不正な行を特定し、FE に値として渡せる (R-IN-010)
  - ロケールは `C.UTF-8` だけを前提にする (specifications-index.md §2.2)
- PFL の検査順 (DR-14、impl second opinion): ファイル行は 1 行ずつ UTF-8、ダブルクオートの順に判定した結果と同じ 1 件を報告する。
  UTF-8 を一括で検査する場合は、最初の不正な UTF-8 行と、最初のダブルクオートを含む行の行番号を比べ、前にある方を報告する。同じ行なら UTF-8 のエラーとする。
- `module.md` は `workspaces/module/module.md` に置く。`test_scope` (FF)、`owns`、「関数一覧」は記入済みである。
  「テスト対象の略語」表は、テストを追加したコミットで、そのテストが使う略語 (綴り全体。`MAINF` など) を追記する。

**関数ごとの実装上の詳細:**

- CLE: `check_line_endings <target> <text>`。1 つの入力を検査し、最初に CR を見つけた 1 行だけを報告する。MAIN が files、patterns の順に呼ぶ。CRLF は検査の対象外とする (R-IN-013 が分割前に LF へ正規化するのは、LF を伴わない CR の検査を通過した後である)。
- PFL: `parse_filelist <text>`。UTF-8 とダブルクオートを検査し、行は変更せず、長さ 0 の行だけを捨てる (DR-08)。エラーの対象は `files` とする。
- PPT: `parse_patterns <text>`。UTF-8 を検査し、両端のスペースとタブを除去してから、空行を捨てる (DR-08)。ダブルクオートは受け付ける (DR-11)。エラーの対象は `patterns` とする。
- 関数の中のコマンドの失敗は、`set -e` に頼らず `|| return 1` で呼び出し元へ返す。`if` の条件や `||` の左辺など、`set -e` が効かない文脈で呼ばれても失敗が伝わるようにする (impl second opinion)。
- CBL: `check_byte_limit <target> <text> <max>`。バイト数が max を超えれば FE でエラーを出して 1 を返す。
- CLL: `check_line_limit <target> <lines> <max>`。行数が max を超えれば FE でエラーを出して 1 を返す。
- CP: `!` で始まる行を除外、それ以外を包含に分類する。パターンが 0 件の場合の扱い (全件) は FF が担う (R-IN-007)。
  - 先頭の `!` は 1 つだけ除く。`!!a.sh` は除外パターン `!a.sh` になる (R-IN-004)。
  - `!` を除いた残りは、再び空白を除去しない (DD-IN-02)。残りが空ならエラー (R-IN-005)、空白で始まればエラー (R-IN-009) とし、行ごとにこの順で判定する。
  - ダブルクオートは文字として残す (R-IN-008)。
- GTR: 上の「glob の変換順」の表で変換し、全体一致のアンカーを付ける。ブラケットはリテラルとして扱う (R-MAT-008)。
- FF: 除外を優先し、包含が 0 件なら全件を対象にする。入力順と重複を保つ。
  - シェルのオプションに結果が依存しない (R-MAT-009、REQ-NF-002)。`[[ =~ ]]` は `nocasematch` の影響を受ける。
  - そのため本体をサブシェル `filter_files() ( ... )` で書き、その中で `shopt -u nocasematch` と `LC_ALL=C.UTF-8` を設定する。呼び出し元のオプションとロケールは変わらない。
  - `globstar` / `extglob` / `nocaseglob` はパス名展開にだけ効く。変数は常にクオートし、パス名展開を起こさない。
- EO: 出力先を検証してから、files、count の順に書く。0 件の files は空で書く (R-OUT-004)。
  - VOF の戻り値が 1 なら R-OUT-001、2 なら R-OUT-002 のエラーを FE で出し、何も書かずに 1 を返す。
  - `files` は WMO で書き、`count` は既存の `write_output <file> <key> <value>` で書く。`write_output` は値に CR / LF があると 1、書き込みに失敗すると 2 を返す。`count` は数字だけなので 1 にはならない。
  - WMO または `write_output` が 0 以外を返したら、R-OUT-006 のエラーを FE で出し、以降を書かずに 1 を返す。files が残り得る (DR-09)。

---

## 2. Implementation Plan

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
- 旧 `write_multiline_output` (`ca-get-changed-files/scripts/_libs/filter.lib.sh`、引数 2 つ) は新 WMO (引数 3 つ) と同じ名前である。
  現在、両方を読み込むスクリプトは無い。
  #134 で `ca-get-changed-files` に組み込むときは、`output.lib.sh` を読み込む前に旧関数を新 WMO に置き換える。
  読み込み順で一方が他方を上書きしないことをテストする (DR-06、DR-07、impl second opinion)

### Phase 2: Module Library Foundation (PR-B)

#### Commit 1: feat(filter-files): add library skeleton and ff_error

- `filter-files.lib.sh` の骨格を作る (ロードガード、`output.lib.sh` の読み込み、`declare -F` による関数の存在確認)
- FE を追加する。specifications-index.md §3.3 の形式、空値の形式、`%` / CR / LF のエンコードに対応する
- エラーメッセージテーブル (キーは Rule ID) の枠を作る。各規則の文言は、その規則を担う関数のコミットで追加する
- T-FF-FE-* (ロードガードのテストを含む)

### Phase 3: Input Processing (PR-B)

#### Commit 1: feat(filter-files): add check_line_endings

- CLE を追加する (R-IN-011)。LF を伴わない CR を検出してエラーにし、最初の 1 行を報告する
- T-FF-CLE-*

#### Commit 2: feat(filter-files): add parse_filelist

- 内部関数 `_ff_split_lines` と PFL を追加する (R-IN-013、R-IN-001、R-IN-010、R-IN-012、R-IN-003)
- 行は変更せず、長さ 0 の行だけを捨てる。UTF-8 とダブルクオートを検査する
- 前の行にダブルクオート、後の行に不正な UTF-8 がある入力では、ダブルクオートのエラーを報告することをテストする (DR-14)。逆の並びと、同じ行に両方がある場合もテストする
- T-FF-PFL-*

#### Commit 3: feat(filter-files): add parse_patterns

- PPT を追加する (R-IN-013、R-IN-001、R-IN-010、R-IN-002、R-IN-003)
- 両端のスペースとタブを除去し、空行を捨てる。UTF-8 を検査し、ダブルクオートは受け付ける
- T-FF-PPT-*

#### Commit 4: feat(filter-files): add input size limit checks

- CBL と定数 `FF_MAX_FILES_BYTES`・`FF_MAX_PATTERNS_BYTES` (120000) を追加する (R-IN-016、R-IN-017)
  - 日本語を含む値を、文字数ではなくバイト数で数えることをテストする
- CLL と定数 `FF_MAX_FILES` (3000)・`FF_MAX_PATTERNS` (1000) を追加する (R-IN-014、R-IN-015)
- どちらも上限ちょうどは受け付け、超えたらエラーにする
- T-FF-CBL-*、T-FF-CLL-*

#### Commit 5: feat(filter-files): add classify_patterns

- CP を追加する (R-IN-004〜R-IN-009)
- `I<TAB>` / `E<TAB>` を stdout に出力する
- `!` だけの行と、空白で始まる除外をエラーにする
- `!!a.sh`、`!` の後のタブ、ダブルクオートを含むパターンをテストする (specifications-input.md §5)
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
- 本体をサブシェルで書き、`shopt -u nocasematch` と `LC_ALL=C.UTF-8` を設定する
- `shopt -s globstar extglob nocasematch nocaseglob` を有効にしたテストを書く (REQ-NF-002、specifications-matching.md §5 の impl-note)
  - 結果が変わらないこと
  - `*.SH` が `a.sh` に一致しないこと (DD-MAT-06) を含める
  - 呼び出し後も、呼び出し元の `nocasematch` が有効のままであることを確かめる
- git リポジトリの外の作業ディレクトリで実行し、次の 2 種類のパスを混ぜて結果を確かめる (REQ-F-012、specifications-matching.md §5 の impl-note)
  - 実在しないが、パターンに一致するパス
  - 実在するが、パターンに一致しないパス
- T-FF-FF-*

### Phase 5: Output and Entry Point (PR-B)

#### Commit 1: feat(filter-files): add emit_outputs

- EO を追加する (R-OUT-001〜R-OUT-006)
- 出力先を検証してから、files、count の順に書く
- 0 件の場合と、書き込み失敗のエラーを扱う
- `count` は既存の `write_output` で書く
- VOF の戻り値 (1 / 2) と R-OUT-001 / R-OUT-002 の対応、`count` だけ書き込みに失敗した場合 (files が残る) をテストする
- T-FF-EO-*

#### Commit 2: feat(filter-files): add filter-files.sh entry script

- MAIN (`scripts/filter-files.sh`) を追加する。環境変数を読む唯一の箇所とし、1.3 の「MAIN の関数の呼び出し順」で関数を呼ぶ
- CP の出力を包含と除外に分けて FF に渡す (1.3 の受け渡し形式)
- 次の書き方は `_ca-resolve-sha/scripts/resolve-sha.sh` に合わせる (REQ-C-006)
  - `set -euo pipefail`、ライブラリの読み込み、`(return 0 2>/dev/null)` の main ガード
- T-FF-MAINF-* (functional): AC-001〜AC-018 を検証する
  - specifications-index.md §5 の横断的なエッジケースも検証する
    - 不正なパターンがあり、出力先も使えない → パターンのエラーで終了する (DD-IDX-02)
    - `files` が未指定 (空) → 0 件で正常終了する
    - `files` が 0 行で、不正なパターンがある → パターンのエラーで終了する
    - `files` が `"a\nb.sh"` → ダブルクオートのエラーで終了する
  - 検査が複数当たる入力で、呼び出し順 (1.3) のとおり最初の 1 件だけが報告されることを確かめる
- 上限ちょうどの入力 (files 3000 行・patterns 1000 行、バイト数の上限以内) で、実機で実行時間を測り、PR に記録する (impl explore review G-01)
  - 負荷の条件として、全パターンが一致しない場合、長いパターン、`**` を繰り返すパターンも測る (impl second opinion)
  - 実用的な速度に収まらない場合は、`FF_MAX_PATTERNS` を下げる。目標の時間と新しい上限は、計測結果を見てユーザーが決める
  - 上限を下げる場合は、まず次の文書を改訂する: requirements (REQ-F-018)、decision-records (DR-16)、specifications-input (R-IN-015、DD-IN-10)
  - その後で定数とテスト (T-FF-CLL-*、T-FF-MAINF-*) を更新する。PR-B のマージ前に済ませる

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

| Date       | Version | Description                                                                                                                                                                                                                                                                                                                                                                                                |
| ---------- | ------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-10-27 | 1.0.0   | Initial implementation plan                                                                                                                                                                                                                                                                                                                                                                                |
| 2026-10-27 | 1.1.0   | Apply impl explore review: byte size limit check (CBL), local declaration and stdout rules, baseline run, ID checks before PR-A merge, upper-bound timing run, fix bullets                                                                                                                                                                                                                                 |
| 2026-10-27 | 1.1.1   | Apply impl harden review: UTF-8 check criteria, timing run is record-only, MAIN splits CP output, cite DR-17 and DR-18, refresh based-on                                                                                                                                                                                                                                                                   |
| 2026-10-27 | 1.1.2   | Apply impl fix review: terminology, enumerate existing callers, full-form ID ranges, unit table order, cite DR-08, DR-09, DR-12, refresh DR version and history comment                                                                                                                                                                                                                                    |
| 2026-10-27 | 1.2.0   | Apply impl second opinion: split PL into PFL and PPT, DR-14 order test, set -e independent failures, WMO name clash note, measure timing to tune pattern limit, nocasematch in FF, EO error mapping and write_output, MAIN call order, error message table keyed by rule ID, GTR ERE table, CP details, REQ-F-012 and cross-cutting tests, move function list to module.md, drop Phase 0, refresh based-on |
