---
title: "ci-platform Release Notes v0.7.0"
version: "0.7.0"
date: 2026-11-19
tags:
  - release
  - reusable-workflows
  - composite-actions
summary: >
  This release adds the ca-run-secretlint composite action and a secretlint scan,
  renames ru-scan-betterleaks.yml to ru-scan-secrets.yml, and removes the default
  Node.js and pnpm versions from ca-setup-repo
---

## ci-platform v0.7.0 - 2026-11-19

シークレットスキャンに secretlint を追加しました。
あわせて、`ru-scan-betterleaks.yml` を `ru-scan-secrets.yml` に改名しました。
`ca-setup-repo` は Node.js と pnpm の既定バージョンを持たなくなりました。
すべての Composite Action と再利用可能ワークフローを v0.7.0 に揃えています。

## 主な変更

### `ca-run-secretlint` を追加

- pnpm をセットアップし、`pnpm dlx secretlint@<version>` を実行する Composite Action を追加しました。
- バージョンは `X.Y.Z` 形式で、メジャーバージョンが 14 以上である必要があります。
- secretlint v14 以降は設定を同梱しているため、設定ファイルは指定しません。

### `ru-scan-betterleaks.yml` を `ru-scan-secrets.yml` に改名

- betterleaks に加えて secretlint でもスキャンするため、ワークフロー名を "Reusable: Scan Secrets" に変更しました。
- `scan-secretlint` ジョブを追加しました。
- `secretlint-version` 入力 (既定値 `14.0.1`) と `pnpm-version` 入力 (既定値は空) を追加しました。
- `ci-scan-secrets.yml` のジョブを `scan-secrets` に変更し、新しいワークフローを呼び出すようにしました。

### `ca-setup-repo` の変更

- `node-version` と `pnpm-version` の既定値を削除しました。
- バージョンを省略した場合は、呼び出し元の解決に委ねます。

### その他のワークフローの変更

- `ru-lint-documents.yml` に `pnpm-version` 入力 (既定値は空) を追加しました。`ca-setup-repo` に渡されます。
- `ru-qa-actionlint.yml` の jactionlint の既定バージョンを 2.5.0 から 2.6.0 に更新しました。
- 公開している Composite Action と `ru-*.yml` に `# @version : 0.7.0` ヘッダーを追加しました。
- 内部で呼び出す ci-platform の Composite Action の参照を v0.6.1 から v0.7.0 に更新しました。

## 移行時の注意

- `ru-scan-betterleaks.yml` を呼び出している場合は、`ru-scan-secrets.yml` に変更してください。
  従来の betterleaks の入力は引き継がれますが、secretlint のジョブも実行されます。
- `ca-setup-repo` の `node-version` と `pnpm-version` を省略していた場合は、必要なバージョンを明示してください。
- secretlint のバージョンを変える場合は、`secretlint-version` を指定してください。メジャーバージョン 14 以上のみ指定できます。
- 参照タグを `v0.7.0` に更新してください。

## 開発者向けの改善

- `scripts/bump-version.sh` を追加しました。`package.json`、`# @version` ヘッダー、`uses: aglabo/ci-platform/...@vX.Y.Z` の参照をまとめて更新できます。
  `--dry-run` に対応しています。`actions.lock` は更新しないため、別途 `gh actions-lock` を実行してください。
- `runners/run-betterleaks.sh` を追加しました。ローカルとグローバルの設定を解決し、ステージ済みの変更、ディレクトリ、ファイルをスキャンできます。
- lefthook の betterleaks を `runners/run-betterleaks.sh` 経由で実行するようにしました。
- `run-shfmt.sh` に `--apply-ignore` を追加し、`.editorconfig` の除外ルールを明示したファイルにも適用するようにしました。
- `prepare-commit-msg.sh` が `fable` モデルに対応し、既定の AI モデルを `opus` にしました。
- pnpm を 12.15.0 から 12.21.0 に更新し、`package.json` のスクリプトを整理しました。
- 不要になった `configs/jactionlint.yaml`、`configs/ghalint.yaml`、`configs/secretlint.config.yaml` を削除しました。
- ドキュメントサイトに、immutable release とバージョンタグの保護に関する説明を追加しました。
