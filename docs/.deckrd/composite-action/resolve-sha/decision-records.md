---
title: "Decision Records: _ca-resolve-sha"
module: "composite-action/resolve-sha"
status: Draft
version: 1.2.0
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

## DR-15: イベント由来の SHA にも完全長 OID の形式検証を適用する

- Status: Accepted
- Context: spec explore review (G-01) で、イベント由来の値 (push の before と github.sha、pull_request の base と head) に形式検証がないと指摘された。`git cat-file -e <v>^{commit}` は `main` や `HEAD~1` も受理する。このため、イベント経路で固定 SHA ではない値を `resolution=event` として出力し得る。
- Decision:
  - イベント由来の値にも `^[0-9a-f]{40}$` を適用する。
  - push の before が形式に一致しない場合は、無効な before として HEAD~N にフォールバックする (DR-02 と同じ扱い)。
  - push の after (github.sha)、pull_request の base と head が形式に一致しない場合は、`::error::` で終了する。
  - 形式検証は、コミット実在検証より先に行う。
- Alternatives:
  - `git rev-parse` で完全長 OID に正規化して出力する。出力値が入力値と異なり得るうえ、DR-14 でオーバーライドに採らなかった方式と食い違うため不採用。
  - GitHub が完全長 SHA を渡すと前提し、記載だけにとどめる。テストや再利用の場面で固定 SHA の契約が破れるため不採用。
- Rationale: 出力が常に固定 SHA であるという契約を、オーバーライド経路だけでなく全経路で保つ。
- Trade-offs: 検証規則が増える。push の before だけ扱いが異なる (エラーではなくフォールバック) ことを、仕様で明示する必要がある。
- Related: REQ-F-004 / REQ-F-005 / REQ-F-006 / REQ-F-008 / REQ-F-013 / REQ-F-016 / DR-02 / DR-14

## DR-16: push の通常解決は after に github.sha を使い続ける

- Status: Accepted
- Context: spec explore review (A-02) で、push の after の基準が経路によって異なると指摘された。通常解決は github.sha を使い、フォールバックは checkout 済み HEAD を使う (DR-09)。checkout の `ref` が github.sha と異なる場合、同じ push でも経路によって after が別のコミットになる。
- Decision: DR-09 を維持する。push の通常解決は (event.before, github.sha) とし、フォールバックとその他イベントは HEAD を基準とする。この差は許容するものとして仕様に明記する。github.sha のコミットを checkout することは、呼び出し元の責務とする。
- Alternatives:
  - 通常解決でも after に HEAD を使う。event.before が HEAD と別の履歴線上になり得るため不採用。
  - github.sha と HEAD が異なる場合はエラーにする。正当な checkout 構成まで拒否するため不採用。
- Rationale: イベントが示す二点の組を崩さず、既存の決定 (DR-09) を変えずに済む。
- Trade-offs: checkout の `ref` を変えた呼び出しでは、経路ごとに after の意味が変わる。呼び出し元はこれを `resolution` で区別する。
- Related: REQ-F-004 / REQ-F-005 / REQ-F-006 / REQ-C-003 / DR-09

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

## DR-20: push の before の検査障害は近似解決の例外とし、遅延取得を抑止する

- Status: Accepted
- Context: codex risk review (spec) で 2 点が指摘された。1 点目は R-104 である。push の before に対する `git cat-file -e` の失敗には、旧コミットの不在とオブジェクトの破損・読み取り障害の両方が含まれる。git はどちらも同じ終了コード (128) を返すため区別できない。2 点目は partial clone である。欠損オブジェクトの参照が promisor remote からの暗黙の取得を起動し、REQ-NF-002 (ネットワーク不使用) を破り得る。
- Decision:
  - push の before の検査失敗は、原因を問わず無効な before として HEAD~N にフォールバックする。旧コミット側の障害を検出できないことを、保証の例外として仕様に明記する。HEAD 側の障害は R-111 / R-113 / R-115 で従来どおり検出する。
  - すべての git 操作に `GIT_NO_LAZY_FETCH=1` を適用し、遅延取得を抑止する。
  - partial clone は許容する。各経路で必要なコミットは、呼び出し元が事前に取得しておく前提とする。遅延取得の抑止によるコミット不在は既存の規則で扱い、shallow 境界と同一視しない。
- Alternatives:
  - before の不在と障害を区別する検査を定義する。終了コードで区別できず、確実な判定方法がないため不採用。
  - partial clone を前提から除外するだけにする。ランナーの git が `GIT_NO_LAZY_FETCH` に対応していれば、抑止で対応できるため不採用。前提の記載は併用する。
  - `git --no-lazy-fetch` を使う。git 2.46.0 以降に限られ、テスト環境の git 2.39.5 で使えないため不採用。
