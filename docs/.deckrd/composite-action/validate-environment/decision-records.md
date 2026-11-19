---
title: "Decision Records: ca-validate-environment"
module: "composite-action/validate-environment"
status: Draft
version: 1.0.0
created: "2026-11-19"
---

<!-- textlint-disable
  ja-technical-writing/sentence-length,
  ja-technical-writing/max-comma,
  ja-technical-writing/no-doubled-joshi,
  ja-technical-writing/no-mix-dearu-desumasu,
  ja-technical-writing/ja-no-redundant-expression,
  @textlint-ja/no-synonyms
  -->
<!-- markdownlint-disable line-length -->

## DR-01: 検証を 3 本のスクリプト・3 ステップに分ける

- Status: Accepted
- Context: 検証対象はランナー、権限、アプリケーションの 3 領域で、それぞれ依存する環境変数・外部コマンドが異なる。
- Decision: `validate-git-runner.sh` / `validate-permissions.sh` / `validate-apps.sh` の 3 本に分け、`action.yml` の独立した 3 ステップから実行する。
  ステップごとに `status` / `message` を出力する。
- Alternatives:
  - 1 本のスクリプトに統合する。領域ごとの出力を分けられず、単体テストも粗くなるため不採用。
- Rationale: 領域ごとに出力とテストを分離できる。呼び出し元は必要な出力だけを参照できる。
- Trade-offs: 先行ステップが失敗すると composite の既定動作で後続ステップは実行されず、後続の出力は空になる。
- Related: REQ-F-001, REQ-F-002, REQ-F-003

## DR-02: 対応 OS を Linux に限る

- Status: Accepted
- Context: 本 Action の呼び出し元は ubuntu 系ランナーだけを使い、後続のツール導入も Linux 前提である。
- Decision: OS が `linux` 以外ならエラーとする。Windows と macOS は対象外とする。
- Alternatives:
  - 他 OS も許可する。後続 Action が動かないため、ゲートの意味が薄れ不採用。
- Rationale: 前提を満たさない環境を、最初のステップで早く失敗させる。
- Trade-offs: Windows / macOS ランナーでは使えない。
- Related: REQ-F-004, REQ-C-001

## DR-03: 書き込み権限は無効なペイロードのプローブで確認する

- Status: Accepted
- Context: `GITHUB_TOKEN` のスコープは API から直接取得できない。実際に書き込むと副作用が残る。
- Decision: `commit` は `git/refs`、`pr` は `pulls` に、必ず検証で弾かれる無効なペイロードを POST する。
  403 は権限なし、201 / 409 / 422 は権限ありと判定する。
- Alternatives:
  - 実際にブランチや PR を作る。副作用が残るため不採用。
  - `X-OAuth-Scopes` ヘッダーを読む。`GITHUB_TOKEN` では返らないため不採用。
- Rationale: リソースを作らずに、書き込み権限の有無だけを区別できる。
- Trade-offs: GitHub API の応答仕様 (422 / 409) に依存する。HTTP ステータスの取得に不具合があると、すべてエラー扱いとなる (OQ-01)。
- Related: REQ-F-012, REQ-F-013, REQ-NF-002

## DR-04: `read` では API 確認を行わない

- Status: Accepted
- Context: `contents: read` は、Actions が既定で付与する最小権限である。API では「付与されていない」ことを検知できない。
- Decision: `actions-type=read` ではトークンの存在だけを確認し、`permissions` セクションの明示をユーザーに促すメッセージを出す。
  `any` はプローブを省略し、トークンの存在だけを確認する。
- Alternatives:
  - 読み取り API を呼んで確認する。権限不足を区別できないため不採用。
- Rationale: 確認できない項目を、確認できたかのように扱わない。
- Trade-offs: `read` の指定ミスはこの Action では検知できない。
- Related: REQ-F-011, REQ-F-014

## DR-05: `require-github-hosted` の既定は Action では `false`

- Status: Accepted
- Context: セルフホストランナーでも使える Action にしたい。一方、スクリプト単体の既定値は `true` である。
- Decision: `action.yml` の既定値を `"false"` とし、常にスクリプトへ明示的に渡す。
  判定は `RUNNER_ENVIRONMENT=github-hosted` による (GitHub 仕様依存)。
- Alternatives:
  - 既定を `true` に揃える。セルフホストランナーが使えなくなるため不採用。
- Rationale: Action 経由では入力の既定値が常に有効となり、スクリプト既定値は単体実行時にだけ効く。
- Trade-offs: 両者の既定値が異なるため、単体実行時の挙動に注意が要る (OQ-04)。
- Related: REQ-F-008

