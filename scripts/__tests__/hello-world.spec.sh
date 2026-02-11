#shellcheck shell=sh

Describe 'Hello World Test'
  It 'outputs hello world'
    When call echo "Hello World"
    The output should eq "Hello World"
    The status should be success
  End
End
