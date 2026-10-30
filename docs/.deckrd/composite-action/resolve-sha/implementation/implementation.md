---
title: "Implementation Plan: _ca-resolve-sha"
based-on: specifications-index.md v2.1.1
status: Draft
version: 1.1.4
created: "2026-10-25"
---

## 1. Overview

### 1.1 Purpose

`ca-get-changed-files` 内の base/head SHA 解決ロジックを、内部 Composite Action `.github/actions/_ca-resolve-sha/` として新設する。
実装する機能は、push / pull_request / その他イベントの SHA 解決、HEAD~N と空ツリー SHA へのフォールバック、オーバーライド入力、`resolution` 出力とする。
評価順序は specifications-index.md §4 に従う。

本計画の範囲は、Composite Action の作成までとする。Phase 5 の完了は単体実装の完了を意味し、ランナー上での動作検証は #134 で行う (DR-27)。

- 既存のワークフローとアクションは変更しない。`ca-get-changed-files` への組み込みは #134 の別タスクとする。
- 本計画による共有ライブラリ `.github/actions/_libs/` への変更は、REQ-C-008 の追加 (ロードガード、VPI、WO) に限る。
  `error.lib.sh`・`constants.lib.sh`・`check_byte_limit` は、後に get-changed-files モジュールが追加した。`rs_error` はその `gha_error` の互換ラッパーとなった (tasks.md T-15)。
- 完了条件は、次のすべてを満たすこととする。
  - actionlint / ghalint を通過する
  - ShellSpec の全テストに `not ok` が無い
  - `pnpm lint:sh` (shellcheck) と `pnpm check:sh` (shfmt) を通過する
  - テスト ID の機械検査 A〜D を通過する

**実装品質基準 (全コミット共通):**

- 各コミットの中で BDD の RGR サイクルを回す。テストが FAIL することを確認してから実装し、PASS を確認してからコミットする。
- テストとその実装は同じコミットに含める。
- テスト ID は `T-RS-<略語>-NN` とする (functional は `T-RS-MAINF-NN`)。ケース名には `[Normal]` / `[Error]` / `[Edge]` を付ける。
- テストの実行は `runners/run-shellspec.sh` 経由で行う。
- 各コミットで `pnpm lint:sh` と `pnpm check:sh` を通す。
- テストを追加したコミットでは、テスト ID の機械検査 B / D (付与網羅性・重複・scope 整合性、略語表との一致) を実行する。検査 A / C は Phase 5 で実行する。
- 内部シンボルは先頭アンダースコアで区別し、ライブラリ内でグローバルな `SCRIPT_DIR` を上書きしない。
- MAIN は環境変数を `${VAR:-}` の形で読み、未設定を空文字として扱う。IC のように想定内で 0 以外を返す関数は、`if` の条件として呼び、`set -e` で中断させない。

### 1.2 Reference

- Prior Art / Reference PR: PoC なし。既存実装 `ca-get-changed-files/scripts/_libs/filter.lib.sh` (`resolve_sha_for_event`、`resolve_before_sha`) を参照する。計画の構成は `setup-tool` の implementation.md に倣う。
- Specifications:
  - specifications-index.md v2.1.1
  - specifications-input.md v1.1.2
  - specifications-resolution.md v2.1.0
  - specifications-output.md v1.2.0
- Decision Records: DR-26、DR-27 (本計画で確定した判断)

### 1.3 Design Decisions

**実装単位と配置:**

| 単位                             | 略語 | 配置                                               |
| -------------------------------- | ---- | -------------------------------------------------- |
| validation.lib.sh のロードガード | VLG  | `.github/actions/_libs/validation.lib.sh`          |
| 正整数の検証                     | VPI  | `.github/actions/_libs/validation.lib.sh`          |
| key=value の出力                 | WO   | `.github/actions/_libs/output.lib.sh`              |
| エラー出力の補助                 | RE   | `_ca-resolve-sha/scripts/_libs/resolve-sha.lib.sh` |
| commit-count の正規化            | NCC  | 同上                                               |
| オーバーライドの判定             | VOV  | 同上                                               |
| partial clone の判定             | IPC  | 同上                                               |
| コミット存在の確認               | IC   | 同上                                               |
| コミットの検証                   | VC   | 同上                                               |
| HEAD~N の解決                    | RHN  | 同上                                               |
| SHA の解決                       | RSH  | 同上                                               |
| 出力の書き出し                   | EO   | 同上                                               |
| 入口                             | MAIN | `_ca-resolve-sha/scripts/resolve-sha.sh`           |
| Action 定義                      | ACT  | `_ca-resolve-sha/action.yml`                       |

