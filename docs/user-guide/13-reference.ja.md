---
title: リファレンス - validate-environment
description: validate-environment アクションの入力・出力・書式リファレンス
slug: validate-environment-reference
sidebar_position: 13
tags:
  - validate-environment
  - reference
  - inputs
  - outputs
---

## 📖 リファレンス

このページでは、`validate-environment` アクションの入力パラメーター・出力値・書式仕様を網羅的に説明します。

---

## 🔧 アクション基本情報

ワークフローから以下のように参照します。

```yaml
- uses: aglabo/ci-platform/.github/actions/validate-environment@v0.1.0
```

> **Linux ランナー専用です**
> Windows および macOS はサポートしていません (`ubuntu-latest`、`ubuntu-22.04` など Linux 系ランナーで使用してください)。

## 📥 入力パラメーター

<!-- markdownlint-disable line-length MD060 -->

| パラメーター            | 型     | 必須   | デフォルト | 説明                                                           |
| ----------------------- | ------ | ------ | ---------- | -------------------------------------------------------------- |
| `architecture`          | string | いいえ | `amd64`    | 期待するランナーアーキテクチャ (`amd64` または `arm64`)        |
| `actions-type`          | string | いいえ | `read`     | 操作種別に応じたパーミッション検証モード                       |
| `additional-apps`       | string | いいえ | ``         | デフォルト (Git・curl) 以外に検証する追加アプリ (パイプ区切り) |
| `require-github-hosted` | string | いいえ | `false`    | `true` にすると GitHub ホステッドランナー以外をエラーにする    |

<!-- markdownlint-enable line-length MD060 -->

### 🏗️ `architecture`

`architecture` には正規化後の名前 (`amd64` または `arm64`) を指定します。
スクリプトが `uname -m` の出力を自動的に正規化するため、ランナー側の表記に依存しません。

<!-- markdownlint-disable line-length MD060 -->

| 値                   | 対応する `uname -m` 出力 | 説明                            |
| -------------------- | ------------------------ | ------------------------------- |
| `amd64` (デフォルト) | `x86_64`、`amd64`、`x64` | 64 bit Intel/AMD アーキテクチャ |
| `arm64`              | `aarch64`、`arm64`       | 64 bit ARM アーキテクチャ       |

<!-- markdownlint-enable line-length MD060 -->

それ以外の値を指定した場合はエラーになります。

---

### ⚙️ `actions-type`

`actions-type` に応じて、GitHub トークンが必要な権限を持つかを検証します。

<!-- markdownlint-disable line-length MD060 -->

| 値                  | 必要な permissions                         | 動作                                      |
| ------------------- | ------------------------------------------ | ----------------------------------------- |
| `read` (デフォルト) | `contents: read`                           | トークンの存在確認 + 読み取り権限プローブ |
| `commit`            | `contents: write`                          | トークンの存在確認 + 書き込み権限プローブ |
| `pr`                | `contents: write` + `pull-requests: write` | トークンの存在確認 + PR 作成権限プローブ  |
| `any`               | 任意                                       | トークンの存在確認のみ (権限プローブなし) |

<!-- markdownlint-enable line-length MD060 -->

### 📋 `additional-apps`

`additional-apps` はパイプ (`|`) 区切りの 4 フィールド形式で記述します。

```bash
cmd|app_name|version_extractor|min_version
```

<!-- markdownlint-disable line-length MD060 -->

| フィールド          | 意味                                                             | 例                        |
| ------------------- | ---------------------------------------------------------------- | ------------------------- |
| `cmd`               | PATH 上の実行ファイル名                                          | `gh`                      |
| `app_name`          | ログやエラーメッセージに表示する名前                             | `GitHub CLI`              |
| `version_extractor` | バージョン抽出方法 (`field:N` / `regex:PATTERN` / `auto` / 空欄) | `regex:version ([0-9.]+)` |
| `min_version`       | 最低バージョン (空欄にするとチェックをスキップして警告)          | `2.0`                     |

<!-- markdownlint-enable line-length MD060 -->

複数アプリを検証する場合は YAML の multiline 文字列で記述します。

```yaml
- uses: aglabo/ci-platform/.github/actions/validate-environment@v0.1.0
  with:
    additional-apps: |
      gh|GitHub CLI|regex:version ([0-9.]+)|2.0
      node|Node.js|regex:v([0-9.]+)|18.0
      jq|jq|field:2|1.6
```

`#` で始まる行はコメントとして無視されます。

#### 🔍 バージョン抽出方式

