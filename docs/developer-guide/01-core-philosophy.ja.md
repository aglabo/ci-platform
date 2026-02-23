---
title: コア哲学
description: ci-platform の設計思想・品質自動化の考え方
slug: developer-guide/core-philosophy
sidebar_position: 1
tags:
  - ci-platform
  - developer-guide
---

## コア哲学

ci-platform の設計・開発は、いくつかの根本的な考え方に基づいています。
このページではその哲学を説明します。

---

## 🔄 Shift Left: 品質を早期に確保する

**「問題は発見が遅れるほどコストが高くなる」** という原則に基づき、ci-platform は品質チェックをできるだけ開発の早い段階に配置します。

<!-- textlint-disable ja-hiraku -->

```
コミット前 → Push → PR → CI → デプロイ
  ↑ 早いほど修正コストが低い
```

<!-- textlint-enable ja-hiraku -->

**ローカルレベル (最早期)**:
lefthook により、コミット前にシークレット検出・コミットメッセージ検証を自動実行します。
開発者はリモートへ送る前に問題を解決できます。

**CI レベル (セカンドライン)**:
GitHub Actions により、Push・PR 時にワークフロー構文・ポリシー・シークレットを再検証します。
ローカルチェックを通過した変更に対する最終ゲートとして機能します。

この二重構造により、問題が本番へ到達する前に必ず捕捉される仕組みを作ります。

---

## 🧩 OSS テンプレートとしての哲学

ci-platform は**テンプレート・基盤として設計**されています。
利用者がフォークして使うのではなく、`uses:` で参照するだけで品質管理を取り込める仕組みを目指しています。

<!-- textlint-disable ja-hiraku -->

**設計上の選択**:

- 独立リポジトリ — `.github` リポジトリではなく、独立して管理することでバージョン固定と段階的拡張を実現
- 外部参照方式 — `aglabo/ci-platform/.github/actions/validate-environment@v0.1.0` のように参照するだけで利用可能
- 最小侵略性 — 利用者のリポジトリへの変更を最小化し、導入コストを下げる
- 段階的拡張 — Composite Actions から Reusable Workflows へ、機能を段階的に追加できる設計

<!-- textlint-enable ja-hiraku -->

---

## 👷 開発者体験 (DX) を重視する

品質管理ツールは「邪魔にならない」ことが重要です。
ci-platform は開発者の作業フローを妨げず、かつ問題を確実に検出できるバランスを追求します。

<!-- textlint-disable ja-hiraku -->

**DX のための設計判断**:

- lefthook による高速フック実行 (並列実行対応)
- CI でのエラーメッセージは問題箇所と修正方法を明示
- ゲートアクション (`validate-environment`) は不要なら即パス、問題があれば即停止
- ドキュメントと設定の分離により、何をカスタマイズできるかが明確

<!-- textlint-enable ja-hiraku -->

開発者が「なぜ失敗したのか」「何を直せばよいか」を自力で解決できるよう、エラーの可視性を優先します。

---

## 🔁 継続的改善とフィードバックループ

ci-platform 自身も継続的な改善サイクルのなかにあります。

<!-- textlint-disable ja-hiraku -->

**フィードバックの流れ**:

1. 実際の OSS 開発での利用を通じて課題を発見する
2. Issue として記録し、優先度を判断する
3. 小さな単位でリリースし、影響範囲を制御する
4. セマンティックバージョニングで変更の重要度を明示する

<!-- textlint-enable ja-hiraku -->

**バージョン戦略**:

```
v0.1.x → Composite Actions (validate-environment)
v0.2.x → Reusable Workflows (actionlint / ghalint / gitleaks)
v0.3.x → 統合スキャン・組織標準テンプレート
```

機能追加は必ずテストを伴い、後方互換性を維持する形で進めます。
破壊的変更はメジャーバージョンの更新として扱います。

---

## 📚 次のステップ

- [ゲートパターン](./02-gate-pattern.ja.md): 哲学が具体化された fail-fast 設計パターン
- [アーキテクチャ](./03-architecture.ja.md): 哲学が実装にどう反映されているかの全体像
- [デザインプリンシプル](./04-design-principles.ja.md): 哲学を具体化した設計原則と実装方針
