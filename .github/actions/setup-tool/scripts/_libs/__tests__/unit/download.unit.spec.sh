#!/usr/bin/env bash
# src: .github/actions/setup-tool/scripts/_libs/__tests__/unit/download.unit.spec.sh
# @(#) : ShellSpec unit tests for build_url(), resolve_assets(), and download_tool()
#
# Copyright (c) 2026- atsushifx <atsushifx@gmail.com>
# MIT License

# shellcheck shell=bash
# cspell:words rhysd

LIB_PATH="${SHELLSPEC_PROJECT_ROOT}/.github/actions/setup-tool/scripts/_libs/download.lib.sh"
Include "$LIB_PATH"

Describe 'Given: repo is rhysd/actionlint and version is 1.7.7 (no v prefix)'
  Describe 'When: build_url is called'
    Describe 'Then: Task T-url-nor - Normal Cases'
      It "T-url-nor-01: outputs the correct GitHub API URL"
        When call build_url "rhysd/actionlint" "1.7.7"
        The output should equal "https://api.github.com/repos/rhysd/actionlint/releases/tags/v1.7.7"
      End
    End
  End
End

Describe 'Given: repo is rhysd/actionlint and version is v1.7.7 (with v prefix)'
  Describe 'When: build_url is called'
    Describe 'Then: Task T-url-edg - Edge Cases'
      It "T-url-edg-01: outputs URL without double v prefix"
        When call build_url "rhysd/actionlint" "v1.7.7"
        The output should equal "https://api.github.com/repos/rhysd/actionlint/releases/tags/v1.7.7"
      End
    End
  End
End

# ─── T-08: resolve_assets() ─────────────────────────────────────────────────

# ─── Internal Helpers (mocks)

# shellcheck disable=SC2329
_mock_curl_amd64() {
  curl() {
    printf '{"assets":[\n'
    printf '  {"name":"actionlint_1.7.7_linux_amd64.tar.gz","browser_download_url":"https://github.com/rhysd/actionlint/releases/download/v1.7.7/actionlint_1.7.7_linux_amd64.tar.gz"},\n'
    printf '  {"name":"checksums.txt","browser_download_url":"https://github.com/rhysd/actionlint/releases/download/v1.7.7/checksums.txt"}\n'
    printf ']}\n200'
    return 0
  }
  export -f curl
}

# shellcheck disable=SC2329
_mock_curl_versioned_checksum() {
  curl() {
    printf '{"assets":[\n'
    printf '  {"name":"actionlint_1.7.7_linux_amd64.tar.gz","browser_download_url":"https://github.com/rhysd/actionlint/releases/download/v1.7.7/actionlint_1.7.7_linux_amd64.tar.gz"},\n'
    printf '  {"name":"actionlint_1.7.7_checksums.txt","browser_download_url":"https://github.com/rhysd/actionlint/releases/download/v1.7.7/actionlint_1.7.7_checksums.txt"}\n'
    printf ']}\n200'
    return 0
  }
  export -f curl
}

# shellcheck disable=SC2329
_mock_curl_x64_only() {
  curl() {
    printf '{"assets":[\n'
    printf '  {"name":"actionlint_1.7.7_linux_x64.tar.gz","browser_download_url":"https://github.com/rhysd/actionlint/releases/download/v1.7.7/actionlint_1.7.7_linux_x64.tar.gz"},\n'
    printf '  {"name":"checksums.txt","browser_download_url":"https://github.com/rhysd/actionlint/releases/download/v1.7.7/checksums.txt"}\n'
    printf ']}\n200'
    return 0
  }
  export -f curl
}

# shellcheck disable=SC2329
_mock_curl_arm64_only() {
  curl() {
    printf '{"assets":[\n'
    printf '  {"name":"actionlint_1.7.7_linux_arm64.tar.gz","browser_download_url":"https://github.com/rhysd/actionlint/releases/download/v1.7.7/actionlint_1.7.7_linux_arm64.tar.gz"},\n'
    printf '  {"name":"checksums.txt","browser_download_url":"https://github.com/rhysd/actionlint/releases/download/v1.7.7/checksums.txt"}\n'
    printf ']}\n200'
    return 0
  }
  export -f curl
}

