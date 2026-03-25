---
title: "Decision Records: setup-tool Composite Action"
module: "composite-action/setup-tool"
---

<!-- textlint-disable
  ja-technical-writing/sentence-length,
  ja-technical-writing/max-comma -->
<!-- markdownlint-disable line-length no-duplicate-heading -->

> DR-01〜DR-10 は requirements.md Section 3 (Design Decisions Summary) に記載。

## Decision Record

### DR-11: validate.spec ルールの規範化・境界明示・エラーメッセージ品質保証

**Phase**: review-harden
**Status**: Accepted
**Date**: 2026-03-23

### Context

`validate.spec.md` の explore レビュー (2026-03-23) での課題:

1. fail-fast 挙動が Section 2.1 の説明文にあるが、規則 (R-xxx) として昇格されていなかった
2. `tool-version` の受理条件が自然言語のみで、`1.2.3.4`・`1.2.3-beta` 等の境界値が明示されていなかった
3. `repo` 検証で「スラッシュが 1 個のみ」という条件が未明示 (`org/repo/extra` の挙動が未定義)
4. `tool-name` 空文字のケースが Edge Cases に記載されていなかった
5. エラーメッセージの内容品質が実装に委ねられていた

### Decision

`validate.spec.md` v1.1.0 に以下を反映:

1. R-001 条件を `^v?[0-9]+(\.[0-9]+){0,2}$` で明示 (4 桁以上・英字修飾子を含む場合も明確に拒否)
2. R-003 条件に「空文字・未指定もパターン不適合」を明記
3. R-004 条件に「スラッシュが 1 個のみ」を追加
4. Section 4 末尾に fail-fast セマンティクスを明記 (最初の失敗で即 exit 1、後続ルール非評価)
5. Section 3.2 のエラーメッセージ仕様に「入力名と期待形式を含む」を追加
6. Section 5 Edge Cases に境界値 4 件を追加 (`1.2.3.4`・`1.2.3-beta`・空 tool-name・repo スラッシュ過剰)

### Alternatives Considered

- Option A: 正規表現は impl-note にのみ記載し仕様には自然言語のみ → テスト作成者が境界値を独自解釈するリスクがある
- Option B: 全条件を正規表現で明示 (今回採択) →「自然言語 + 正規表現」の併記で可読性と正確性を両立

### Rationale

バリデーション仕様の目的は「何が通り、何が拒否されるか」の境界値をテスト可能な形で明示することです。
自然言語のみでは境界が曖昧になり、実装とテストに齟齬が起きます。
REQ-NF-002 の「失敗の理由に応じたエラーメッセージ」要件に適合させるため、エラーメッセージ内容を仕様として規定する。

### Consequences

- Positive:
  - テスト作成者が境界値をテスト仕様から直接導出できる
  - 実装者とレビュアーの解釈の一致が保証される
  - エラーメッセージ品質が仕様として保証される (REQ-NF-002 適合)
- Negative:
  - 正規表現が仕様ドキュメントに含まれるため、仕様変更時に正規表現の更新も必要になる

---

### DR-12: tool-version 検証を normalize_version() に委譲し柔軟な入力形式を許容

**Phase**: spec-update
**Status**: Accepted
**Date**: 2026-03-23

### Context

`validate.spec.md` v1.1.x では `tool-version` を `^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]+$` で厳格に検証していた。
`common.lib.sh` に `normalize_version()` が既存実装として存在し、v/V プレフィックス・X.Y・X 形式の正規化と英字修飾子の拒否を一括して担えることが判明した。

### Decision

- `tool-version` 検証・正規化を `common.lib.sh` の `normalize_version()` に委譲する
- `normalize_version()` の return 1 を validation failure として扱い exit 1
- 正規化後の X.Y.Z 値を後続ステップへの出力として確定する (R-001-N)
- 許容形式を拡大: `vX.Y.Z`, `X.Y.Z`, `X.Y`, `X` すべて受け付け

### Alternatives Considered

- Option A: 正規表現 `^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]+$` を維持 (X.Y.Z のみ許容) → 呼び出し側に正規化責務を押し付ける。CI で `v1.7.10` を渡すユースケースに対応できない
- Option B: normalize_version() に委譲 (今回採択) → 既存関数の再利用で実装コスト低、柔軟な入力形式に対応

### Rationale

