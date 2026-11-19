---
title: "Decision Records: Secretlint Scan Job (Reusable Workflow)"
module: "reusable-workflows/secretlint"
status: Draft
version: 1.0.0
created: "2026-11-19"
---

<!-- markdownlint-disable line-length -->
<!-- textlint-disable
  ja-technical-writing/sentence-length,
  ja-technical-writing/no-exclamation-question-mark
  -->

## DR-01: Run secretlint as a separate, independent job

- Status: Accepted
- Context: `ru-scan-secrets.yml` already scans with betterleaks. secretlint adds a second detector with different rules.
- Decision: Add `scan-secretlint` as its own job with no `needs` relationship to `scan-betterleaks`.
- Alternatives:
  - Run secretlint as a step of the betterleaks job.
    Rejected: a betterleaks failure would hide the secretlint result, and the two tools need different setup.
  - A separate reusable workflow file.
    Rejected: callers would have to invoke two workflows to get a full secret scan.
- Rationale: One call gives both results.
- Trade-offs: The two jobs share the workflow's input list, including `fetch-depth`, which secretlint does not need.
- Related: REQ-F-005

## DR-02: Delegate to `ca-run-secretlint` and forward inputs unchanged

- Status: Accepted
- Context: The action owns version validation, pnpm setup, and the `pnpm dlx secretlint@<version>` call (module `composite-action/run-secretlint`).
- Decision: The job passes `pnpm-version` and `secretlint-version` through without interpretation.
- Alternatives:
  - Validate the version in the workflow as well. Rejected: duplicate rules would drift.
- Rationale: A single place enforces the major-14-or-later rule.
- Trade-offs: An invalid version fails inside the action, not at the workflow boundary.
- Related: REQ-F-003, REQ-C-003

## DR-03: No environment validation, configuration, or report in this job

- Status: Accepted
- Context: `scan-betterleaks` validates the environment, resolves a configuration, and uploads a report.
  secretlint v14 bundles its configuration and prints findings to the log.
- Decision: `scan-secretlint` has only `target-checkout` and `secretlint-scan`.
- Alternatives:
  - Add `ca-validate-environment` for symmetry. Open: tracked in requirements §9.
- Rationale: Smallest job that meets the requirement.
- Trade-offs: No report artifact on failure; the log is the only evidence.
- Related: REQ-F-004

## Change History

| Date       | Version | Description     |
| ---------- | ------- | --------------- |
| 2026-11-19 | 1.0.0   | Initial release |
