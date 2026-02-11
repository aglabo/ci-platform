#!/usr/bin/env bash
# General test utility functions

run_from_directory() {
  local target_dir="$1"
  shift
  (cd "$target_dir" && main "$@")
}