`version_extractor` フィールドには 3 種類の方式を指定できます。

<!-- markdownlint-disable line-length MD060 -->

| 方式           | 書式            | 動作                                                        | 例                            |
| -------------- | --------------- | ----------------------------------------------------------- | ----------------------------- |
| フィールド指定 | `field:N`       | `--version` 出力をスペース区切りで N 番目のフィールドを取得 | `field:2` → `jq-1.6` の `1.6` |
| 正規表現       | `regex:PATTERN` | `sed -E` でキャプチャグループ `\1` を抽出                   | `regex:version ([0-9.]+)`     |
| 自動抽出       | `auto`          | `--version` 出力から `X.Y` または `X.Y.Z` 形式を自動検出    | `auto`                        |
| デフォルト     | ''              | 抽出方式が空欄のときは、`auto`として自動抽出                | ''                            |

空欄の場合は `auto` として扱われます。

<!-- markdownlint-enable line-length MD060 -->

各方式の使用例を以下に示します。

```yaml
additional-apps: |
  # field:N 方式 (jq は "jq-1.6" 形式で出力するためフィールド指定が必要)
  jq|jq|field:2|1.6

  # regex:PATTERN 方式 (gh は "gh version 2.x.x" 形式)
  gh|GitHub CLI|regex:version ([0-9.]+)|2.0

  # auto 方式 (semver X.Y.Z 形式が直接含まれる場合)
  # "auto" と明示してもよく、空欄にすると自動的に auto として扱われる
  curl|curl|auto|7.0
```

### 🔒 `require-github-hosted`

GitHub ホステッドランナーか否かを `RUNNER_ENVIRONMENT` 環境変数で判定します。

<!-- markdownlint-disable line-length MD060 -->

| 値                   | 動作                                                           |
| -------------------- | -------------------------------------------------------------- |
| `false` (デフォルト) | セルフホストランナーも許可 (デフォルト)                        |
| `true`               | `RUNNER_ENVIRONMENT` が `github-hosted` でなければエラーにする |

<!-- markdownlint-enable line-length MD060 -->

> `RUNNER_ENVIRONMENT` は GitHub Actions が GitHub ホステッドランナーに自動設定する変数です。
> セルフホストランナーではこの変数が設定されないため、`true` にするとセルフホストランナーはエラーになります。

---

## 📤 出力値

各検証の結果は `status` と `message` のペアで出力されます。

<!-- markdownlint-disable line-length MD060 -->

| 出力名                | 値                  | 説明                                 |
| --------------------- | ------------------- | ------------------------------------ |
| `runner-status`       | `success` / `error` | ランナー検証の結果                   |
| `runner-message`      | 文字列              | ランナー検証の詳細メッセージ         |
| `permissions-status`  | `success` / `error` | パーミッション検証の結果             |
| `permissions-message` | 文字列              | パーミッション検証の詳細メッセージ   |
| `apps-status`         | `success` / `error` | アプリケーション検証の結果           |
| `apps-message`        | 文字列              | アプリケーション検証の詳細メッセージ |

<!-- markdownlint-enable line-length MD060 -->

### 📖 出力値の参照方法

出力値は `steps.<id>.outputs.<name>` の形式で参照します。

```yaml
steps:
  - name: Validate environment
    id: validate
    uses: aglabo/ci-platform/.github/actions/validate-environment@v0.1.0
    with:
      actions-type: read

  - name: Check results
    run: |
      echo "Runner: ${{ steps.validate.outputs.runner-status }}"
      echo "Permissions: ${{ steps.validate.outputs.permissions-status }}"
      echo "Apps: ${{ steps.validate.outputs.apps-status }}"
```

## 🔒 制約事項

| 制約         | 内容                                                                   | 備考             |
| ------------ | ---------------------------------------------------------------------- | ---------------- |
| 対応 OS      | Linux のみ (`ubuntu-latest`、`ubuntu-22.04` など)                      |                  |
| アプリ上限   | `additional-apps` に指定できるアプリは最大 30 件                       | DOS対策のため    |
| セキュリティ | `eval` 非使用。バージョン抽出は `sed` のみ使用し、メタキャラクター禁止 | '\d'等は使用不可 |

---

## 📚 関連ドキュメント

- [Validate Environment 概要](./10-about-validate-environment.ja.md): アクションの概要と検証内容
- [クイックスタート](./11-quickstart.ja.md): 最小構成での利用手順
- [利用シナリオ](./12-basic-scenarios.ja.md): 典型的な利用例
