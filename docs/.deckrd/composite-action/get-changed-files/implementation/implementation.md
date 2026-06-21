---
id: IMPL
module: composite-action/get-changed-files
status: approved
refs: [SPEC]
---

# Implementation: ca-get-changed-files

## File Structure

```
.github/actions/ca-get-changed-files/
├── action.yml
└── scripts/
    ├── get-changed-files.sh
    ├── _libs/
    │   └── filter.lib.sh
    └── __tests__/
        ├── unit/
        │   └── filter.unit.spec.sh
        └── functional/
            └── get-changed-files.functional.spec.sh
```

## Implementation Notes

### action.yml

- `runs.using: composite`
- SHA（BEFORE_SHA/AFTER_SHA）はenv:セクションで`github.event.before`/`github.sha`から注入
- inputは`pattern`のみ

### get-changed-files.sh

- ヘッダー: `#!/usr/bin/env bash` + `# src:` + `# @(#):` + MIT + `# shellcheck shell=bash`
- `set -euo pipefail`
- `SCRIPT_DIR="${BASH_SOURCE[0]%/*}"`
- `_libs/filter.lib.sh` をsource
- main()関数にロジックを集約
- `[[ "${BASH_SOURCE[0]}" == "${0}" ]]` でmain呼び出し

### filter.lib.sh

- guard pattern: `[ -n "${FILTER_LIB_LOADED:-}" ] && return 0`
- `resolve_before_sha()`: ゼロSHA→empty-tree変換
- `write_multiline_output()`: GITHUB_OUTPUT multiline書き出し

## Commit Linkage

各実装ファイルは以下のcommit参照を含める:

```
ci(actions): add ca-get-changed-files composite action

Implements: IMPL-001
Spec: SPEC-001
Req: REQ-001
```