`normalize_version()` はすでにバリデーターとして機能する (return 1 + stderr) 。新たな検証ロジックを追加せず既存実装を活用することで、責務集約と実装コスト削減を両立する。

### Consequences

- Positive:
  - ユーザーが `v1.7.10` / `1.7` など様々な形式で入力可能になる
  - バリデーション・正規化ロジックが `common.lib.sh` に集約される
  - `validate.spec.md` の R-001 条件がシンプルになる
- Negative:
  - `normalize_version()` の仕様変更が validate の挙動に直接影響する (依存関係の明示が必要)

---

### DR-13: 全入力にサニタイズと文字数上限を適用

**Phase**: spec-update
**Status**: Accepted
**Date**: 2026-03-23

### Context

`^[a-z][a-z0-9_-]*$` 等のパターン検証は、ゼロ幅スペース (`\u200b` 等) や制御文字 (`\x00`-`\x1f`) をパターンによっては通過させてしまう可能性がある。また文字数上限がないと、異常に長い入力がコマンドライン引数やファイル名として展開された際にバッファ超過・ログ汚染のリスクがある。

### Decision

- 全入力の検証前に R-000 サニタイズを実行 (前後空白・制御文字・ゼロ幅文字除去)
- 文字数上限を設定: tool-name 64 文字・tool-version 32 文字・asset-template 256 文字・repo org 部 39 文字・repo repo 部 64 文字
- org 部の 39 文字は GitHub の実制約に準拠。その他は実用範囲から設定

### Alternatives Considered

- Option A: パターン検証のみ (現状) → 不可視文字のすり抜けリスクあり
- Option B: サニタイズ + 文字数制限 (今回採択) → 防御深度が増す。実用上の制約として許容範囲内

### Rationale

セキュリティの観点から「入力を信頼しない」原則を適用する。不可視文字はデバッグを困難にし、ログ汚染・なりすまし等のリスクを持つ。文字数制限は GitHub 実制約と実用範囲に基づいており、正当なユースケースを妨げない。

### Consequences

- Positive:
  - 不可視文字・制御文字によるセキュリティリスクを排除
  - 異常入力に対する防御深度が増す
  - エラーメッセージが明確になる (「64 文字以内で指定してください」等)
- Negative:
  - サニタイズによって入力が変形する場合もあるため、デバッグ時に元の入力と異なる値が検証される点を認識する必要がある

---

### DR-14: 入力検証をホワイトリスト方式に統一し Unicode を拒否、checksum-template に `<filename>` メタ変数を導入

**Phase**: spec-update
**Status**: Accepted
**Date**: 2026-03-23

### Context

前回の DR-13 で「サニタイズ (除去) + パターン検証」を採用したが、`validate-apps.sh` の設計 (ホワイトリストベース拒否) と整合していなかった。また `checksum-template` が `asset-template` と同一のプレースホルダ方式を使っており、`{tool_name}` 等を直接埋め込める設計はインジェクションリスクがあった。

### Decision

1. 全入力の検証を「前後空白除去 → ASCII 以外 Unicode を拒否 (R-000U) → ホワイトリスト正規表現」に統一
2. フィールド別ホワイトリスト:
   - `tool-name`/`repo` 各部: `^[a-z][a-z0-9_-]{0,N}$`
   - `asset-template`: `^[A-Za-z0-9._{}/-]{1,256}$`
   - `checksum-template`: `^(<filename>)?[A-Za-z0-9._-]{0,255}$`
3. `checksum-template` のプレースホルダを `<filename>` メタ変数 1 種に限定 (0 or 1 回) 。`<filename>` は解決済みの `asset_filename` に置換される

### Alternatives Considered

- Option A: DR-13 の「除去 + 検証」を維持 → 入力の変形のため、デバッグが困難。`validate-apps.sh` の設計と不整合
- Option B: ホワイトリスト拒否 (今回採択) → 入力は変形しない (前後空白除去のみ) 。拒否理由が明確

### Rationale

「除去」は入力を変形させてデバッグを困難にする。`validate-apps.sh` が実証しているホワイトリスト拒否のほうが、透明性が高い。`checksum-template` の `<filename>` 限定はプレースホルダ構文を最小化しインジェクション面を削減する。

### Consequences

