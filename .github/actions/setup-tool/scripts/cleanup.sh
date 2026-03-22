#!/usr/bin/env bash
# src: ./.github/actions/scripts/cleanup.sh
# @(#) : Cleanup temporary files
#
# Copyright (c) 2026- aglabo <https://github.com/aglabo>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT
#
# @file cleanup.sh
# @brief Remove temporary directory and files
# @description
#   Removes the temporary directory created during tool installation.
#   Idempotent: safe to call multiple times. Can be used with GitHub
#   Actions 'if: always()' to ensure cleanup even on failure.
#
#   **Required Environment Variables:**
#   - TEMP_DIR: Temporary directory to remove
#
# @example
#   # Using command-line arguments
#   ./cleanup.sh /tmp/tool
#
#   # Using environment variables
#   TEMP_DIR=/tmp/tool ./cleanup.sh
#
# @exitcode 0 Always succeeds
#
# @author aglabo
# @version 1.0.0
# @license MIT

set -euo pipefail

# Parse arguments with environment variable fallback
readonly TEMP_DIR="${1:-${TEMP_DIR:-}}"

echo "Cleaning up temporary files..."

if [[ -n "${TEMP_DIR}" ]] && [[ -d "${TEMP_DIR}" ]]; then
  rm -rf "${TEMP_DIR}"
  echo "✓ Cleanup completed"
else
  echo "No temporary directory to clean"
fi
