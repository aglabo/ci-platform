# 📦 OSS Project Starter Template

This template helps you quickly launch a modern open source project.
It comes with best practices and essential tools pre-configured.

---

## Features

- Easy development environment setup via `scripts/setup-dev-env.sh`
  - Installs lefthook hooks, ShellSpec, and aglabo dev/doc tools (runs on `pnpm install`)
- Includes common boilerplate files such as `.editorconfig`, `.gitignore`, and more
  - Minimal configuration with flexibility for future extensions
- Lightweight Git hook environment powered by `lefthook`
  - Prevents credential leakage using tools like `betterleaks` and `secretlint`

## Getting Started

1. Fork this template repository to your own GitHub account.
2. Customize it as needed (e.g., change the name in the `LICENSE` file to your GitHub handle).
3. When creating a new repository, select this template as a base.
4. You'll get a ready-to-use repository with all essential configurations preloaded.

## Included Tools

| Tool        | Description                                    |
| ----------- | ---------------------------------------------- |
| lefthook    | Git commit hook manager                        |
| delta       | Visual Git diff viewer                         |
| commitlint  | Linting for commit message format              |
| betterleaks | Detects secrets and credentials in source code |
| secretlint  | Static analysis tool to catch secrets in files |
| cspell      | Spellchecker for code and documentation        |
| dprint      | Fast and extensible code formatter (optional)  |

> **Note**
> These tools are installed independently (e.g. with a package manager or pnpm) and are not bundled with the repository.
> You are responsible for managing their versions and keeping them up to date.

## Public Actions and Workflows

Reference the public components by release tag.
Example: `aglabo/ci-platform/.github/actions/<action>@v0.6.1`

### Composite Actions

| Action                                 | Description                                                                                |
| -------------------------------------- | ------------------------------------------------------------------------------------------ |
| `ca-get-changed-files` (new in v0.5.0) | Lists files changed by the event (push / pull_request / HEAD~N), filtered by glob patterns |
| `ca-setup-repo`                        | Validates and checks out a tool repository, runs `pnpm install`, and adds `bin/` to `PATH` |
| `ca-setup-tool`                        | Downloads, verifies, and installs a tool from GitHub Releases                              |
| `ca-validate-environment`              | Validates the runner environment (Linux only, architecture, permissions)                   |

### Reusable Workflows

| Workflow                                 | Description                                                  |
| ---------------------------------------- | ------------------------------------------------------------ |
| `ru-lint-documents.yml` (new in v0.6.0)  | Lints changed Markdown files with textlint and markdownlint  |
| `ru-qa-actionlint.yml`                   | Lints GitHub Actions workflows with jactionlint              |
| `ru-qa-actions-lock.yml` (new in v0.6.0) | Verifies the workflow action lockfile with `gh actions-lock` |
| `ru-qa-ghalint.yml`                      | Lints GitHub Actions workflows with ghalint                  |
| `ru-scan-betterleaks.yml`                | Scans the repository for secrets with betterleaks            |

By default, the lint and secret-scan workflows use configs from [aglabo/global-configs](https://github.com/aglabo/global-configs).

### Example: `ca-get-changed-files`

```yaml
steps:
  - uses: actions/checkout@v7.0.1
    with:
      fetch-depth: 0 # required
  - id: changed
    uses: aglabo/ci-platform/.github/actions/ca-get-changed-files@v0.6.1
    with:
      pattern: |
        **/*.md
        !docs/**
  - if: steps.changed.outputs.count != '0'
    env:
      CHANGED_FILES: ${{ steps.changed.outputs.files }}
    run: printf '%s\n' "$CHANGED_FILES"
```

## License

This template is licensed under the MIT License.
For more details, see [LICENSE](./LICENSE).
