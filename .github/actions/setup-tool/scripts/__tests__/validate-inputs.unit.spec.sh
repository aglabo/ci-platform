#!/bin/bash
# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154

# Test suite for validate_symbol() function
# Module: composite-action/setup-tool
# Target: validation.lib.sh

Describe 'validate_symbol()'
  LIB_PATH="${SHELLSPEC_PROJECT_ROOT}/.github/actions/setup-tool/scripts/_libs/validation.lib.sh"
  Include "$LIB_PATH"

  SYMBOL_PATTERN='^[a-z][a-z0-9_-]{0,63}$'

  Describe 'Given: a value matching the whitelist pattern'
    Describe 'When: validate_symbol is called'
      Describe 'Then: Task T-01-01 - ホワイトリストパターンに適合する値'
        # T-01-01-01: lowercase only
        It 'returns 0 for lowercase-only value "actionlint"'
          When call validate_symbol "actionlint" "tool-name" "$SYMBOL_PATTERN"
          The status should be success
        End

        # T-01-01-02: digits, hyphens, underscores
        It 'returns 0 for value with digits/hyphens/underscores "my-tool_v2"'
          When call validate_symbol "my-tool_v2" "tool-name" "$SYMBOL_PATTERN"
          The status should be success
        End
      End
    End
  End
End
