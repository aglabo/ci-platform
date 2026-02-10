# 📦 OSS Project Starter Template

This template helps you quickly launch a modern open source project with best practices and essential tools.

---

## 🛠 Features

- Easy development environment setup via PowerShell scripts
  - Lightweight setup using Scoop & pnpm for Windows
- Includes common boilerplate files such as `.editorconfig`, `.gitignore`, and more
  - Minimal configuration with flexibility for future extensions
- Lightweight Git hook environment powered by `lefthook`
  - Prevents credential leakage using tools like `gitleaks` and `secretlint`

---

## 🚀 Getting Started

1. Fork this template repository to your own GitHub account.
2. Customize it as needed (e.g., change the name in the `LICENSE` file to your GitHub handle).
3. When creating a new repository, select this template as a base.
4. You'll get a ready-to-use repository with all essential configurations preloaded.

---

## 🧰 Included Tools

| Tool       | Description                                    |
| ---------- | ---------------------------------------------- |
| lefthook   | Git commit hook manager                        |
| delta      | Visual Git diff viewer                         |
| commitlint | Linting for commit message format              |
| gitleaks   | Detects secrets and credentials in source code |
| secretlint | Static analysis tool to catch secrets in files |
| cspell     | Spellchecker for code and documentation        |
| dprint     | Fast and extensible code formatter (optional)  |

> ⚠️ **Note**
> These tools are installed independently using Scoop or pnpm and are not bundled with the repository.
> You are responsible for managing their versions and keeping them up to date.

---

## 🧪 Testing

This project uses [ShellSpec](https://shellspec.info/) for shell script testing.

### Running Tests

```bash
# Setup development environment (includes ShellSpec)
./scripts/setup-dev-env.sh

# Run all tests
./scripts/run-specs.sh

# Run specific test file
./scripts/run-specs.sh scripts/__tests__/greeting.spec.sh

# Run with focus mode
./scripts/run-specs.sh --focus
```

### Test Structure

Tests follow the `__tests__` subdirectory pattern:

```text
scripts/
├── greeting.sh              # Implementation
├── __tests__/
│   └── greeting.spec.sh     # Tests for greeting.sh
├── setup-dev-env.sh         # Implementation
└── __tests__/
    └── setup-dev-env.spec.sh  # Tests for setup-dev-env.sh (future)
```

### Writing Tests

See `scripts/__tests__/greeting.spec.sh` for the reference implementation.

Key patterns:
- Test file location: `<script_dir>/__tests__/<name>.spec.sh`
- Import source: `Include ../script.sh`
- Use `Describe` → `Context` → `It` hierarchy
- Validate output, stderr, and exit codes

---

## 📄 License

This template is licensed under the MIT License.
For more details, see [LICENSE](./LICENSE).
