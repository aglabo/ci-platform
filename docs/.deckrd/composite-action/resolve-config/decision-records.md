---
title: "Decision Records: _ca-resolve-config"
module: "composite-action/resolve-config"
status: Draft
version: 1.0.0
created: "2026-11-19"
---

## DR-01: 明示入力 config は唯一の候補とする

- Status: Accepted
- Context: 呼び出し元が `config` を指定した場合に、その指定が不在のとき、local や global へ進むかを決める必要がある。
- Decision: `config` が空でなければ、それだけを候補とする。通常ファイルでなければ、`file not found` のエラーにする。
- Alternatives:
  - 不在なら local / global へフォールバックする。指定の誤りが黙って別の設定に化けるため不採用。
- Rationale: 明示した指定は、呼び出し元の意図である。誤りは早く、はっきり失敗させる。
- Trade-offs: 呼び出し元は、指定したファイルを必ず用意する必要がある。
- Related: REQ-F-001

## DR-02: 探索順は config、local-config、global-config とする

- Status: Accepted
- Context: ツールの設定は、リポジトリ固有のものと、組織共通のものがある。
- Decision: 明示入力、リポジトリ内、グローバルの順に探す。
- Alternatives:
  - global を優先する。リポジトリ固有の設定が使えなくなるため不採用。
- Rationale: 具体的な指定ほど優先する。実行用スクリプト `runners/run-*.sh` も、ローカルを優先してグローバルへ落ちる順に揃う。
- Trade-offs: リポジトリ内の設定が、グローバルの設定を隠す。
- Related: REQ-F-002

## DR-03: パス検査は共有ライブラリの validate_path に任せる

- Status: Accepted
- Context: 設定のパスは呼び出し元の入力である。workspace の外のファイルを読ませない検査が要る。検査は他の Action でも使える。
- Decision: `.github/actions/_libs/path.lib.sh` に `validate_path` を置く (PR #216)。
  `resolve-config.lib.sh` は `GITHUB_WORKSPACE` を root として呼ぶ。
  検査は字面 (空、`..`、空白、root の内側) と、realpath による symlink の脱出の 2 段で行う。
- Alternatives:
  - `resolve-config.lib.sh` に独自の検査を持つ。他の Action で再利用できないため、#216 で置き換えた。
- Rationale: 検査を 1 箇所に集める。テストも共有ライブラリ側で持てる。
- Trade-offs: `validate_path` のテスト (`test_scope: PA`) は本モジュールの所有外となる。
- Related: REQ-F-004, REQ-C-002

## DR-04: 拒否したパスは不在と区別する

- Status: Accepted
- Context: local-config が workspace の外を指す場合に、global へ進むかを決める必要がある。
- Decision: 拒否は終了コード 1、不在は 2 として区別する。拒否した場合は、後続の候補を探さずエラーにする。
- Alternatives:
  - 拒否も不在と同じく次の候補へ進める。不正な入力が検知されないため不採用。
- Rationale: 拒否は入力の誤りまたは攻撃である。正常な不在とは意味が異なる。
- Trade-offs: 呼び出し元の誤ったパスが、global への落ち先を失わせる。
- Related: REQ-F-005

## DR-05: 出力は解決に成功した後にだけ書き出す

- Status: Accepted
- Context: エラー時に `config-file` が部分的に書き出されると、後続のステップが古い値や不完全な値を使うおそれがある。
- Decision: `main` は `resolve_config` の成功後に、`config-file`、`source`、`::notice::` の順で書く。エラー時は何も書かない。
- Alternatives:
  - 候補ごとに途中で書き出す。部分出力が残るため不採用。
- Rationale: 出力の有無が、解決の成否に一致する。
- Trade-offs: なし。
- Related: REQ-F-009

## DR-06: 空白を含むパスは実在しても拒否する

- Status: Accepted
- Context: `resolve_config` は結果を `<path> <source>` の 1 行で返し、空白で分割する。パスに空白があると、分割が曖昧になる。
- Decision: `validate_path` は値の空白を拒否する。root の空白は許す。
- Alternatives:
  - 区切りを変える (NUL、タブ)。呼び出し元でも空白は扱いにくく、必要性が低いため不採用。
- Rationale: 設定ファイルのパスに空白を使う実例は無い。単純な区切りを保つ方を選ぶ。
- Trade-offs: 空白を含むパスの設定ファイルは使えない。
- Related: REQ-F-004

## Change History

| Date       | Version | Description     |
| ---------- | ------- | --------------- |
| 2026-11-19 | 1.0.0   | Initial release |
