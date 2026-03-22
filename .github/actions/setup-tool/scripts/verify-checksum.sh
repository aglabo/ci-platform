#!/usr/bin/env bash
# src: ./.github/actions/scripts/verify-checksum.sh
# @(#) : Verify SHA256 checksum of downloaded tool
#
# Copyright (c) 2026- aglabo <https://github.com/aglabo>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT
#
# @file verify-checksum.sh
# @brief Verify SHA256 checksum of downloaded binary
# @description
#   Verifies the SHA256 checksum of the downloaded tool binary against
#   the expected checksum from the checksums file. This ensures the
#   downloaded file has not been corrupted or tampered with.
#
#   **Required Environment Variables:**
#   - TOOL_NAME: Tool binary name
#   - TOOL_VERSION: Tool version
#   - ARCH_SUFFIX: Architecture suffix ("amd64" or "x64")
#   - TEMP_DIR: Temporary directory containing downloaded files
#
#   **Expected Files:**
#   - ${TEMP_DIR}/${TOOL_NAME}.tar.gz: Downloaded binary
#   - ${TEMP_DIR}/checksums.txt: Checksums file
#
# @example
#   # Using command-line arguments
#   ./verify-checksum.sh actionlint 1.7.10 amd64 /tmp/tool
#
#   # Using environment variables
#   TOOL_NAME=actionlint TOOL_VERSION=1.7.10 ARCH_SUFFIX=amd64 \
#   TEMP_DIR=/tmp/tool ./verify-checksum.sh
#
# @exitcode 0 Checksum matches
# @exitcode 3 Checksum verification fails
#
# @author aglabo
# @version 1.0.0
# @license MIT

set -euo pipefail

# Parse arguments with environment variable fallback
readonly TOOL_NAME="${1:-${TOOL_NAME:?Error: TOOL_NAME required (arg 1 or env var)}}"
readonly TOOL_VERSION="${2:-${TOOL_VERSION:?Error: TOOL_VERSION required (arg 2 or env var)}}"
readonly ARCH_SUFFIX="${3:-${ARCH_SUFFIX:?Error: ARCH_SUFFIX required (arg 3 or env var)}}"
readonly TEMP_DIR="${4:-${TEMP_DIR:?Error: TEMP_DIR required (arg 4 or env var)}}"

FILENAME="${TOOL_NAME}_${TOOL_VERSION}_linux_${ARCH_SUFFIX}.tar.gz"

# Extract expected checksum
EXPECTED_CHECKSUM=$(grep -w "${FILENAME}" "${TEMP_DIR}/checksums.txt" | awk '{print $1}' | head -1)

if [[ -z "${EXPECTED_CHECKSUM}" ]]; then
  echo "::error::Could not find checksum for ${FILENAME} in checksums.txt"
  exit 3
fi

# Calculate actual checksum
ACTUAL_CHECKSUM=$(sha256sum "${TEMP_DIR}/${TOOL_NAME}.tar.gz" | awk '{print $1}')

# Display comparison
echo "Expected checksum: ${EXPECTED_CHECKSUM}"
echo "Actual checksum:   ${ACTUAL_CHECKSUM}"

# Verify match
if [[ "${EXPECTED_CHECKSUM}" != "${ACTUAL_CHECKSUM}" ]]; then
  echo "::error::Checksum verification failed! Downloaded file may be corrupted or tampered."
  exit 3
fi

echo "✓ Checksum verification passed"
