---
title: "Decision Records: Actions Lock Reusable Workflow"
module: "reusable-workflows/actions-lock"
status: Draft
version: 1.0.0
created: "2026-11-19"
---

<!-- markdownlint-disable line-length -->
<!-- textlint-disable
  ja-technical-writing/sentence-length,
  ja-technical-writing/no-exclamation-question-mark
  -->

## DR-01: Install the extension with a pinned `gh extension install`

- Status: Accepted
- Context: `gh-actions-lock` is distributed as a GitHub CLI extension, not as a release binary that `ca-setup-tool` could unpack.
- Decision: Run `gh extension install github/gh-actions-lock --pin "${EXT_VERSION}"` with the `version` input (default `v0.4.1`).
- Alternatives:
  - Install the latest extension. Rejected: verification rules could change without notice.
  - Install through `ca-setup-tool`. Rejected: the extension is not a plain release archive.
- Rationale: A pinned tag keeps verification reproducible.
- Trade-offs: The default must be bumped by hand.
- Related: REQ-F-003

## DR-02: Verify non-interactively and keep the output as a report

- Status: Accepted
- Context: CI must not block on prompts, and a failed verification needs a readable explanation after the run.
- Decision: Run `gh actions-lock --verify --no-interactive 2>&1 | tee .github/report/actions-lock-report.txt` and exit with `PIPESTATUS[0]`. Upload the file on failure.
- Alternatives:
  - Run without `tee`. Rejected: the message is only in the log.
  - Use `set -o pipefail` instead of `PIPESTATUS`. Equivalent, but `PIPESTATUS[0]` states which command decides the status.
- Rationale: The artifact preserves the evidence of a stale lockfile.
- Trade-offs: A clean run produces a report file that is not uploaded.
- Related: REQ-F-004, REQ-F-005

## DR-03: No `ca-setup-tool` and no `_ca-resolve-config`

- Status: Accepted
- Context: Other quality workflows install a binary and resolve a configuration file.
- Decision: This workflow validates the environment with `ca-validate-environment` only. It has no configuration input and installs no binary.
- Alternatives:
  - Add a `config` input for symmetry. Rejected: the tool has no configuration.
- Rationale: Smallest workflow that meets the requirement.
- Trade-offs: The step chain differs from `actionlint`, `ghalint`, and `betterleaks`.
- Related: REQ-F-002, REQ-C-002

## Change History

| Date       | Version | Description     |
| ---------- | ------- | --------------- |
| 2026-11-19 | 1.0.0   | Initial release |
