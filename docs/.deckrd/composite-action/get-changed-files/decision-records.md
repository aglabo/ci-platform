---
title: "Decision Records: ca-get-changed-files"
based-on: requirements.md v2.1.2
module: "composite-action/get-changed-files"
status: approved
version: 1.4.0
created: "2026-10-29"
---

## DR-01: 差分範囲の SHA 解決を `_ca-resolve-sha` に任せる

**Phase**: req
**Status**: Accepted

### Context

現行の Action は、`filter.lib.sh` の `resolve_sha_for_event` / `resolve_before_sha` で SHA を解決している。
push と pull_request 以外のイベントは `Unsupported event` で失敗し、force push や履歴不足にも対応していない。
同じ規則は内部 Action `_ca-resolve-sha` (#135) に切り出され、これらのケースにも対応している。

### Decision

SHA の解決は `_ca-resolve-sha` のスクリプトで行い、本 Action のスクリプトとライブラリから SHA 解決のコードを削除する。

### Alternatives Considered

- 現行の `resolve_sha_for_event` を残し、その他イベントの分岐だけを足す。規則が 2 か所に分かれるため不採用。

### Rationale

SHA 解決の規則と入力検証を 1 か所にまとめ、イベントへの対応を `_ca-resolve-sha` の改訂だけで広げられる。

### Consequences

- Positive:
  - すべてのイベントで動作する
  - force push、新規ブランチ、履歴不足を `_ca-resolve-sha` の規則で扱える
- Negative:
  - push のブランチ削除・タグの push がエラーになる (`_ca-resolve-sha` REQ-F-020)。現行はタグの作成を受け付けていた

### Related

- REQ-F-001
- REQ-F-002
- REQ-F-008
- REQ-C-008

---

## DR-02: 変更ファイルの絞り込みを `_ca-filter-files` に任せる

**Phase**: req
**Status**: Accepted

### Context

現行の `pattern` は `git diff` に渡す git pathspec であり、1 つしか指定できず、除外もできない。
glob の照合と出力の書き出しは、内部 Action `_ca-filter-files` (#136) が提供している。

### Decision

`git diff` には pathspec を渡さずに全変更ファイルを取得し、`_ca-filter-files` のスクリプトで絞り込む。
出力 `files` / `count` は `_ca-filter-files` が書き出した値をそのまま公開する。

### Alternatives Considered

- pathspec のまま、複数行を複数の pathspec として `git diff` に渡す。`git diff` の外で使えず、除外に pathspec magic が要るため不採用。

### Rationale

照合規則と出力の書式を `_ca-filter-files` に一本化し、本 Action は一覧の取得だけを持つ。

### Consequences

- Positive:
  - 複数パターンと除外を 1 つの入力で表せる
  - 本 Action のローカル `write_multiline_output` を削除できる (`_ca-filter-files` DR-07)
- Negative:
  - pathspec 固有の書き方 (例: パスの途中に一致する `*.txt`) が使えなくなる

### Related

- REQ-F-003
- REQ-F-004
- REQ-F-005
- REQ-F-008

---

## DR-03: 入力 `before-sha` / `after-sha` を削除し、`commit-count` に置き換える

**Phase**: req
**Status**: Accepted

### Context

`_ca-resolve-sha` は、`ca-get-changed-files` の置き換えを単純にするため、オーバーライド入力 `before-sha` / `after-sha` を持つ (`_ca-resolve-sha` DR-07)。
一方 Issue #134 は、本 Action の入力を `commit-count` 1 つにすることを求めている。

### Decision

本 Action から `before-sha` / `after-sha` を削除し、`commit-count` (default "1") を追加する。
`_ca-resolve-sha` のオーバーライド入力には常に空文字列を渡す。

### Alternatives Considered

- `before-sha` / `after-sha` を残し、`commit-count` を並べて追加する。2 種類の SHA 入力の優先順位を決める必要があり、インターフェースが複雑になるため不採用 (Issue #134)。

### Rationale

呼び出し元は SHA を組み立てずに済み、入力は数値 1 つになる。現在の呼び出し元はテストジョブだけであり、移行の影響が小さい。

### Consequences

- Positive:
  - 入力が単純になる
- Negative:
  - 呼び出し元は任意の SHA の組を指定できなくなる (破壊的変更)
  - `_ca-resolve-sha` のオーバーライド機能は、本 Action からは使われない

### Related

- REQ-F-001
- REQ-F-002
- REQ-C-005
- REQ-C-008

---

## DR-04: 入力名 `pattern` を維持し、意味だけを glob に変える

**Phase**: req
**Status**: Accepted

### Context

`_ca-filter-files` の入力名は複数形の `patterns` とし、本 Action の既存の入力名は `pattern` となっている。

### Decision

本 Action の入力名は `pattern` のままとし、値を 1 行 1 個の glob パターン (`!` で除外) として扱う。

### Alternatives Considered

- `patterns` に改名して内部 Action とそろえる。破壊的変更が 1 つ増えるため不採用。

### Rationale

`*.yml` のような単純な glob は、改訂前後で書き換えずに使える。

### Consequences

- Positive:
  - 呼び出し元の書き換えが、pathspec 固有の書き方を使っている箇所だけで済む
- Negative:
  - 公開入力と内部入力で名前が異なる

### Related

- REQ-F-004
- REQ-C-005

---

## DR-05: 内部 Action は `uses:` ではなく、`${GITHUB_ACTION_PATH}/..` のスクリプトを直接実行して使う

**Phase**: req
**Status**: Accepted

### Context

Composite Action の中の `uses: ./.github/actions/_ca-*` は、呼び出し元リポジトリの checkout を基準に解決される。
このため、ci-platform 以外のリポジトリから本 Action を使うと、内部 Action が見つからずに失敗する。
リポジトリ内のテストジョブは ci-platform 自身を checkout するため、この失敗を検出できない。

### Decision

次の 2 つのスクリプトを run step で実行する。

- `${GITHUB_ACTION_PATH}/../_ca-resolve-sha/scripts/resolve-sha.sh`
- `${GITHUB_ACTION_PATH}/../_ca-filter-files/scripts/filter-files.sh`

内部 Action の `action.yml` が行っている env の対応付けは、本 Action の `action.yml` で同じ名前で行う。

### Alternatives Considered

- `uses: aglabo/ci-platform/.github/actions/_ca-resolve-sha@<sha> # vX.Y.Z` で自己参照する。
  内部 Action の契約をそのまま使えるが、リリースごとに pin を更新する必要があり、PR 中は古い版でテストされるため不採用。

### Rationale

`uses:` で参照された Action のリポジトリは同じ ref で全体が取得されるため、兄弟ディレクトリのスクリプトは常に本 Action と同じ版になる。

### Consequences

- Positive:
  - pin の更新が不要で、PR 中も同じ版の内部スクリプトでテストできる
- Negative:
  - env の対応付けを、内部 Action と本 Action の 2 か所で書くことになる。食い違いの検査方法は spec で定める
  - 内部 Action のディレクトリ構成 (`scripts/` の位置) に依存する

### Related

- REQ-F-007
- REQ-C-001

---

## DR-06: `git diff` は `core.quotePath=false` で実行する

**Phase**: req
**Status**: Accepted

### Context

`git diff` は既定で、非 ASCII 文字を含むパスを `"..."` の引用表記で出力する。
`_ca-filter-files` は、ダブルクオートを含む files の行を、デコードしていない引用表記とみなしてエラーにする (`_ca-filter-files` REQ-F-017)。

### Decision

`git -c core.quotePath=false diff ...` で実行し、非 ASCII 文字を含むパスをそのまま出力させる。
`"`・`\`・制御文字を含むまれなパスは引用表記のまま渡り、`_ca-filter-files` でエラー終了する。

### Alternatives Considered

- `git diff -z` で NUL 区切りで取得し、改行や `"` を含むパスを本 Action が先に検出する。実装量が増えるため不採用。
- 既定のままにする。日本語のパスを含む差分がエラーになるため不採用。

### Rationale

日本語などのパスを扱え、まれな特殊パスは `_ca-filter-files` の既存の検査でエラーとして検出できる。

### Consequences

- Positive:
  - 非 ASCII 文字を含むパスを扱える
- Negative:
  - `"` や `\` を含むパスがあると、差分を取得できずエラー終了する

### Related

- REQ-F-003
- REQ-F-006

---

## DR-07: `pattern` の有無に関わらず常に `_ca-filter-files` を通し、上限超過はエラーとする

**Phase**: req
**Status**: Accepted

### Context

`_ca-filter-files` は、files が 3000 行または 120000 バイトを超えるとエラーになる (`_ca-filter-files` REQ-F-018)。
`pattern` が空のときに `_ca-filter-files` を飛ばせば、全件取得では上限がなくなる。

### Decision

`pattern` が空でも常に `_ca-filter-files` を通す。上限を超える差分はエラー終了とし、上限を制約として明記する。

### Alternatives Considered

- `pattern` が空のときは `_ca-filter-files` を飛ばし、本 Action が `files` / `count` を出力する。出力の経路が 2 つになり、書式の検査も 2 か所で必要になるため不採用。

### Rationale

出力の経路と入力の検査を 1 つにそろえる。上限は GitHub の PR の差分の最大ファイル数 (3000) に合わせてあり、通常の利用では超えない。

### Consequences

- Positive:
  - 出力の書式と入力の検査が常に同じになる
- Negative:
  - 3000 件または 120000 バイトを超える差分は取得できない

### Related

- REQ-F-004
- REQ-F-006

---

## DR-08: 出力は `files` / `count` だけとし、`resolution` は公開しない

**Phase**: req
**Status**: Accepted

### Context

`_ca-resolve-sha` は、SHA の解決経路を `resolution` で通知する (`_ca-resolve-sha` DR-08)。
Issue #134 は、出力 `files` / `count` を変えないことを Non-Goals としている。

### Decision

本 Action の出力は `files` / `count` だけとし、`resolution` は内部でだけ扱う。

### Alternatives Considered

- `resolution` を出力に追加し、フォールバック時に全件検査へ切り替えるかを呼び出し元が判断できるようにする。Issue #134 の範囲を超えるため不採用。必要になれば後の改訂で追加する。

### Rationale

公開インターフェースの変更を、Issue #134 が求める範囲に限る。

### Consequences

- Positive:
  - 出力の契約が改訂前と同じになる
- Negative:
  - 呼び出し元は、範囲が HEAD~N や空ツリーへのフォールバックで決まったかを区別できない

### Related

- REQ-F-005
- REQ-NF-002

---

## DR-09: 旧ライブラリ `filter.lib.sh` はファイルごと削除する

**Phase**: review-harden
**Status**: Accepted

### Context

REQ-F-008 は 3 つの関数の削除を求め、ファイル自体の削除は「してよい」(MAY) としていた。
3 つの関数を削除すると、`filter.lib.sh` に残る関数は無い。

### Decision

`scripts/_libs/filter.lib.sh` とそのテスト (`scripts/_libs/__tests__/unit/filter.unit.spec.sh`) を削除しなければならない (MUST)。

### Alternatives Considered

- Option A: 空のライブラリとして残す。読み込む側が残り、AC-016 の検査対象 (定義の不在) とファイルの存在が食い違うため不採用。
- Option B: 新しい関数の置き場として `filter.lib.sh` を再利用する。名前が中身 (変更ファイルの取得) と合わないため不採用。新しい関数は `get-changed-files.lib.sh` に置く (spec)。

### Rationale

残す理由の無いファイルを MAY のままにすると、実装ごとに判断が分かれる。

### Consequences

- Positive:
  - 旧ロジックの痕跡がファイル単位で無くなり、AC-016 を単純に検査できる
- Negative:
  - 旧テストの ID (`T-rsv-*`・`T-rsl-*`・`T-wrt-*`) が失われる (DD-IDX-03 で `T-GCF-*` に置き換える)

### Related

- REQ-F-008
- AC-016

---

## DR-10: 対象リポジトリを作業ディレクトリに checkout することを呼び出し元の義務とする

**Phase**: review-harden
**Status**: Accepted

### Context

`_ca-resolve-sha` と `git diff` は `$PWD` で実行される。本 Action には、対象リポジトリの場所を受け取る入力が無い。
requirements v2.0.3 は、これを Assumptions に書いていた。

### Decision

REQ-C-003 に次を加える。呼び出し元は、対象リポジトリを作業ディレクトリ (`$GITHUB_WORKSPACE`) に checkout しなければならない (MUST)。
`actions/checkout` の `path` で別の場所に取得してはならない (MUST NOT)。この前提を `action.yml` の description に明記する (AC-017)。

### Alternatives Considered

- Option A: 対象リポジトリのパスを入力 (`working-directory` など) として受け取る。
  `_ca-resolve-sha` がパス入力を Out of Scope としており (`_ca-resolve-sha` DR-19)、内部 Action の変更 (REQ-C-006) を伴うため不採用。
- Option B: Assumptions のままにする。守られない場合に、別のリポジトリを対象に成功し得るため不採用。

### Rationale

partial clone の禁止と同じく、checkout の方法に関する前提であり、呼び出し元が守れる。

### Consequences

- Positive:
  - 呼び出し元の義務が REQ-C-003 にまとまる
- Negative:
  - サブディレクトリに checkout する構成 (複数リポジトリの checkout) では使えない

### Related

- REQ-C-003
- AC-017

---

## DR-11: `pattern` のサイズと非 UTF-8 のパスは前提とし、検査しない

**Phase**: review-harden
**Status**: Accepted

### Context

`pattern` が環境変数 1 つ分の上限を超えると、filter-files の step が起動できず `::error::` が出ない。
UTF-8 として不正なパスは、ランナーが step 出力を読むときに置き換えられ、`_ca-filter-files` で検出できないことがある。

### Decision

両者は Assumptions に残し、本 Action では検査しない。

### Alternatives Considered

- Option A: `pattern` のバイト数を本 Action で先に検査する。現実に起きない入力のための検査になるため不採用。
- Option B: 変更ファイルの一覧を一時ファイルで渡し、文字列変換を避ける。`_ca-filter-files` の入力契約の変更 (REQ-C-006) を伴うため不採用。

### Rationale

`pattern` は利用者が手で書く値であり、`_ca-filter-files` が 100 行に制限する。非 UTF-8 のパスは、まれにしか現れない。

### Consequences

- Positive:
  - 検査と受け渡しの構成が単純なまま保たれる
- Negative:
  - 前提が破れた場合、`::error::` が出ない失敗、または不正なバイトの置き換えが起こり得る

### Related

- REQ-F-004
- REQ-F-006

---

## DR-12: 3 つの step で構成し、env の対応付けの一致を静的に検査する

**Phase**: review-harden
**Status**: Accepted

### Context

本 Action は、`_ca-resolve-sha`・本 Action のスクリプト・`_ca-filter-files` の 3 つのスクリプトを順に実行する (DR-05)。
内部スクリプトはどちらも `main` と `emit_outputs` を定義するため、同じプロセスで読み込めない。
内部 Action の `action.yml` が行う env の対応付けは、本 Action の `action.yml` にも書く (DR-05 の Negative)。

### Decision

本 Action は 3 つの step (`resolve-sha`・`get-changed-files`・`filter-files`) で構成し、段間の値は step 出力と env で受け渡さなければならない (MUST)。
各 step の env の名前と式が、内部 Action の `action.yml` の step env と一致することを、静的検査 (GACT) で確かめなければならない (MUST)。
ただし、値の出どころが本 Action で変わる env は、名前だけを比べる。
対象は `INPUT_BEFORE_SHA`・`INPUT_AFTER_SHA` (空文字列を明示)、`INPUT_FILES` (前の step の出力)、`INPUT_PATTERNS` (入力 `pattern`) とする。

### Alternatives Considered

- Option A: `get-changed-files.sh` が 2 つの内部スクリプトを子プロセスとして順に呼ぶ。step は 1 つになる。
  ただし、内部スクリプトの出力 (`$GITHUB_OUTPUT`) は自前で受け渡すことになり、env の対応付けもスクリプト内に持つため不採用。
- Option B: env の一致を検査しない。内部 Action の env を変えたときに、本 Action だけが古い名前のまま動かなくなるため不採用。

### Rationale

step ごとに出力ファイルが分かれ、内部スクリプトの出力のキーが衝突しない。失敗した step の後続は、GitHub Actions が実行しない。

### Consequences

- Positive:
  - 内部スクリプトを変更せずに、そのまま使える
  - env の対応付けのずれを、実行せずに検出できる
- Negative:
  - 変更ファイルの一覧が環境変数を経由するため、環境変数の上限に依存する (DR-13)

### Related

- DR-05
- DD-ACT-01
- DD-ACT-03
- R-ACT-010
- R-ACT-040

---

## DR-13: 変更ファイルの取得の段でも 120000 バイトの上限を検査する

**Phase**: review-harden
**Status**: Accepted

### Context

変更ファイルの一覧は、環境変数 `INPUT_FILES` で絞り込みの段に渡す (DR-12)。
環境変数 1 つ分の上限 (約 131072 バイト) を超えると、絞り込みの段は起動できず、`::error::` が出ないまま失敗する。

### Decision

変更ファイルの取得の段は、`files` を書く前に、一覧のバイト数が 120000 を超えないことを検査しなければならない (MUST)。
上限は `_ca-filter-files` の上限 (`_ca-filter-files` REQ-F-018) と同じ値とし、エラーの文言も同じとする。

### Alternatives Considered

- Option A: 検査せず、環境変数の上限を超えた場合の失敗を文書化するだけにする。REQ-F-006 の `::error::` を満たせないため不採用。
- Option B: 一覧を一時ファイルで渡す。`_ca-filter-files` の入力契約の変更 (REQ-C-006) を伴うため不採用 (DR-11)。

### Rationale

絞り込みの段と同じ上限で先に止めれば、120000 バイトを超える一覧はすべて `::error::` で報告される。

### Consequences

- Positive:
  - 環境変数の上限による、メッセージの無い失敗が起きない
- Negative:
  - 同じ上限を 2 つのモジュールに持つ。`_ca-filter-files` の上限を変えるときは、本 Action も同時に改訂する

### Related

- DR-07
- DD-DIF-02
- R-DIF-003
- REQ-F-006

---

## DR-14: エラーは内部 Action と同じ形式・文言で出し、内部のエラーと git の出力は書き換えない

**Phase**: review-harden
**Status**: Accepted

### Context

本 Action のエラーには、内部スクリプトが出すものと、本 Action のスクリプトが出すものの 2 種類がある。
内部スクリプトのエラーの対象名は内部の名前 (`patterns`・`files`) であり、公開入力名 (`pattern`) と食い違う。
`git diff` が失敗したときは、git 自身もメッセージを標準エラー出力に出す。

### Decision

本 Action のスクリプトが出すエラーは、`::error::<対象>: <問題> (got: '<値>')` の形式とし、問題の文言は spec に定めた英語の文字列としなければならない (MUST)。
文言は `_ca-filter-files` と同じものを使う。
対象の文言は `exceeds the limit of 120000 bytes`・`is not a writable file`・`failed to write`・`value must not be empty` とする。
内部スクリプトのエラーは書き換えずに出さなければならない (MUST)。`git diff` の失敗時は、git の標準エラー出力をそのまま出し、その後に `::error::` を 1 行出す。

### Alternatives Considered

- Option A: 内部スクリプトのエラーを捕まえ、対象名を公開入力名に書き換える。出力の捕捉と変換の仕組みが要り、構成が複雑になるため不採用。
- Option B: git の標準エラー出力を抑え、`::error::` の 1 行だけにする。失敗の原因 (不在のオブジェクト等) が分からなくなるため不採用。

### Rationale

内部 Action と本 Action でエラーの読み方がそろい、文言でテストできる。

### Consequences

- Positive:
  - エラーの形式と文言が、内部 Action と同じ規則でテストできる
  - git の失敗の原因をログで追える
- Negative:
  - 公開入力 `pattern` の不正は、対象 `patterns` として報告される
  - git の出力は `::error::` 以外の行として、ログに残る

### Related

- DD-IDX-01
- DD-IDX-02
- R-DIF-002
- REQ-F-006

---

## DR-15: テストの fixture は実 git リポジトリに index から登録し、期待値ファイルと比べる

**Phase**: review-harden
**Status**: Accepted

### Context

LCF・MAINF・RUNF は、`git diff` の結果を実 git リポジトリで検証する (REQ-NF-001)。
大量のパス (120000 / 120001 バイト、3001 件) と、`"`・`\`・タブを含むパス、シンボリックリンクの fixture が要る。
作業ツリーにファイルを作る方式は、NTFS の禁止文字・パス長・ファイル作成の速度の制約を受ける。
3001 行や 120000 バイトの期待値は、テストの中に直接書くと読めない。

### Decision

大量のパスと特殊文字のパスの fixture は、作業ツリーにファイルを作らず、`git hash-object -w` の blob を `git update-index` で index に直接登録してコミットしなければならない (MUST)。
これらのケースは、`GF_TMP_ROOT` の直下 (リポジトリの外) に置いた `paths.txt` と `expected.txt` を使い、実際の出力を `expected.txt` と `diff` で比べて検証する。
git をスタブにしてはならない (MUST NOT)。所要時間はテストの合否に使わず、`GCF_FIXTURE_TIMING` が設定されたときだけ記録する。
実 git fixture は `_ca-resolve-sha` の `git-fixture.sh` を読み取り専用で使う。

### Alternatives Considered

- Option A: すべてのケースで作業ツリーにファイルを作る。WSL 以外で特殊文字のパスが作れず、3001 件の作成が遅いため不採用。
- Option B: git をスタブにし、`paths.txt` を `git diff` の出力として返す。git の引用表記 (AC-010 / AC-011) を検証できず、REQ-NF-001 を満たさない。RUNF では resolve-sha も実 git を使うため不採用。
- Option C: 所要時間に閾値を設けてアサーションする。実行環境で大きく変わり、不安定なテストになるため不採用。
- Option D: 本モジュール専用の fixture helper を持つ。GIT_* の除去などの安全策を重複して持つことになるため不採用。

### Rationale

実 git の挙動 (引用表記、バイト順の出力) を検証しつつ、ファイルシステムの制約と期待値の読みにくさを避けられる。

### Consequences

- Positive:
  - 特殊文字のパスと大量のパスの fixture を、WSL でも Git Bash でも同じ方法で作れる
  - 失敗時に `diff` で違う行が分かる
- Negative:
  - 作業ツリーと index が一致しない fixture になる (コミット間の比較なので結果には影響しない)
  - `_ca-resolve-sha` の helper の変更が、本モジュールのテストに影響する
  - 期待値の引用表記への変換を、テストの内部ヘルパーとして持つ

### Related

- REQ-NF-001
- AC-010
- AC-011
- AC-012
- DD-IDX-03

---

## DR-16: action.yml の値は静的検査で検証し、境界値は受け付ける端と最初に拒否される値で確かめる

**Phase**: review-harden
**Status**: Accepted

### Context

RUNF は、3 つのスクリプトを action.yml と同じ順で実行するが、action.yml を読まずに env を自前で組み立てる。
RUNF で「呼び出し元の env が使われない」ことを確かめても、テスト自身が渡した値を確かめるだけになり、action.yml の値が変わっても失敗しない。
本 Action には、本 Action と内部 Action が持つ上限・下限が 8 つある (一覧のバイト数、件数、pattern の行数とバイト数、commit-count の範囲、履歴の長さ、変更ファイルの件数の下限)。

### Decision

action.yml の値 (env の対応付け、step の構成、入出力) は、静的検査 (GACT) で検証しなければならない (MUST)。RUNF に、action.yml の値に依存するケースを置いてはならない (MUST NOT)。
すべての上限・下限は、受け付ける端の値 (`=`) と、最初に拒否される値 (上限は `>`、下限は `<`) の 2 つで検証しなければならない (MUST)。
境界と Task ID の対応は、tasks.md の「Boundary Check」の表で管理する。

### Alternatives Considered

- Option A: RUNF が action.yml を読んで env を組み立てる。action.yml の変更を RUNF でも検出できるが、YAML を解釈するヘルパーが要り、RUNF の失敗の原因が分かりにくくなるため不採用。
- Option B: 境界ごとに 3 点 (`<`・`=`・`>`) を取る。受け付ける側の内側の点 (上限なら `max-1`) は `=` と同じ経路を通るだけで、fixture の作成時間だけが増えるため不採用。

### Rationale

テストが何を検出できるかを、テストの種類ごとに一意にする。境界の検証は、振る舞いが切り替わる 2 点で十分であり、どの境界も同じ基準で漏れなく確かめられる。

### Consequences

- Positive:
  - action.yml の値を変えると、必ず GACT のどれかが失敗する
  - 境界の検証の抜けを、Boundary Check の表で機械的に見つけられる
- Negative:
  - action.yml の値と実行時の振る舞いの結び付きは、GACT と RUNF の 2 つを合わせて初めて確かめられる
  - 内部 Action の上限 (件数・pattern・commit-count) の境界を、本モジュールでも fixture で再び確かめることになる

### Related

- DR-12
- DR-15
- DD-ACT-02
- AC-012
- AC-018

## Change History

| Date       | Version | Description                                                                                                                                                                                    |
| ---------- | ------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-10-29 | 1.0.0   | Initial release: DR-01..DR-08 for Issue #134 requirements                                                                                                                                      |
| 2026-10-29 | 1.1.0   | Add DR-09 (delete filter.lib.sh), DR-10 (checkout to the workspace is a caller obligation), DR-11 (pattern size and non-UTF-8 paths stay assumptions) from req harden review                   |
| 2026-10-30 | 1.2.0   | Add DR-12 (three steps, static env check), DR-13 (byte limit also in the diff stage), DR-14 (error format and wording, pass-through of internal errors and git stderr) from spec harden review |
| 2026-10-30 | 1.2.1   | Clarify DR-12: env compared by name only where the value source differs (overrides, INPUT_FILES, INPUT_PATTERNS)                                                                               |
| 2026-10-30 | 1.3.0   | Add DR-15 (test fixtures registered to the index of a real git repo, compared with expected files; no git stub, timing recorded only) from impl harden review                                  |
| 2026-10-30 | 1.4.0   | Add DR-16 (action.yml values are verified by static checks only; boundaries are tested at the accepted edge and the first rejected value) from tasks harden review                             |
