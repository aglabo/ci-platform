#shellcheck shell=sh

Describe 'run-specs.sh - Functional'
  Include ../../run-specs.sh
  Include ../helpers/test-env.helpers.sh
  Include ../helpers/mock.helpers.sh
  Include ../helpers/test-utils.helpers.sh

  # Setup and teardown for test environment
  BeforeEach 'setup_test_env'
  AfterEach 'teardown_test_env'

  Describe 'main()'
    Context 'with path and options combined'
      It 'passes path and options in correct order'
        When call main "scripts/__tests__" "--focus"
        The output should include "SHELLSPEC_ARGS: scripts/__tests__ --focus"
        The status should be success
      End

      It 'passes all arguments to ShellSpec'
        When call main "test.spec.sh" "--tag" "unit" "--format" "documentation"
        The output should include "test.spec.sh --tag unit --format documentation"
        The status should be success
      End
    End

    Context 'directory isolation'
      It 'executes in subshell without changing caller directory'
        check_directory() {
          local before_dir="$(pwd)"
          main "."
          local after_dir="$(pwd)"
          [[ "$before_dir" == "$after_dir" ]] && echo "DIRECTORY_UNCHANGED"
        }

        When call check_directory
        The output should include "DIRECTORY_UNCHANGED"
        The status should be success
      End
    End

    Context 'error handling'
      It 'returns ShellSpec exit code on success'
        When call main "."
        The output should include "SHELLSPEC_ARGS: ."
        The status should eq 0
      End

      It 'returns ShellSpec exit code on failure'
        # Create failing mock
        create_mock_shellspec "" 1

        When call main "."
        The status should eq 1
      End
    End

    Context 'environment variables'
      It 'respects custom PROJECT_ROOT'
        custom_root="$TEST_TMPDIR/custom-root"
        mkdir -p "$custom_root/.tools/shellspec"

        export SHELLSPEC="$custom_root/.tools/shellspec/shellspec"
        create_custom_mock_shellspec "CUSTOM_ROOT_SHELLSPEC"
        export PROJECT_ROOT="$custom_root"

        When call main "."
        The output should include "CUSTOM_ROOT_SHELLSPEC"
        The status should be success
      End

      It 'respects custom SHELLSPEC path'
        custom_shellspec="$TEST_TMPDIR/custom-shellspec"
        export SHELLSPEC="$custom_shellspec"
        create_custom_mock_shellspec "CUSTOM_SHELLSPEC"

        When call main "."
        The output should include "CUSTOM_SHELLSPEC"
        The status should be success
      End
    End

    Context 'working directory independence'
      It 'produces consistent results from project root'
        When call run_from_directory "$PROJECT_ROOT" "scripts/__tests__"
        The output should include "scripts/__tests__"
        The status should be success
      End

      It 'produces consistent results from scripts directory'
        When call run_from_directory "$PROJECT_ROOT/scripts" "."
        The output should include "SHELLSPEC_ARGS: ."
        The status should be success
      End

      It 'produces consistent results from test directory'
        When call run_from_directory "$PROJECT_ROOT/scripts/__tests__" "."
        The output should include "SHELLSPEC_ARGS: ."
        The status should be success
      End
    End

    Context 'path type handling'
      It 'passes absolute path unchanged'
        When call main "/absolute/path/tests"
        The output should include "/absolute/path/tests"
        The status should be success
      End
    End
  End
End
