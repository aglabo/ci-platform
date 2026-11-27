---
title: "ci-platform Release Notes v0.9.0"
version: "0.9.0"
date: 2026-11-28
tags:
  - release
  - reusable-workflows
summary: >
  This release adds a cspell document QA job to ru-lint-documents and documents secret scanning on the documentation site
---

## ci-platform v0.9.0 - 2026-11-28

`ru-lint-documents` に cspell によるスペルチェックを追加し、ドキュメントサイトにシークレットスキャンの説明を追加しました。

## 主な変更

### cspell によるドキュメント QA の追加

- `ru-lint-documents.yml` に `qa-cspell` ジョブを追加し、変更されたファイルのスペルをチェックするようにしました。
- 設定ファイルを指定する `cspell-config` 入力を追加しました (省略可能)。
- cspell の設定は、リポジトリ内の設定またはグローバル設定を使用します。
- チェックに失敗した場合は、cspell のレポートを artifact としてアップロードします。

### シークレットスキャンのドキュメント追加

- `ru-scan-secrets` ワークフローのリファレンスを追加し、入力、並行ジョブ、設定ファイルの解決、パスの制約、タイムアウトを説明しました。
- betterleaks による Git 履歴のスキャンと、secretlint によるファイルのスキャンを説明しました。
- 開発者ガイドとユーザーガイドの構成図と説明を `ru-scan-secrets` に合わせて更新しました。
- 廃止した betterleaks ワークフローのリファレンスを削除しました。

## 移行時の注意

- 参照タグを `v0.9.0` に更新してください。
- `ru-lint-documents` を利用している場合は、スペルチェックが追加で実行されます。チェックが失敗した場合は、報告された単語の綴りを修正してください。綴りが正しい単語は、cspell の辞書に追加してください。

## 開発者向け変更

- プロジェクト辞書に `rhysd` と `Diátaxis` を追加しました。
- `configs/textlintrc.yaml` の `no-mix-dearu-desumasu` を、ブロックスタイルの YAML に変更しました。
