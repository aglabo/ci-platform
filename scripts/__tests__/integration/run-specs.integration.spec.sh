#shellcheck shell=sh

Describe 'run-specs.sh - Integration'
  Include ../../run-specs.sh
  Include ../helpers/test-env.helpers.sh
  Include ../helpers/mock.helpers.sh

  # Setup and teardown for test environment
  BeforeEach 'setup_test_env'
  AfterEach 'teardown_test_env'

  Describe 'Integration tests'
    Context 'real-world scenarios'
      It 'runs all tests in project'
        When call main
        The output should include "SHELLSPEC_ARGS: ."
        The status should be success
      End

      It 'runs tests in specific directory'
        When call main "scripts/__tests__"
        The output should include "scripts/__tests__"
        The status should be success
      End

      It 'runs single test file with options'
        When call main "test.spec.sh" "--focus" "--format" "tap"
        The output should include "test.spec.sh --focus --format tap"
        The status should be success
      End

      It 'handles multiple test files'
        When call main "test1.spec.sh" "test2.spec.sh"
        The output should include "test1.spec.sh test2.spec.sh"
        The status should be success
      End
    End
  End
End
