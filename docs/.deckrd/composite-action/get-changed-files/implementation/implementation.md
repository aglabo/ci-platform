---
title: "Implementation Plan: ca-get-changed-files"
based-on: specifications-index.md v2.2.1
status: approved
version: 2.3.3
created: "2026-10-30"
---

<!-- textlint-disable ja-technical-writing/sentence-length -->
<!-- markdownlint-disable line-length -->

## 1. Overview

### 1.1 Purpose

公開 Composite Action `.github/actions/ca-get-changed-files/` を組み直す (Issue #134)。
SHA の解決を `_ca-resolve-sha`、glob による絞り込みを `_ca-filter-files` のスクリプトに任せ、本 Action は変更ファイルの取得だけを持つ。
入力は `commit-count` と `pattern` (glob、複数行、`!` で除外) とし、出力 `files` / `count` は従来どおりとする。
評価順序は specifications-index.md §3.4 に従う。SHA の解決 → 変更ファイルの取得 → 絞り込み → 出力の公開の順とし、いずれかの段が失敗したら後続の段を実行しない。

本計画の範囲は、`ca-get-changed-files` 配下の書き直し、旧ライブラリ `filter.lib.sh` の削除、共有ライブラリへの追加、`test-get-changed-files` ジョブの改訂までとする。

- `_ca-resolve-sha/`・`_ca-filter-files/` の契約は変更しない (REQ-C-006)。両者のライブラリを共有ライブラリへ置き換える変更は、各モジュールの文書 (`_ca-filter-files` implementation.md v1.7.x、`_ca-resolve-sha` tasks.md T-15) で扱う。
- `_libs/` の変更は、`error.lib.sh`・`constants.lib.sh` の追加と、`validation.lib.sh` への `check_byte_limit` の追加に限る (REQ-C-006)。既存関数は変更しない。
- `CHANGELOG.md` は変更しない。記載は次のマイナーリリースの release PR で行う (DD-IDX-04)。
- 完了条件は、次のすべてを満たすこととする。
  - actionlint / ghalint を通過する
  - ShellSpec の全テストに `not ok` が無い
  - `pnpm lint:sh` (shellcheck) と `pnpm check:sh` (shfmt) を通過する
  - テスト ID の機械検査 A〜D を通過する

PR は 1 つとする。実装は `feat-134/get-changed-files/02-impl` ブランチで行う (本 impl / tasks 文書のブランチ `feat-134/get-changed-files/01-docs` の上に作る)。

**実装品質基準 (全コミット共通):**

- 各コミットの中で BDD の RGR サイクルを回す。テストが FAIL することを確認してから実装し、PASS を確認してからコミットする。
- テストとその実装は同じコミットに含める。
- テスト ID は `T-GCF-<略語>-NN` とする。略語は `module.md` の「関数一覧」に従う (DD-IDX-03)。ケース名には `[Normal]` / `[Error]` / `[Edge]` を付ける。
- テストを追加したコミットでは、そのテストが使う略語を `module.md` の「テスト対象の略語」表に追記する (テスト ID 検査 D)。
- ShellSpec の `It` にはテスト ID をリテラルで書き、`Parameters` は使わない (テスト ID 検査 B / D が ID を読めるようにするため)。
- テストの実行は `runners/run-shellspec.sh` 経由で行う。
- 各コミットで `pnpm lint:sh` と `pnpm check:sh` を通す。
- テストを追加したコミットでは、テスト ID の機械検査 B / D を実行する。検査 A / C は PR の最後 (Phase 4 の後) に実行する。
  - 専用のスクリプトは無い。testing-guidelines §6.1 の抽出パイプラインを、§6.2〜§6.5 の走査範囲 (B / D は本モジュールの `owns` 配下) に対して実行する。
- 内部シンボルは先頭アンダースコアで区別する。本 Action のスクリプトの中でだけ使う関数は、ファイルをまたいで呼ぶ場合も内部シンボルとする (coding-guidelines「内部シンボルの命名」)。
- 環境変数を読むのは MAINF の対象 (`main`) だけとし、`${VAR:-}` の形で読む。`list_changed_files` は引数だけを入力とする。

### 1.2 Reference

- Prior Art / Reference PR: PoC なし。
  - 構成と書き方は `_ca-resolve-sha` (`scripts/resolve-sha.sh` → `scripts/_libs/resolve-sha.lib.sh`) と `_ca-filter-files` (`scripts/filter-files.sh` → `scripts/_libs/filter-files.lib.sh`) に倣う (DD-DIF-04)。
  - action.yml の静的検査は `_ca-filter-files/scripts/__tests__/unit/action.unit.spec.sh` (awk による section / step / env の抽出) に倣う。
  - 実 git fixture は `_ca-resolve-sha/scripts/__tests__/helpers/git-fixture.sh` を読み取り専用で使う (spec index §3.5 の impl-note)。
    helper の変更は本モジュールのテストに影響する。resolve-sha 側で helper を変えるときは、本モジュールのテストも実行する。
  - CI ジョブは `test-resolve-sha` ジョブの書き方に合わせる (R-IDX-001〜R-IDX-007)。
- Specifications:
  - specifications-index.md v2.2.0
  - specifications-action.md v2.2.0
  - specifications-diff.md v2.2.1
- Requirements: requirements.md v2.2.0
- Decision Records: decision-records.md
  - DR-01〜DR-16

### 1.3 Design Decisions

**実装単位と配置:**

実装単位 (関数・テスト対象)、テストの略語、シグネチャ、所在は、`workspaces/module/module.md` の「関数一覧」を正とする。本書では再掲しない。

| ファイル                                                            | 内容                                         |
| ------------------------------------------------------------------- | -------------------------------------------- |
| `scripts/_libs/get-changed-files.lib.sh`                            | ロードガード、上限の定数、LCF                |
| `scripts/get-changed-files.sh`                                      | MAINF の対象 (`main`)                        |
| `action.yml`                                                        | 3 つの step の連鎖                           |
| `scripts/_libs/__tests__/unit/get-changed-files.unit.spec.sh`       | T-GCF-LCF-*                                  |
| `scripts/__tests__/functional/get-changed-files.functional.spec.sh` | T-GCF-MAINF-* (旧ファイルの内容を置き換える) |
| `scripts/__tests__/unit/action.unit.spec.sh`                        | T-GCF-GACT-*                                 |
| `scripts/__tests__/functional/action.functional.spec.sh`            | T-GCF-RUNF-*                                 |

パスは `.github/actions/ca-get-changed-files/` からの相対とする。

**ライブラリ (`get-changed-files.lib.sh`):**

- ロードガード変数は `GET_CHANGED_FILES_LIB_LOADED` とする。書き方は `filter-files.lib.sh` に合わせる。
  - ガード変数は判定直後に設定する。共有ライブラリ `_libs/output.lib.sh` と `_libs/validation.lib.sh` (`_libs/error.lib.sh` を読み込む) を自身の位置から読み込み、失敗したら 1 を返してアクションを失敗させる。
  - ガード変数が設定済みなら、ライブラリと共有ライブラリの関数は最初の読み込みで定義済みとみなし、`declare -F` による依存関数の確認は行わない (`filter-files.lib.sh` と同じ形)。
- 上限の定数は `readonly GCF_MAX_FILES_BYTES=$GHA_MAX_ENV_VALUE_BYTES` とする (DR-13)。共通定数 `GHA_MAX_ENV_VALUE_BYTES` (120000) は `_libs/constants.lib.sh` が定義し、`_libs/validation.lib.sh` の後に読み込む。
  - `_ca-filter-files` のライブラリは別プロセスで動くため、読み込まない (impl-note DD-DIF-03)。値の一致は、両ライブラリが同じ共通定数を代入していることを GACT の静的検査で確かめる (R-DIF-033)。
- エラー出力は共有ライブラリ `_libs/error.lib.sh` の `gha_error <target> [<problem> <value>]` を使う。
  - 形式は `ff_error` / `rs_error` と同じ (DD-IDX-01、DR-14)。引数が 3 個未満なら空の形式、3 個なら通常の形式とする。値の `%` / CR / LF は `%25` / `%0D` / `%0A` にエンコードする。
  - `gha_error` 自体は T-GCF-GE / T-GCF-ELG で検証する。本 Action での形式は LCF と MAINF のテストで検証する。
- バイト数の上限の検査は共有ライブラリ `_libs/validation.lib.sh` の `check_byte_limit` を使い、上限に `GCF_MAX_FILES_BYTES` を渡す (文言 `exceeds the limit of <max> bytes` は `check_byte_limit` が組み立てる)。
- エラーの文言 (specifications-diff.md「エラーの文言」) のうち、`_ca-filter-files` / `_ca-resolve-sha` と共通のもの (`GITHUB_OUTPUT`、R-DIF-013 の `is not a writable file`、R-DIF-016 の `failed to write`) は `_libs/error.lib.sh` の定数 `GHA_TARGET_GITHUB_OUTPUT` / `GHA_MSG_NOT_WRITABLE` / `GHA_MSG_WRITE_FAILED` を使う。本 Action 固有の文言はライブラリの定数として 1 か所にまとめる。`main` は文言を直接書かず、定数を参照する。

**変更ファイルの取得 (`list_changed_files <before> <after>`):**

- `git -c core.quotePath=false diff --name-only --diff-filter=ACMR --end-of-options <before> <after>` を作業ディレクトリで実行する。`--end-of-options` で、`-` で始まる値をオプションとして解釈させない。pathspec は渡さない (R-DIF-001、DD-DIF-01)。
- 結果はコマンド置換で受け取り、終了コードを `|| { ...; return 1; }` で判定する。git の標準エラー出力は抑えずにそのまま出し、その後に R-DIF-002 のエラーを 1 行出す (値は `<before>..<after>`)。
- バイト数は、関数内で `local LC_ALL=C` を単独の文で設定してから `${#var}` で数える (外部コマンドを使わない)。コマンド置換が末尾の LF を落とすため、値は「LF で連結、末尾の LF なし」の形になる。
- 120000 バイトを超えたら R-DIF-003 のエラー (値はバイト数) を出し、一覧を出さずに 1 を返す。ちょうど 120000 は受け付ける。
- 一覧は加工しないまま stdout へ出す (R-DIF-004)。空の一覧は何も出さずに 0 を返す。データは `echo` ではなく `printf '%s'` で出力する。
- LF を含むパスは、`core.quotePath=false` でも引用表記で出る。このため、一覧の 1 行は 1 パスに対応する (DR-06)。

**入口 (`main`):**

- 呼び出し順は R-DIF-010〜R-DIF-016 に従い、失敗したら以降を呼ばずに非 0 で終了する。
  1. `BEFORE_SHA` → `AFTER_SHA` → `GITHUB_OUTPUT` の空の検査 (空の形式)
  2. `validate_output_file "$GITHUB_OUTPUT"`。0 以外なら R-DIF-013 のエラーとする (空の `GITHUB_OUTPUT` は手順 1 で R-DIF-012 として止まるため、戻り値 1 には届かない)
  3. `list_changed_files` (エラーはライブラリが出す)
  4. 一覧が空でなければ `mapfile -t` (ヒアストリング) で配列に読み込み、`write_multiline_output "$GITHUB_OUTPUT" files "${lines[@]}"` で書く。0 行なら行の引数を渡さない
  5. `write_multiline_output` が 0 以外を返したら R-DIF-016 のエラー (値は出力先のパス) とする
- 上の手順 1〜3 (spec の Step 1〜4) の失敗では、`$GITHUB_OUTPUT` に何も書かない。
- スクリプトの位置は `dirname` と `pwd` で解決し、main のガードは `(return 0 2>/dev/null)` とする (impl-note DD-DIF-04)。`set -euo pipefail` を持つ。
- ヘッダーの `@(#)` 行は、イベントによらない説明へ改める (carry-over-134)。

**action.yml:**

- 入力・出力・step の構成は specifications-action.md の R-ACT-001〜R-ACT-032 に従う。step の `id` は `resolve-sha`・`get-changed-files`・`filter-files` とする (DD-ACT-04)。
- `INPUT_BEFORE_SHA`・`INPUT_AFTER_SHA` は step の env で `""` を明示する (DD-ACT-02)。
- `run` に `${{ }}` を書かず、パスは `${GITHUB_ACTION_PATH}` で参照する (REQ-C-001)。
- `# src:` ヘッダーを `./.github/actions/ca-get-changed-files/action.yml` に直す (carry-over-134)。
- `description` に R-ACT-003 の 4 項目を書く。

**テスト:**

- LCF (unit): `git-fixture.sh` を `Include` し、`BeforeEach 'gf_setup'` / `AfterEach 'gf_cleanup'` で例ごとのリポジトリを作る。`list_changed_files` は `gf_run_in <repo>` で実行する。
  - 通常のファイルの追加・削除・リネームは、`gf_git` で作業ツリーにファイルを作って行う。`gf_commit` が足すのは `file-N.txt` だけである。
  - 特殊文字 (`"`・`\`・タブ) を含むパス、シンボリックリンク (型の変更 `T`)、長いパスや多数のパスは、作業ツリーにファイルを作らず、index への直接の登録で作る。
    `git hash-object -w` で作った blob を `git update-index --add --cacheinfo <mode>,<blob>,<path>` で index に直接登録してからコミットする (mode は通常 `100644`、シンボリックリンクは `120000`)。
    多数のパスは、`git update-index --index-info` に 1 行 1 エントリで渡し、1 回の呼び出しで登録する。
    NTFS の禁止文字・パス長・ファイル作成の速度の制約を受けないようにするためである。`git diff` はコミット間の比較なので、作業ツリーとの不一致は結果に影響しない。
  - 120000 / 120001 バイトの一覧は、上の方法で長いパスを多数登録して作る。パスの要素は 255 バイト以下とし、ディレクトリで分ける。
  - fixture の git はホストの global / system 設定を無視するため、`diff.renames` などは既定値になる。`list_changed_files` は必ず `gf_run_in` を通して実行する。
  - ShellSpec は Windows では `runners/run-shellspec.sh` が WSL 上で実行する。index への直接の登録により、`SHELLSPEC_NO_WSL=1` で Git Bash から実行した場合も fixture を作れる。
- MAINF (functional): 実 git fixture で `main` を実行し、`$GITHUB_OUTPUT` の内容を検証する。失敗系では、出力先ファイルが空のままであることを確かめる。
  - 通常のケースは、スクリプトを `bash` で実行する内部ヘルパーで動かす。
  - R-DIF-016 (検証を通過した後の書き込み失敗) だけは専用の内部ヘルパーを使う。サブシェルの中でスクリプトを source し、`write_multiline_output` を 0 以外を返す関数に差し替えてから `main` を呼ぶ。`set -euo pipefail` を ShellSpec の実行シェルに残さないためである。
- GACT (unit): action.yml を awk で静的に検査する。RUNF は action.yml を読まないため、step の構成と env の値は GACT だけが検証する。`_ca-filter-files` の action.unit.spec.sh の抽出関数 (`_act_section`・`_act_step`・step env の抽出) を、本ファイルの内部ヘルパーとして書く (所有範囲の外のファイルは読み込まない)。
  - R-ACT-040 は `_ca-resolve-sha/action.yml`、R-ACT-041 は `_ca-filter-files/action.yml`、R-DIF-033 は `_ca-filter-files/scripts/_libs/filter-files.lib.sh` の `FF_MAX_FILES_BYTES` の右辺を読んで比べる。
  - step の数 (3)・順序・`id` (R-ACT-010〜R-ACT-012、DD-ACT-04) と、全 step が `shell: bash` で `if:`・`continue-on-error` を持たないこと (R-ACT-013) を検査する。
  - 3 つの step の env は、期待する `KEY: value` の行の集合と過不足なく一致することを確かめる (R-ACT-020〜R-ACT-023。filter-files の T-FF-ACT-01 と同じ方式)。
- RUNF (functional): `ca-get-changed-files`・`_ca-resolve-sha`・`_ca-filter-files`・`_libs` を一時ディレクトリにコピーし、action.yml と同じパスと env で 3 つのスクリプトを順に実行する (AC-014)。
  - 作業ディレクトリは `.github/actions` を持たない fixture リポジトリとする。
  - イベントの環境変数は、action.yml の resolve-sha の step の env と同じ名前で渡す。
    push のケースは `GITHUB_EVENT_NAME=push`・`GITHUB_REF=refs/heads/main`・`GITHUB_EVENT_DELETED=false`・`GITHUB_BEFORE_SHA`・`GITHUB_AFTER_SHA` を設定する (resolve-sha はブランチ削除とブランチ以外の ref の push をエラーにする)。
    その他イベントのケースは `GITHUB_EVENT_NAME=workflow_dispatch` とし、push と pull_request の値を空にする。
    pull_request のケースは `GITHUB_EVENT_NAME=pull_request`・`GITHUB_BASE_SHA`・`GITHUB_HEAD_SHA` を設定し、push の値を空にする。
  - step ごとに別の `$GITHUB_OUTPUT` を使い、前の step の出力 (`before_sha`・`after_sha`・`files`) を内部ヘルパーで読み取って次の step の env に渡す。いずれかの step が失敗したら、それ以降の step は実行しない。
  - 内部ヘルパーは、GitHub Actions の step 出力の書式 (`key=value` と `key<<DELIM` ... `DELIM`) を読む。
  - 失敗系では、失敗した step より後の step の `$GITHUB_OUTPUT` が作られていないことと、filter-files の step の出力に `files`・`count` のキーが無いことを確かめる。
    Action の出力として公開されるのは filter-files の step の出力だけである (R-ACT-002)。filter-files の段で失敗するケースでは、get-changed-files の step の出力に `files` が残る。
  - 3001 件の差分は、LCF と同じく index への直接の登録で作り、期待値ファイルとの比較で検証する。
- 期待値ファイルとの比較 (LCF・MAINF・RUNF 共通): 大量のパス (120000 / 120001 バイト、3001 件) と特殊文字のパスのケースは、実際の出力を期待値ファイル `expected.txt` と比べて検証する。git はスタブにしない (REQ-NF-001、DR-15)。
  - `gf_setup` の一時ディレクトリ (`GF_TMP_ROOT`) を作業領域とし、その下のサブディレクトリを実 git リポジトリとして初期化する。
  - `GF_TMP_ROOT` の直下 (リポジトリの外) に、fixture のパス一覧 `paths.txt` と期待値 `expected.txt` を作る。
  - リポジトリへは `paths.txt` から index への直接の登録で入れ、コミットする。
  - 実際の出力 (LCF は stdout、MAINF / RUNF は `$GITHUB_OUTPUT` から取り出した `files`) を `expected.txt` と `diff` で比べる。
  - `expected.txt` は `paths.txt` を `LC_ALL=C sort` で並べたものとする (`git diff --name-only` はパスをバイト順に出す)。
    `"`・`\`・タブを含むパスは git の引用表記 (例: `"a\"b.sh"`) に変える。この変換は内部ヘルパー 1 か所にまとめる。
  - 境界のケースでは、実行前に `paths.txt` から作る一覧のバイト数 (LF で連結、末尾の LF なし) が 120000 / 120001 であることを確かめる。
  - 対象のコードは `gf_run_in <repo>` で実行し、テストの中で `cd` しない。後始末は `AfterEach 'gf_cleanup'` に任せる。
  - fixture は `gf_setup` の後、`It` の中で作り、作成の失敗を `It` の中で検出する (`BeforeEach` が失敗すると ShellSpec は `AfterEach` を実行しない)。
- 環境変数の隔離 (MAINF・RUNF 共通): スクリプトが読む環境変数 (`BEFORE_SHA`・`AFTER_SHA`・`GITHUB_OUTPUT`・`GITHUB_EVENT_NAME`・`GITHUB_REF`・`GITHUB_EVENT_DELETED`・`GITHUB_*_SHA`・`INPUT_*`) とライブラリのロードガード変数 (`*_LIB_LOADED`) は、ケースごとにすべて明示的に設定するか unset してから実行する。
  ランナーや開発者の環境の値 (例: ランナーの実際の `GITHUB_OUTPUT`) を漏れ込ませないためである。書き方は `_ca-filter-files` の functional テスト (`INPUT_FILES` の unset、`GITHUB_OUTPUT` の export) に合わせる。ただし RUNF は step ごとに別の出力ファイルを使うため、`GITHUB_OUTPUT` を export せず、各 step の実行時に env で渡す。
- 所要時間の記録 (LCF・MAINF・RUNF 共通): 所要時間はテストの合否に使わない (実行環境で大きく変わり、閾値は不安定なテストを生むため)。
  - fixture を index へ直接登録する内部ヘルパーで、`EPOCHREALTIME` により fixture の作成と対象のコードの実行の所要時間を測る。
  - 環境変数 `GCF_FIXTURE_TIMING` (出力先ファイルのパス) が設定されているときだけ、ケース ID と 2 つの所要時間を 1 行ずつ追記する。行の書式は `<ケース ID> fixture=<秒>.<マイクロ秒 6 桁> run=<秒>.<マイクロ秒 6 桁>` とし、3 つの欄をタブで区切る。未設定なら何もしない。
  - Windows から `runners/run-shellspec.sh` で実行すると、ShellSpec は WSL 上で動き、渡される環境変数は `SKIP_INTEGRATION_TESTS` だけである (`runners/libs/wsl.lib.sh`)。
    記録するときは `WSLENV=GCF_FIXTURE_TIMING/p` を併せて設定してパスを WSL 側へ変換して渡すか、WSL のシェルから直接実行する。
  - 実ファイル方式との比較はテストに含めない。記録した所要時間を見てユーザーが方式の見直しを求めた場合に限り、一時的なスクリプト (コミットしない) で 1 回だけ測り、結果を PR に記録する。

---

## 2. Implementation Plan

### Phase 1: Library (list-changes)

Phase 1 の開始前に、全テストを 1 回実行して結果をベースラインとして記録する。
ベースラインで既に FAIL しているテストは、本計画の変更と切り分けて報告する (中断はしない)。
各コミットの後、ベースラインで PASS していた本モジュール外のテストが FAIL した場合は、次のコミットへ進まずに報告する。

#### Commit 1: feat(get-changed-files): add get-changed-files.lib.sh with list_changed_files

- `scripts/_libs/get-changed-files.lib.sh` を作る (ロードガード、`GCF_MAX_FILES_BYTES`、LCF が出すエラーの文言 (R-DIF-002・R-DIF-003))
  - 各部分は、それを検証する T-GCF-LCF-* の RGR で入れる。ロードガードは T-GCF-LCF-20 で入れる
  - `output.lib.sh` の読み込みと関数の存在確認、`main` だけが使うエラーの文言は、Phase 2 Commit 1 で入れる (LCF は使わず、検証するテストも MAINF にある)
  - v2.3.1 で `_gcf_error` と共通の文言の定数を共有ライブラリ (`gha_error`、`GHA_*`)、バイト数の検査を `check_byte_limit` に置き換え、関数の存在確認を廃止した
- LCF を追加する (R-DIF-001〜R-DIF-004)
- T-GCF-LCF-*: 実 git fixture で次を検証する
  - 変更・追加・リネーム (新しいパスだけ)・空白を含むパス・非 ASCII のパス (引用表記なし)
  - 削除だけの差分・同じツリー・型の変更 (`T`) は空の一覧
  - 空ツリー SHA を before にした場合の全ファイル
  - `a"b.sh`・`a\b.sh`・タブを含むパスは引用表記のまま返す (index への直接の登録で作る)
  - 不在のコミットでの git の失敗 (git の stderr の後に `::error::files: failed to list changed files` の 1 行)
  - 120000 バイトちょうどを受け付け、120001 バイトでエラーとなる (値はバイト数、一覧を出さない)
  - ライブラリを 2 回読み込んでも、`readonly` の再定義エラーが起きず、`list_changed_files` を呼べる (エッジケース)
- `module.md` の「テスト対象の略語」に `LCF` を追記する

### Phase 2: Entry Script

#### Commit 1: feat(get-changed-files): rewrite get-changed-files.sh entry point

- `scripts/get-changed-files.sh` の `main` を書き直す (R-DIF-010〜R-DIF-016)。`filter.lib.sh` を読み込まず、`get-changed-files.lib.sh` を読み込む
- `get-changed-files.lib.sh` に、`output.lib.sh` の読み込みと関数の存在確認 (ガード変数の設定より前)、`main` が出すエラーの文言 (R-DIF-010〜R-DIF-013・R-DIF-016) の定数を追加する
  - v2.3.0 で関数の存在確認を廃止し、ガード変数の設定を判定の直後へ移した。v2.3.1 で共通の文言は `_libs/error.lib.sh` の `GHA_*` に移した
- `count` と `PATTERN` の扱いを削除する (絞り込みと件数は filter-files の段が担う)
- 旧 functional テスト (`T-gcf-*`) を削除し、同じファイルを T-GCF-MAINF-* で書き直す (R-DIF-031)
  - AC-009 (削除を含めない)、AC-010 (非 ASCII)、AC-015 (同じツリー・削除だけ) を検証する
  - `BEFORE_SHA`・`AFTER_SHA`・`GITHUB_OUTPUT` の空、書き込めない出力先 (ディレクトリ)、git の失敗、バイト数の超過で、エラーを 1 件出し、出力先に何も書かないことを検証する
  - 検査が複数当たる入力で、R-DIF-010〜R-DIF-013 の順のとおり最初の 1 件だけが報告されることを確かめる。例: `BEFORE_SHA` と `GITHUB_OUTPUT` がともに空なら `BEFORE_SHA` のエラーだけが出る
  - `write_multiline_output` を差し替えて書き込みを失敗させ、R-DIF-016 のエラー (値は出力先のパス) が出ることを検証する
  - 行全体が `EOF` のパスがある場合に区切り文字が `EOF_1` になることを検証する
  - (v2.3.0 で削除) 継承されたロードガード変数の検出 (旧 T-GCF-MAINF-14) は、依存関数の確認の廃止に伴い行わない
- `module.md` の「テスト対象の略語」に `MAINF` を追記する
- この時点の action.yml は旧構成のままで、新しい `main` と合わない。Phase 3 で揃える (同じ PR の中の途中状態とする)。`test-get-changed-files` ジョブが通るのは Phase 4 の後とする

### Phase 3: Action Definition and Legacy Removal

#### Commit 1: feat(get-changed-files): chain internal scripts in action.yml

- `action.yml` を 3 つの step の構成に書き直す (R-ACT-001〜R-ACT-032)
  - 入力 `before-sha`・`after-sha` を削除し、`commit-count` (既定値 `"1"`) を追加する。`pattern` の説明を glob に改める
  - 出力 `files`・`count` は `steps.filter-files.outputs.*` を値とする
  - `description` と `# src:` ヘッダーを改める
- T-GCF-GACT-*: R-ACT-001〜R-ACT-003、R-ACT-010〜R-ACT-013、R-ACT-020〜R-ACT-023、R-ACT-030〜R-ACT-032、R-ACT-040〜R-ACT-046 を静的に検査する
- actionlint / ghalint を通過する (REQ-C-004)
- `module.md` の「テスト対象の略語」に `GACT` を追記する

#### Commit 2: refactor(get-changed-files): remove legacy filter.lib.sh

- `scripts/_libs/filter.lib.sh` と `scripts/_libs/__tests__/unit/filter.unit.spec.sh` を削除する (R-DIF-030、R-DIF-031、DR-09)
- T-GCF-GACT-* に R-DIF-032 (`filter.lib.sh` が無く、旧関数の定義が無い) と R-DIF-033 (上限の値が filter-files と一致する) を追加する

#### Commit 3: test(get-changed-files): add step chain functional tests

- T-GCF-RUNF-*: 配置をコピーした一時ディレクトリで、3 つのスクリプトを action.yml と同じ順に実行する
  - AC-001 (push)、AC-003 / AC-004 (その他イベントと commit-count)、AC-005 (不正な commit-count)
  - pull_request: base と head が分岐した fixture で、`files` が tasks.md T-04-01-02 の期待値 (base 側だけの変更を含み、base 側だけの追加を含まない二点比較の結果) と一致することを確かめる (AC-002 の流れの局所的な確認。実イベントでの検証は CI ジョブ)
  - AC-006〜AC-008 (除外を含む複数行の pattern、空の pattern、一致 0 件)
  - AC-011 (ダブルクオートを含むパス)、AC-012 (3001 行・120000 バイト以下)、AC-013 (1 コミットの履歴)
  - AC-014 (作業ディレクトリに `.github/actions` が無い)、AC-018 (`!` だけの行、101 行の pattern)
  - 失敗系では、失敗した step より後の step が実行されず (その step の `$GITHUB_OUTPUT` が作られない)、filter-files の step の出力に `files` / `count` が無いことを確かめる
  - step の env の `""` が呼び出し元の `INPUT_BEFORE_SHA` に優先すること (DD-ACT-02) は RUNF では確かめない。RUNF は action.yml を読まずに env を自前で組み立てるため、GACT (T-GCF-GACT-19) が step の env の値を静的に検査する
- `module.md` の「テスト対象の略語」に `RUNF` を追記する
- `GCF_FIXTURE_TIMING` を設定して全テストを 1 回実行し (Windows からの実行時は §1.3「所要時間の記録」の `WSLENV` の指定に従う)、大量のパスのケース (LCF の 120000 / 120001 バイト、RUNF の 3001 件) の所要時間を PR に記録する

### Phase 4: CI Job

#### Commit 1: ci(workflows): rework test-get-changed-files job

- `.github/workflows/_tests_ca_composite-actions.yml` の `test-get-changed-files` ジョブを、R-IDX-001〜R-IDX-007 に従って書き直す
  - pull_request: `pattern` を空にして実行し、`files` と `count` が `git diff` の結果と一致することを確かめる (R-IDX-002)
  - その他イベント: 2 ファイルの一時コミットを作り、4 つのケースを検証する (R-IDX-003、R-IDX-004)
  - 失敗系: `commit-count: "0"` と `!` だけの `pattern` を `continue-on-error: true` で実行し、outcome が `failure` であることを確かめる (R-IDX-005、R-IDX-007)
    - あわせて、失敗した step の `files`・`count` の出力が空であることを Verify ステップで確かめる (spec の R-IDX-005 / R-IDX-007 は outcome だけを求めており、その上に追加する検査とする)
  - 後始末: 一時コミットを取り消す (R-IDX-006)
  - `before-sha` / `after-sha` を渡すステップと、pathspec を前提とした `*.txt` のステップを削除する
- summary ジョブは変更しない (ジョブ名を変えないため)
- 保護領域 (`.github/workflows/*.yml`) の変更のため、PR に変更理由を明記する
- 1.1 の完了条件をすべて確認する (テスト ID の機械検査 A / C を含む)

PR 本文には、REQ-C-008 の 5 項目 (破壊的変更と移行方法) を記載する (R-IDX-020)。

---

## 3. Change History

<!-- SemVer: MAJOR = approach discarded, MINOR = interface, contract, premise or design policy changed,
     PATCH = additions within the existing policy or clarification. Keep frontmatter `version` equal to the newest row.
     `based-on` must cite a three-part version that exists in specifications-index.md.
     See docs/.deckrd/rules/deckrd-rule-document-versioning.md -->

| Date       | Version | Description                                                                                                                                                                                                                                             |
| ---------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-10-30 | 1.0.0   | Initial implementation plan (rewrite for #134; replaces the unversioned plan)                                                                                                                                                                           |
| 2026-10-30 | 1.0.1   | Apply impl explore review: R-DIF-016 via stubbed writer, GACT covers step layout and full env values, index-direct fixtures for special/long/many paths, RUNF failure output check, error wording in lib constants, ID check method, stated assumptions |
| 2026-10-30 | 1.0.2   | Verify large and special-path cases by comparing outputs with fixture and expected files beside a real git repo in the temp dir (no git stub); bulk index registration via --index-info                                                                 |
| 2026-10-30 | 1.0.3   | Record fixture build and run time via GCF_FIXTURE_TIMING (no timing assertions); record limit-case timings in the PR                                                                                                                                    |
| 2026-10-30 | 1.0.4   | Add a MAINF case for an inherited OUTPUT_LIB_LOADED: the dependency check fails and nothing is written                                                                                                                                                  |
| 2026-10-30 | 1.0.5   | Apply impl harden review: cite DR-15, user decides on a real-file timing comparison (W-01), RUNF event env per case (GF-01), env isolation for MAINF and RUNF (GF-02)                                                                                   |
| 2026-10-30 | 1.0.6   | Apply impl fix review: unify terms (index への直接の登録, 期待値ファイルとの比較), WSLENV for GCF_FIXTURE_TIMING, move the R-DIF-016 case under MAINF, reorder test items, map entry steps to spec Step 1-4                                             |
| 2026-10-30 | 1.0.7   | Apply impl second opinion: RUNF failure checks the filter-files step output only, add a RUNF pull_request case, CI failure cases also check empty files / count                                                                                         |
| 2026-10-30 | 1.0.8   | Record the dependency-check message of get-changed-files.lib.sh, and the MAINF helpers (bash run for normal cases, subshell source and stub for R-DIF-016)                                                                                              |
| 2026-10-30 | 1.0.9   | Include the library load guard variables (*_LIB_LOADED) in the env isolation of MAINF and RUNF (tasks harden GF-03)                                                                                                                                     |
| 2026-10-30 | 2.2.0   | Unify document versions to 2.2.0 and approve                                                                                                                                                                                                            |
| 2026-10-30 | 2.2.1   | Split the library build: the load guard comes with T-GCF-LCF-20, and the output.lib.sh loading, dependency check and main-only error wording move to Phase 2 Commit 1                                                                                   |
| 2026-10-30 | 2.2.2   | Add --end-of-options to the git diff of LCF (spec diff v2.2.1)                                                                                                                                                                                          |
| 2026-10-30 | 2.2.3   | Fix the DR range (DR-16) and the spec diff version in 1.2, defer the empty form of _gcf_error to Phase 2 Commit 1, define the timing line format                                                                                                        |
| 2026-10-30 | 2.2.4   | Match the code: the empty form of _gcf_error is used with fewer than 3 arguments (target only), and main maps any validate_output_file failure to R-DIF-013 (an empty GITHUB_OUTPUT stops at step 1)                                                    |
| 2026-10-30 | 2.2.5   | List R-ACT-001..003 and R-ACT-030..032 among the GACT checks of Phase 3 Commit 1, as tasks.md T-03 covers them                                                                                                                                          |
| 2026-10-30 | 2.2.6   | RUNF no longer checks the INPUT_BEFORE_SHA override (DD-ACT-02); GACT checks the step env statically, as tasks.md T-04 states                                                                                                                           |
| 2026-10-31 | 2.2.7   | Match the RUNF tests: the pull_request case compares files with the tasks.md T-04-01-02 expected list, and RUNF passes GITHUB_OUTPUT per step instead of exporting it                                                                                   |
| 2026-10-31 | 2.3.0   | Set the load guard first and return 1 on a failed shared library load; drop the declare -F dependency check and its error (removes T-GCF-MAINF-14)                                                                                                      |
| 2026-10-31 | 2.3.1   | Use the shared gha_error, GHA_* wording constants and check_byte_limit instead of _gcf_error, the duplicated wording constants and the inline byte check                                                                                                |
| 2026-10-31 | 2.3.2   | Assign the shared GHA_MAX_ENV_VALUE_BYTES of _libs/constants.lib.sh to GCF_MAX_FILES_BYTES; GACT compares the right-hand sides                                                                                                                          |
| 2026-10-31 | 2.3.3   | Follow requirements v2.3.0 (REQ-C-006): scope includes the shared-library additions; drop the stale _gcf_error from Phase 1 Commit 1                                                                                                                    |