# shellcheck disable=SC2329
_mock_curl_fail() {
  curl() { return 1; }
  export -f curl
}

# shellcheck disable=SC2329
_mock_curl_no_checksums() {
  curl() {
    printf '{"assets":[\n'
    printf '  {"name":"actionlint_1.7.7_linux_amd64.tar.gz","browser_download_url":"https://github.com/rhysd/actionlint/releases/download/v1.7.7/actionlint_1.7.7_linux_amd64.tar.gz"}\n'
    printf ']}\n200'
    return 0
  }
  export -f curl
}

# ─── Tests

Describe 'Given: API returns amd64 tar.gz and checksums.txt'
  Describe 'When: resolve_assets is called with amd64 x64 candidates'
    Describe 'Then: Task T-res-nor - Normal Cases'
      BeforeEach '_mock_curl_amd64'
      AfterEach 'unset -f curl'

      It "T-res-nor-01: stdout line 1 is amd64 download URL"
        When call resolve_assets "https://api.github.com/repos/rhysd/actionlint/releases/tags/v1.7.7" "actionlint" "amd64" "x64"
        The output line 1 should equal "https://github.com/rhysd/actionlint/releases/download/v1.7.7/actionlint_1.7.7_linux_amd64.tar.gz"
      End

      It "T-res-nor-02: stdout line 2 is checksums.txt URL and line 3 is amd64"
        When call resolve_assets "https://api.github.com/repos/rhysd/actionlint/releases/tags/v1.7.7" "actionlint" "amd64" "x64"
        The output line 2 should include "checksums.txt"
        The output line 3 should equal "amd64"
      End
    End
  End
End

Describe 'Given: API returns amd64 tar.gz and actionlint_1.7.7_checksums.txt (no checksums.txt)'
  Describe 'When: resolve_assets is called with amd64 x64 candidates'
    Describe 'Then: Task T-res-nor - Versioned Checksums'
      BeforeEach '_mock_curl_versioned_checksum'
      AfterEach 'unset -f curl'

      It "T-res-nor-03: stdout line 2 URL contains actionlint_1.7.7_checksums.txt"
        When call resolve_assets "https://api.github.com/repos/rhysd/actionlint/releases/tags/v1.7.7" "actionlint" "amd64" "x64"
        The output line 2 should include "actionlint_1.7.7_checksums.txt"
      End
    End
  End
End

Describe 'Given: API returns x64 tar.gz and checksums.txt (no amd64)'
  Describe 'When: resolve_assets is called with amd64 x64 candidates'
    Describe 'Then: Task T-res-edg - x64 Fallback'
      BeforeEach '_mock_curl_x64_only'
      AfterEach 'unset -f curl'

      It "T-res-edg-01: stdout line 1 contains x64 and line 3 is x64"
        When call resolve_assets "https://api.github.com/repos/rhysd/actionlint/releases/tags/v1.7.7" "actionlint" "amd64" "x64"
        The output line 1 should include "x64"
        The output line 3 should equal "x64"
      End
    End
  End
End

Describe 'Given: API returns arm64 tar.gz only (no amd64 or x64)'
  Describe 'When: resolve_assets is called with amd64 x64 candidates'
    Describe 'Then: Task T-res-err - Error Cases'
      BeforeEach '_mock_curl_arm64_only'
      AfterEach 'unset -f curl'

      It "T-res-err-01: stderr contains ::error:: and exit code is 2"
        When call resolve_assets "https://api.github.com/repos/rhysd/actionlint/releases/tags/v1.7.7" "actionlint" "amd64" "x64"
        The stderr should include "::error::"
        The status should equal 2
      End
    End
  End
End