- Positive:
  - 入力値が前後空白除去以外で変形しないため、エラー時に元の入力がそのまま表示される
  - ホワイトリスト外文字 (Unicode・制御文字・特殊記号) はすべて明確に拒否される
  - `checksum-template` の `<filename>` は asset_filename との依存関係を明示し、テンプレート設計が安全になる

- Negative:
  - `asset-template` の `{keyword}` 構文はホワイトリストで `{` `}` を許可するが、`keyword` の内容は validate では検証しない。
  - (未知キーワードは build-url 側で空文字置換)

---

### DR-15: ログメッセージ生成を logging.lib.sh に集約し、出力責務を呼び出し側に委譲

**Phase**: implementation-design
**Status**: Accepted
**Date**: 2026-03-25

### Context

`common.lib.sh` の `normalize_version()` が `echo "Error: ..." >&2` 形式でエラーを出力しており、
`validation.lib.sh` は `echo "::error::..." >&2` 形式を使用している。
形式が不統一であり、テスト時にメッセージ内容を検証しにくい問題があった。
また、GitHub Actions アノテーション形式 (`::error::`, `::warning::`) を各関数が直接出力すると、
ローカル実行時の挙動との差異や、テスト時のモック困難性が生じる。

### Decision

1. `_libs/logging.lib.sh` を新規作成し、メッセージ**生成**関数を集約する:
   - `make_error_message <field> <msg>` → stdout に `::error::<field>: <msg>` を返す
   - `make_warning_message <field> <msg>` → stdout に `::warning::<field>: <msg>` を返す
   - `make_notice_message <msg>` → stdout に `::notice::<msg>` を返す
2. 各関数は**出力しない** (stdout にメッセージ文字列を echo するのみ)
3. 出力 (`>&2` や `echo`) は呼び出し側の責務とする
4. `common.lib.sh` / `validation.lib.sh` は `logging.lib.sh` を source して使用する
5. テストでは `Mock make_error_message` で差し替え可能にする

### Alternatives Considered

- Option A: 各ライブラリが独自にメッセージを直接出力 (現状) → 形式不統一・テストでモック困難
- Option B: logging.lib.sh がメッセージを生成して出力まで担う → 呼び出し側が出力先 (stdout/stderr) を選べない
- Option C: メッセージ生成のみを担い出力は呼び出し側 (今回採択) → テストでモック可能・出力先を呼び出し側が制御できる

### Rationale

メッセージ形式を一箇所に集約することで、GitHub Actions アノテーション形式の変更が
`logging.lib.sh` 一箇所の修正で済む。出力責務を呼び出し側に委譲することで、
ShellSpec の `Mock` を使ったメッセージ生成のテストが容易になる。

### Consequences

- Positive:
  - `::error::` / `::warning::` 形式が全ライブラリで統一される
  - テスト時に `Mock make_error_message` でメッセージ生成を差し替え可能
  - 呼び出し側が stdout/stderr を選択できる柔軟性がある
- Negative:
  - すべての呼び出し側が `. logging.lib.sh` する必要
  - メッセージ出力の 2行記述 (`_msg=$(make_error_message ...); echo "$_msg" >&2`) がやや冗長

---

### DR-16: validate_symbol を 2 層構造に再設計 (汎用バックエンド + フィールド専用フロントエンド)

**Phase**: implementation-design
**Status**: Accepted
**Date**: 2026-03-25

### Context

現行の `validate_symbol(value, field_name, pattern)` は呼び出し側がパターン文字列を知る必要があり、
以下の問題があった。

1. 呼び出し側がパターン正規表現を直接持つため、パターン変更時に呼び出し箇所を全修正する必要がある
2. テストケースごとにパターン文字列をハードコードしており、テストと実装の二重管理になる
3. `validate-inputs.sh` 側でパターン定数を定義するか関数内に定数を置くかの責務が曖昧
4. 戻り値がステータスコードのみで、正規化後の値をキャプチャする方法がない

### Decision

`validation.lib.sh` を 2 層構造に再設計する:

**Layer 1 汎用バックエンド (内部関数)**:

```bash
# _validate_symbol_backend value field_name pattern
# stdout: normalized value (trim済み) on success | (nothing) on failure
# stderr: ::error:: message on failure (logging.lib.sh 経由)
# return: 0 on success, 1 on failure
_validate_symbol_backend() { ... }
```

