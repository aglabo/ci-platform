#!/usr/bin/env bash
# src: .github/actions/setup-tool/scripts/__tests__/integration/action.integration.spec.sh
# @(#) : ShellSpec integration tests for action.yml — static analysis of composite action definition
#
# Copyright (c) 2026- atsushifx <atsushifx@gmail.com>
# MIT License

# shellcheck shell=bash
# cspell:words actionlint rhysd composites

# ─── Fixture constants

readonly _ACTION_YML="${SHELLSPEC_PROJECT_ROOT}/.github/actions/setup-tool/action.yml"

# ─── T-17: action.yml 静的解析テスト ─────────────────────────────────────────

Describe 'action.yml: inputs definition'
  It "T-act-nor-01: inputs.repo is defined in action.yml"
    When run grep -q "repo:" "$_ACTION_YML"
    The status should be success
  End

  It "T-act-nor-02: inputs.tool-version.default matches X.Y.Z format"
    When run grep -qE "default: ['\"]?[0-9]+\.[0-9]+\.[0-9]+['\"]?" "$_ACTION_YML"
    The status should be success
  End
End

Describe 'action.yml: runs configuration'
  It "T-act-nor-03: runs.using is composite"
    When run grep -q "using: composite" "$_ACTION_YML"
    The status should be success
  End

  It "T-act-nor-04: run step references setup-tool.sh"
    When run grep -q "setup-tool.sh" "$_ACTION_YML"
    The status should be success
  End

  It "T-act-nor-05: TOOL_REPO env var passes inputs.repo without injection"
    When run grep -q "TOOL_REPO" "$_ACTION_YML"
    The status should be success
  End

  It "T-act-nor-06: TOOL_VERSION env var passes inputs.tool-version without injection"
    When run grep -q "TOOL_VERSION" "$_ACTION_YML"
    The status should be success
  End
End

Describe 'action.yml: script path exists'
  It "T-act-nor-07: setup-tool.sh referenced in action.yml actually exists"
    The file "${SHELLSPEC_PROJECT_ROOT}/.github/actions/setup-tool/scripts/setup-tool.sh" should be exist
  End
End