Describe 'Given: curl fails to connect'
  Describe 'When: resolve_assets is called'
    Describe 'Then: Task T-res-err - Error Cases'
      BeforeEach '_mock_curl_fail'
      AfterEach 'unset -f curl'

      It "T-res-err-02: stderr contains ::error:: and exit code is 2"
        When call resolve_assets "https://api.github.com/repos/rhysd/actionlint/releases/tags/v1.7.7" "actionlint" "amd64" "x64"
        The stderr should include "::error::"
        The status should equal 2
      End
    End
  End
End

Describe 'Given: API returns amd64 tar.gz only (no checksums file)'
  Describe 'When: resolve_assets is called with amd64 x64 candidates'
    Describe 'Then: Task T-res-err - Error Cases'
      BeforeEach '_mock_curl_no_checksums'
      AfterEach 'unset -f curl'

      It "T-res-err-03: stderr contains ::error:: and exit code is 2"
        When call resolve_assets "https://api.github.com/repos/rhysd/actionlint/releases/tags/v1.7.7" "actionlint" "amd64" "x64"
        The stderr should include "::error::"
        The status should equal 2
      End
    End
  End
End

# ─── T-09: download_tool() ──────────────────────────────────────────────────

# ─── Internal Helpers (mocks and setup)

# shellcheck disable=SC2329
_mock_curl_download_ok() {
  curl() { touch "$3"; return 0; }
  export -f curl
}

# shellcheck disable=SC2329
_mock_curl_download_fail() {
  curl() { return 1; }
  export -f curl
}

# shellcheck disable=SC2329
_mock_curl_checksum_fail() {
  _call_count=0
  curl() {
    _call_count=$((_call_count + 1))
    if [ "$_call_count" -eq 1 ]; then
      touch "$3"; return 0
    else
      return 1
    fi
  }
  export -f curl
  _call_count=0
}

_test_temp_dir=""

# shellcheck disable=SC2329
_setup_temp() {
  _test_temp_dir=$(mktemp -d)
}

# shellcheck disable=SC2329
_teardown_temp() {
  rm -rf "$_test_temp_dir"
  unset -f curl 2>/dev/null || true
  unset _call_count 2>/dev/null || true
}

# ─── Tests

Describe 'Given: DOWNLOAD_URL and CHECKSUM_URL are valid'
  BeforeEach '_setup_temp'
  BeforeEach '_mock_curl_download_ok'
  AfterEach '_teardown_temp'

  Describe 'When: download_tool is called'
    Describe 'Then: Task T-dwn-nor - Normal Cases'
      It "T-dwn-nor-01: saves tool archive as actionlint.tar.gz in TEMP_DIR"
        When call download_tool "https://example.com/actionlint.tar.gz" "https://example.com/checksums.txt" "$_test_temp_dir" "actionlint"
        The file "${_test_temp_dir}/actionlint.tar.gz" should be exist
      End

      It "T-dwn-nor-02: saves checksums.txt in TEMP_DIR"
        When call download_tool "https://example.com/actionlint.tar.gz" "https://example.com/checksums.txt" "$_test_temp_dir" "actionlint"
        The file "${_test_temp_dir}/checksums.txt" should be exist
      End
    End
  End
End

Describe 'Given: curl fails to download the tool archive'
  BeforeEach '_setup_temp'
  BeforeEach '_mock_curl_download_fail'
  AfterEach '_teardown_temp'

  Describe 'When: download_tool is called'
    Describe 'Then: Task T-dwn-err - Error Cases'
      It "T-dwn-err-01: stderr contains ::error:: and exit code is 2"
        When call download_tool "https://invalid.example.com/actionlint.tar.gz" "https://example.com/checksums.txt" "$_test_temp_dir" "actionlint"
        The stderr should include "::error::"
        The status should equal 2
      End
    End
  End
End

Describe 'Given: curl fails to download checksums.txt (archive succeeds)'
  BeforeEach '_setup_temp'
  BeforeEach '_mock_curl_checksum_fail'
  AfterEach '_teardown_temp'

  Describe 'When: download_tool is called'
    Describe 'Then: Task T-dwn-err - Error Cases'
      It "T-dwn-err-02: stderr contains ::error:: and exit code is 2"
        When call download_tool "https://example.com/actionlint.tar.gz" "https://invalid.example.com/checksums.txt" "$_test_temp_dir" "actionlint"
        The stderr should include "::error::"
        The status should equal 2
      End
    End
  End
