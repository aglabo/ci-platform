#!/usr/bin/env bash
# src: .github/actions/_ca-resolve-sha/scripts/__tests__/helpers/git-fixture.sh
# @(#) : real git repository fixtures for resolve-sha tests
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT
# shellcheck shell=bash

# Usage (ShellSpec):
#   Include "${SHELLSPEC_PROJECT_ROOT}/.github/actions/_ca-resolve-sha/scripts/__tests__/helpers/git-fixture.sh"
#   BeforeEach 'gf_setup'
#   AfterEach 'gf_cleanup'
#
# Every example gets its own temporary root (GF_TMP_ROOT), so specs can run in
# parallel (`--jobs 4`). All repositories are created under that root, and every
# git call made by the fixture ignores the global and system git config of the
# host (signing, hooks, default branch, ...).
#
# gf_setup also unsets every exported GIT_* variable (GIT_DIR, GIT_WORK_TREE,
# GIT_INDEX_FILE, GIT_CONFIG_PARAMETERS, GIT_CONFIG_COUNT/KEY_n/VALUE_n,
# GIT_DEFAULT_HASH, ...) in the example's shell, so neither the fixture nor the
# code under test can act on the host repository (e.g. when run from a git hook).
# Repositories are always created with the sha1 object format (40-hex OIDs).
#
# Fixtures that take a repository path (gf_git, gf_commit, gf_partial_clone,
# gf_remove_object) reject an empty path instead of running `git -C ""`, which
# would act on the cwd -- the host repository under ShellSpec. Assign builder
# results with a checked `var="$(gf_...)" || return 1` instead of nesting an
# unchecked `$(gf_...)` in another fixture's arguments.

[ -n "${GIT_FIXTURE_LOADED:-}" ] && return 0
GIT_FIXTURE_LOADED=1

# Base of the fixed commit timestamps (seconds since the epoch, UTC)
readonly _GF_DATE_BASE=1700000000

##
# @description Run git with the host's global / system config ignored.
# @arg $@ git arguments
# @stdout git stdout
# @return git exit code
_gf_git() {
  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git "$@"
}

##
# @description Apply the local config every fixture repository needs.
# @arg $1 repo — repository path
# @return 0 on success, non-zero on git failure
_gf_configure() {
  local repo="$1"

  _gf_git -C "$repo" config user.name "git-fixture" &&
    _gf_git -C "$repo" config user.email "git-fixture@example.invalid" &&
    _gf_git -C "$repo" config commit.gpgsign false &&
    _gf_git -C "$repo" config gc.auto 0
}

##
# @description Fail unless gf_setup has created the temporary root.
# @stderr error message when the root is missing
# @return 0 if GF_TMP_ROOT is a directory, 1 otherwise
_gf_require_root() {
  if [[ -z "${GF_TMP_ROOT:-}" || ! -d "$GF_TMP_ROOT" ]]; then
    echo "git-fixture: gf_setup has not been called" >&2
    return 1
  fi
}

##
# @description Fail unless a repository path argument is non-empty, so that a
#              failed builder never turns `git -C "$repo"` into a git call on the cwd.
# @arg $1 caller — name of the calling fixture (for the message)
# @arg $2 path   — repository path to check
# @stderr error message when the path is empty
# @return 0 if the path is non-empty, 1 otherwise
_gf_require_path() {
  if [[ -z "$2" ]]; then
    echo "git-fixture: $1: empty repository path" >&2
    return 1
  fi
}

##
# @description Unset every exported GIT_* variable in the current shell, so that
#              later git calls (fixture and code under test alike) start from a
#              clean environment and never follow GIT_DIR & co. to the host repo.
# @return 0
_gf_clear_git_env() {
  local _gf_var

  while IFS= read -r _gf_var; do
    unset "$_gf_var"
  done < <(compgen -e GIT_)
  return 0
}

##
# @description Clear the host's GIT_* environment (see _gf_clear_git_env), then
#              create the per-example temporary root and export GF_TMP_ROOT.
#              Call it directly (not in a command substitution): the variable
#              would be lost with the subshell and the directory would leak.
# @stdout (none)
# @return 0 on success, 1 if mktemp fails
gf_setup() {
  _gf_clear_git_env
  GF_TMP_ROOT="$(mktemp -d)" || return 1
  export GF_TMP_ROOT
}