関数のシグネチャは specifications-index.md §3.5 の impl-note に従う。

**確定した判断:**

- VPI と WO は共有ライブラリの関数であり、エラーを出さずに終了コードだけを返す。エラーは呼び出し側 (NCC、EO) がモジュール専用の RE で出す。既存のエラー形式は spec の形式と異なり、既存関数は変更できないため (DR-26)。
- VLG・VPI・WO のテストは、`_libs/__tests__/unit/` に新しいテストファイル (`*.spec.sh`) として置き、RS モジュールの `owns` にファイル単位で含める。旧形式の ID を使う既存のテストファイルには追加しない (DR-26)。
- WO は `write_output <file> <key> <value>` とし、出力先を引数で受け取る。`$GITHUB_OUTPUT` を読むのは MAIN だけとし、EO 経由で WO へ渡す (DR-26)。
  - 既存の `write_status` と異なり、出力先が空の場合に `/dev/null` へ黙って書かない。
- 出力の事前検査 (R-OUT-003 から R-OUT-006) は EO が正とする。WO は自身の安全のため、次の 2 つだけを終了コードで返す (DR-26)。
  - 終了コード 1: 不正な引数 (出力先が空、値に CR / LF を含む)
  - 終了コード 2: 書き込みの失敗
  - EO は WO の終了コード 2 を R-OUT-008 に対応付ける。終了コード 1 は事前検査の後には起きない想定であり、起きた場合も R-OUT-008 と同じく直ちに止まる。
- action.yml は、CI ジョブを追加せず、actionlint / ghalint と ShellSpec の静的検査 (ACT) で確かめる。ランナー上での実行検証は #134 で行う (DR-27)。
- `module.md` は `workspaces/module/module.md` に置いたまま、`owns` と略語表を記入する。
- テストは本物の git リポジトリを作るフィクスチャで行う (REQ-NF-001)。
  - フィクスチャは `_ca-resolve-sha/scripts/__tests__/helpers/git-fixture.sh` に置く。
  - 例ごとに `mktemp` で独立したディレクトリを作り、After で削除する (`.shellspec` の `--jobs 4` による並列実行に対応する)。
  - フィクスチャ内で `user.name` / `user.email` を設定する。partial clone は、元リポジトリで `uploadpack.allowFilter` を有効にして作る。
  - VPI の `<max>` と WO の `<key>` は、呼び出し側が妥当性を保証する内部引数とし、VPI / WO では検証しない。
  - Windows では `runners/run-shellspec.sh` が WSL で実行するため、フィクスチャの git は WSL 側のものとなる。

**関数ごとの実装上の詳細:**

specifications-index.md §3.5 の impl-note を補う。tasks.md はこの記述に従う。

- IPC はエラーを出さず、終了コードで状態を返す。エラーは RSH が RE で出す (R-RES-008、R-RES-010)。
  - 終了コード 0: partial clone である
  - 終了コード 1: 該当なし (git リポジトリでない場合を含む)
  - 終了コード 2: 設定の参照に失敗した
- NCC は、確定した commit-count (N) を stdout に 1 行で出す。エラー時は stdout に何も出さない。
- RE は stdout に何も出さず、stderr に 1 行だけ出す。
  - 第 3 引数 (値) を省略した場合は、空の形式 (`::error::<対象>: value must not be empty`) を出す。
  - 値を渡した場合は、空文字列であっても通常の形式 (`(got: '<値>')`) を出す。
- RSH は、オーバーライドの値が両方とも空でない場合に override の経路と判定する。組み合わせと形式は VOV で検証済みとする。
- EO のエラーの対象は、step の出力キー (`before_sha` / `after_sha` / `resolution`) とする。出力先の異常は `GITHUB_OUTPUT` を対象とする。
- エラーの問題を説明する文言は、英語の短い句とする。テストでは `::error::` の接頭辞、対象、`(got: '<値>')` の部分を確かめ、問題の文言は固定しない。

---

## 2. Implementation Plan

### Phase 0: Preparation (Documents)

#### Commit 1: docs(ca/resolve-sha): declare module ownership and test abbreviations

