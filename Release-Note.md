---
title: "ci-platform Release Notes v0.6.1"
version: "0.6.1"
date: 2026-11-08
tags:
  - release
  - documentation
summary: >
  This release updates the action references and tool versions used by the
  reusable workflows, and adds a config input to the betterleaks workflow
---

## ci-platform v0.6.1 - 2026-11-08

再利用可能ワークフローが内部で使う Action の参照とツールのバージョンを更新しました。
v0.6.0 の再利用可能ワークフローは、内部で v0.5.0 の Composite Action を呼び出しています。
v0.6.0 は immutable release で変更できないため、更新した参照を v0.6.1 として提供します。

## 主な変更

### 内部の Action 参照を v0.6.0 に更新

- 再利用可能ワークフローが呼び出す ci-platform の Composite Action を、v0.5.0 から v0.6.0 に更新しました。
- `pnpm/action-setup` を v6.1.0 から v6.1.1 に更新しました。

### `ru-scan-betterleaks.yml` の変更

- `config` 入力を追加しました。betterleaks の設定ファイルのパスを指定できます。
  既定値は `./global/configs/betterleaks.toml` で、従来と同じパスです。
- betterleaks の既定バージョンを 1.9.0 から 1.10.0 に更新しました。
- checkout に成功した場合だけ、後続のステップを実行するようにしました。

## 移行時の注意

- 互換性を壊す変更はありません。
- betterleaks 1.9.0 を使い続ける場合は、`version: "1.9.0"` を指定してください。

## 開発者向けの改善

- `runners/` の診断出力を、ヘルパースクリプトからエントリポイントのスクリプトに移しました。
- ドキュメントサイトに、Action とワークフローのリファレンスと、v0.6.0 のバージョン別ドキュメントを追加しました。