##
# @description Remove the temporary root created by gf_setup and unset GF_TMP_ROOT.
#              Safe to call when gf_setup was not called.
# @return 0
gf_cleanup() {
  if [[ -n "${GF_TMP_ROOT:-}" && -d "$GF_TMP_ROOT" ]]; then
    rm -rf "$GF_TMP_ROOT"
  fi
  unset GF_TMP_ROOT
  return 0
}

##
# @description Run git inside a fixture repository with the host config ignored.
#              Use it for ad-hoc setup such as `gf_git "$repo" config extensions.partialClone origin`.
#              An empty repo is rejected without running git.
# @arg $1 repo — repository path (must be non-empty)
# @arg $@ git arguments (after $1)
# @stdout git stdout
# @stderr error message when repo is empty
# @return git exit code, or 1 when repo is empty
gf_git() {
  local repo="$1"
  _gf_require_path gf_git "$repo" || return 1
  shift
  _gf_git -C "$repo" "$@"
}

##
# @description Create an empty repository (`git init`, no commits) on branch main,
#              with the sha1 object format pinned (clones inherit it from origin).
# @arg $1 name — directory name under GF_TMP_ROOT
# @stdout the repository path
# @return 0 on success, 1 on failure
gf_init_repo() {
  local name="$1"
  local repo

  _gf_require_root || return 1
  repo="${GF_TMP_ROOT}/${name}"
  _gf_git -c init.defaultBranch=main init -q --object-format=sha1 "$repo" || return 1
  _gf_configure "$repo" || return 1
  printf '%s\n' "$repo"
}

##
# @description Add one commit on the current branch. Each commit adds its own file,
#              so trees never repeat. Dates are fixed and increase per commit.
# @arg $1 repo    — repository path (must be non-empty)
# @arg $2 message — commit message (default: "commit")
# @stdout the new commit OID
# @stderr error message when repo is empty
# @return 0 on success, 1 on failure (including an empty repo)
gf_commit() {
  local repo="$1"
  local message="${2:-commit}"
  local seq date

  _gf_require_path gf_commit "$repo" || return 1
  seq="$(_gf_git -C "$repo" rev-list --all --count)" || return 1
  seq=$((seq + 1))
  date="@$((_GF_DATE_BASE + seq * 60)) +0000"
  printf '%s\n' "$message" >"${repo}/file-${seq}.txt" || return 1
  _gf_git -C "$repo" add "file-${seq}.txt" || return 1
  GIT_AUTHOR_DATE="$date" GIT_COMMITTER_DATE="$date" \
    _gf_git -C "$repo" commit -q -m "$message" || return 1
  _gf_git -C "$repo" rev-parse HEAD
}

##
# @description Create a repository with a linear history of N commits on main.
# @arg $1 name  — directory name under GF_TMP_ROOT
# @arg $2 count — number of commits (0 gives an empty repository)
# @stdout the repository path
# @return 0 on success, 1 on failure
gf_linear_repo() {
  local name="$1"
  local count="$2"
  local repo i

  repo="$(gf_init_repo "$name")" || return 1
  for ((i = 1; i <= count; i++)); do
    gf_commit "$repo" "commit-${i}" >/dev/null || return 1
  done
  printf '%s\n' "$repo"
}

##
# @description Create a repository whose HEAD is a merge commit (`--no-ff`).
#              main holds <main_count> commits starting at the root commit; branch
#              side forks from the root and adds <side_count> commits; main then
#              merges side. HEAD^1 is the last main commit, HEAD^2 the last side commit.
#              First-parent history length: main_count + 1.
#              Full history length:         main_count + side_count + 1.
# @arg $1 name       — directory name under GF_TMP_ROOT
# @arg $2 main_count — commits on main before the merge (>= 1, includes the root)
# @arg $3 side_count — commits on side (>= 1)
# @stdout the repository path
# @return 0 on success, 1 on failure
gf_merge_repo() {
  local name="$1"
  local main_count="$2"
  local side_count="$3"
  local repo root i

  repo="$(gf_init_repo "$name")" || return 1
  root="$(gf_commit "$repo" "root")" || return 1
  for ((i = 2; i <= main_count; i++)); do
    gf_commit "$repo" "main-${i}" >/dev/null || return 1
  done
  _gf_git -C "$repo" checkout -q -b side "$root" || return 1
  for ((i = 1; i <= side_count; i++)); do
    gf_commit "$repo" "side-${i}" >/dev/null || return 1
  done
  _gf_git -C "$repo" checkout -q main || return 1
  GIT_AUTHOR_DATE="@$((_GF_DATE_BASE + 86400)) +0000" \
    GIT_COMMITTER_DATE="@$((_GF_DATE_BASE + 86400)) +0000" \
    _gf_git -C "$repo" merge -q --no-ff -m "merge side" side || return 1
  printf '%s\n' "$repo"
}

