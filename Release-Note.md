---
title: "ci-platform Release Notes v0.7.1"
version: "0.7.1"
date: 2026-11-19
tags:
  - release
  - reusable-workflows
  - composite-actions
summary: >
  This patch release pins the external action used by ca-run-secretlint to
  a commit SHA and aligns all composite actions and the package version to v0.7.1
---

## ci-platform v0.7.1 - 2026-11-19

`ca-run-secretlint` が利用する外部 Action をコミット SHA に固定しました。
すべての Composite Action とパッケージのバージョンを v0.7.1 に揃えています。

## 主な変更

### 外部 Action をコミット SHA に固定

- `ca-run-secretlint` が利用する `pnpm/action-setup` (v6.1.1) を、タグではなくコミット SHA で参照するようにしました。
- `ca-setup-repo` が利用する外部 Action は、今回のリリースでもタグ参照のままです。

### 再利用可能ワークフローの参照

- 再利用可能ワークフロー (`ru-*.yml`) と `ci-publish-docs.yml` が呼び出す Composite Action の参照は、v0.7.0 のままです。
- v0.7.1 タグの作成後に、これらの参照を v0.7.1 へ更新する予定です。

### バージョンの統一

- すべての Composite Action の `# @version` ヘッダーを 0.7.1 に更新しました。
- `package.json` のバージョンを 0.7.1 に更新しました。

## 移行時の注意

- 機能の変更はありません。入力や出力の互換性にも影響はありません。
- 参照タグを `v0.7.1` に更新してください。

## 開発者向けの改善

- Dependabot の監視対象に Composite Action のディレクトリ (`/.github/actions/*`) を追加しました。
- Composite Action のテストで明示する pnpm のバージョンを、`packageManager` に合わせて 12.21.0 に更新しました。
