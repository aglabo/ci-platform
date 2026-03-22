#!/usr/bin/env bash
# src: ./.github/actions/scripts/setup-directories.sh
# @(#) : Setup installation directories for GitHub tool
#
# Copyright (c) 2026- aglabo <https://github.com/aglabo>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT
#
# @file setup-directories.sh
# @brief Create installation and temporary directories
# @description
#   Creates persistent binary directory (BIN_DIR) and temporary download
#   directory (TEMP_DIR) for GitHub tool installation. Updates GITHUB_ENV
#   and GITHUB_PATH for subsequent steps.
#
#   **Required Environment Variables:**
#   - RUNNER_TEMP: GitHub Actions temporary directory
#   - GITHUB_ENV: File to persist environment variables
#   - GITHUB_PATH: File to add directories to PATH
#
#   **Outputs to GITHUB_ENV:**
#   - BIN_DIR: ${RUNNER_TEMP}/bin
#   - TEMP_DIR: Temporary directory from mktemp -d
#
# @example
#   RUNNER_TEMP=/tmp GITHUB_ENV=/tmp/env GITHUB_PATH=/tmp/path \
#   ./setup-directories.sh
#
# @exitcode 0 Always succeeds
#
# @author aglabo
# @version 1.0.0
# @license MIT

set -euo pipefail

# Create persistent bin directory in runner temp
BIN_DIR="${RUNNER_TEMP}/bin"
mkdir -p "${BIN_DIR}"
echo "BIN_DIR=${BIN_DIR}" >> "${GITHUB_ENV}"
echo "Installation directory: ${BIN_DIR}"

# Create job-local temp directory
TEMP_DIR=$(mktemp -d)
echo "TEMP_DIR=${TEMP_DIR}" >> "${GITHUB_ENV}"
echo "Temporary directory: ${TEMP_DIR}"

# Add bin directory to PATH for subsequent steps
echo "${BIN_DIR}" >> "${GITHUB_PATH}"
echo "✓ Directories configured and PATH updated"
