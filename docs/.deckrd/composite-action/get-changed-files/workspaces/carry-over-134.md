# Issue #134 の持ち越し事項

requirements v2.0.1 の作成時に見つけた食い違いのうち、spec 以降で扱うものを記録する。
各項目は、対応したフェーズで解消済みにする。

## 旧ドキュメント (spec / impl / tasks) とコードの食い違い

spec / impl / tasks を新しい requirements から作り直す際に解消する。

- [x] 旧 spec は `action.yml` を 1 step としているが、コードには resolve-sha の step がある
- [x] 旧 impl に書かれたユニットテストのパス (`scripts/__tests__/unit/`) が、実際の場所 (`scripts/_libs/__tests__/unit/filter.unit.spec.sh`) と違う
- [x] 旧 tasks の ID 体系 (`[nrm-01]`) が、コードの `T-gcf-*` とも module.md の `test_scope: GCF` とも合わない
- [x] 旧 impl が、存在しない ID (IMPL-001、SPEC-001、REQ-001) を参照している
- [x] 旧 tasks は `write_multiline_output` の「空値」テストを挙げているが、コードの T-wrt-edg-01 は値 `0` を検証している

## コードの問題 (#134 の実装で書き直す際に解消する)

- [ ] `action.yml` の `run` の中で `${{ github.action_path }}` を使っている (requirements REQ-C-001 で禁止)
- [ ] `action.yml` の `# src:` ヘッダーが `./.github/actions/validate-environment/action.yml` を指している
- [ ] `get-changed-files.sh` の `@(#)` 行が、push イベント専用の説明のまま (pull_request・その他イベントに触れていない)

## モジュール外の作業

- [ ] `_tests_ca_composite-actions.yml` に `test-filter-files` ジョブがない。
      filter-files implementation.md Phase 6 Commit 2 の作業であり、#136 の残作業として別ブランチで扱う
