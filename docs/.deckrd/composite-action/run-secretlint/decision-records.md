---
title: "Decision Records: ca-run-secretlint"
module: "composite-action/run-secretlint"
status: Draft
version: 1.0.0
created: "2026-11-19"
---

## DR-01: secretlint は pnpm dlx で実行する

- Status: Accepted
- Context: secretlint をどう用意して実行するかを決める必要がある。
- Decision: `pnpm dlx "secretlint@<version>"` で実行する。リポジトリの依存には導入しない。
- Alternatives:
  - リポジトリの devDependencies に導入する。呼び出し元ごとに導入が要るため不採用。
  - `npx` を使う。Action が pnpm をセットアップするため、pnpm に揃える。
- Rationale: 呼び出し元は設定を書かず、導入もしない。版は入力で固定できる。
- Trade-offs: 実行のたびに secretlint を取得する。pnpm のセットアップが要る。
- Related: REQ-F-001, REQ-F-002

## DR-02: バージョンは major 14 以上の X.Y.Z だけを受け付ける

- Status: Accepted
- Context: `secretlint-version` は `pnpm dlx` の引数に入る。dist-tag や余分な文字列が混入すると、固定した版以外が動く。
- Decision: 先頭 0 のない major が 14 以上の `X.Y.Z` だけを受け付ける。`v` 接頭辞、接尾辞、dist-tag、空、複数行は拒否する。
- Alternatives:
  - 範囲指定や dist-tag を許す。実行する版が固定されないため不採用。
  - 検証せず pnpm に任せる。引数の混入を防げないため不採用。
- Rationale: 14 以降が設定を同梱する (DR-03)。厳密な形式で、実行する版を 1 つに決める。
- Trade-offs: 13 以前は使えない。更新のたびに入力を書き換える必要がある。
- Related: REQ-F-004

## DR-03: 設定ファイルの入力は設けない

- Status: Accepted
- Context: secretlint v14 以降は設定を同梱する。設定ファイルを渡す入力を設けるかを決める。
- Decision: `secretlintrc` や `config` の入力を設けない。引数なしで実行する。
- Alternatives:
  - 設定ファイルを入力で受け取る。同梱設定の前提が崩れ、検証の対象も増えるため不採用。
- Rationale: 設定を一定にして、リポジトリ間で検査の結果を揃える。
- Trade-offs: リポジトリごとの設定は使えない。
- Related: REQ-F-002, REQ-C-003

## DR-04: 外部 Action は SHA で固定し、チェックアウトと Node.js は扱わない

- Status: Accepted
- Context: 公開 Action が使う外部 Action は、供給網の攻撃面になる。Action の責務の境界も決める。
- Decision: `pnpm/action-setup` はコミット SHA で固定し、コメントに版 `v6.1.1` を残す。
  `actions/checkout` と Node.js のセットアップは行わない。
- Alternatives:
  - タグで指定する。タグは移動できるため不採用。
  - Node.js も本 Action で用意する。ランナーの Node.js で足りるため不採用。
- Rationale: 外部への依存を 1 つに絞り、固定する。チェックアウトは呼び出し元の責務とする。
- Trade-offs: 更新のたびに SHA を調べる必要がある。
- Related: REQ-C-002, REQ-NF-002

## DR-05: 入力の検証は pnpm の呼び出しより前に行う

- Status: Accepted
- Context: 不正な値で `pnpm dlx` を実行すると、取得や実行の副作用が出る。
- Decision: `main` は検証に成功した後にだけ `pnpm dlx` を実行する (fail-first)。失敗時は pnpm を呼ばない。
- Alternatives:
  - pnpm の失敗に任せる。不正な値の種類によっては実行してしまうため不採用。
- Rationale: 副作用の前に、はっきりしたエラーで止める。
- Trade-offs: なし。
- Related: REQ-F-004

## Change History

| Date       | Version | Description     |
| ---------- | ------- | --------------- |
| 2026-11-19 | 1.0.0   | Initial release |
