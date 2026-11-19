---
title: Internal Design Directory
description: Purpose and usage of the .deckrd internal design directory
---

## .deckrd

This directory contains internal design documents and decision records
used during development.

- Documents under this directory are not part of the public API.
- Decisions are recorded as DR (Decision Records).
- This directory may be extracted as a standalone repository in the future.

## Layout

```text
docs/.deckrd/
├── rules/                      # Deckrd rules (workflow, BDD cycle, document model, ...)
├── composite-action/<module>/  # Design documents for composite actions
└── reusable-workflows/<module>/# Design documents for reusable workflows
```

Each module directory follows the design chain `requirements → specifications → implementation → tasks`:

```text
<namespace>/<module>/
├── requirements/requirements.md
├── specifications/specifications*.md   # split into an index plus per-area files when large
├── implementation/implementation.md
├── tasks/tasks.md
├── workspaces/module/module.md         # required: test_scope and owned files
└── decision-records.md
```

- The rules are indexed in `.claude/rules/deckrd-rules/deckrd-rules-index.md`.
- Directory layout, ID schemes, and versioning are defined in
  `rules/deckrd-rule-document-model.md` and `rules/deckrd-rule-document-versioning.md`.
- `workspaces/` holds persistent per-module notes. It is not part of the design chain.
- Some module directory names predate renames of the action they describe.
  For example, `setup-tool-repo` describes `ca-setup-repo`. Each document states the current name.