- Rationale: 区別できない失敗を区別できるように見せかけず、例外として明記する。環境変数は未対応の git では無視されるだけで副作用がない。
- Trade-offs: `GIT_NO_LAZY_FETCH` に未対応の git (例: 2.43.0) では抑止が効かない。この場合の REQ-NF-002 は、呼び出し元の事前取得の前提で担保する。
- Related: REQ-F-006 / REQ-F-013 / REQ-F-014 / REQ-NF-002 / DR-02 / DR-10 / DR-14

## DR-21: コミット実在検証を OID 自体の型検査とし、replace refs を無効にする

- Status: Accepted
- Context: codex risk review (requirements v1.2.0) で、注釈付きタグの OID が検証を通過すると指摘された。タグの OID も `^[0-9a-f]{40}$` に一致する。`git cat-file -e <oid>^{commit}` はタグを剥がしてコミットへ解決するため、存在検査も成功する。値をそのまま出力するため、コミット OID の契約に反してタグ OID を返し得る。また replace refs が有効だと、置換後のオブジェクトの型を検査してしまう。
- Decision:
  - 「コミットとして存在する」の検査を、修飾なしの OID に対する `git cat-file -t <oid>` とする。終了コード 0 かつ出力 `commit` の場合のみ成功とする。push の before を含む全検証対象に適用する。
  - 終了コードが 0 以外なら、値を問わず検査失敗とする。
  - 注釈付きタグは、参照先がコミットでも拒否する。lightweight tag の参照先 OID はコミット OID であり受理する。
  - すべての git 操作に `GIT_NO_REPLACE_OBJECTS=1` を適用し、型検査と HEAD~N の解決で置換の扱いをそろえる。
  - 旧形式の graft ファイルは、この設定で無効にならないため、対象外とする。
- Alternatives:
  - `git rev-parse --verify -q <oid>^{commit}` の出力を元の OID と比較する。同じ結果を得られるが、契約 (OID 自体が commit 型) を直接表現できないため不採用。
  - `git --no-replace-objects` を各呼び出しに付ける。環境変数なら全呼び出しに一括で適用でき、付け忘れが起きないため不採用。
- Rationale: 存在検査と型検査を 1 回の git 呼び出しで行い、出力が常にコミット OID であることを保証する。`GIT_NO_REPLACE_OBJECTS` は git 1.6.6 で導入済みであり、テスト環境の git 2.39.5 でも使える。
- Trade-offs: 注釈付きタグの OID を渡していた呼び出し元は、コミット OID に直す必要がある。replace refs を意図して使うリポジトリでは、置換前の履歴で解決する。
- Related: REQ-F-005 / REQ-F-006 / REQ-F-013 / REQ-NF-002 / DR-10 / DR-15

## DR-22: 遅延取得抑止に未対応の git での partial clone は対象外とし、AC-017 を全経路に広げる

- Status: Accepted
- Context: codex risk review (requirements v1.2.0) で、DR-20 の代替策が成立しないと指摘された。`GIT_NO_LAZY_FETCH` に未対応の git では、push の before の存在検査自体が遅延取得を起動し得る。HEAD 側の事前取得では防げない。また AC-017 は push の before しか検証せず、他の経路で抑止が漏れる実装を排除できない。
- Decision:
  - `GIT_NO_LAZY_FETCH` に未対応の git と partial clone の組み合わせは対象外とし、呼び出し元の責務とする。
  - AC-017 は抑止に対応した git での実行を前提とし、push の before、pull_request の base、オーバーライド値、HEAD~N に至る祖先の欠損を検証する。
  - 祖先の欠損は shallow 境界と区別し、`empty-tree` ではなくエラーとすることを AC-017 で確認する。
- Alternatives:
  - 抑止に対応した git を必須とし、バージョンで判定する。抑止機能は修正版へのバックポートで導入されており、バージョンの大小では判定できないため不採用。
  - partial clone を一律に対象外とする。抑止に対応した git では安全に扱えるため不採用。
- Rationale: 担保できない前提を要件から外し、担保できる範囲を全経路のテストで確認する。
- Trade-offs: 古い git の self-hosted runner で partial clone を使う場合、ネットワーク不使用は保証されない。
- Related: REQ-NF-002 / REQ-C-003 / DR-20

## Change History

| Date       | Version | Description                                                                             |
| ---------- | ------- | --------------------------------------------------------------------------------------- |
| 2026-10-25 | 1.0.0   | Initial release                                                                         |
| 2026-10-25 | 1.1.0   | Add DR-07..DR-14 (review harden / req revision / codex review); clarify DR-03 threshold |
| 2026-10-25 | 1.2.0   | Add DR-15..DR-22 (spec review explore / harden / codex review, req revision)            |
