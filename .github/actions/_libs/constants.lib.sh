#!/usr/bin/env bash
# src: .github/actions/_libs/constants.lib.sh
# @(#) : limits shared by the composite actions
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# shellcheck shell=bash

# Load guard: return early when this library has already been loaded. An empty
# CONSTANTS_LIB_LOADED counts as "not loaded". The readonly constants below
# must stay after the guard: re-sourcing would otherwise fail on redefining them.
[ -n "${CONSTANTS_LIB_LOADED:-}" ] && return 0
CONSTANTS_LIB_LOADED=1

# The constants are read by the libraries of each action, not by this
# library, so SC2034 (appears unused) is disabled for each of them.

# Byte limit of one value passed through an environment variable: leaves about
# 11 KB of MAX_ARG_STRLEN (131072) for the variable name and the terminator
# (filter-files DR-16)
# shellcheck disable=SC2034
readonly GHA_MAX_ENV_VALUE_BYTES=120000
# Maximum number of files in the diff of a GitHub pull request (filter-files DR-16)
# shellcheck disable=SC2034
readonly GHA_MAX_PR_FILES=3000
