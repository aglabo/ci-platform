---
title: "Specifications Index: setup-tool Composite Action"
module: "composite-action/setup-tool"
based-on: requirements.md v1.0.5
status: Draft
---

<!-- textlint-disable
  ja-technical-writing/sentence-length,
  ja-technical-writing/max-comma -->
<!-- markdownlint-disable line-length -->

## Overview

`setup-tool` Composite Action の仕様書インデックス。
要件書（requirements.md v1.0.5）を基に、ライブラリ・ステップ単位で分割した仕様書群を管理する。

## Specification Files

| ファイル                                             | 対象 FR                                               | 説明                                                          |
| ---------------------------------------------------- | ----------------------------------------------------- | ------------------------------------------------------------- |
| [validate.spec.md](./validate.spec.md)               | REQ-F-010, REQ-F-011                                  | 入力値バリデーション（tool-name/version/repo/asset-template） |
| [build-url.spec.md](./build-url.spec.md)             | REQ-F-002, REQ-F-003                                  | URL Builder ライブラリ（テンプレート解決・URL 組み立て）      |
| [verify-identity.spec.md](./verify-identity.spec.md) | REQ-F-004, REQ-F-012                                  | バイナリ同一性検証（SHA256 チェックサム照合）                 |
| [extract-install.spec.md](./extract-install.spec.md) | REQ-F-006, REQ-F-009                                  | tar.gz 展開・バイナリ配置・PATH 追加                          |
| [orchestration.spec.md](./orchestration.spec.md)     | REQ-F-001, REQ-F-005, REQ-F-007, REQ-F-008, REQ-F-009 | action.yml 全体のステップ制御・入出力定義                     |

## Full Requirements Coverage

| REQ ID     | Covered By                                           |
| ---------- | ---------------------------------------------------- |
| REQ-F-001  | orchestration.spec.md                                |
| REQ-F-002  | build-url.spec.md                                    |
| REQ-F-003  | build-url.spec.md                                    |
| REQ-F-004  | verify-identity.spec.md                              |
| REQ-F-005  | orchestration.spec.md                                |
| REQ-F-006  | extract-install.spec.md                              |
| REQ-F-007  | orchestration.spec.md                                |
| REQ-F-008  | orchestration.spec.md                                |
| REQ-F-009  | extract-install.spec.md, orchestration.spec.md       |
| REQ-F-010  | validate.spec.md                                     |
| REQ-F-011  | validate.spec.md                                     |
| REQ-F-012  | verify-identity.spec.md                              |
| REQ-NF-001 | verify-identity.spec.md, extract-install.spec.md     |
| REQ-NF-002 | orchestration.spec.md                                |
| REQ-NF-003 | 全 spec ファイル（各ライブラリの単体テスト可能性）   |
| REQ-NF-004 | orchestration.spec.md                                |
| REQ-C-001  | verify-identity.spec.md（sha256sum 前提）            |
| REQ-C-002  | extract-install.spec.md（tar.gz 限定）               |
| REQ-C-003  | build-url.spec.md（GitHub Releases URL 形式）        |
| REQ-C-004  | orchestration.spec.md（permissions: contents: read） |

## Change History

| Date       | Version | Description             |
| ---------- | ------- | ----------------------- |
| 2026-03-23 | 1.0.0   | Initial index (5 files) |
