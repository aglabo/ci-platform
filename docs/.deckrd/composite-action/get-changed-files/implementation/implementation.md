---
id: IMPL
module: composite-action/get-changed-files
status: approved
refs: [SPEC]
---

# Implementation: ca-get-changed-files

## File Structure

```bash
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
- SHA（BEFORE_SHA/AFTER_SHA）は env:セクションで `github.event.before`/`github.sha` から注入
- input は `pattern` のみ

### get-changed-files.sh

- ヘッダー: `#!/usr/bin/env bash` + `# src:` + `# @(#):` + MIT + `# shellcheck shell=bash`
- `set -euo pipefail`
- `SCRIPT_DIR="${BASH_SOURCE[0]%/*}"`
- `_libs/filter.lib.sh` を source
- main()関数にロジックを集約
- `[[ "${BASH_SOURCE[0]}" == "${0}" ]]` で main 呼び出し

### filter.lib.sh

- guard pattern: `[ -n "${FILTER_LIB_LOADED:-}" ] && return 0`
- `resolve_before_sha()`: ゼロ SHA→empty-tree 変換
- `write_multiline_output()`: GITHUB_OUTPUT multiline 書き出し

## Commit Linkage

各実装ファイルは以下の commit 参照を含む。

```text
ci(actions): add ca-get-changed-files composite action

Implements: IMPL-001
Spec: SPEC-001
Req: REQ-001
```
