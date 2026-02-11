#!/usr/bin/env bash
# Mock creation helpers for tests

create_mock_shellspec() {
  local output_prefix="${1:-SHELLSPEC_ARGS:}"
  local exit_code="${2:-0}"

  # Check if we should create a silent mock (when output_prefix is explicitly empty)
  if [[ $# -gt 0 && -z "$1" ]]; then
    # Create silent mock (no output) - when called with empty string as first arg
    cat > "$SHELLSPEC" << EOF
#!/usr/bin/env bash
exit ${exit_code}
EOF
  else
    # Create mock with output
    cat > "$SHELLSPEC" << EOF
#!/usr/bin/env bash
echo "${output_prefix} \$*"
exit ${exit_code}
EOF
  fi
  chmod +x "$SHELLSPEC"
}

create_shellspec_config() {
  local shell="${1:-bash}"
  local pattern="${2:-*.spec.sh}"

  cat > "$TEST_TMPDIR/fake-project/.shellspec" << EOF
--shell ${shell}
--pattern "${pattern}"
EOF
}

create_custom_mock_shellspec() {
  local output_message="$1"
  local exit_code="${2:-0}"

  cat > "$SHELLSPEC" << EOF
#!/usr/bin/env bash
echo "${output_message}"
exit ${exit_code}
EOF
  chmod +x "$SHELLSPEC"
}
