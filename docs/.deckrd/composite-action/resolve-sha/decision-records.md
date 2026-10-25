---
title: "Decision Records: _ca-resolve-sha"
module: "composite-action/resolve-sha"
status: Draft
version: 2.1.0
created: "2026-10-25"
---

## DR-01: SHA 解決ロジックを内部 Composite Action に切り出す

- Status: Accepted
- Context: base/head SHA の解決ロジックは `ca-get-changed-files` の `filter.lib.sh` に埋め込まれている。
  このため、他の Action から再利用できない (Issue #135, 親 #134)。
- Decision: `.github/actions/_ca-resolve-sha/` を内部 Composite Action として新設する。入力は `commit-count`、出力は `before-sha` / `after-sha` とする。
- Alternatives:
  - 現状維持: `ca-get-changed-files` 内に保持する。再利用できないため不採用。
- Rationale: 将来の内部 Action でも同じ解決ロジックを共有できる。
- Trade-offs: Action が 1 つ増える。`ca-get-changed-files` 側の置き換えは別タスクとなる。
- Related: REQ-F-001, REQ-C-004, REQ-C-006

## DR-02: push の before が無効な場合は HEAD~N に fall back する

- Status: Accepted
- Context: push の `github.event.before` は、新規ブランチでは空または全ゼロになる。force push ではリポジトリに存在しない場合がある。従来は空ツリー SHA への置換のみで、この 2 ケースは未対応だった。
- Decision: `before` が空・全ゼロの場合、および `git cat-file -e` で存在しないと判定された場合は、before-sha を HEAD~N に fall back する。
- Alternatives:
  - 従来どおり空ツリー SHA に置換する。全ファイルが変更扱いとなるため不採用。
- Rationale: 直近 N コミットを基準にすることで、意図に近い差分が得られる。
- Trade-offs: force push 前の履歴との差分は得られず、HEAD~N 基準の差分になる。
- Related: REQ-F-005, REQ-F-006

## DR-03: 履歴不足時は空ツリー SHA を before-sha とする

- Status: Accepted
- Context: 初回コミットのみのリポジトリや shallow clone では、履歴が N+1 コミットに満たず HEAD~N を解決できない。
- Decision: HEAD~N を解決できない場合、before-sha は空ツリー SHA `4b825dc642cb6eb9a060e54bf8d69288fbee4904` とする。
- Alternatives:
  - エラー終了する。ワークフローが失敗するため不採用。
- Rationale: 空ツリーとの差分は「到達可能な全履歴の変更」を意味し、履歴不足時の自然な上限となる。
- Trade-offs: 全ファイルが変更扱いとなり、呼び出し元の処理対象は増える場合がある。
- Related: REQ-F-007, REQ-C-003

## DR-04: pull_request は base.sha をそのまま使う

- Status: Accepted
- Context: pull_request では、base ブランチ先頭との直接比較と merge-base との比較で差分が異なり得る。
- Decision: before-sha に `pull_request.base.sha` をそのまま使う。merge-base 計算はスコープ外とする。
- Alternatives:
  - merge-base を計算する。スコープ外のため見送り。
- Rationale: 現行挙動を維持し、変更範囲を限定する。
- Trade-offs: base ブランチが進んでいる場合、PR 外の変更が差分に含まれる可能性がある。
- Related: REQ-F-008

## DR-05: commit-count の検証は常に先頭で行う (fail-first)

- Status: Accepted
- Context: pull_request では commit-count が SHA 解決に使われないため、検証をイベント別処理の中に置くと入力契約がイベントごとに異なる。
- Decision: 0・負数・非数値は、イベントを問わず最初に `::error::` と非ゼロ終了で拒否する。
- Alternatives:
  - HEAD~N を使うイベントのみ検証する。入力契約が不均一になるため不採用。
- Rationale: 全イベントで同じ入力契約を保証し、不正入力を早期に検出できる。
- Trade-offs: pull_request では使用しない値でも検証によりエラーになり得る。
- Related: REQ-F-002, REQ-F-003

## DR-06: その他イベントは HEAD~N / HEAD で解決する

- Status: Accepted
- Context: 現行実装は push / pull_request 以外で `Unsupported event` エラーとなり、workflow_dispatch 等から再利用できない。
- Decision: その他イベントは before-sha を HEAD~N、after-sha を HEAD として解決する。`pull_request_target` 等の PR 系イベントも `pull_request` と同一視せず、その他イベントとして扱う。
- Alternatives:
  - 従来どおり `Unsupported event` エラーとする。再利用性を損なうため不採用。
- Rationale: 内部の共通 Action として、イベント種別を問わず利用可能にする。
- Trade-offs: 未知のイベントでもエラーにならないため、想定外の利用を検出しにくくなる。
- Related: REQ-F-009

## DR-07: 明示オーバーライド入力 before-sha / after-sha を継承する

- Status: Accepted
- Context: 現行の `ca-get-changed-files` は入力 `before-sha` / `after-sha` による明示オーバーライドを持つ (`filter.lib.sh` の `resolve_sha_for_event`)。requirements v1.0.0 はこれに言及しておらず、置き換えタスクで呼び出し元の入力契約が失われる。
- Decision: 入力 `before-sha` / `after-sha` (required: false, default "") を追加する。両方が指定された場合はイベント別解決より優先して採用する。片方のみの指定は `::error::` と非ゼロ終了で拒否する。`commit-count` の検証は DR-05 どおり先頭で行い、コミット実在検証 (DR-10) はオーバーライド値にも適用する。
- Alternatives:
  - オーバーライドを廃止し、呼び出し元に残す。置き換えタスクの移行コストが増えるため不採用。
- Rationale: 現行挙動と互換を保ち、`ca-get-changed-files` からの移行を単純な置換にできる。
- Trade-offs: 入力が 3 つに増え、入力の組み合わせ検証が必要になる。
- Related: REQ-F-011, REQ-F-015, REQ-C-006

## DR-08: 解決経路を resolution 出力で通知する

- Status: Accepted
- Context: フォールバック (HEAD~N / 空ツリー) 時も正常終了するため、呼び出し元は返された SHA が正確な差分基準か近似かを区別できない (codex risk review の最優先指摘)。
- Decision: 出力 `resolution` を追加し、`override` / `event` / `fallback-head-n` / `empty-tree` のいずれかを設定する。
- Alternatives:
  - `::warning::` をログに出すのみ。呼び出し元が条件分岐に使えないため不採用。
  - 通知しない。見逃しを呼び出し元が検知できないため不採用。
- Rationale: 呼び出し元が全件検査への切り替え等を判断できる。
- Trade-offs: 出力契約が 1 つ増え、値の追加は呼び出し元への影響を伴う。
- Related: REQ-F-012, DR-02, DR-03

## DR-09: フォールバックとその他イベントの基準は checkout 済み HEAD とする

- Status: Accepted
- Context: requirements v1.0.0 では push のフォールバックが before に HEAD~N、after に `github.sha` を使い、その他イベントは HEAD を使う。checkout の `ref` が `github.sha` と異なると、無関係な履歴同士を比較し得る。
- Decision: HEAD~N を使う経路 (push のフォールバック、その他イベント) では、before-sha を HEAD~N、after-sha を HEAD とする。push の通常解決と pull_request はイベント提供の SHA を使う。
- Alternatives:
  - `github.sha~N` / `github.sha` に統一する。checkout の `ref` が異なるとローカルに存在しない SHA を返し得るため不採用。
- Rationale: before / after が常に checkout 済みの同一履歴上に存在する。
- Trade-offs: checkout の `ref` を変えた場合、イベントの意図 (`github.sha`) とは異なる範囲の差分になる。
- Related: REQ-F-005, REQ-F-006, REQ-F-009

## DR-10: 出力 SHA のコミット実在検証と git エラーの区別

- Status: Accepted
- Context: requirements v1.0.0 は push の before のみ実在を確認する。PR の base/head やオーバーライド値が不在でも正常終了し、呼び出し元の `git diff` で失敗する。また、HEAD~N の解決失敗をすべて履歴不足と扱うと、リポジトリ不在等の異常が空ツリーで隠れる。
- Decision:
  - 空ツリー以外の出力 SHA は `git cat-file -e <sha>^{commit}` で検証する。
  - push の before が不在の場合は、DR-02 どおり HEAD~N に fall back する。
  - オーバーライド値・pull_request の base/head・push の after が不在の場合は、`::error::` と非ゼロ終了とする。
  - 空ツリーへの fall back は、HEAD がコミットとして解決でき、かつ HEAD~N が解決できない場合 (shallow 境界を含む履歴不足) に限る。
  - HEAD 自体を解決できない場合はエラーとする。
- Alternatives:
  - push の before のみ検証する (v1.0.0 どおり)。Action が成功して後続が失敗するため不採用。
- Rationale: fail-first 原則に従い、異常を発生源で検出する。コミット以外のオブジェクトを比較対象と誤認しない。
- Trade-offs: 検証用の git 呼び出しが増える。PR の base がローカルに無い checkout 構成ではエラーになる。
- Related: REQ-F-007, REQ-F-008, REQ-F-013, REQ-F-014 (DR-03)

## DR-11: スコープとインターフェースの明確化

- Status: Accepted
- Context: explore レビューで、Composite Action では宣言できない制約、共有ライブラリに存在しない関数への依存、未確定の入力形式・環境変数名が指摘された。
- Decision:
  - REQ-C-002 (`permissions: contents: read`) は呼び出し元 workflow / job の制約とする。
  - `commit-count` の許容形式は `^[1-9][0-9]*$` とする (前後空白・先頭ゼロは不可)。
  - `_libs/` の拡張 (`output.lib.sh` への汎用出力関数、`validation.lib.sh` への正整数検証関数) をスコープに含める。
  - イベント値を受け取る環境変数名は、現行の `GITHUB_BEFORE_SHA` / `GITHUB_AFTER_SHA` / `GITHUB_BASE_SHA` / `GITHUB_HEAD_SHA` と `INPUT_*` に揃える。
  - `pull_request_target` は DR-06 どおりその他イベントとして扱う。
- Alternatives:
  - `_libs/` を拡張せず、スクリプト内に実装する。共通の型・定数の配置規約に反するため不採用。
- Rationale: 実装可能かつ検証可能な契約にし、spec フェーズの Open Question を減らす。
- Trade-offs: `_libs/` の変更が既存の Action に影響しないことを確認する必要がある。
- Related: REQ-F-002, REQ-F-010, REQ-C-002, REQ-C-007

## DR-12: checkout の fetch-depth はイベントごとに N+1 / base を含む深さとする

- Status: Accepted
- Context: requirements v1.0.0 は `fetch-depth: 0` を前提としていた。完全な履歴取得を避け、commit-count に見合った深さで checkout したい。ただし `fetch-depth: N` では HEAD~N が常に shallow 境界の外となり、pull_request の base も取得されない。
- Decision:
  - push / その他イベントでは、呼び出し元は `fetch-depth` を N+1 以上 (N は commit-count) として checkout する。
  - リポジトリの履歴が N+1 コミットに満たず HEAD~N を解決できない場合は、空ツリー SHA とする (DR-03)。
  - pull_request では、`pull_request.base.sha` を含む深さ (`fetch-depth: 0` 等) で checkout する。base が不在の場合は DR-10 どおりエラーとする。
  - `_ca-resolve-sha` 自身は履歴を取得しない (REQ-NF-002)。
- Alternatives:
  - `fetch-depth: N` とする。HEAD~N が常に解決できず、フォールバック経路が必ず空ツリーになるため不採用。
  - Action 内で `git fetch --depth` により履歴を補う。REQ-NF-002 (ネットワークアクセス禁止) に反するため不採用。
- Rationale: 必要最小限の履歴で HEAD~N を解決でき、checkout のコストを抑えられる。
- Trade-offs: push の `github.event.before` が shallow 範囲外となりやすく、通常解決より HEAD~N fall back (DR-02) が多くなる。
- Related: REQ-C-003, REQ-F-006, REQ-F-007, REQ-F-013

## DR-13: 本 Action は SHA 解決器とし、変更網羅は保証しない

- Status: Accepted
- Context: codex risk review で、フォールバック経路 (HEAD~N / 空ツリー) は正常終了しても変更を見落とし得ると指摘された。例として、複数コミットの push で before が shallow 範囲外の場合、最後の N コミットしか比較されない。また、pull_request の base 先頭と head の直接比較は、PR が導入した変更とは一致しない。
- Decision: `_ca-resolve-sha` は二点比較の基準 SHA を返す SHA 解決器と定義する。イベント全体の変更網羅は保証しない。`resolution` が `event` / `override` 以外の場合に全件検査等へ切り替えるかは、呼び出し元の責務とする。pull_request の出力は base 先頭と head の二点差の基準であると明記する。
- Alternatives:
  - 見落とし防止を保証する。網羅できない経路では空ツリーかエラーを返す。DR-02 の HEAD~N フォールバックを撤回することになり、CI の処理量が増えるため不採用。
- Rationale: 責務を SHA 解決に限定し、変更検出の方針は利用目的を知る呼び出し元に委ねる。DR-08 の `resolution` がその判断材料となる。
- Trade-offs: 呼び出し元が `resolution` を無視すると、見落としは検出されない。
- Related: REQ-F-008 / REQ-F-009 / REQ-F-012 / DR-02 / DR-04 / DR-08

## DR-14: 入力形式・git 障害分類・checkout と出力の契約を厳格化する

- Status: Accepted
- Context: codex risk review で、いくつかの穴が指摘された。リビジョン式のオーバーライドはコミット検証を通過する。after-sha が空ツリー SHA でも検証免除で通過する。commit-count に上限がない。HEAD~N の解決失敗を一律に履歴不足と扱う。PR の head 取得が前提に含まれない。出力が部分的に書き出され得る。
- Decision:
  - オーバーライド値は `^[0-9a-f]{40}$` (完全長 SHA-1 OID) に限る。
  - 空ツリー SHA の検証免除は before-sha に限る。
  - commit-count の上限は 1000 とする。
  - 空ツリーへのフォールバックは、HEAD~N 解決失敗の原因が履歴終端 (root) または shallow 境界の場合に限る。それ以外の git 障害はエラーとする。
  - HEAD~N は第一親を N 世代たどる。
  - pull_request の checkout は base と head の両方を含む深さとする。対象は作業ディレクトリの checkout 済みリポジトリとする。
  - 出力はすべての検証成功後にまとめて書き出す。失敗時は書き出さずに非ゼロ終了し、呼び出し元は非ゼロ終了時の出力を使わない。
  - `fetch-depth` が N+1 未満 (契約違反) の場合の挙動は、空ツリーへのフォールバックとして定義する。
- Alternatives:
  - オーバーライド値を `git rev-parse` で OID に正規化する。入力契約が曖昧なまま残るため不採用。
- Rationale: fail-first 原則に従い、出力が固定 SHA であり、かつ git 障害が成功扱いで隠れないことを保証する。
- Trade-offs: 短縮 SHA を渡していた呼び出し元は修正が必要になる。履歴終端・shallow 境界の判定のために git 呼び出しが増える。
- Related: REQ-F-002 / REQ-F-007 / REQ-F-010 / REQ-F-013 / REQ-F-014 / REQ-F-016 / REQ-C-003

## DR-17: GITHUB_EVENT_NAME はオーバーライドの有無に関わらず検証する

- Status: Accepted
- Context: Phase 10 のレビューで、仕様間の食い違いが見つかった。resolution 仕様はオーバーライドなしの場合だけイベント名を検証し、index と output 仕様は常に検証する。GITHUB_EVENT_NAME はランナーが常に設定する既定の環境変数である。
- Decision: GITHUB_EVENT_NAME の空・未設定は、オーバーライドの有無に関わらずエラーとする。評価順序は、commit-count、オーバーライド、イベント名の検証、SHA 解決、書き出しとする。規則は resolution 仕様に置き、他の仕様はそれを参照する。
- Alternatives:
  - オーバーライドなしの場合だけ検証する。実行ごとに環境の契約が変わるため不採用。
- Rationale: すべての実行で同じ環境の契約を保つ。ランナーは常に値を設定するため、実運用でオーバーライドを妨げることはない。
- Trade-offs: オーバーライドだけを使うテストでも、イベント名の設定が必要になる。
- Related: REQ-F-003 / REQ-F-009 / REQ-F-011 / DR-05 / DR-07

## DR-18: 書き出し中の I/O 失敗による部分出力は、呼び出し元の契約で扱う

- Status: Accepted
- Context: DR-14 は all-or-nothing の出力を定める。ただし `$GITHUB_OUTPUT` への追記中に I/O 障害 (ディスク満杯等) が起きると、先に書いた行が残る可能性は排除できない (output 仕様 OQ1)。
- Decision: 書き出し前の検査 (出力先の設定、書き込み可否、改行、resolution の値) はすべて最初の行を書く前に終える。それでも残る I/O 失敗による部分出力は許容し、非ゼロ終了する。呼び出し元は非ゼロ終了したステップの出力を使ってはならない、と契約に明記する。
- Alternatives:
  - 3 行を組み立てて 1 回の追記で書き出す。部分出力の機会は減るが、ゼロにはできないため不採用。
- Rationale: 防げない失敗を防げるように見せかけず、契約で責務を明確にする。GitHub Actions では、失敗したステップの後続は既定で実行されない。
- Trade-offs: `if: always()` などで失敗後も出力を参照する呼び出し元は、部分出力を受け取り得る。
- Related: REQ-F-010, DR-14

## DR-19: 前提と非保証を明記し、追加の入出力は設けない

- Status: Accepted
- Context: spec explore review で、暗黙の前提と未検討の代替案がいくつか挙がった (A-01 / G-02 / G-05 / ALT-02 / ALT-03)。
- Decision:
  - リポジトリのオブジェクト形式は SHA-1 を前提とする。SHA-256 リポジトリは対象外とする。
  - before が after の祖先であるかは検証しない。結果は二点スナップショットの差の基準である (DR-13 の範囲)。
  - pull_request_review、merge_group など pull_request 以外のイベントは、その他イベントとして扱う (DR-06 を維持)。
  - 対象リポジトリのパス入力 (`path`) と、近似経路での `::notice::` 出力は設けない。
- Alternatives:
  - `path` 入力を追加する。現時点で呼び出し元に必要がないため、必要になった時点で検討する。
  - 近似経路で `::notice::` を併せて出す。出力契約の外の副作用が増えるため、`resolution` だけで通知する (DR-08)。
- Rationale: スコープを広げずに、利用者が誤解しやすい前提だけを明文化する。
- Trade-offs: SHA-256 リポジトリやサブディレクトリへの checkout には、別途対応が必要になる。
- Related: REQ-F-008 / REQ-F-009 / REQ-F-012 / DR-06 / DR-08 / DR-13

## DR-23: partial clone はエラーとし、対象外の環境を前提として扱う

- Status: Accepted
- Context: spec review と codex review の指摘を受け、DR-15、DR-16、DR-20、DR-21、DR-22 を追加した。しかし、2 つの SHA を履歴から得る内部 Action に対して、要件・仕様・テストが過剰になった。イベント値は GitHub のコンテキストが与える完全長 SHA であり、呼び出し元も内部 Action に限られる。partial clone、replace refs、graft、注釈付きタグの OID は、通常の `actions/checkout` では生じない。
- Decision:
  - DR-15、DR-16、DR-20、DR-21、DR-22 を削除する。DR-ID は再利用しない。
  - partial clone のリポジトリ (`remote.<name>.promisor` または `extensions.partialClone` が設定されている) では、オブジェクトを参照する前に `::error::` で終了する。
  - 判定は git の設定だけで行い、オブジェクトを参照しない。このため、遅延取得は起動しない。
  - イベント由来の SHA には形式検証をしない。GitHub が完全長 SHA を渡すことを前提とする。
  - replace refs、旧形式の graft ファイル、注釈付きタグの OID の入力は対象外とする。コミット検証は DR-10 のとおりとする。
  - push の通常解決の after は github.sha とする (DR-09 の範囲)。checkout の `ref` が github.sha と異なる場合の差は許容する。
- Alternatives:
  - 削除した DR を維持する。テスト用の fixture (promisor remote、replace ref、タグ) と仕様の分量が増え、現実に起きない失敗の検出にとどまるため不採用。
  - partial clone を許容し、`GIT_NO_LAZY_FETCH` で遅延取得を抑止する。未対応の git では存在検査自体が取得を起動し得るため不採用。
- Rationale: 責務を二点の SHA 解決に絞る。起こり得ない入力は前提として明記し、検出が簡単な partial clone はエラーで拒否する。
- Trade-offs: partial clone で本 Action を使う呼び出し元は、通常の clone に切り替える必要がある。対象外の入力は検出しないため、前提が破れた場合の挙動は保証しない。
- Related: REQ-F-005 / REQ-F-006 / REQ-F-013 / REQ-F-019 / REQ-NF-002 / DR-09 / DR-10 / DR-19

## DR-24: オーバーライド値に空ツリー SHA を受け付けない

- Status: Accepted
- Context: REQ-F-013 は before-sha 側の空ツリー SHA を実在検証から免除する。一方、REQ-F-011 と AC-007 は、オーバーライド値がコミットとして存在する前提に立つ。このため、入力 before-sha に空ツリー SHA を指定できるかが曖昧であった (codex review)。現行の `ca-get-changed-files` は、オーバーライド値をそのまま通し、空ツリー SHA の指定も受け付けていた。ただし、空ツリー SHA を指定する利用元はない。
- Decision:
  - オーバーライド値は、before-sha / after-sha とも、コミットとして存在する完全長 SHA に限る。
  - 入力 before-sha / after-sha に空ツリー SHA が指定された場合は、`::error::` で終了する。
  - 空ツリー SHA の実在検証の免除は、REQ-F-007 の経路で本 Action が生成した before-sha に限る。
- Alternatives:
  - 入力 before-sha に限り空ツリー SHA を許容する。`resolution=override` で before が空ツリーとなる状態が生まれ、`empty-tree` 経路と区別できなくなるため不採用。
- Rationale: オーバーライドの契約を「実在するコミットのペア」に統一する。ゼロ SHA のオーバーライドがすでに REQ-F-013 でエラーとなることとも整合する。`resolution` の値と比較基準の対応も一意に保てる。
- Trade-offs: 現行実装からの挙動変更となる。全ファイルを比較したい呼び出し元は、本 Action を経由せずに空ツリー SHA を自ら基準とする必要がある。
- Related: REQ-F-011 / REQ-F-013 / REQ-F-016 / AC-009 / DR-07 / DR-08 / DR-10 / DR-14

## DR-25: push はブランチの作成・更新に限り、それ以外はエラーとする

- Status: Accepted
- Context: push の分岐は `github.event.before` の状態だけで決めており、ブランチ削除やタグの作成・移動・削除を区別していなかった (codex review)。ブランチ削除では、`github.sha` と `github.ref` がデフォルトブランチに戻る。このため clone の深さに応じて、次のどちらかが正常終了で返る。「削除したブランチの先頭とデフォルトブランチの先頭の比較」(`resolution=event`) か、デフォルトブランチの HEAD~N (`fallback-head-n`) である。タグの push でも、比較の意味を持たない基準が正常終了で返る。いずれもエラーにならず、誤った基準が呼び出し元に渡る。
- Decision:
  - オーバーライドが指定されていない push では、`GITHUB_REF` が `refs/heads/` で始まり、かつ `GITHUB_EVENT_DELETED` が `true` でない場合だけ解決する。それ以外は `::error::` で終了する (許可リスト方式)。
  - 削除の判定には `github.event.deleted` を使う。削除時は `github.ref` がデフォルトブランチに戻るため、ref だけでは削除を検出できない。
  - オーバーライドが指定されている場合は、この検証を適用しない。オーバーライドではイベントの before / after と ref を参照しないためである。
  - DR-17 のイベント名の検証は環境の契約の検査であり、全経路に適用する。本 DR の検証は、イベント別解決の意味に対する制限であり、push のイベント別解決にだけ適用する。
  - push 以外のイベントは、ref がタグであっても REQ-F-009 で解決する。本 DR の制限は、push の before / after の意味に依存するものだからである。
- Alternatives:
  - 前提として Out of Scope に記載し、検出しない。前提が破れると誤った基準が正常終了で返り、fail-first の方針 (DR-10, DR-14) に反するため不採用。
  - 削除・タグの push を、その他イベントと同様に HEAD~N / HEAD で解決する。削除時の比較は意味を持たず、`resolution` で区別できるだけであるため不採用。
  - オーバーライド指定時にも検証を適用する。タグの push で任意の二点を比較する用途を塞ぐため不採用。
- Rationale: 誤った基準を正常終了で返す経路をなくす。判定は環境変数だけで行い、git の操作を要しない。
- Trade-offs: `on: push` を絞っていない呼び出し元では、ブランチ削除やタグの push のたびに本 Action がエラーとなる。呼び出し元は、これらの push を除外する必要がある。除外には `branches:` での絞り込みか `if: ${{ !github.event.deleted }}` を使う。現行の `ca-get-changed-files` は、タグ作成 (before が全ゼロ) を空ツリーとの比較として成功させていた。このため挙動変更となるが、該当する呼び出し元はない。オーバーライド値の妥当性は呼び出し元の責務とし、REQ-F-013 / REQ-F-016 の検証だけを適用する。
- Related: REQ-F-003 / REQ-F-004..006 / REQ-F-009 / REQ-F-011 / REQ-F-020 / REQ-C-003 / REQ-C-006 / DR-10 / DR-14 / DR-17

## Change History

| Date       | Version | Description                                                                             |
| ---------- | ------- | --------------------------------------------------------------------------------------- |
| 2026-10-25 | 1.0.0   | Initial release                                                                         |
| 2026-10-25 | 1.1.0   | Add DR-07..DR-14 (review harden / req revision / codex review); clarify DR-03 threshold |
| 2026-10-25 | 1.2.0   | Add DR-15..DR-22 (spec review explore / harden / codex review, req revision)            |
| 2026-10-25 | 2.0.0   | Remove DR-15/16/20/21/22 (over-scoped); add DR-23 (partial clone is an error)           |
| 2026-10-25 | 2.1.0   | Add DR-24 (reject empty tree override), DR-25 (push limited to branch create/update)    |
