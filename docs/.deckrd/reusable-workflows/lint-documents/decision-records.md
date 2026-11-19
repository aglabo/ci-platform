---
title: "Decision Records: Lint Documents Reusable Workflow"
module: "reusable-workflows/lint-documents"
status: Draft
version: 1.0.0
created: "2026-11-19"
---

<!-- markdownlint-disable line-length -->
<!-- textlint-disable
  ja-technical-writing/sentence-length,
  ja-technical-writing/no-exclamation-question-mark
  -->

## DR-01: Lint changed files only, listed once

- Status: Accepted
- Context: Linting the whole repository on every change is slow and reports problems unrelated to the change.
- Decision: A shared `get-changed-files` job lists the changed files that match `pattern` with `ca-get-changed-files`. The lint jobs read the list through job outputs.
- Alternatives:
  - Each lint job lists files itself. Rejected: duplicated work and a risk of different file sets.
  - Lint the whole repository. Rejected: slow and noisy.
- Rationale: One listing keeps both linters on the same files.
- Trade-offs: The workflow needs a third job and a full-history checkout (`fetch-depth: 0`) in it.
- Related: REQ-F-002

## DR-02: Two independent lint jobs

- Status: Accepted
- Context: textlint and markdownlint have separate configurations and separate failure reports.
- Decision: Run them as `qa-textlint` and `qa-markdownlint` in parallel, with no dependency between them.
- Alternatives:
  - One job running both linters in sequence. Rejected: the first failure would hide the second result.
- Rationale: Authors see both sets of violations in one run.
- Trade-offs: Tool setup and configuration checkout run twice.
- Related: REQ-F-003

## DR-03: Resolve configuration with `_ca-resolve-config`

- Status: Accepted
- Context: Configuration used to come only from the global repository. Repositories need to override it, as `runners/run-*.sh` already allow.
- Decision: Each lint job runs `_ca-resolve-config` with the tool-specific input, the local candidate under `configs/`, and the global candidate under `global/configs/`.
- Alternatives:
  - Global configuration only. Rejected: no repository override.
  - Local configuration only. Rejected: every repository would need its own copy.
- Rationale: The same precedence (input, local, global) applies to every quality workflow and to the local runners.
- Trade-offs: One more composite-action step per job; a missing explicit input fails instead of falling back.
- Related: REQ-F-005

## DR-04: Documentation tools from `agla-doc-tools` at a selectable ref

- Status: Accepted
- Context: textlint, markdownlint, and their rules are maintained together in `aglabo/agla-doc-tools`.
- Decision: Install the repository with `ca-setup-repo` at the `doc-tools-version` ref (default `v0.3.0`) into `./.tools/agla-doc-tools`.
- Alternatives:
  - Install each linter from npm. Rejected: rule sets would drift from the shared tool repository.
- Rationale: A single ref pins every documentation tool.
- Trade-offs: The pnpm version must match the tool repository; an empty `pnpm-version` defers to `packageManager`.
- Related: REQ-F-004

## DR-05: Skip lint jobs when nothing matches

- Status: Accepted
- Context: Many changes touch no Markdown file.
- Decision: Both lint jobs carry `if: needs.get-changed-files.outputs.count != '0'`.
- Alternatives:
  - Always run the lint jobs with an empty target list. Rejected: pays setup cost and the linters may error on an empty list.
- Rationale: Fast feedback and no spurious failures.
- Trade-offs: A skipped job counts as success for required checks that allow skips.
- Related: REQ-F-003

## Change History

| Date       | Version | Description     |
| ---------- | ------- | --------------- |
| 2026-11-19 | 1.0.0   | Initial release |
