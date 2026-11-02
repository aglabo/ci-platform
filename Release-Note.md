---
title: "ci-platform Release Notes v0.4.1"
version: "0.4.1"
date: 2026-10-27
tags:
  - release
  - documentation
summary: >
  This release updates the default tool versions used by the workflows and setup action
---

## ci-platform v0.5.0 - 2026-11-02

変更ファイルを取得する Composite Action を追加しました。イベントに応じた差分の取得、
コミット数の指定、パターンによる絞り込みに対応します。
あわせて、ci-platform のワークフローで使用する GitHub Actions の参照管理を改善しました。

## 主な変更

### 変更ファイルを取得する Composite Action を追加

- `ca-get-changed-files` を追加しました。GitHub Actions のイベントに応じた差分範囲から
  変更ファイルを取得し、ファイル一覧と件数を後続のステップへ出力します。
- `commit-count` 入力を追加し、差分取得に使うコミット数を指定できます。
- パターンを指定して、取得したファイルを絞り込めます。

### GitHub Actions の参照管理を改善

- ci-platform のワークフローで使用する Action の参照をバージョンタグに更新しました。
- `.github/workflows/actions.lock` を追加し、ワークフローごとの参照、解決先コミット、リポジトリ情報を記録します。

## 開発者向けの改善

- ローカルの lint runner は、リポジトリ内の設定を優先して使用します。設定が見つからない場合は、
  探索した場所を含むエラーを表示します。
- ShellCheck と shfmt の対象指定、および複数の ShellSpec ファイル・glob の処理を改善しました。
- GitHub Actions の入力サイズ検証とエラー出力に共通ライブラリを導入しました。