- `workspaces/module/module.md` の `owns` に、次の 4 つを記入する
  - `.github/actions/_ca-resolve-sha/**`
  - `_libs/__tests__/unit/validation-load-guard.unit.spec.sh`
  - `_libs/__tests__/unit/validate-positive-int.unit.spec.sh`
  - `_libs/__tests__/unit/write-output.unit.spec.sh`
- 略語表に VLG、VPI、WO、RE、NCC、VOV、IPC、IC、VC、RHN、RSH、EO、MAIN、ACT を記入する

### Phase 1: Shared Library Additions

既存のテストが 1 件でも FAIL した場合は、Phase 1 を中断し、次のコミットへ進まずに報告する。
対象は、既存の `_libs` のテストと、既存の利用元 (`ca-setup-repo`、`ca-setup-tool`、`ca-validate-environment`) のテストとする。

#### Commit 1: feat(actions/libs): add load guard to validation.lib.sh

- `VALIDATION_LIB_LOADED` によるロードガードを追加する (`env.lib.sh` / `output.lib.sh` と同じ書き方)
- T-RS-VLG-* (`validation-load-guard.unit.spec.sh`)
- 既存の `_libs` のテストと、既存の利用元のテストが PASS することを確認する

#### Commit 2: feat(actions/libs): add validate_positive_int

- VPI (`validate_positive_int <value> <max>`) を追加する。エラーは出さず、終了コードだけを返す
- 桁数を判定してから数値として比較する。`<max>` の桁数 (`<max>` が 1000 なら 4 桁) を超える値は不正とする
- T-RS-VPI-*: 境界値 1000 / 1001 / 10000、20 桁の数字列、先頭ゼロ、空白、負数、非数値

#### Commit 3: feat(actions/libs): add write_output

- WO (`write_output <file> <key> <value>`) を追加する。key=value を引数の出力先に追記する
- 不正な引数 (出力先が空、値に CR / LF を含む) は終了コード 1、書き込みの失敗は終了コード 2 で返す。エラーは出さない
- T-RS-WO-*
- T-RS-WO-*: 出力先に既存の内容がある場合も、上書きせず追記することを確かめる

### Phase 2: Input Validation

#### Commit 1: feat(ca/resolve-sha): add module library skeleton and error helper

- `scripts/_libs/resolve-sha.lib.sh` の骨格を作る (ロードガード、空ツリー SHA の定数)
- RE を追加する。specifications-index.md §3.3 の形式で出し、値の `%` / CR / LF をエンコードする。値が空の場合の形式にも対応する
- T-RS-RE-*

#### Commit 2: feat(ca/resolve-sha): add normalize_commit_count

- NCC を追加する (R-IN-001 から R-IN-003)。検証は VPI を使い、エラーは RE で出す
- T-RS-NCC-*

#### Commit 3: feat(ca/resolve-sha): add validate_override

- VOV を追加する (R-IN-004 から R-IN-007)。`none` / `override` を判定し、片方のみの指定と形式の不一致をエラーにする
- T-RS-VOV-*

### Phase 3: SHA Resolution

#### Commit 1: test(ca/resolve-sha): add git repository fixture helper

- テスト用に本物の git リポジトリを作るヘルパー `scripts/__tests__/helpers/git-fixture.sh` を追加する
- 直線履歴、merge、shallow clone (`--depth`)、partial clone (`--filter`)、オブジェクトの欠損を作れるようにする
- shallow clone は `file://` の URL から作る。ローカルのパスを指定した clone では `--depth` が無視され、完全な履歴になるため
- 例ごとに独立した一時ディレクトリを使い、After で削除する

#### Commit 2: feat(ca/resolve-sha): add is_partial_clone

- IPC を追加する。設定の参照結果を、該当あり / 該当なし / 参照の失敗の 3 状態で返す (R-RES-008、R-RES-010)
- T-RS-IPC-*

#### Commit 3: feat(ca/resolve-sha): add commit verification

- IC (エラーを出さないコミット存在の確認) と VC (R-RES-021、R-RES-024、R-RES-025) を追加する。空ツリー SHA は免除しない
- T-RS-IC-*、T-RS-VC-*

#### Commit 4: feat(ca/resolve-sha): add resolve_head_n

- RHN を追加する (R-RES-011 から R-RES-015)。HEAD は 1 回だけ OID に解決し、以降はその OID を起点にする
- 世代数は第一親の系列だけで数える
- T-RS-RHN-*: merge と shallow の組み合わせ、オブジェクトの欠損、fetch-depth の境界

#### Commit 5: feat(ca/resolve-sha): add resolve_sha validation gates and override route

