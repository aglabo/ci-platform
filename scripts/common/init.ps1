# src: /scripts/common/init.ps1
# @(#) : Common script initializer
#
# Copyright (c) 2025 atsushifx <http://github.com/atsushifx>
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

Set-StrictMode -Version Latest


<##
.SYNOPSIS
Initializes common constants for PowerShell scripts.

.DESCRIPTION
Defines SCRIPT_ROOT as the base directory for script execution context,
and LIBS_DIR as the path to the shared library directory (scripts/libs).
Ensures the variables are only defined once and marked as read-only.

.EXAMPLE
Init-ScriptEnvironment
# Defines $SCRIPT_ROOT and $LIBS_DIR if not already defined.

.NOTES
#>
function Init-ScriptEnvironment {
    $scriptRoot = Split-Path -Parent $PSScriptRoot
    $libsDir    = Join-Path $scriptRoot "libs"

    if (-not (Get-Variable -Name "SCRIPT_ROOT" -Scope Script -ErrorAction SilentlyContinue)) {
        Set-Variable -Name "SCRIPT_ROOT" `
                     -Value $scriptRoot `
                     -Scope Script `
                     -Option ReadOnly
    }

    if (-not (Get-Variable -Name "LIBS_DIR" -Scope Script -ErrorAction SilentlyContinue)) {
        Set-Variable -Name "LIBS_DIR" `
                     -Value $libsDir `
                     -Scope Script `
                     -Option ReadOnly
    }
}

## Initialization
Init-ScriptEnvironment