End

# ─── T-10: verify_checksum() ────────────────────────────────────────────────

# ─── Internal Helpers (fixtures)

_checksum_test_temp_dir=""
_expected_hash=""

# shellcheck disable=SC2329
_setup_checksum_ok() {
  _checksum_test_temp_dir=$(mktemp -d)
  echo "fake tool content" > "${_checksum_test_temp_dir}/actionlint.tar.gz"
  _expected_hash=$(sha256sum "${_checksum_test_temp_dir}/actionlint.tar.gz" | awk '{print $1}')
  echo "${_expected_hash}  actionlint_1.7.7_linux_amd64.tar.gz" > "${_checksum_test_temp_dir}/checksums.txt"
}

# shellcheck disable=SC2329
_setup_checksum_mismatch() {
  _checksum_test_temp_dir=$(mktemp -d)
  echo "fake tool content" > "${_checksum_test_temp_dir}/actionlint.tar.gz"
  echo "0000000000000000000000000000000000000000000000000000000000000000  actionlint_1.7.7_linux_amd64.tar.gz" > "${_checksum_test_temp_dir}/checksums.txt"
}

# shellcheck disable=SC2329
_setup_checksum_no_entry() {
  _checksum_test_temp_dir=$(mktemp -d)
  echo "fake tool content" > "${_checksum_test_temp_dir}/actionlint.tar.gz"
  echo "abcdef1234  other_tool_1.0.0_linux_amd64.tar.gz" > "${_checksum_test_temp_dir}/checksums.txt"
}

# shellcheck disable=SC2329
_teardown_checksum() {
  rm -rf "$_checksum_test_temp_dir"
}

# ─── Tests

Describe 'Given: sha256sum matches checksums.txt entry'
  BeforeEach '_setup_checksum_ok'
  AfterEach '_teardown_checksum'
  Describe 'When: verify_checksum is called'
    Describe 'Then: Task T-vfy-nor - Normal Cases'
      It "T-vfy-nor-01: exits 0 when sha256sum matches"
        When call verify_checksum "actionlint" "1.7.7" "amd64" "$_checksum_test_temp_dir"
        The status should be success
      End
    End
  End
End

Describe 'Given: checksums.txt has no entry for the original filename'
  BeforeEach '_setup_checksum_no_entry'
  AfterEach '_teardown_checksum'
  Describe 'When: verify_checksum is called'
    Describe 'Then: Task T-vfy-err - Error Cases'
      It "T-vfy-err-01: outputs ::error:: and exits 3 when entry not found"
        When call verify_checksum "actionlint" "1.7.7" "amd64" "$_checksum_test_temp_dir"
        The stderr should include "::error::"
        The status should equal 3
      End
    End
  End
End

Describe 'Given: sha256sum does not match the expected hash'
  BeforeEach '_setup_checksum_mismatch'
  AfterEach '_teardown_checksum'
  Describe 'When: verify_checksum is called'
    Describe 'Then: Task T-vfy-err - Error Cases'
      It "T-vfy-err-03: outputs ::error:: and exits 3 on hash mismatch"
        When call verify_checksum "actionlint" "1.7.7" "amd64" "$_checksum_test_temp_dir"
        The stderr should include "::error::"
        The status should equal 3
      End
    End
  End
End

Describe 'Given: checksums.txt keyed by original name, file on disk is renamed'
  BeforeEach '_setup_checksum_ok'
  AfterEach '_teardown_checksum'
  Describe 'When: verify_checksum is called'
    Describe 'Then: Task T-vfy-edg - Edge Cases'
      It "T-vfy-edg-01: grep searches by original name (tool_ver_linux_arch.tar.gz)"
        When call verify_checksum "actionlint" "1.7.7" "amd64" "$_checksum_test_temp_dir"
        The status should be success
      End
      It "T-vfy-edg-02: sha256sum target is the renamed file (actionlint.tar.gz)"
        When call verify_checksum "actionlint" "1.7.7" "amd64" "$_checksum_test_temp_dir"
        The status should be success
      End
    End
  End
