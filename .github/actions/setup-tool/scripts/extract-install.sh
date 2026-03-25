#!/usr/bin/env bash
# src: ./.github/actions/scripts/extract-install.sh
# @(#) : Extract and install GitHub tool binary
#
# Copyright (c) 2026- aglabo <https://github.com/aglabo>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT
#
# @file extract-install.sh
# @brief Extract tar.gz and install binary with proper permissions
# @description
#   Extracts the downloaded tar.gz file and installs the tool binary
#   to the installation directory with executable permissions (755).
#
#   **Required Environment Variables:**
#   - TOOL_NAME: Tool binary name
#   - TEMP_DIR: Temporary directory containing tar.gz
#   - BIN_DIR: Installation directory
#
#   **Expected Files:**
#   - ${TEMP_DIR}/${TOOL_NAME}.tar.gz: Downloaded archive
#
#   **Output:**
#   - ${BIN_DIR}/${TOOL_NAME}: Installed binary (755 permissions)
#
# @example
#   # Using command-line arguments
#   ./extract-install.sh actionlint /tmp/tool /tmp/bin
#
#   # Using environment variables
#   TOOL_NAME=actionlint TEMP_DIR=/tmp/tool BIN_DIR=/tmp/bin \
#   ./extract-install.sh
#
# @exitcode 0 Installation succeeds
# @exitcode 4 Extraction or installation fails
#
# @author aglabo
# @version 1.0.0
# @license MIT

set -euo pipefail

# Parse arguments with environment variable fallback
readonly TOOL_NAME="${1:-${TOOL_NAME:?Error: TOOL_NAME required (arg 1 or env var)}}"
readonly TEMP_DIR="${2:-${TEMP_DIR:?Error: TEMP_DIR required (arg 2 or env var)}}"
readonly BIN_DIR="${3:-${BIN_DIR:?Error: BIN_DIR required (arg 3 or env var)}}"

echo "Extracting ${TOOL_NAME}..."

if ! tar -xzf "${TEMP_DIR}/${TOOL_NAME}.tar.gz" -C "${TEMP_DIR}"; then
  echo "::error::Failed to extract ${TOOL_NAME}.tar.gz"
  exit 4
fi

echo "Installing ${TOOL_NAME} to ${BIN_DIR}..."

if ! install -m 755 "${TEMP_DIR}/${TOOL_NAME}" "${BIN_DIR}/${TOOL_NAME}"; then
  echo "::error::Failed to install ${TOOL_NAME} to ${BIN_DIR}"
  exit 4
fi

echo "✓ Installation completed"
