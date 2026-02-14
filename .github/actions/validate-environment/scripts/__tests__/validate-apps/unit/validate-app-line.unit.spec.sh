#shellcheck shell=sh

Describe 'validate-app-line.sh'
  Include ../../../validate-apps.sh

  Describe 'validate_app_line()'
    Context 'with valid input'
      It 'accepts valid 2-field format (cmd|app_name)'
        When call validate_app_line "git|Git"
        The status should be success
      End

      It 'accepts valid 4-field format (cmd|app_name|extractor|min_ver)'
        When call validate_app_line "docker|Docker|field:3|20.10"
        The status should be success
      End

      It 'accepts cmd with valid special characters (/ . - _)'
        When call validate_app_line "/usr/bin/git|Git||"
        The status should be success
      End

      It 'accepts app_name with spaces'
        When call validate_app_line "node|Node.js||"
        The status should be success
      End

      It 'accepts app_name with unicode characters'
        When call validate_app_line "app|アプリ||"
        The status should be success
      End
    End

    Context 'with invalid format (field count)'
      It 'rejects 1-field format'
        When call validate_app_line "git"
        The status should be failure
        The stderr should include "Invalid app definition format"
      End

      It 'rejects 3-field format'
        When call validate_app_line "git|Git|field:3"
        The status should be failure
        The stderr should include "Invalid app definition format"
      End

      It 'rejects 5-field format'
        When call validate_app_line "git|Git|field:3|2.30|extra"
        The status should be failure
        The stderr should include "Invalid app definition format"
      End

      It 'rejects empty line'
        When call validate_app_line ""
        The status should be failure
        The stderr should include "Invalid app definition format"
      End
    End

    Context 'with control characters in cmd'
      It 'rejects cmd with newline character'
        Data
          #|printf 'git\nmalicious|App||'
        End
        When call validate_app_line "$(printf 'git\nmalicious')|App||"
        The status should be failure
        The stderr should include "Invalid command name"
        The stderr should include "contains control characters"
      End

      It 'rejects cmd with carriage return'
        When call validate_app_line "$(printf 'git\rmalicious')|App||"
        The status should be failure
        The stderr should include "Invalid command name"
        The stderr should include "contains control characters"
      End

      It 'rejects cmd with tab character'
        When call validate_app_line "$(printf 'git\tmalicious')|App||"
        The status should be failure
        The stderr should include "Invalid command name"
        The stderr should include "contains control characters"
      End
    End

    Context 'with control characters in app_name'
      It 'rejects app_name with newline character'
        When call validate_app_line "git|$(printf 'App\nName')||"
        The status should be failure
        The stderr should include "Invalid app_name"
        The stderr should include "contains control characters"
      End

      It 'rejects app_name with carriage return'
        When call validate_app_line "git|$(printf 'App\rName')||"
        The status should be failure
        The stderr should include "Invalid app_name"
        The stderr should include "contains control characters"
      End

      It 'rejects app_name with tab character'
        When call validate_app_line "git|$(printf 'App\tName')||"
        The status should be failure
        The stderr should include "Invalid app_name"
        The stderr should include "contains control characters"
      End
    End

    Context 'error message clarity'
      It 'distinguishes cmd vs app_name in error messages'
        When call validate_app_line "$(printf 'bad\ncmd')|GoodApp||"
        The status should be failure
        The stderr should include "command name"
        The stderr should not include "app_name"
      End

      It 'reports malicious input context'
        When call validate_app_line "git|$(printf 'Bad\nApp')||"
        The status should be failure
        The stderr should include "malicious input or data corruption"
      End
    End
  End
End
