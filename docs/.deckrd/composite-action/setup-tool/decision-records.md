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
