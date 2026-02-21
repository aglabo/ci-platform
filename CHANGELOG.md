---
title: "ci-platform Change Log"
version: "0.1.0"
date: 2026-02-21
tags:
  - release
  - validate-environment
  - ci-platform
summary: >
  Initial public foundation release establishing structured CI environment validation,
  including runner checks, application validation, token permission verification,
  and ShellSpec-based testing architecture.
---

## [0.1.0] - 2026-02-21

### Overview

Initial public foundation release of the **validate-environment** GitHub Action.

This release establishes a structured validation framework for CI environments.
It includes runner verification, application validation, and GitHub token permission checks.
It introduces a comprehensive ShellSpec-based testing architecture.
It also establishes standardized repository governance.

v0.1.0 provides a stable baseline for reusable CI platform actions across the ecosystem.

---

### Added

#### Environment Validation

- Runner OS validation
- Application existence and version validation
- GitHub token permission validation
  - Supports explicit permission checks
  - Adds flexible `any` permission type

#### Testing & CI

- ShellSpec-based test framework
- Comprehensive unit tests for runner and validation architecture
- CI scanning workflow (`scan-all`)
- CI linting configuration

#### Developer Tooling

- Commit message generator script and agent
- Development setup scripts
- Test runner scripts
- Lefthook integration

#### Repository Governance

- LICENSE, README, SECURITY policy
- AI collaboration guidelines (`CLAUDE.md`)
- Documentation lint configuration
- Commit and secret validation rules
- Renovate configuration
- git-cliff changelog configuration

### Improved

- Simplified validation scripts for clarity and maintainability
- Reduced global variables in runner validation
- Unified validation output format
- Improved OS detection logic
- Increased test coverage across validation modules

### Notes

This version focuses on architectural stability and reproducibility.
Future releases will expand reusable workflows and additional CI platform utilities.
