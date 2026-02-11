#shellcheck shell=sh

Describe 'run-specs.sh - Unit'
  Include ../../run-specs.sh
  Include ../helpers/test-env.helpers.sh
  Include ../helpers/mock.helpers.sh

  # Setup and teardown for test environment
  BeforeEach 'setup_test_env'
  AfterEach 'teardown_test_env'

  Describe 'main()'
    Context 'with no arguments'
      It 'defaults to current directory "."'
        When call main
        The output should include "SHELLSPEC_ARGS: ."
        The status should be success
      End
    End

    Context 'with path argument'
      It 'passes the path to ShellSpec'
        When call main "scripts/__tests__"
        The output should include "SHELLSPEC_ARGS: scripts/__tests__"
        The status should be success
      End

      It 'passes "." explicitly'
        When call main "."
        The output should include "SHELLSPEC_ARGS: ."
        The status should be success
      End

      It 'passes specific test file'
        When call main "scripts/__tests__/test.spec.sh"
        The output should include "SHELLSPEC_ARGS: scripts/__tests__/test.spec.sh"
        The status should be success
      End
    End

    Context 'with options'
      It 'passes --focus option'
        When call main "--focus"
        The output should include "SHELLSPEC_ARGS: --focus"
        The status should be success
      End

      It 'passes --tag option with value'
        When call main "--tag" "unit"
        The output should include "SHELLSPEC_ARGS: --tag unit"
        The status should be success
      End

      It 'passes multiple options'
        When call main "--focus" "--format" "tap"
        The output should include "SHELLSPEC_ARGS: --focus --format tap"
        The status should be success
      End
    End

    Context 'argument count differentiation'
      It 'handles single test file'
        When call main "test.spec.sh"
        The output should include "SHELLSPEC_ARGS: test.spec.sh"
        The status should be success
      End

      It 'handles exactly two test files'
        When call main "test1.spec.sh" "test2.spec.sh"
        The output should include "test1.spec.sh test2.spec.sh"
        The status should be success
      End

      It 'handles three or more test files'
        When call main "test1.spec.sh" "test2.spec.sh" "test3.spec.sh"
        The output should include "test1.spec.sh test2.spec.sh test3.spec.sh"
        The status should be success
      End

      It 'handles directory argument'
        When call main "scripts/__tests__"
        The output should include "scripts/__tests__"
        The status should be success
      End
    End

    Context 'path type handling'
      It 'passes relative path with ./ unchanged'
        When call main "./scripts/__tests__"
        The output should include "./scripts/__tests__"
        The status should be success
      End

      It 'passes parent directory reference unchanged'
        When call main "../other-dir"
        The output should include "../other-dir"
        The status should be success
      End
    End
  End
End
