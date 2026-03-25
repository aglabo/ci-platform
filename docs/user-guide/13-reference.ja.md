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

> このアクションは **Linux ランナー専用** です (`ubuntu-latest`、`ubuntu-22.04` など) 。
> Windows・macOS はサポートしていません。

## 📖 リファレンス

このページでは、`validate-environment` アクションの入力パラメーター・出力値・書式仕様を網羅的に説明します。

---

## 🔧 アクション基本情報

ワークフローから以下のように参照します。

```yaml
- uses: aglabo/ci-platform/.github/actions/validate-environment@21e02575bb3c3ec61a149801d696b53669f85208 # v0.1.0
```

> 安全のため、SHAを指定しています。実際に使用する際には、最新バージョンのSHAを使用してください。

## 📥 入力パラメーター

<!-- markdownlint-disable line-length  -->

| パラメーター            | 型     | 必須   | デフォルト            | 説明                                                                      |
| ----------------------- | ------ | ------ | --------------------- | ------------------------------------------------------------------------- |
| `architecture`          | string | いいえ | `amd64`               | 期待するランナーアーキテクチャ (`amd64` または `arm64`)                   |
| `actions-type`          | string | いいえ | `read`                | 操作種別に応じたパーミッション検証モード                                  |
| `additional-apps`       | string | いいえ | ``                    | デフォルト (Git・curl) 以外に検証する追加アプリ (パイプ区切り)            |
| `require-github-hosted` | string | いいえ | `false`               | `true` にすると GitHub ホステッドランナー以外をエラーにする               |
| `github-token`          | string | いいえ | `${{ github.token }}` | GitHub API アクセス用トークン。PAT を使う場合は `secrets.<MY_PAT>` を渡す |

<!-- markdownlint-enable line-length  -->

### 🏗️ `architecture`

`architecture` には正規化後の名前 (`amd64` または `arm64`) を指定します。
スクリプトが `uname -m` の出力を自動的に正規化するため、ランナー側の表記に依存しません。

<!-- markdownlint-disable line-length  -->

| 値                   | 対応する `uname -m` 出力 | 説明                            |
| -------------------- | ------------------------ | ------------------------------- |
| `amd64` (デフォルト) | `x86_64`、`amd64`、`x64` | 64 bit Intel/AMD アーキテクチャ |
| `arm64`              | `aarch64`、`arm64`       | 64 bit ARM アーキテクチャ       |

<!-- markdownlint-enable line-length  -->

補足:

- それ以外の値を指定した場合はエラーになります (自動フォールバックはしません) 。
- 期待値と実際のアーキテクチャが一致しない場合も即エラーになります。

---

### ⚙️ `actions-type`

`actions-type` に応じて、GitHub トークンが必要な権限を持つかを検証します。

<!-- markdownlint-disable line-length  -->

| 値                  | 必要な permissions                         | 動作                                                           |
| ------------------- | ------------------------------------------ | -------------------------------------------------------------- |
| `read` (デフォルト) | `contents: read`                           | `contents: read` 必須。API プローブなし (トークン存在確認のみ) |
| `commit`            | `contents: write`                          | トークンの存在確認 + 書き込み権限プローブ                      |
| `pr`                | `contents: write` + `pull-requests: write` | トークンの存在確認 + PR 作成権限プローブ                       |
| `any`               | 制限なし (permissions を検証しない)        | トークンの存在確認のみ (権限プローブなし)                      |

<!-- markdownlint-enable line-length  -->

### 📋 `additional-apps`

`additional-apps` はパイプ (`|`) 区切りの 4 フィールド形式で記述します。

```plaintext
cmd|app_name|version_extractor|min_version
```

<!-- markdownlint-disable line-length  -->

| フィールド          | 意味                                                             | 例                        |
| ------------------- | ---------------------------------------------------------------- | ------------------------- |
| `cmd`               | PATH 上の実行ファイル名                                          | `gh`                      |
| `app_name`          | ログやエラーメッセージに表示する名前                             | `GitHub CLI`              |
| `version_extractor` | バージョン抽出方法 (`field:N` / `regex:PATTERN` / `auto` / 空欄) | `regex:version ([0-9.]+)` |
| `min_version`       | 最低バージョン (空欄にするとチェックをスキップして警告)          | `2.0`                     |

<!-- markdownlint-enable line-length  -->

補足:

- 複数アプリを検証する場合は YAML の multiline 文字列で記述します。

```yaml
- uses: aglabo/ci-platform/.github/actions/validate-environment@21e02575bb3c3ec61a149801d696b53669f85208 # v0.1.0
  with:
    additional-apps: |
      gh|GitHub CLI|field:3|2.0
      node|Node.js|regex:v([0-9.]+)|20.0
      jq|jq|regex:([0-9.]+)|1.6
```

補足:

- `#` で始まる行はコメントとして無視されます。
- 安全のため、実行ファイル名には、タブ、改行コードなどのコントロールキャラ・`./`、`../` のような相対パス・
  `;`、`&`、半角スペースなどの特殊文字を含めることはできません。
  なお、`regex:PATTERN` の PATTERN では半角スペース (0x20) は使用できます。
- 安全のため、表示名には、改行コード、タブを含めることはできません。

#### 🔍 バージョン抽出方式

`version_extractor` は、`--version`で出力されたバージョン出力から、指定した型式でバージョン番号を取得します。
取得には、以下の 3 種類の方式を指定できます。

<!-- markdownlint-disable line-length  -->

