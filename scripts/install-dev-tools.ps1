# src: ./scripts/in
# @(#) :
#
# Copyright (c) 2025- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

<#
.SYNOPSIS
    Installs development support tools in batch

.DESCRIPTION
    This script installs multiple development support tools using package managers such as
    winget, scoop, pnpm, and eget. It provides a convenient way to set up a complete
    development environment in one command.

    **Installation flow:**
    1. Verify eget is installed (fallback to winget if needed)
    2. Install winget packages
    3. Install scoop packages
    4. Install pnpm packages

.NOTES
    @Version  1.3.2
    @Since    2025-06-12
    @Author   atsushifx
    @License  MIT
#>

# ============================================================================
# Setup
# ============================================================================

Set-StrictMode -Version Latest

. "$PSScriptRoot/common/init.ps1"
. "$LIBS_DIR/AgInstaller.ps1"

# ============================================================================
# Configuration
# ============================================================================

##
# @description WinGet packages to install
# @var array of package specifications (packageName, packageId)
$WinGetPackages = @(
    # Environment variable manager for managing .env files
    # "dotenvx, dotenvx.dotenvx"

    # Shell Development
    "shellcheck, koalaman.shellcheck",

    ## AI Agent
    "claude, Anthropic.ClaudeCode",
    "codex, OpenAI.Codex",
    "copilot, GitHub.Copilot",
    "opencode, SST.OpenCode",

    ## Dev Utils
    "gh, GitHub.cli",
    "orhun.git-cliff",
    "jq, jqLang.jq"
)

##
# @description Scoop packages to install
# @var array of package names
$ScoopPackages = @(
    # Git hook manager for managing pre-commit, pre-push hooks
    "lefthook",
    # Code formatter supporting multiple languages
    "dprint",
    # Secret information scanner to detect credentials in code
    "gitleaks",

    "actionlint",
    "ghalint"
)

## ShellSpec install directory (relative to project root)
$ShellSpecInstallDir = ".tools/shellspec"

##
# @description npm packages to install via pnpm
# @var array of npm package names
$PnpmPackages = @(
    # Commit message checker - validates conventional commits format
    "commitlint",
    "@commitlint/cli",
    "@commitlint/config-conventional",
    "@commitlint/types",

    # Secret information leak checker - scans for sensitive data
    "secretlint",
    "@secretlint/secretlint-rule-preset-recommend",

    # Spell checker for code and documentation
    "cspell",

    # Parallel command runner
    "concurrently"
)

# ============================================================================
# Functions
# ============================================================================

##
# @description Install shellspec via git clone
# @details Shallow-clones shellspec repository to install directory if not already installed
# @param [string] $InstallDir  Path to install directory (default: $ShellSpecInstallDir)
# @return void
function Install-ShellSpec {
    param(
        [string]$InstallDir = $ShellSpecInstallDir
    )

    if (Test-Path "$InstallDir/shellspec") {
        Write-Host "  shellspec is already installed in $InstallDir" -ForegroundColor Yellow
        return
    }

    Write-Host "  Installing shellspec to $InstallDir..." -ForegroundColor Cyan
    try {
        git clone --depth 1 https://github.com/shellspec/shellspec.git $InstallDir 2>$null
        Write-Host "  shellspec installed successfully to $InstallDir" -ForegroundColor Green
    }
    catch {
        Write-Warning "shellspec installation failed: $_"
    }
}

##
# @description Install development tools using configured package managers
# @details
#   Executes installation pipeline:
#   1. Ensures eget is available (installs via winget if needed)
#   2. Installs winget, scoop, pnpm, and eget packages sequentially
#   3. Reports completion status
#
# @return 0 Always succeeds (errors reported but don't stop execution)
# @global $WinGetPackages Array of winget packages to install
# @global $ScoopPackages Array of scoop packages to install
# @global $PnpmPackages Array of pnpm packages to install
# @example
#   Install-DevelopmentTools
function Install-DevelopmentTools {
    # Install packages from each package manager
    Write-Host "Installing WinGet packages..." -ForegroundColor Cyan
    $WinGetPackages | Install-WinGetPackages

    Write-Host "Installing Scoop packages..." -ForegroundColor Cyan
    $ScoopPackages | Install-ScoopPackages

    Write-Host "Installing pnpm packages..." -ForegroundColor Cyan
    $PnpmPackages | Install-PnpmPackages

    Write-Host "Installing git-based tools..." -ForegroundColor Cyan
    Install-ShellSpec
}

# ============================================================================
# Main Execution
# ============================================================================

Write-Host "[Starting] development tool setup..." -ForegroundColor Green
Install-DevelopmentTools
Write-Host "[Done]" -ForegroundColor Green
