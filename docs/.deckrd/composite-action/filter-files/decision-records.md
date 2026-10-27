---
title: "Decision Records: _ca-filter-files"
module: "composite-action/filter-files"
status: Draft
version: 1.0.6
created: "2026-10-27"
---

## DR-01: ファイルフィルタを git diff から独立した内部 Action に切り出す

- Status: Accepted
- Context: `ca-get-changed-files` の `pattern` は git pathspec として `git diff` に渡されている。
  パターンは 1 つしか指定できず、除外もできない。
  `git diff` の外では使えないため、他の Action が持つファイルリストには適用できない (Issue #136)。
- Decision: `.github/actions/_ca-filter-files/` を内部 Composite Action として新設する。
  入力は `files` / `patterns`、出力は `files` / `count` とする。
- Alternatives:
  - git pathspec を `git diff` に渡し続ける。`git diff` の中でしか使えず、複数パターンと除外を 1 つの入力で渡しにくいため不採用。
  - 各行で git pathspec magic (`:(glob)`、`:(exclude)`) を使う。呼び出し元が pathspec 構文を覚える必要があり、フィルタも `git diff` への依存が残るため不採用。
- Rationale: ファイル一覧の取得と絞り込みを分離し、絞り込みを他の Action から再利用できる。
- Trade-offs: Action が 1 つ増える。`ca-get-changed-files` から呼び出すには別途置き換えが必要になる (DR-06)。
- Related: REQ-F-001, REQ-F-012, REQ-C-003, REQ-C-005

## DR-02: glob を独自に正規表現へ変換して照合する

- Status: Accepted
- Context: Bash の `[[ $file == $pattern ]]` では `*` が `/` にも一致し、`*.sh` が `dir/a.sh` に一致する。リポジトリには `**` に対応し `*` が `/` で止まる照合の実装が無い。
- Decision: `**`・`*`・`?` を、本要件の規則どおりの正規表現に変換して各ファイルパスと照合する。
- Alternatives:
  - `[[ == ]]` をそのまま使う。`*` が `/` に一致し、照合規則が明確にならないため不採用。
  - パスを `/` で分割し、セグメント単位で照合する。正規表現のエスケープ漏れは起きない。
    一方で `**` のバックトラックを自前で書く必要がある。impl で実装量を比較し、採用する場合は本 DR を改訂する (explore review ALT-02)。
  - `shopt -s globstar` などのシェル機能に依存する。ファイルシステム上の展開が前提であり、文字列の照合には使えず、シェルの状態にも依存するため不採用。
- Rationale: 照合規則を本ドキュメントで定義したとおりに固定でき、単体テストで検証できる。
- Trade-offs: 変換を手書きするため不具合が入り得る。`**/`、ドット、ブラケットなどの境界ケースを重点的にテストする (REQ-NF-001)。
- Related: REQ-F-005〜REQ-F-008, REQ-NF-001, REQ-NF-002

## DR-03: パターンは glob のみ受け付け、正規表現は受け付けない

- Status: Accepted
- Context: ファイルの抽出方法として glob と正規表現が考えられる。正規表現を受け付ける場合は、行ごとの接頭辞や入力による切り替えが必要になる。
- Decision: パターンは glob のみとする。正規表現は内部の照合にだけ使い、呼び出し元には公開しない。
- Alternatives:
  - 行ごとに接頭辞 (例: `re:`) で glob と正規表現を区別する。構文が増え、検証範囲が広がるため不採用。
  - 入力 (例: `pattern-type`) で一括して切り替える。同様の理由で不採用。
- Rationale: 呼び出し元が覚える構文を 1 つに絞り、照合規則を単純に保つ。
- Trade-offs: 正規表現でしか表せない条件は指定できない。
- Related: REQ-F-009

## DR-04: 包含パターンが 0 件の場合は全ファイルを通す

- Status: Accepted
- Context: Issue #136 は、パターンが空のときに全ファイルを通すか失敗させるかを仕様で決めるとしていた。
- Decision: `patterns` が未指定・空文字列・空行 (両端の空白を除いて空になる行) のみの場合は、全ファイルを通し、エラーにしない。空行はパターンとして数えない。
- Alternatives:
  - エラーにする。パターン無しを呼び出し元の誤りとみなす案。フィルタ不要な呼び出しで Action を使えなくなり、`ca-get-changed-files` の現行挙動 (`pattern` 省略時は全件) とも食い違うため不採用。
- Rationale: 保持条件 (包含パターン 0 件 = 全件一致) と一貫し、既存の呼び出し元の挙動を保てる。
- Trade-offs: パターンの渡し忘れを検出できない。
- Related: REQ-F-003, REQ-F-004

## DR-05: 除外パターンは包含パターンより優先する

- Status: Accepted
- Context: 1 つのファイルが包含パターンと除外パターンの両方に一致する場合の扱いを決める必要がある。
- Decision: 除外パターンに 1 つでも一致したファイルは、包含パターンへの一致にかかわらず除く。パターンの記述順には依存しない。
- Alternatives:
  - 記述順で後勝ちにする (`.gitignore` 方式、GitHub Actions の `paths` フィルタも同じ)。利用者には馴染みがあるが、結果が行の並びに依存し、読み手が判断しにくいため不採用。
- Rationale: Issue #136 の受け入れ基準 (除外は包含にも一致していても除かれる) に従う。
- Trade-offs: 「除外したディレクトリ内の特定ファイルだけを戻す」指定はできない。
- Related: REQ-F-002, REQ-F-003

## DR-06: ca-get-changed-files の置き換えは get-changed-files 側で扱う

- Status: Accepted
- Context: Issue #136 は `ca-get-changed-files` から pathspec を外し `_ca-filter-files` を呼び出す変更を含む。
  この変更は `pattern` の意味を git pathspec から glob に変える破壊的変更である。
  影響先は get-changed-files の REQ-F-004、テストジョブの `*.txt` パターン、T-gcf-nor-02 である。
- Decision: 本モジュールの要件は `_ca-filter-files` 単体で閉じる。`ca-get-changed-files` の置き換えは、get-changed-files モジュールのドキュメントを改訂して扱う。
- Alternatives:
  - 本モジュールの要件に置き換えまで含める。2 つのモジュールの要件が同じ変更を記述し、乖離するおそれがあるため不採用。
- Rationale: 変更の所有者をモジュール単位で明確にする。
- Trade-offs: Issue #136 の完了には、get-changed-files 側のドキュメント改訂も必要になる。
- Related: REQ-C-005

## DR-07: 複数行出力関数を `_libs` に追加し、区切り文字を一意な文字列にする

- Status: Accepted
- Context: 複数行出力関数 `write_multiline_output` は `ca-get-changed-files/scripts/_libs/filter.lib.sh` のローカル実装しかない。
  区切り文字が固定の `EOF` であり、パスが `EOF` だと出力が壊れる。
- Decision: `.github/actions/_libs/output.lib.sh` に `write_multiline_output` を新規追加する (追加のみ)。区切り文字には、値の行と重ならない一意な文字列を使う。候補を値の全行と比較し、衝突したら選び直す。
- Alternatives:
  - 既存実装を区切り文字 `EOF` のまま `_libs` へ移す。パスが `EOF` の場合の破損が残るため不採用。
  - `_ca-filter-files` の中に独自の書き出し処理を持つ。同種の処理が Action ごとに重複するため不採用。
- Rationale: 共有ライブラリに 1 つだけ正しい実装を置き、他の Action から再利用できるようにする。
- Trade-offs: `filter.lib.sh` のローカル実装と同名の関数が一時的に並存する。
  `ca-get-changed-files` は、後続の get-changed-files の要件改訂で共有ライブラリの `write_multiline_output` に切り替え、ローカル実装を廃止する (DR-06)。
- Related: REQ-F-013, REQ-C-006, REQ-C-007

## DR-08: 入力行の両端の空白を除去し、空になった行を無視する

- Status: Accepted
- Context: YAML のブロックスカラー (`files: |`) で渡すと値の末尾に改行が付き、インデント由来の空白が残る場合もある。
  空行や空白をそのまま扱うと、`count` が 1 多くなる、空の包含パターンで全件が除外されるなどの誤動作が起きる (explore review Q-01, Q-03)。
- Decision: `files` と `patterns` の各行の両端からスペースとタブを除去する。除去後の空行は無視する。パスの途中の空白は除去しない。
- Alternatives:
  - 除去しない。空白もパス・パターンの一部とみなす。YAML 由来の空白で一致しなくなり、末尾改行で件数がずれるため不採用。
  - 完全な空行だけを無視し、空白は残す。空白のみの行やインデント付きの行が誤って扱われるため不採用。
- Rationale: 呼び出し元の YAML の書き方によらず、同じ結果を得られる。
- Trade-offs: 両端に空白を持つパスは表現できない。CR を除去対象に含めるかは spec で決める。
- Related: REQ-F-001, REQ-F-002, REQ-F-004, REQ-F-010 (AC-012)

## DR-09: 非ゼロで終了するのは出力不能時と、spec で不正と決めた入力に限る

- Status: Accepted
- Context: 本 Action は文字列を絞り込むだけであり、一致 0 件や空入力は正常な結果である (REQ-F-014)。
  一方、`$GITHUB_OUTPUT` に書き込めないと、後続ステップが `files` と `count` の不整合な値を受け取る (explore review Q-04)。
- Decision: 非ゼロで終了するのは、出力先が使えない場合 (REQ-F-015) と、spec で不正と決めたパターンの場合に限る。出力先の検証は最初の書き込みの前に行う。
- Alternatives:
  - 一致 0 件もエラーにする。呼び出し元が 0 件を正常系として扱えなくなるため不採用。
  - 書き込みの失敗を検出した時点でエラーにする。出力の一部だけが書かれた状態で残るため不採用。
- Rationale: 正常系と異常系の境界を明確にし、異常系のテストを列挙できるようにする。`_ca-resolve-sha` の fail-first 規約とも合う。
- Trade-offs: 書き込みの前に検証しても、検証後の書き込み失敗 (ディスク不足など) は防げない。その場合も非ゼロで終了する。
- Related: REQ-F-014, REQ-F-015, REQ-C-006 (AC-009, AC-011)

## DR-10: 入力の前提を呼び出し元の義務として定める

- Status: Accepted
- Context: 本 Action はパスを検証・正規化しない (REQ-F-001 の trim を除く)。
  しかし、デコード済み・リポジトリ相対・正規化済み・LF 区切りといった前提は Assumptions (非規範) に置かれており、前提が崩れたときの責任の所在が定まっていない (harden review P-01)。
- Decision: これらの前提を REQ-C-009 として呼び出し元の義務 (MUST) とする。本 Action は条件を満たさない入力を検出・補正せず、受け取った文字列のまま照合する。
- Alternatives:
  - 本 Action で正規化する (`./` の除去、引用表記のデコードなど)。純粋なフィルタという責務を越え、照合規則が複雑になるため不採用。
  - 前提を Assumptions のまま残す。前提違反時の結果を規定できないため不採用。
- Rationale: 責務の境界を明確にする。`_ca-resolve-sha` が checkout 前提を呼び出し元の MUST (REQ-C-003) としているのと同じ扱いになる。
- Trade-offs: 呼び出し元ごとにデコード・正規化が必要になる。
- Related: REQ-C-009, REQ-F-001, REQ-F-012

## DR-11: ダブルクオートの解釈は GitHub Actions (YAML) に任せ、Action では外さない

- Status: Accepted
- Context: 呼び出し元は `with:` の値をダブルクオートで囲むことがある。GitHub Actions は `with:` を YAML として解釈し、クオートを外した文字列を Action に渡す。
  一方、ブロックスカラー (`files: |`) 内の行に書いたクオートは、YAML の解釈後も文字として残る。
- Decision: Action はクオートを自分では外さない。GitHub Actions が YAML として解釈した後の値をそのまま使い、行内に残るクオートは文字として照合する。
- Alternatives:
  - trim 後の行が `"..."` で囲まれていれば、Action が YAML のダブルクオート文字列の規則 (エスケープを含む) で外す。
    ブロックスカラー内でも空白を含むパスを書けるが、YAML の解釈を Action でも重ねて実装する必要があり、照合規則も複雑になるため不採用。
- Rationale: クオートの解釈を 1 か所 (GitHub Actions) に限り、Action の入力を「届いた文字列」として単純に保つ。
- Trade-offs: ブロックスカラー内の行では、両端に空白を持つパスを表現できない (DR-08)。クオートで囲んだ行は、クオートを含む文字列として扱われる。
- Related: REQ-F-001, REQ-F-016 (AC-013)

## DR-12: 出力先の検証関数を `_libs/output.lib.sh` に追加する

- Status: Accepted
- Context: REQ-F-015 は、最初の書き込みの前に `$GITHUB_OUTPUT` の出力先を検証することを求める。
  同じ検証は `_ca-resolve-sha` の内部関数 `_rs_check_output_file` にしかなく、共有ライブラリには無い (spec Phase 6)。
- Decision: 出力先の検証関数を `.github/actions/_libs/output.lib.sh` に追加し、`_ca-filter-files` はそれを使う。関数名と戻り値は spec で定める。
- Alternatives:
  - `_ca-filter-files` のライブラリ内部に検証関数を持つ。resolve-sha と同じ処理が Action ごとに重複するため不採用。
- Rationale: `write_output`・`write_multiline_output` と同じ場所に置き、出力に関する処理を共有ライブラリにまとめる。
- Trade-offs: `_libs` への追加が 2 関数になる。`_ca-resolve-sha` の内部関数を共有関数へ置き換えるかは、本モジュールの範囲外とする。
- Related: REQ-F-015, REQ-C-006, REQ-C-007

## DR-13: 共有出力関数の契約を定める

- Status: Accepted
- Context: `_libs/output.lib.sh` に追加する `validate_output_file` と `write_multiline_output` は、他のモジュールからも呼ばれる。
  `ca-get-changed-files` も後続の改訂で利用する (DR-07, DR-12)。
  契約が output 分割仕様の DD にしか無いと、他モジュールの改訂時に参照されない (harden review P-01)。
- Decision: 次の契約を共有関数の仕様とする。詳細は specifications-output.md の R-OUT-010〜R-OUT-022 に従う。
  - `validate_output_file <file>`: 書き込める通常ファイルなら 0 を返す。ファイルが無い場合は、親ディレクトリに書き込めれば 0 とする。
    パスが空なら 1、それ以外は 2 を返し、ファイルは作らない。
  - `write_multiline_output <file> <key> <value>`: キーは英字または `_` で始まり、英数字・`_`・`-` だけからなる。
    値は LF で行に分け、1 行ごとに LF を付けて書く。値が空なら内容の行を書かない。
    区切り文字は `EOF`、`EOF_1`… のうち、値のどの行とも一致しない最初の候補とする。
    引数不正なら 1、書き込み失敗なら 2 を返す。
  - どちらも標準出力・標準エラー出力に何も出さない。`::error::` は呼び出し側が出す。
- Alternatives:
  - 契約を output 分割仕様の DD のままにする。他モジュールから契約を辿れないため不採用。
- Rationale: 既存の `write_output` と同じく、共有関数は終了コードだけを返し、エラー表示は呼び出し側に任せる。
- Trade-offs: 契約を変える場合は、本 DR と利用する全モジュールの改訂が必要になる。
- Related: DR-07, DR-12 (REQ-F-013, REQ-F-015, REQ-C-007)

## DR-14: 不正な入力を定義し、最初の 1 件で終了する

- Status: Accepted
- Context: DR-09 は、非ゼロで終了する入力の定義を spec に委ねた。spec では不正な入力を 3 種類に決め、報告の件数も決めた (harden review P-02)。
- Decision: 次の入力を不正とし、最初の 1 件を `::error::` で報告して、出力を書き出す前に非ゼロで終了する。
  - UTF-8 として不正なバイト列を含む行 (`files`・`patterns`)
  - `!` だけのパターン行
  - 空白 (スペース・タブ) で始まる除外パターン
  - 検査は `files`、`patterns` の順に、各入力の中では先頭から行う。パターン行は 1 行ずつ、`!` だけの行かを先に判定する。
- Alternatives:
  - 不正な行をすべて報告する。エラーの行数が入力によって変わり、テストの期待値が定まりにくいため不採用。
  - 空白で始まる除外パターンを黙って受け付ける。何にも一致しないパターンを書き間違いと気付けないため不採用。
- Rationale: fail-first の方針に従い、最初の誤りで止める。
- Trade-offs: 不正な行が複数ある場合、利用者は 1 件ずつ直すことになる。
- Related: DR-09, REQ-F-002, REQ-F-015

## DR-15: エラー形式を内部 Action 共通の形式にそろえる

- Status: Accepted
- Context: `_ca-resolve-sha` はエラー形式を `::error::<対象>: <問題> (got: '<値>')` と定めた (resolve-sha DD-IDX-01)。
  `_ca-filter-files` も同じ形式を採用し、2 つ目の内部 Action になる (harden review P-03)。
- Decision: 内部 Action のエラーは `::error::<対象>: <問題> (got: '<値>')` の形式とする。
  値が空なら `::error::<対象>: value must not be empty` とし、値の `%`・CR・LF をエンコードする。
- Alternatives:
  - Action ごとに形式を決める。呼び出し元のログの読み方が Action ごとに変わるため不採用。
- Rationale: 内部 Action のエラーを同じ読み方で扱えるようにする。
- Trade-offs: 形式を変える場合は、採用している全 Action を合わせて改訂する必要がある。
- Related: REQ-C-006, specifications-index.md 3.3

## Change History

| Date       | Version | Description                                                                      |
| ---------- | ------- | -------------------------------------------------------------------------------- |
| 2026-10-27 | 1.0.0   | Initial release                                                                  |
| 2026-10-27 | 1.0.1   | Add alternatives from explore review (DR-02, DR-05)                              |
| 2026-10-27 | 1.0.2   | Add DR-08 to DR-10 from harden review                                            |
| 2026-10-27 | 1.0.3   | Add DR-11 (double quote interpretation)                                          |
| 2026-10-27 | 1.0.4   | Clarify DR-07: get-changed-files switches to shared write_multiline_output later |
| 2026-10-27 | 1.0.5   | Add DR-12 (shared output destination check)                                      |
| 2026-10-27 | 1.0.6   | Add DR-13 to DR-15 from spec harden review                                       |
