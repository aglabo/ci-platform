---
title: "ci-platform Release Notes v0.4.0"
version: "0.4.0"
date: 2026-10-15
tags:
  - release
  - documentation
summary: >
  v0.4.0 では、GitHub Actions の検証を jactionlint へ移行し、CI の同時実行制御と
  参照先の固定を改善しました。あわせてローカルランナーの WSL 対応、設定ファイルと
  プロジェクトルートの解決処理、開発環境のセットアップを改善しています。
---

## ci-platform v0.4.0 - 2026-10-15

GitHub Actions のワークフロー検証を jactionlint へ移行し、CI の実行制御と参照先の固定を改善しました。あわせて、ローカルランナーの WSL 対応、設定ファイル・プロジェクトルートの解決処理、開発環境のセットアップを改善しています。

## 主な変更

### GitHub Actionsの検証をjactionlintへ移行

- 再利用可能ワークフロー `ru-qa-actionlint.yml` の検証ツールを jactionlint へ変更しました。既定バージョンは 2.2.0 です。
- 設定ファイルの既定パスを `./shared/configs/jactionlint.yaml` に変更し、実行時には環境変数経由で渡すようにしました。
- 検証レポートとアーティファクトの名前を `jactionlint-report` に変更しました。出力ファイルは `.github/report/jactionlint-report.txt` です。
- ローカル実行用の `runners/run-actionlint.sh` を追加し、`lint:gha:actions` から呼び出すようにしました。コマンドライン引数と終了ステータスを jactionlint へ連携します。

### CIワークフローの実行制御を改善

- 再利用可能ワークフローや Composite Action の参照先をコミット SHA へ固定する変更を実施しました。
- シークレットスキャンとワークフローQA に同時実行制御を追加し、進行中の重複実行をキャンセルするようにしました。
- ドキュメント公開では、進行中の実行のキャンセルを Pull Request 時に限定しました。
- Composite Action のテストにも同時実行制御を追加しました。
- 対象ワークフローの既定シェルを Bash に統一しました。
- `ca-get-changed-files` では、変更前後の SHA を環境変数経由でシェルへ渡すようにしました。
- `actions/setup-node` を v7.1.0 へ更新し、`actions/upload-artifact` を v7.0.2 のコミット SHA へ固定しました。
- betterleaks の既定バージョンを 1.9.0 へ更新しました。

### ローカルランナーとWSL対応を改善

- ShellSpec の実行処理を `runners/exec/shellspec-exec.sh` へ分離し、テスト種別・spec ファイル・glob の解決処理を追加しました。
- Windows から ShellSpec を実行する際に、WSL へ処理を委譲する仕組みを追加しました。
- プロジェクトルートの Git 検索とフォールバックをライブラリの配置場所基準に変更しました。
- ファイルフィルターの先頭にある `./` を正規化し、指定方法による検索結果の差異を修正しました。
- ShellCheck のディレクトリ走査で `node_modules` 配下を除外するようにしました。
- markdownlint の設定参照先と textlint のキャッシュパスを修正しました。
- markdownlint、textlint、jactionlint のランナーで、`XDG_CONFIG_HOME` が未設定の場合に `~/.config` を使用するようにしました。
- 引数転送、終了ステータス、プロジェクトルート解決、ファイルの除外・正規化に関するユニットテストを追加しました。

### 開発環境とツール設定を更新

- 開発環境セットアップに Lefthook の導入確認を追加し、ShellSpec 導入時のエラーメッセージを改善しました。
- Agla ツールを Git clone 後に `pnpm install --frozen-lockfile` を実行し、各ツールをセットアップするようにしました。
- セットアップ失敗時の終了コードを改善し、スクリプトを source した場合の自動実行を抑止しました。
- `prepare-commit-msg.sh` で Git hook の位置引数に対応し、AI 実行オプションを見直しました。既定モデルは `gpt-6-luna` です。
- pnpm を 12.4.2から 12.11.2 へ更新しました。
- dprint の JSON・Markdown・TOML プラグインをそれぞれ 0.25.2・0.26.0・0.9.0 へ更新しました。
- `check:dprint` を差分ファイル一覧の表示へ変更し、通常のチェック用に `check:dprint:diff` を追加しました。
- ShellSpec の並列実行数を 16から 4 へ変更し、実行オプションを整理しました。
- textlint・markdownlint のルールと除外設定を調整しました。`releases` ディレクトリを textlint の対象外にしました。
- EditorConfig、Git ignore、git-cliff の設定とコメントを整理しました。
- CODEOWNERS を追加し、全ファイルのコードオーナーを `@atsushifx` に設定しました。

## 移行時の注意点

- `ru-qa-actionlint.yml` のファイル名は継続しますが、実行ツールは jactionlint になります。独自の設定ファイルを渡す場合は、jactionlint 向けの設定を確認してください。
- レポートを後続処理で参照している場合は、アーティファクト名とファイル名を `jactionlint-report` に合わせて更新してください。
- ローカルで `lint:gha:actions` を使用する場合は、jactionlint を実行できる環境を用意してください。
- `check:dprint` を CI の合否判定に使用している場合は、用途に応じて `check:dprint:diff` へ切り替えてください。

## 関連リンク

- [リポジトリ](https://github.com/aglabo/ci-platform)
- [ワークフロー検証の修正（#131）](https://github.com/aglabo/ci-platform/pull/131)
