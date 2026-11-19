---
title: "ci-platform Release Notes v0.7.1"
version: "0.7.1"
date: 2026-11-19
tags:
  - release
  - reusable-workflows
  - composite-actions
summary: >
  This patch release pins the external actions used by composite actions to
  commit SHAs and relocks the ci-platform references in reusable workflows to v0.7.1
---

## ci-platform v0.7.1 - 2026-11-19

Composite Action が利用する外部 Action をコミット SHA に固定しました。
あわせて、再利用可能ワークフローが参照する ci-platform の Composite Action を v0.7.1 に更新しました。
すべての Composite Action とパッケージのバージョンを v0.7.1 に揃えています。

## 主な変更

### 外部 Action をコミット SHA に固定

- `ca-setup-repo` と `ca-run-secretlint` が利用する外部 Action を、タグではなくコミット SHA で参照するようにしました。
  - `actions/checkout`: v7.0.1
  - `actions/setup-node`: v7.1.0
  - `pnpm/action-setup`: v6.1.1

### 再利用可能ワークフローの参照を更新

- 次の再利用可能ワークフローが呼び出す Composite Action の参照を、v0.7.0 から v0.7.1 に更新しました。
  - `ru-lint-documents.yml`
  - `ru-qa-actionlint.yml`
  - `ru-qa-actions-lock.yml`
  - `ru-qa-ghalint.yml`
  - `ru-scan-secrets.yml`
- 上記ワークフローの `# @version` ヘッダーを 0.7.1 に更新しました。
- `ci-publish-docs.yml` が呼び出す `ca-validate-environment` を v0.7.1 に更新しました。

### バージョンの統一

- すべての Composite Action の `# @version` ヘッダーを 0.7.1 に更新しました。
- `package.json` のバージョンを 0.7.1 に更新しました。

## 移行時の注意

- 機能の変更はありません。入力や出力の互換性にも影響はありません。
- 参照タグを `v0.7.1` に更新してください。

## 開発者向けの改善

- `.github/workflows/actions.lock` の `aglabo/ci-platform` を v0.6.1 から v0.7.0 に更新しました。