End

# ─── T-14: resolve_assets ヘルパー関数テスト ──────────────────────────────────

# shellcheck disable=SC2329
_mock_curl_fail_for_fetch() {
  curl() { return 1; }
  export -f curl
}

Describe 'Given: API returns amd64 tar.gz and checksums.txt (for _fetch_assets)'
  BeforeEach '_mock_curl_amd64'
  AfterEach 'unset -f curl'
  Describe 'When: _fetch_assets is called'
    Describe 'Then: Task T-fta-nor - Normal Cases'
      It "T-fta-nor-01: stdout contains amd64 tar.gz name"
        When call _fetch_assets "https://api.github.com/repos/rhysd/actionlint/releases/tags/v1.7.7"
        The output should include "actionlint_1.7.7_linux_amd64.tar.gz"
      End
    End
  End
End

Describe 'Given: curl fails when fetching assets'
  BeforeEach '_mock_curl_fail_for_fetch'
  AfterEach 'unset -f curl'
  Describe 'When: _fetch_assets is called'
    Describe 'Then: Task T-fta-err - Helper Unit Tests'
      It "T-fta-err-01: outputs ::error:: to stderr and returns 2"
        When call _fetch_assets "https://api.github.com/repos/rhysd/actionlint/releases/tags/v1.7.7"
        The stderr should include "::error::"
        The status should equal 2
      End
    End
  End
End

Describe 'Given: pairs contain both checksums.txt and tool_version_checksums.txt'
  # Use printf to embed actual tab characters
  _test_pairs="$(printf 'actionlint_1.7.7_linux_amd64.tar.gz\thttps://dl/actionlint_1.7.7_linux_amd64.tar.gz\nactionlint_1.7.7_checksums.txt\thttps://dl/actionlint_1.7.7_checksums.txt\nchecksums.txt\thttps://dl/checksums.txt')"
  Describe 'When: _find_checksum_url is called'
    Describe 'Then: Task T-fcu-nor - Helper Unit Tests'
      It "T-fcu-nor-01: prefers checksums.txt over tool_version_checksums.txt"
        When call _find_checksum_url "$_test_pairs"
        The output should equal "https://dl/checksums.txt"
      End
    End
  End
End

# ─── T-08-03-02: resolve_assets with arm64 single candidate ─────────────────

Describe 'Given: asset list contains linux_arm64.tar.gz and checksums.txt'
  Describe 'When: resolve_assets is called with ARCH_CANDIDATES=[arm64] (single arg)'
    Describe 'Then: Task T-res-edg - ARM64 Candidate'
      BeforeEach '_mock_curl_arm64_only'
      AfterEach 'unset -f curl'

      It "T-res-edg-02: stdout line 3 equals arm64 and stdout line 1 URL includes arm64"
        When call resolve_assets "https://api.github.com/repos/rhysd/actionlint/releases/tags/v1.7.7" "actionlint" "arm64"
        The output line 1 should include "arm64"
        The output line 3 should equal "arm64"
      End
    End
  End
End

# ─── T-08-04-04: resolve_assets with empty assets array ─────────────────────

# shellcheck disable=SC2329
_mock_curl_empty_assets() {
  curl() {
    printf '{"assets":[]}\n200'
    return 0
  }
  export -f curl
}

Describe 'Given: GitHub API response is {"assets":[]} (empty array)'
  Describe 'When: resolve_assets is called with amd64 x64 candidates'
    Describe 'Then: Task T-res-err - Error Cases'
      BeforeEach '_mock_curl_empty_assets'
      AfterEach 'unset -f curl'

      It "T-res-err-04: stderr includes ::error:: and exit code is 2"
        When call resolve_assets "https://api.github.com/repos/rhysd/actionlint/releases/tags/v1.7.7" "actionlint" "amd64" "x64"
        The stderr should include "::error::"
        The status should equal 2
      End
    End
  End