**Layer 2: フィールド専用フロントエンド (公開 API)**:

```bash
# パターンを関数内 readonly 定数として保持
validate_tool_name()  { _validate_symbol_backend "$1" "tool-name"  '^[a-z][a-z0-9_-]{0,63}$'; }
validate_repo_org()   { _validate_symbol_backend "$1" "repo-org"   '^[a-z0-9][a-z0-9-]{0,38}$'; }
validate_repo_name()  { _validate_symbol_backend "$1" "repo-name"  '^[A-Za-z0-9._-]{1,100}$'; }
```

**戻り値の再設計**:

- 成功: `return 0` + stdout に trim 済み値を出力
- 失敗: `return 1` + stderr に `::error::` メッセージを出力 (logging.lib.sh 使用)

**呼び出しイディオム**:

```bash
tool_name=$(validate_tool_name "$INPUT_TOOL_NAME") || exit 1
```

### Alternatives Considered

- Option A: 現行設計 (パターンを引数で渡す) を維持 → 呼び出し側がパターンを知る必要がある
- Option B: パターン名 (文字列キー) を引数で渡し、関数内で連想配列ルックアップ → bash 3 非互換・複雑
- Option C: 2 層構造 (今回採択) → パターンがフロントエンド関数内に閉じる・テストが関数単位で独立

### Rationale

フィールド専用関数にすることで「この入力には必ずこのパターン」が関数定義に自明に現れる。
`$(validate_tool_name "$val") || exit 1` のイディオムで正規化値の取得と失敗処理が 1 行で書ける。
バックエンドは引数でパターンを受け取るためテスト用の任意パターンも自然に渡せる。

### Consequences

- Positive:
  - 呼び出し側がパターン文字列を一切知らなくてよい
  - パターン変更はフロントエンド関数 1 箇所の修正で完結
  - `$(validate_tool_name "$val") || exit 1` のイディオムが使いやすい
  - テストがフィールド単位で独立し、意図が明確になる
- Negative:
  - フィールドが増えるたびにフロントエンド関数を追加する必要がある
  - `_validate_symbol_backend` の内部関数規約 (`_` プレフィックス) をチームで共有する必要がある

---

### DR-17: repo 検証を validate_repository() に一本化し org/name 個別関数を廃止

**Phase**: implementation-design
**Status**: Accepted
**Date**: 2026-03-25

### Context

DR-16 の 2 層設計で `validate_repo_org()` / `validate_repo_name()` を個別に定義したが、
`repo` 入力は常に `org/name` 形式で受け取るため、呼び出し側でスラッシュ分割と 2 回の検証呼び出しが必要になる。
これは呼び出し側の責務が増え、スラッシュ個数チェック (DR-11 R-004) の実装場所も曖昧になる。

### Decision

- `validate_repo_org()` / `validate_repo_name()` を**廃止**する
- `validate_repository(value)` を新設し、以下を一括して担う:
  1. trim (前後空白除去)
  2. スラッシュが 1 個のみかチェック (0 個・2 個以上はエラー)
  3. org 部を `_validate_symbol_backend` で検証 (`^[a-z0-9][a-z0-9-]{0,38}$`)
  4. name 部を `_validate_symbol_backend` で検証 (`^[A-Za-z0-9._-]{1,100}$`)
  5. 成功: stdout に `"org/name"` を出力して return 0
  6. 失敗: stderr に `::error::repo:` メッセージを出力して return 1

### Alternatives Considered

- Option A: `validate_repo_org` / `validate_repo_name` を個別に公開 → 呼び出し側でスラッシュ分割・2 回呼び出しが必要
- Option B: `validate_repository()` に一本化 (今回採択) → 呼び出し側は 1 行で完結、スラッシュ検証も内包

### Rationale

`repo` は仕様上常に `org/name` 形式であり、分割して個別検証する必要性が呼び出し側にはない。
`$(validate_repository "$INPUT_REPO") || exit 1` の 1 行イディオムで一貫して扱える。

### Consequences

- Positive:
  - 呼び出し側が `org/name` 分割ロジックを持たなくてよい
  - スラッシュ個数チェックが `validate_repository()` 内に集約される
  - `$(validate_repository "$val") || exit 1` のイディオムが一貫する
- Negative:
  - org 部・name 部を個別にテストする場合は `_validate_symbol_backend` を直接テストする必要がある