- RSH の検査部分を追加する: R-RES-001 (イベント名)、R-RES-009 (push の ref 種別。削除を先に判定)、R-RES-010 / R-RES-008 (partial clone)
- R-RES-002 (オーバーライドの経路) を追加する
- T-RS-RSH-*

#### Commit 6: feat(ca/resolve-sha): add resolve_sha event routes

- RSH のイベント別経路を追加する: R-RES-003 から R-RES-007 (push の通常解決とフォールバック、pull_request、その他イベント)
- T-RS-RSH-* (連番は Commit 5 の続き)

### Phase 4: Output and Entry Point

#### Commit 1: feat(ca/resolve-sha): add emit_outputs

- EO (`emit_outputs <file> <before> <after> <resolution>`) を追加する (R-OUT-001 から R-OUT-008)。出力先は引数で受け取る
- 最初の書き込みの前に事前検査 (R-OUT-003 から R-OUT-006) をすべて終え、WO が 0 以外を返した時点で直ちに止まる (R-OUT-008、DR-26)
- エラーは RE で出す
- T-RS-EO-*
- T-RS-EO-*: 2 回目の WO を失敗させた場合に直ちに止まり、1 件目の出力が残ることを確かめる (R-OUT-008、DR-18。テスト内で WO を差し替える)

#### Commit 2: feat(ca/resolve-sha): add resolve-sha.sh entry point

- MAIN (`scripts/resolve-sha.sh`) を追加する。環境変数 (`$GITHUB_OUTPUT` を含む) を読む唯一の箇所とし、NCC → VOV → RSH → EO の順に呼ぶ
- `set -euo pipefail`、ライブラリの読み込み、`BASH_SOURCE` ガードは `ca-get-changed-files/scripts/get-changed-files.sh` の書き方に合わせる
- T-RS-MAINF-* (functional): specifications-index.md §4 の評価順序、AC-022 の組み合わせ、成功時の 3 出力
- T-RS-MAINF-*: partial clone のフィクスチャで、`git fetch` の子プロセスが起動されないことを確かめる (AC-018。`GIT_TRACE` の出力で確認する)

### Phase 5: Action Definition

#### Commit 1: feat(ca/resolve-sha): add action.yml

- `_ca-resolve-sha/action.yml` を作成する。inputs は既定値を明示し、outputs は kebab-case とする
- REQ-C-006 の環境変数を step の `env` で対応付ける。`run` 内に `${{ }}` を書かない
- T-RS-ACT-*: action.yml を grep で静的に検査する (外部ツールは増やさない、DR-27)
  - REQ-C-006 の 10 個の環境変数が step の `env` にそろっている
  - `run` 内に `${{ }}` が無い
  - outputs が `before-sha` / `after-sha` / `resolution` の 3 つである
  - outputs の `value` が、実在する step ID の出力を参照している
  - 10 個の環境変数が、`run` を持つ同じ step の `env` にある
- 1.1 の完了条件をすべて確認する (テスト ID の機械検査 A / C を含む)
- 既存のワークフローとアクションは変更しない

---

## 3. Change History

<!-- SemVer: MAJOR = approach discarded, MINOR = interface, contract, premise or design policy changed,
     PATCH = additions within the existing policy or clarification. Keep frontmatter `version` equal to the newest row.
     `based-on` must cite a three-part version that exists in specifications-index.md.
     See docs/.deckrd/rules/deckrd-rule-document-versioning.md -->

| Date       | Version | Description                                                                                                                            |
| ---------- | ------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-10-25 | 1.0.0   | Initial implementation plan                                                                                                            |
| 2026-10-25 | 1.1.0   | Apply explore review: shell lint and test ID checks, WO takes output file, action.yml static check, fixture placement                  |
| 2026-10-25 | 1.1.1   | Apply harden / fix review: spec impl-note moved out of Phase 0, Phase 1 stop condition, DR-26/27 refs, wording                         |
| 2026-10-25 | 1.1.2   | Apply codex review: action.yml wiring checks, no-fetch and partial-write tests, file:// shallow fixture, env and exit-code handling    |
| 2026-10-25 | 1.1.3   | Add per-function implementation details (IPC exit codes, NCC stdout, RE forms, RSH override detection, EO error target, error wording) |
| 2026-10-31 | 1.1.4   | Note that error.lib.sh / constants.lib.sh / check_byte_limit came later from get-changed-files and rs_error now wraps gha_error        |