End

# ─── T-08-04-05: resolve_assets with invalid JSON response ──────────────────

# shellcheck disable=SC2329
_mock_curl_invalid_json() {
  curl() {
    printf 'not valid json at all\n200'
    return 0
  }
  export -f curl
}

Describe 'Given: curl succeeds but returns invalid JSON'
  Describe 'When: resolve_assets is called with amd64 x64 candidates'
    Describe 'Then: Task T-res-err - Error Cases'
      BeforeEach '_mock_curl_invalid_json'
      AfterEach 'unset -f curl'

      It "T-res-err-05: stderr includes ::error:: and exit code is 2"
        When call resolve_assets "https://api.github.com/repos/rhysd/actionlint/releases/tags/v1.7.7" "actionlint" "amd64" "x64"
        The stderr should include "::error::"
        The status should equal 2
      End
    End
  End
End

# ─── T-10-02-02: verify_checksum with missing checksums.txt ─────────────────

# shellcheck disable=SC2329
_setup_checksum_no_checksums_file() {
  _checksum_test_temp_dir=$(mktemp -d)
  echo "fake tool content" > "${_checksum_test_temp_dir}/actionlint.tar.gz"
  # checksums.txt intentionally NOT created
}

Describe 'Given: checksums.txt does NOT exist in TEMP_DIR (only tar.gz present)'
  BeforeEach '_setup_checksum_no_checksums_file'
  AfterEach '_teardown_checksum'
  Describe 'When: verify_checksum is called'
    Describe 'Then: Task T-vfy-err - Error Cases'
      It "T-vfy-err-02: stderr includes ::error:: and exit code is 3"
        When call verify_checksum "actionlint" "1.7.7" "amd64" "$_checksum_test_temp_dir"
        The stderr should include "::error::"
        The status should equal 3
      End
    End
  End
End

# ─── T-10-03-02: verify_checksum with missing tar.gz ────────────────────────

# shellcheck disable=SC2329
_setup_checksum_no_tarball() {
  _checksum_test_temp_dir=$(mktemp -d)
  # actionlint.tar.gz intentionally NOT created
  echo "0000000000000000000000000000000000000000000000000000000000000000  actionlint_1.7.7_linux_amd64.tar.gz" > "${_checksum_test_temp_dir}/checksums.txt"
}

Describe 'Given: actionlint.tar.gz does NOT exist in TEMP_DIR (only checksums.txt present)'
  BeforeEach '_setup_checksum_no_tarball'
  AfterEach '_teardown_checksum'
  Describe 'When: verify_checksum is called'
    Describe 'Then: Task T-vfy-err - Error Cases'
      It "T-vfy-err-04: stderr includes ::error:: and exit code is 3"
        When call verify_checksum "actionlint" "1.7.7" "amd64" "$_checksum_test_temp_dir"
        The stderr should include "::error::"
        The status should equal 3
      End
    End
  End
End

# ─── T-14-03: _fetch_assets() with HTTP 404 response ────────────────────────

# shellcheck disable=SC2329
_mock_curl_http_404() {
  curl() {
    # curl -w '\n%{http_code}' 形式: body + newline + status code
    printf '{"message":"Not Found","documentation_url":"https://docs.github.com/rest"}\n404'
    return 0
  }
  export -f curl
}

Describe 'Given: curl succeeds but GitHub API returns HTTP 404'
  BeforeEach '_mock_curl_http_404'
  AfterEach 'unset -f curl'
  Describe 'When: _fetch_assets is called'
    Describe 'Then: Task T-fta-err - HTTP Error Cases'
      It "T-fta-err-02: stderr contains ::error:: with 404 and exit code is 2"
        When call _fetch_assets "https://api.github.com/repos/rhysd/actionlint/releases/tags/v99.0.0"
        The stderr should include "::error::"
        The stderr should include "404"
        The status should equal 2
      End
    End
  End
End
