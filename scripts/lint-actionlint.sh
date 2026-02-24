#!/usr/bin/env bash
# src: /scripts/lint-actionlint
# @(#) : Document linting and writing tools installation script
#
# Copyright (c) 2025 Furukawa Atsushi <atsushifx@gmail.com>
#
# Released under the MIT License.
# https://opensource.org/licenses/MIT

set -euo pipefail

files=$(git ls-files ".github/workflows/*.yml" ".github/workflows/*.yaml")

if [ -n "$files" ]; then
  pnpm exec actionlint ${files}
else
  echo "No workflow files found."
fi