## DR-06: アプリケーション検証はフェイルファストにする

- Status: Accepted
- Context: ゲート Action では、最初の不備で止めたほうがログが読みやすい。
- Decision: 検証ループは最初の失敗で `handle_validation_error` を呼び、`status=error` を書いて終了する。
  全アプリの成功時のみ `status=success` とバージョン一覧を書く。
- Alternatives:
  - 全アプリを検証して失敗を集約する。出力形式が複雑になるため不採用。
- Rationale: 実装が単純になり、失敗原因が 1 件に絞られる。
- Trade-offs: 複数の不備は、修正と再実行を繰り返して初めて分かる。
- Related: REQ-F-022

## DR-07: バージョン抽出は接頭辞付き抽出器と許可リストで安全化する

- Status: Accepted
- Context: `additional-apps` は呼び出し元が与える文字列であり、そのまま評価するとインジェクションの経路になる。
- Decision: `eval` を使わない。抽出方式は `field:N` / `regex:PATTERN` / 空 (auto) に限る。
  正規表現は `is_safe_regex` で、制御文字 → 危険なメタ文字 → 許可リスト (`A-Za-z0-9 . _ ( ) + ^ : [ ] -` と空白) の順に検査する。
  ReDoS の面を減らすため `*` と `?` は許可リストから除く。
- Alternatives:
  - 任意の `sed` スクリプトを許す。インジェクションを防げないため不採用。
- Rationale: 抽出器の種類と文字種を限れば、検査が機械的に書ける。
- Trade-offs: 表現できる正規表現が限られる。`#` は行内コメントとして除去されるため、パターンに使えない。
- Related: REQ-F-017, REQ-NF-001

## DR-08: 入力はすべて環境変数で渡す

- Status: Accepted
- Context: `run:` に `${{ inputs.* }}` を展開すると、スクリプトインジェクションの経路になる。
- Decision: すべての入力を `env:` に渡し、`run:` 本体にはシェル変数だけを書く。
  スクリプトの場所は `${GITHUB_ACTION_PATH}` で解決する。
- Alternatives:
  - `run:` に直接展開する。インジェクションの面が増えるため不採用。
- Rationale: 値がシェルの構文として解釈されない。
- Trade-offs: 入力ごとに `env:` の行が要る。
- Related: REQ-NF-001, REQ-F-001

## DR-09: 追加アプリは最大 30 件に制限する

- Status: Accepted
- Context: 標準入力から読む件数に上限がないと、ゲート Action のリソース枯渇につながる。
- Decision: 既定アプリを含めて `MAX_APPS=30` を超えたら `::error::` を出して終了する (`initialize_apps_list` は終了コード 2)。
- Alternatives:
  - 上限なし。DoS の面になるため不採用。
- Rationale: 通常の用途に十分で、暴走を防げる。
- Trade-offs: 31 件以上は分割できない。
- Related: REQ-F-020

## DR-10: 既定の検査対象は Git (2.30 以上) と curl とする

- Status: Accepted
- Context: 後続の Action が確実に使うコマンドだけを、既定で検査する。
- Decision: 既定アプリは `git|Git|field:3|2.30` と `curl|curl||` とする。それ以外 (例: `gh`) は `additional-apps` で追加する。
- Alternatives:
  - `gh` も既定で検査する。使わない呼び出し元にも要求が及ぶため不採用。
- Rationale: 既定は最小にし、追加は呼び出し元が選ぶ。
- Trade-offs: スクリプト冒頭のコメントは `gh` を既定の検査対象と書いており、実装と食い違う (OQ-03)。
- Related: REQ-F-015

## DR-11: 共有ライブラリは `GITHUB_ACTION_PATH` からの相対で読み込む

- Status: Accepted
- Context: 3 本のスクリプトは `output.lib.sh` / `env.lib.sh` を共有する。Action の実行時とテストの実行時で、基準のパスが異なる。
- Decision: `${GITHUB_ACTION_PATH}/../_libs` を使う。`GITHUB_ACTION_PATH` が空のときは `${SHELLSPEC_PROJECT_ROOT}/.github/actions/_libs` を使う。
- Alternatives:
  - 相対パス (`BASH_SOURCE` 基準)。呼び出し方により基準がずれるため不採用。
- Rationale: 実行環境ごとの基準を 1 箇所で吸収できる。
- Trade-offs: どちらの変数も空だと、読み込みが失敗する。
- Related: REQ-C-004

## Change History

| Date       | Version | Description                                     |
| ---------- | ------- | ----------------------------------------------- |
| 2026-11-19 | 1.0.0   | Initial release: DR-01..DR-11 from current code |