##
# @description Create a shallow clone of a fixture repository. Uses a file:// URL
#              because a plain local path ignores --depth and copies the full history.
# @arg $1 origin — source repository path
# @arg $2 name   — directory name under GF_TMP_ROOT
# @arg $3 depth  — clone depth (>= 1)
# @stdout the clone path
# @return 0 on success, 1 on failure
gf_shallow_clone() {
  local origin="$1"
  local name="$2"
  local depth="$3"
  local repo

  _gf_require_root || return 1
  repo="${GF_TMP_ROOT}/${name}"
  _gf_git clone -q --depth "$depth" "file://${origin}" "$repo" || return 1
  _gf_configure "$repo" || return 1
  printf '%s\n' "$repo"
}

##
# @description Create a partial clone (`--filter=blob:none`) of a fixture repository.
#              Enables uploadpack.allowFilter on the origin so the filter is honoured.
#              An empty origin is rejected before the origin's config is touched.
# @arg $1 origin — source repository path (must be non-empty)
# @arg $2 name   — directory name under GF_TMP_ROOT
# @stdout the clone path
# @stderr error message when origin is empty
# @return 0 on success, 1 on failure (including an empty origin)
gf_partial_clone() {
  local origin="$1"
  local name="$2"
  local repo

  _gf_require_root || return 1
  _gf_require_path gf_partial_clone "$origin" || return 1
  repo="${GF_TMP_ROOT}/${name}"
  _gf_git -C "$origin" config uploadpack.allowFilter true || return 1
  _gf_git clone -q --filter=blob:none "file://${origin}" "$repo" || return 1
  _gf_configure "$repo" || return 1
  printf '%s\n' "$repo"
}

##
# @description Delete one loose object file to simulate a corrupted repository.
#              Fixture repositories never pack (gc.auto=0), so objects made by
#              gf_commit are loose.
# @arg $1 repo — repository path (must be non-empty)
# @arg $2 oid  — full object ID to delete
# @stderr error message when repo is empty or the object is not a loose object
# @return 0 on success, 1 on failure (including an empty repo)
gf_remove_object() {
  local repo="$1"
  local oid="$2"
  local objects path

  _gf_require_path gf_remove_object "$repo" || return 1
  objects="$(_gf_git -C "$repo" rev-parse --git-path objects)" || return 1
  [[ "$objects" == /* ]] || objects="${repo}/${objects}"
  path="${objects}/${oid:0:2}/${oid:2}"
  if [[ ! -f "$path" ]]; then
    echo "git-fixture: not a loose object: ${oid}" >&2
    return 1
  fi
  rm -f "$path"
}

##
# @description Append an unparsable line to the repository's .git/config, so that
#              any later config read fails with a non 0/1 exit code.
# @arg $1 repo — repository path
# @return 0 on success, 1 on failure
gf_break_config() {
  local repo="$1"

  printf '%s\n' '[git-fixture-broken' >>"${repo}/.git/config"
}

##
# @description Create a plain directory that is not inside any git repository.
# @arg $1 name — directory name under GF_TMP_ROOT
# @stdout the directory path
# @stderr error message when the directory is inside a git work tree
# @return 0 on success, 1 on failure
gf_non_git_dir() {
  local name="$1"
  local dir

  _gf_require_root || return 1
  dir="${GF_TMP_ROOT}/${name}"
  mkdir -p "$dir" || return 1
  if _gf_git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
    echo "git-fixture: ${dir} is inside a git repository" >&2
    return 1
  fi
  printf '%s\n' "$dir"
}