| 方式           | 書式            | 動作                                                     | 例                                        |
| -------------- | --------------- | -------------------------------------------------------- | ----------------------------------------- |
| フィールド指定 | `field:N`       | 出力をスペース区切りで N 番目のフィールドを取得          | `field:3` → `gh version 2.0.0` の `2.0.0` |
| 正規表現       | `regex:PATTERN` | `sed -E` でキャプチャグループ `\1` を抽出                | `regex:version ([0-9.]+)`                 |
| 自動抽出       | `auto`          | `--version` 出力から `X.Y` または `X.Y.Z` 形式を自動検出 | `auto`                                    |
| デフォルト     | ''              | 抽出方式が空欄のときは、`auto`として自動抽出             | ''                                        |

<!-- markdownlint-enable line-length  -->

補足:

- **空欄の場合は `auto` として扱われます。**
- 自動抽出の場合、1〜3桁の数字をメジャーバージョンとして扱います。4桁は日付データを取得する場合があるため無視しています。
- `regex:PATTERN` を使用する場合、パターンには必ず 1つ以上のキャプチャグループを含めてください。
  マッチしない場合はエラーになります。
- 使用できる文字はホワイトリストで制限されています: 英数字 / `. _ - [ ] ( ) + ^ :` / 半角スペース (0x20) のみ有効です。
  `*` `?` `|` は ReDoS 攻撃面を低減するため意図的に除外されています。
  それ以外の文字 (バックスラッシュ・`#`・シェルメタ文字・制御文字など) はエラーになります。

各方式の使用例を以下に示します。

```yaml
additional-apps: |
  # field:N 方式 (gh は "gh version 2.x.x" のようにスペース区切りで出力するため field が有効)
  gh|GitHub CLI|field:3|2.0

  # regex:PATTERN 方式 (jq は "jq-1.6" 形式でスペースがないため regex が必要)
  jq|jq|regex:([0-9.]+)|1.6

  # auto 方式 (semver X.Y.Z 形式が直接含まれる場合)
  # "auto" と明示すると`semver`型式を自動で取得する。空欄にすると自動的に auto として扱われる
  curl|curl|auto|7.0
```

### 🔒 `require-github-hosted`

GitHub ホステッドランナーか否かを `RUNNER_ENVIRONMENT` 環境変数で判定します。

<!-- markdownlint-disable line-length  -->

| 値                   | 動作                                                           |
| -------------------- | -------------------------------------------------------------- |
| `false` (デフォルト) | セルフホストランナーも許可 (デフォルト)                        |
| `true`               | `RUNNER_ENVIRONMENT` が `github-hosted` でなければエラーにする |

<!-- markdownlint-enable line-length  -->

補足:

- `RUNNER_ENVIRONMENT` は GitHub Actions が GitHub ホステッドランナーに自動設定する変数です。
- セルフホストランナーではこの変数が設定されないため、`true` にするとセルフホストランナーはエラーになります。

---

## 📤 出力値

各検証の結果は `status` と `message` のペアで出力されます。
各検証は `runner` → `permissions` → `apps` の順で実行されます。
いずれかが `error` を返した場合、アクションは即時に非ゼロの終了コードで終了します (`fail-fast`)。後続の検証ステップは実行されません。

<!-- markdownlint-disable line-length  -->

| 出力名                | 値                  | 説明                                 |
| --------------------- | ------------------- | ------------------------------------ |
| `runner-status`       | `success` / `error` | ランナー検証の結果                   |
| `runner-message`      | 文字列              | ランナー検証の詳細メッセージ         |
| `permissions-status`  | `success` / `error` | パーミッション検証の結果             |
| `permissions-message` | 文字列              | パーミッション検証の詳細メッセージ   |
| `apps-status`         | `success` / `error` | アプリケーション検証の結果           |
| `apps-message`        | 文字列              | アプリケーション検証の詳細メッセージ |

<!-- markdownlint-enable line-length  -->

### 📖 出力値の参照方法

出力値は `steps.<id>.outputs.<name>` の形式で参照します。

```yaml
steps:
  - name: Validate environment
    id: validate
    uses: aglabo/ci-platform/.github/actions/validate-environment@21e02575bb3c3ec61a149801d696b53669f85208 # v0.1.0
    with:
      actions-type: read

  - name: Check results
    run: |
      echo "Runner: ${{ steps.validate.outputs.runner-status }}"
      echo "Permissions: ${{ steps.validate.outputs.permissions-status }}"
      echo "Apps: ${{ steps.validate.outputs.apps-status }}"
```

## 🔒 制約事項

<!-- markdownlint-disable line-length -->

| 制約           | 内容                                                                                                                                                       | 備考                     |
| -------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------ |
| アプリ上限     | `additional-apps` に指定できるアプリは最大 30 件                                                                                                           | DoS対策のため            |
| フィールド数   | 1 定義あたり 2列 (`cmd\|app_name`) または 4列 (`cmd\|app_name\|extractor\|version`) のみ有効。3列など他の数はエラー。2列の場合はバージョンチェックをしない | フェイルファストで即終了 |
| バージョン比較 | `sort -V` (GNU coreutils) による比較。`X.Y` / `X.Y.Z` 形式に対応。PCRE / strict semver 非準拠                                                              | Linux runner 専用        |
| セキュリティ   | `eval` 非使用。バージョン抽出は POSIX ERE (`sed -E`) 準拠。                                                                                                | POSIX ERE 準拠           |
| 正規表現方言   | 正規表現は POSIX ERE に準拠します (PCRE 記法は使用できません) 。                                                                                           | `sed -E` 使用            |

<!-- markdownlint-enable line-length -->

---

## 📚 関連ドキュメント

- [Validate Environment 概要](./10-about-validate-environment.ja.md): アクションの概要と検証内容
- [クイックスタート](./11-quickstart.ja.md): 最小構成での利用手順
- [利用シナリオ](./12-basic-scenarios.ja.md): 典型的な利用例
