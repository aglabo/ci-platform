#!/usr/bin/env bash
# src: ./.github/actions/scripts/download-tool.sh
# @(#) : Download GitHub tool binary and checksums
#
# Copyright (c) 2026- aglabo <https://github.com/aglabo>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT
#
# @file download-tool.sh
# @brief Download binary and checksums from GitHub releases
# @description
#   Downloads tool binary (tar.gz) and checksums file from GitHub releases.
#   Files are saved to TEMP_DIR for subsequent verification and extraction.
#
#   **Required Environment Variables:**
#   - TOOL_NAME: Tool binary name (e.g., "actionlint", "ghalint")
#   - TOOL_VERSION: Version to download (e.g., "1.7.10")
#   - GITHUB_ORG: GitHub organization (e.g., "rhysd")
#   - ARCH_SUFFIX: Architecture suffix ("amd64" or "x64")
#   - TEMP_DIR: Temporary directory for downloads
#
#   **Download URLs:**
#   - Binary: https://github.com/{ORG}/{TOOL}/releases/download/v{VERSION}/{TOOL}_{VERSION}_linux_{ARCH}.tar.gz
#   - Checksums: https://github.com/{ORG}/{TOOL}/releases/download/v{VERSION}/{TOOL}_{VERSION}_checksums.txt
#
# @example
#   # Using command-line arguments
#   ./download-tool.sh actionlint 1.7.10 rhysd amd64 /tmp/tool
#
#   # Using environment variables
#   TOOL_NAME=actionlint TOOL_VERSION=1.7.10 GITHUB_ORG=rhysd \
#   ARCH_SUFFIX=amd64 TEMP_DIR=/tmp/tool \
#   ./download-tool.sh
#
# @exitcode 0 Download succeeds
# @exitcode 2 Download fails (network error or release not found)
#
# @author aglabo
# @version 1.0.0
# @license MIT

set -euo pipefail

# Parse arguments with environment variable fallback
readonly TOOL_NAME="${1:-${TOOL_NAME:?Error: TOOL_NAME required (arg 1 or env var)}}"
readonly TOOL_VERSION="${2:-${TOOL_VERSION:?Error: TOOL_VERSION required (arg 2 or env var)}}"
readonly GITHUB_ORG="${3:-${GITHUB_ORG:?Error: GITHUB_ORG required (arg 3 or env var)}}"
readonly ARCH_SUFFIX="${4:-${ARCH_SUFFIX:?Error: ARCH_SUFFIX required (arg 4 or env var)}}"
readonly TEMP_DIR="${5:-${TEMP_DIR:?Error: TEMP_DIR required (arg 5 or env var)}}"

DOWNLOAD_URL="https://github.com/${GITHUB_ORG}/${TOOL_NAME}/releases/download/v${TOOL_VERSION}/${TOOL_NAME}_${TOOL_VERSION}_linux_${ARCH_SUFFIX}.tar.gz"
CHECKSUM_URL="https://github.com/${GITHUB_ORG}/${TOOL_NAME}/releases/download/v${TOOL_VERSION}/${TOOL_NAME}_${TOOL_VERSION}_checksums.txt"

echo "Downloading ${TOOL_NAME} v${TOOL_VERSION}..."

if ! curl -sSL -o "${TEMP_DIR}/${TOOL_NAME}.tar.gz" "${DOWNLOAD_URL}"; then
  echo "::error::Failed to download ${TOOL_NAME} binary from ${DOWNLOAD_URL}"
  exit 2
fi

if ! curl -sSL -o "${TEMP_DIR}/checksums.txt" "${CHECKSUM_URL}"; then
  echo "::error::Failed to download checksums from ${CHECKSUM_URL}"
  exit 2
fi

echo "✓ Download completed"
