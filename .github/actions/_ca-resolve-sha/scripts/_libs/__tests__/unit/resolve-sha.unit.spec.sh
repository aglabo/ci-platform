#!/bin/bash
# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154

# Test suite for resolve-sha.lib.sh
# Module: composite-action/resolve-sha (test_scope RS)
# Target: _ca-resolve-sha/scripts/_libs/resolve-sha.lib.sh

# --- テスト基盤 ---
# (ShellSpec DSL: Describe / Context / It / When / The)

# --- テスト対象 ---
Include "${SHELLSPEC_PROJECT_ROOT}/.github/actions/_ca-resolve-sha/scripts/_libs/resolve-sha.lib.sh"

# --- ヘルパー ---
# Real git repository fixtures (gf_setup / gf_cleanup / gf_linear_repo / ...)
Include "${SHELLSPEC_PROJECT_ROOT}/.github/actions/_ca-resolve-sha/scripts/__tests__/helpers/git-fixture.sh"

# --- 内部ヘルパー ---
# 定数
# Value carrying an LF followed by a workflow command; used by T-RS-RE-05
_RE_INJECTED_VALUE=$'x\n::add-mask::secret'
# Value with a CR between two characters; used by T-RS-RE-07
_RE_CR_VALUE=$'a\rb'
# Value with an LF between two characters; used by T-RS-RE-08
_RE_LF_VALUE=$'a\nb'
# Valid 40-digit lowercase hex OID; used by T-RS-VOV-02 .. T-RS-VOV-10, T-RS-VOV-13 .. T-RS-VOV-15
_VOV_OID_A="0123456789abcdef0123456789abcdef01234567"
# Valid 40-digit lowercase hex OID different from _VOV_OID_A; used by T-RS-VOV-02, T-RS-VOV-12
_VOV_OID_B="89abcdef0123456789abcdef0123456789abcdef"
# 40-character OID containing uppercase hex digits; used by T-RS-VOV-07
_VOV_OID_UPPER="0123456789ABCDEF0123456789abcdef01234567"
# 7-digit abbreviated SHA; used by T-RS-VOV-06
_VOV_OID_SHORT="0123456"
# 39-digit lowercase hex (one short of a full OID); used by T-RS-VOV-13
_VOV_OID_39="0123456789abcdef0123456789abcdef0123456"
# 41-digit lowercase hex (one over a full OID); used by T-RS-VOV-14
_VOV_OID_41="0123456789abcdef0123456789abcdef012345678"
# 40-character OID whose last character is non-hex 'g'; used by T-RS-VOV-15
_VOV_OID_NONHEX="0123456789abcdef0123456789abcdef0123456g"
# Exit code of _ipc_run when the fixture builder fails; no T-RS-IPC case expects it
_IPC_SETUP_FAILED=98
# Exit code of _ic_run / _ic_run_head when the fixture builder fails; no T-RS-IC case expects it
_IC_SETUP_FAILED=98
# Valid-format 40-digit hex OID absent from the fixture repository; used by T-RS-IC-02, T-RS-IC-07
_IC_OID_MISSING="0123456789abcdef0123456789abcdef01234567"
# 40-digit zero OID (never a real object); used by T-RS-IC-05
_IC_OID_ZERO="0000000000000000000000000000000000000000"
# Exit code of _vc_run / _vc_run_head when the fixture builder fails; no T-RS-VC case expects it
_VC_SETUP_FAILED=98
# Valid-format 40-digit hex OID absent from the fixture repository; used by T-RS-VC-03, T-RS-VC-06
_VC_OID_MISSING="0123456789abcdef0123456789abcdef01234567"
# Exit code of _rhn_run when the fixture builder fails; no T-RS-RHN case expects it
_RHN_SETUP_FAILED=98
# ShellSpec `match pattern` for a full 40-digit lowercase hex OID; used by T-RS-RHN-04
_RHN_OID40_PATTERN="$(printf '[0-9a-f]%.0s' {1..40})"
# HEAD commit OID returned by the git mock (_rhn_git_mock); used by T-RS-RHN-15, T-RS-RHN-16
_RHN_MOCK_HEAD="0123456789abcdef0123456789abcdef01234567"
# File (under GF_TMP_ROOT) where _rhn_git_mock logs the answered git calls; used by T-RS-RHN-15, T-RS-RHN-16
_RHN_MOCK_CALL_LOG="rhn-git-calls.log"
# File (under GF_TMP_ROOT) where _rhn_git_mock logs unanswered git calls; used by T-RS-RHN-15, T-RS-RHN-16
_RHN_MOCK_UNEXPECTED_LOG="rhn-git-unexpected.log"
# Exit code of _rhn_run_mocked when the git mock was misused; no T-RS-RHN case expects it
_RHN_MOCK_MISUSED=97
# Exit code of _rsh_run when the fixture setup fails; no T-RS-RSH case expects it
_RSH_SETUP_FAILED=98
# Valid-format 40-digit hex OID absent from the fixture repository; used by T-RS-RSH-04, T-RS-RSH-07, T-RS-RSH-17, T-RS-RSH-18, T-RS-RSH-22, T-RS-RSH-25, T-RS-RSH-26, T-RS-RSH-31, T-RS-RSH-32
_RSH_OID_MISSING="0123456789abcdef0123456789abcdef01234567"
# Second absent valid-format OID, different from _RSH_OID_MISSING; used by T-RS-RSH-04, T-RS-RSH-31, T-RS-RSH-32
_RSH_OID_MISSING2="89abcdef0123456789abcdef0123456789abcdef"
# 40-digit zero OID (a push that created the branch); used by T-RS-RSH-06, T-RS-RSH-34
_RSH_OID_ZERO="0000000000000000000000000000000000000000"
# Valid 40-digit lowercase hex OID used as the before value; used by T-RS-EO-01 .. T-RS-EO-04, T-RS-EO-06 .. T-RS-EO-10, T-RS-EO-12 .. T-RS-EO-14
_EO_OID_BEFORE="0123456789abcdef0123456789abcdef01234567"
# Valid 40-digit lowercase hex OID used as the after value; used by T-RS-EO-01 .. T-RS-EO-05, T-RS-EO-07 .. T-RS-EO-14
_EO_OID_AFTER="89abcdef0123456789abcdef0123456789abcdef"
# Pre-existing line placed in the output file before emit_outputs runs; used by T-RS-EO-02
_EO_EXISTING_LINE="existing=1"
# Value containing an LF, rejected as an output value; used by T-RS-EO-05
_EO_VALUE_LF=$'a\nb'
# Value containing a lone CR, rejected as an output value; used by T-RS-EO-06
_EO_VALUE_CR=$'a\rb'
# Known resolution followed by a trailing LF, rejected before the first write; used by T-RS-EO-13
_EO_RESOLUTION_LF=$'event\n'
# Path of resolve-sha.lib.sh, sourced in a fresh bash process; used by T-RS-RLG-01 .. T-RS-RLG-04
_RLG_LIB_PATH="${SHELLSPEC_PROJECT_ROOT}/.github/actions/_ca-resolve-sha/scripts/_libs/resolve-sha.lib.sh"

# 関数
##
# Run is_partial_clone with <dir> as the working directory, in a subshell so the
# cwd never leaks between examples. The host's global / system git config is
# ignored (only inside the subshell) so the result does not depend on the host;
# the host's GIT_* environment has already been cleared by gf_setup.
# Requires: the directory has been built by a git-fixture builder.
# @arg $1 dir — directory to inspect
# @return is_partial_clone's exit code, or 99 when cd into <dir> fails
_ipc_in() {
  (
    cd "$1" || exit 99
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 is_partial_clone
  )
}

##
# Build the fixture with <builder>, then run is_partial_clone in the directory it
# built (_ipc_dir). A builder failure returns _IPC_SETUP_FAILED instead of running
# is_partial_clone, so a half-built fixture makes the example fail rather than
# pass by accident (e.g. a missing clone that also yields "not partial", 1).
# Requires: gf_setup has been called (BeforeEach).
# @arg $1 builder — one of the _ipc_build_* functions
# @return is_partial_clone's exit code, 99 when cd fails,
#         or _IPC_SETUP_FAILED (98) when the builder fails
_ipc_run() {
  "$1" || return "$_IPC_SETUP_FAILED"
  _ipc_in "$_ipc_dir"
}

##
# Build a normal (full, non-filtered) clone of a 3-commit origin; used by T-RS-IPC-01.
# Sets: _ipc_dir — the clone path. Prints nothing on stdout.
# @return 0 on success, 1 when any fixture step fails
_ipc_build_normal_clone() {
  local _ipc_origin

  _ipc_origin="$(gf_linear_repo origin 3)" || return 1
  _ipc_dir="${GF_TMP_ROOT}/clone"
  gf_git "$_ipc_origin" clone -q "file://${_ipc_origin}" "$_ipc_dir" || return 1
}

##
# Build a depth-2 shallow clone of a 3-commit origin; used by T-RS-IPC-02.
# Sets: _ipc_dir — the clone path. Prints nothing on stdout.
# @return 0 on success, 1 when any fixture step fails
_ipc_build_shallow_clone() {
  local _ipc_origin

  _ipc_origin="$(gf_linear_repo origin 3)" || return 1
  _ipc_dir="$(gf_shallow_clone "$_ipc_origin" shallow 2)" || return 1
}

##
# Build a --filter=blob:none partial clone (promisor remote) of a 3-commit origin;
# used by T-RS-IPC-03.
# Sets: _ipc_dir — the clone path. Prints nothing on stdout.
# @return 0 on success, 1 when any fixture step fails
_ipc_build_partial_clone() {
  local _ipc_origin

  _ipc_origin="$(gf_linear_repo origin 3)" || return 1
  _ipc_dir="$(gf_partial_clone "$_ipc_origin" partial)" || return 1
}

##
# Build a 1-commit repository whose .git/config is unparsable; used by
# T-RS-IPC-04, T-RS-IPC-05.
# Sets: _ipc_dir — the repository path. Prints nothing on stdout.
# @return 0 on success, 1 when any fixture step fails
_ipc_build_broken_config() {
  _ipc_dir="$(gf_linear_repo broken 1)" || return 1
  gf_break_config "$_ipc_dir" || return 1
}

##
# Build a normal clone that only has extensions.partialClone set (no promisor
# remote); used by T-RS-IPC-06.
# Sets: _ipc_dir — the clone path. Prints nothing on stdout.
# @return 0 on success, 1 when any fixture step fails
_ipc_build_extensions_only() {
  _ipc_build_normal_clone || return 1
  gf_git "$_ipc_dir" config extensions.partialClone origin || return 1
}

##
# Build a normal clone whose only promisor key is on a remote not named origin
# (remote.upstream.promisor=true); used by T-RS-IPC-08.
# Sets: _ipc_dir — the clone path. Prints nothing on stdout.
# @return 0 on success, 1 when any fixture step fails
_ipc_build_upstream_promisor() {
  _ipc_build_normal_clone || return 1
  gf_git "$_ipc_dir" config remote.upstream.promisor true || return 1
}

##
# Build a normal clone whose only promisor-like key is a different key that
# merely starts with "promisor" (remote.origin.promisorx=true); used by T-RS-IPC-09.
# Sets: _ipc_dir — the clone path. Prints nothing on stdout.
# @return 0 on success, 1 when any fixture step fails
_ipc_build_near_miss_key() {
  _ipc_build_normal_clone || return 1
  gf_git "$_ipc_dir" config remote.origin.promisorx true || return 1
}

##
# Build a plain directory outside any git repository; used by T-RS-IPC-07.
# Sets: _ipc_dir — the directory path. Prints nothing on stdout.
# @return 0 on success, 1 when the directory cannot be created or is inside a repo
_ipc_build_non_git_dir() {
  _ipc_dir="$(gf_non_git_dir plain)" || return 1
}

##
# Build a normal clone (as T-RS-IPC-01) whose .git/config has mode 000, so git
# cannot read it; used by T-RS-IPC-10. The temp root stays writable, so
# gf_cleanup can still remove the unreadable file.
# Sets: _ipc_dir — the clone path. Prints nothing on stdout.
# @return 0 on success, 1 when any fixture step fails
_ipc_build_unreadable_config() {
  _ipc_build_normal_clone || return 1
  chmod 000 "$_ipc_dir/.git/config" || return 1
}

##
# Decide whether an unreadable file cannot be reproduced where the fixtures live;
# used by T-RS-IPC-10 (Skip if). A probe file is created under GF_TMP_ROOT (the
# filesystem _ipc_build_unreadable_config uses), set to mode 000 and checked for
# readability. It stays readable when permissions are not enforced: as root, on
# NTFS under Git Bash, or on drvfs mounted without metadata. The probe is removed
# afterwards. ShellSpec evaluates `Skip if` after BeforeEach, so GF_TMP_ROOT exists.
# Requires: gf_setup has been called (BeforeEach).
# @return 0 (skip) when the mode-000 probe is still readable,
#         1 when permissions are enforced or the probe cannot be created
#         (the example then runs and reports the fixture problem itself)
_ipc_cannot_enforce_unreadable() {
  local _ipc_probe="${GF_TMP_ROOT}/ipc-unreadable-probe"
  local _ipc_readable=1

  : >"$_ipc_probe" || return 1
  chmod 000 "$_ipc_probe" && [ -r "$_ipc_probe" ] && _ipc_readable=0
  rm -f "$_ipc_probe"
  return "$_ipc_readable"
}

##
# Run is_commit <sha> with <dir> as the working directory, in a subshell so the
# cwd never leaks between examples. The host's global / system git config is
# ignored (only inside the subshell) so the result does not depend on the host;
# the host's GIT_* environment has already been cleared by gf_setup.
# Requires: the directory has been built by _ic_build_repo or gf_non_git_dir.
# @arg $1 dir — directory to inspect (a repository, or a non-git directory)
# @arg $2 sha — value passed to is_commit
# @return is_commit's exit code, or 99 when cd into <dir> fails
_ic_in() {
  (
    cd "$1" || exit 99
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 is_commit "$2"
  )
}

##
# Build a 2-commit linear repository; used by T-RS-IC-01 .. T-RS-IC-06.
# Sets: _ic_dir — the repository path, _ic_head — its HEAD commit OID.
# Prints nothing on stdout.
# @return 0 on success, 1 when any fixture step fails
_ic_build_repo() {
  _ic_dir="$(gf_linear_repo ic 2)" || return 1
  _ic_head="$(gf_git "$_ic_dir" rev-parse HEAD)" || return 1
}

##
# Build the repository with _ic_build_repo, then run is_commit on its HEAD OID
# (only known after the build, so it is resolved inside `When`). A builder
# failure returns _IC_SETUP_FAILED instead of running is_commit.
# Requires: gf_setup has been called (BeforeEach).
# @stderr a setup-failure message when the builder fails (every IC case expects empty stderr)
# @return is_commit's exit code, 99 when cd fails,
#         or _IC_SETUP_FAILED (98) when the builder fails
_ic_run_head() {
  _ic_build_repo || _ic_setup_failed || return
  _ic_in "$_ic_dir" "$_ic_head"
}

##
# Build the repository with _ic_build_repo, then run is_commit <sha> in it.
# A builder failure returns _IC_SETUP_FAILED instead of running is_commit and
# writes a message to stderr. IC error cases only expect a non-zero status, so
# the stderr message is what keeps a fixture failure from passing them.
# Requires: gf_setup has been called (BeforeEach).
# @arg $1 sha — value passed to is_commit (may be empty)
# @stderr a setup-failure message when the builder fails (every IC case expects empty stderr)
# @return is_commit's exit code, 99 when cd fails,
#         or _IC_SETUP_FAILED (98) when the builder fails
_ic_run() {
  _ic_build_repo || _ic_setup_failed || return
  _ic_in "$_ic_dir" "$1"
}

##
# Build the repository with _ic_build_repo, then run is_commit on its HEAD tree
# OID (HEAD^{tree}, only known after the build, so it is resolved inside `When`).
# A builder or rev-parse failure returns _IC_SETUP_FAILED instead of running
# is_commit. Used by T-RS-IC-06.
# Requires: gf_setup has been called (BeforeEach).
# Sets: _ic_tree — the HEAD tree OID.
# @stderr a setup-failure message when the setup fails (every IC case expects empty stderr)
# @return is_commit's exit code, 99 when cd fails,
#         or _IC_SETUP_FAILED (98) when the setup fails
_ic_run_tree() {
  _ic_build_repo || _ic_setup_failed || return
  _ic_tree="$(gf_git "$_ic_dir" rev-parse 'HEAD^{tree}')" || _ic_setup_failed || return
  _ic_in "$_ic_dir" "$_ic_tree"
}

##
# Create a non-git directory with gf_non_git_dir, then run is_commit <sha> with
# it as the working directory. A fixture failure returns _IC_SETUP_FAILED
# instead of running is_commit. Used by T-RS-IC-07.
# Requires: gf_setup has been called (BeforeEach).
# Sets: _ic_dir — the non-git directory path.
# @arg $1 sha — value passed to is_commit
# @stderr a setup-failure message when the setup fails (every IC case expects empty stderr)
# @return is_commit's exit code, 99 when cd fails,
#         or _IC_SETUP_FAILED (98) when the setup fails
_ic_run_non_git() {
  _ic_dir="$(gf_non_git_dir ic-plain)" || _ic_setup_failed || return
  _ic_in "$_ic_dir" "$1"
}

##
# Report a fixture setup failure for the IC wrappers.
# @stderr "is_commit fixture setup failed"
# @return _IC_SETUP_FAILED (98)
_ic_setup_failed() {
  echo "is_commit fixture setup failed" >&2
  return "$_IC_SETUP_FAILED"
}

##
# Run verify_commit <sha> <field> with <dir> as the working directory, in a
# subshell so the cwd never leaks between examples. The host's global / system
# git config is ignored (only inside the subshell) so the result does not depend
# on the host; the host's GIT_* environment has already been cleared by gf_setup.
# Requires: the directory has been built by _vc_build_repo.
# @arg $1 dir   — repository directory to inspect
# @arg $2 sha   — value passed to verify_commit
# @arg $3 field — error target name passed to verify_commit
# @return verify_commit's exit code, or 99 when cd into <dir> fails
_vc_in() {
  (
    cd "$1" || exit 99
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 verify_commit "$2" "$3"
  )
}

##
# Build a 2-commit linear repository; used by T-RS-VC-01 .. T-RS-VC-06.
# Sets: _vc_dir — the repository path, _vc_head — its HEAD commit OID.
# Prints nothing on stdout.
# @return 0 on success, 1 when any fixture step fails
_vc_build_repo() {
  _vc_dir="$(gf_linear_repo vc 2)" || return 1
  _vc_head="$(gf_git "$_vc_dir" rev-parse HEAD)" || return 1
}

##
# Build the repository with _vc_build_repo, then run verify_commit <sha> <field>
# inside it; used by T-RS-VC-02 .. T-RS-VC-06. A builder failure returns
# _VC_SETUP_FAILED instead of running verify_commit.
# Requires: gf_setup has been called (BeforeEach).
# @arg $1 sha   — value passed to verify_commit
# @arg $2 field — error target name passed to verify_commit
# @stderr a setup-failure message when the builder fails
# @return verify_commit's exit code, 99 when cd fails,
#         or _VC_SETUP_FAILED (98) when the builder fails
_vc_run() {
  _vc_build_repo || _vc_setup_failed || return
  _vc_in "$_vc_dir" "$1" "$2"
}

##
# Build the repository with _vc_build_repo, then run verify_commit on its HEAD
# OID (only known after the build, so it is resolved inside `When`). A builder
# failure returns _VC_SETUP_FAILED instead of running verify_commit.
# Requires: gf_setup has been called (BeforeEach).
# @arg $1 field — error target name passed to verify_commit
# @stderr a setup-failure message when the builder fails
# @return verify_commit's exit code, 99 when cd fails,
#         or _VC_SETUP_FAILED (98) when the builder fails
_vc_run_head() {
  _vc_build_repo || _vc_setup_failed || return
  _vc_in "$_vc_dir" "$_vc_head" "$1"
}

##
# Report a fixture setup failure for _vc_run / _vc_run_head; used by T-RS-VC-01 .. T-RS-VC-06.
# @stderr "verify_commit fixture setup failed"
# @return _VC_SETUP_FAILED (98)
_vc_setup_failed() {
  echo "verify_commit fixture setup failed" >&2
  return "$_VC_SETUP_FAILED"
}

##
# Run resolve_head_n <n> with <dir> as the working directory, in a subshell so
# the cwd never leaks between examples. The host's global / system git config is
# ignored (only inside the subshell) so the result does not depend on the host;
# the host's GIT_* environment has already been cleared by gf_setup.
# Requires: the directory has been built by an _rhn_build_* builder.
# @arg $1 dir — directory to run resolve_head_n in
# @arg $2 n   — commit count passed to resolve_head_n
# @return resolve_head_n's exit code, or 99 when cd into <dir> fails
_rhn_in() {
  (
    cd "$1" || exit 99
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 resolve_head_n "$2"
  )
}

##
# Build the fixture with <builder> [args...], then run resolve_head_n <n> in the
# directory it built (_rhn_dir); used by T-RS-RHN-01 .. T-RS-RHN-14. It is called
# by `When call` (no subshell), so the expected OIDs the builder sets
# (_rhn_head / _rhn_before) are visible to the assertions that follow. The
# variables are reset first so a half-run builder cannot leave stale values.
# A builder failure returns _RHN_SETUP_FAILED instead of running resolve_head_n.
# Requires: gf_setup has been called (BeforeEach).
# Sets: _rhn_dir, _rhn_head, _rhn_before (through the builder).
# @arg $1 n       — commit count passed to resolve_head_n
# @arg $2 builder — one of the _rhn_build_* functions
# @arg $3.. args  — arguments passed to <builder>
# @stderr a setup-failure message when the builder fails
# @return resolve_head_n's exit code, 99 when cd fails,
#         or _RHN_SETUP_FAILED (98) when the builder fails
_rhn_run() {
  _rhn_dir='' _rhn_head='' _rhn_before=''
  "$2" "${@:3}" || _rhn_setup_failed || return
  _rhn_in "$_rhn_dir" "$1"
}

##
# Report a fixture setup failure for _rhn_run / _rhn_run_untrusted; used by
# T-RS-RHN-01 .. T-RS-RHN-14, T-RS-RHN-17.
# @stderr "resolve_head_n fixture setup failed"
# @return _RHN_SETUP_FAILED (98)
_rhn_setup_failed() {
  echo "resolve_head_n fixture setup failed" >&2
  return "$_RHN_SETUP_FAILED"
}

##
# Same as _rhn_run, but resolve_head_n runs with GIT_TEST_ASSUME_DIFFERENT_OWNER=1
# so git treats the work directory as owned by another user ("detected dubious
# ownership"); used by T-RS-RHN-17. The variable is exported only inside a
# subshell around the resolve_head_n call (after the builder ran, since gf_setup
# clears GIT_* and the builder's own git calls must not be affected), so it
# never leaks into other examples.
# Requires: gf_setup has been called (BeforeEach).
# Sets: _rhn_dir, _rhn_head, _rhn_before (through the builder).
# @arg $1 n       — commit count passed to resolve_head_n
# @arg $2 builder — one of the _rhn_build_* functions
# @arg $3.. args  — arguments passed to <builder>
# @stderr a setup-failure message when the builder fails
# @return resolve_head_n's exit code, 99 when cd fails,
#         or _RHN_SETUP_FAILED (98) when the builder fails
_rhn_run_untrusted() {
  _rhn_dir='' _rhn_head='' _rhn_before=''
  "$2" "${@:3}" || _rhn_setup_failed || return
  (
    export GIT_TEST_ASSUME_DIFFERENT_OWNER=1
    _rhn_in "$_rhn_dir" "$1"
  )
}

##
# Stand-in for git used by _rhn_run_mocked; used by T-RS-RHN-15, T-RS-RHN-16.
# The whole argument list is matched exactly, so a changed option or OID never
# hits an answered arm. Only the calls resolve_head_n makes are answered:
#   rev-parse --verify -q HEAD^{commit}
#       -> prints _RHN_MOCK_HEAD, returns 0
#   rev-parse --verify -q _RHN_MOCK_HEAD~<n>^{commit}
#       -> prints nothing, returns 1 (HEAD~N does not resolve)
#   rev-list --first-parent --count _RHN_MOCK_HEAD
#       -> prints _rhn_mock_count, returns 0
#   anything else
#       -> prints nothing, returns 1, and appends the call to the unexpected log
# Every answered call is appended to the call log. The logs are files, because
# resolve_head_n discards git's stderr and runs git in command substitutions.
# Requires: _rhn_mock_n / _rhn_mock_count have been set by _rhn_run_mocked;
#           gf_setup has been called (the logs live under GF_TMP_ROOT).
# @arg $@ — git arguments
# @stdout the mocked git output described above
# @return the mocked git exit code described above
_rhn_git_mock() {
  case "$*" in
  "rev-parse --verify -q HEAD^{commit}")
    printf '%s\n' "$_RHN_MOCK_HEAD"
    ;;
  "rev-parse --verify -q ${_RHN_MOCK_HEAD}~${_rhn_mock_n}^{commit}")
    printf '%s\n' "$*" >>"${GF_TMP_ROOT}/${_RHN_MOCK_CALL_LOG}"
    return 1
    ;;
  "rev-list --first-parent --count $_RHN_MOCK_HEAD")
    printf '%s\n' "$_rhn_mock_count"
    ;;
  *)
    printf '%s\n' "$*" >>"${GF_TMP_ROOT}/${_RHN_MOCK_UNEXPECTED_LOG}"
    return 1
    ;;
  esac
  printf '%s\n' "$*" >>"${GF_TMP_ROOT}/${_RHN_MOCK_CALL_LOG}"
}

##
# Run resolve_head_n <n> with git replaced by _rhn_git_mock, whose first-parent
# count prints <count>; used by T-RS-RHN-15, T-RS-RHN-16. The git function and
# the _rhn_mock_* variables are defined only inside a subshell whose cwd is
# GF_TMP_ROOT, so the mock never leaks into the assertions or other examples,
# and a git call that bypasses the mock cannot touch the project checkout.
# After the run, the mock logs are checked (_rhn_check_mock_calls): an
# unexpected git call, or a missing first-parent count call, adds a stderr line
# and returns _RHN_MOCK_MISUSED, so the examples' one-line stderr check fails
# instead of passing through the wrong branch (R-RES-013 prints the same prefix).
# Requires: gf_setup has been called (BeforeEach).
# @arg $1 n     — commit count passed to resolve_head_n
# @arg $2 count — output of the mocked `git rev-list --first-parent --count`
# @stderr resolve_head_n's stderr, then a mock-misuse message when the check fails
# @return resolve_head_n's exit code, 99 when cd into GF_TMP_ROOT fails,
#         or _RHN_MOCK_MISUSED (97) when the mock check fails
_rhn_run_mocked() {
  local _rhn_status

  (
    cd "$GF_TMP_ROOT" || exit 99
    _rhn_mock_n="$1"
    _rhn_mock_count="$2"
    git() { _rhn_git_mock "$@"; }
    resolve_head_n "$1"
  )
  _rhn_status=$?
  _rhn_check_mock_calls || return
  return "$_rhn_status"
}

##
# Check the logs written by _rhn_git_mock; used by _rhn_run_mocked.
# Fails when any unexpected git call was logged, or when the first-parent count
# call (`rev-list --first-parent --count _RHN_MOCK_HEAD`) was never made.
# Requires: gf_setup has been called (the logs live under GF_TMP_ROOT).
# @stderr "unexpected git call: <args>" per unexpected call, or
#         "git first-parent count was not called"
# @return 0 when the mock was used as expected, _RHN_MOCK_MISUSED (97) otherwise
_rhn_check_mock_calls() {
  local _rhn_unexpected="${GF_TMP_ROOT}/${_RHN_MOCK_UNEXPECTED_LOG}"

  if [ -s "$_rhn_unexpected" ]; then
    sed 's/^/unexpected git call: /' "$_rhn_unexpected" >&2
    return "$_RHN_MOCK_MISUSED"
  fi
  if ! grep -Fqx "rev-list --first-parent --count $_RHN_MOCK_HEAD" \
    "${GF_TMP_ROOT}/${_RHN_MOCK_CALL_LOG}" 2>/dev/null; then
    echo "git first-parent count was not called" >&2
    return "$_RHN_MOCK_MISUSED"
  fi
}

##
# Build a <count>-commit linear repository; used by T-RS-RHN-01, T-RS-RHN-02,
# T-RS-RHN-04, T-RS-RHN-08, T-RS-RHN-09, T-RS-RHN-10, T-RS-RHN-17.
# Sets: _rhn_dir — the repository path, _rhn_head — its HEAD commit OID,
#       _rhn_before — the commit OID of <rev> (only when <rev> is given).
# Prints nothing on stdout.
# @arg $1 count — number of commits
# @arg $2 rev   — optional revision whose commit OID is the expected before
# @return 0 on success, 1 when any fixture step fails
_rhn_build_linear() {
  _rhn_dir="$(gf_linear_repo rhn "$1")" || return 1
  _rhn_head="$(gf_git "$_rhn_dir" rev-parse HEAD)" || return 1
  if [[ -n "${2:-}" ]]; then
    _rhn_before="$(gf_git "$_rhn_dir" rev-parse --verify "${2}^{commit}")" || return 1
  fi
}

##
# Build a repository whose HEAD is a --no-ff merge of a 2-commit side branch into
# a 3-commit main branch; used by T-RS-RHN-03.
# Sets: _rhn_dir — the repository path, _rhn_head — its HEAD (merge) commit OID,
#       _rhn_before — the first parent HEAD^1 (P1, the last main commit).
# Prints nothing on stdout.
# @return 0 on success, 1 when any fixture step fails
_rhn_build_merge() {
  _rhn_dir="$(gf_merge_repo rhn 3 2)" || return 1
  _rhn_head="$(gf_git "$_rhn_dir" rev-parse HEAD)" || return 1
  _rhn_before="$(gf_git "$_rhn_dir" rev-parse HEAD^1)" || return 1
}

##
# Build a plain directory outside any git repository; used by T-RS-RHN-05.
# Sets: _rhn_dir — the directory path.
# Prints nothing on stdout.
# @return 0 on success, 1 when the fixture step fails
_rhn_build_non_git() {
  _rhn_dir="$(gf_non_git_dir rhn)" || return 1
}

##
# Build a repository right after `git init`, with no commits (HEAD is unborn);
# used by T-RS-RHN-06.
# Sets: _rhn_dir — the repository path.
# Prints nothing on stdout.
# @return 0 on success, 1 when the fixture step fails
_rhn_build_empty() {
  _rhn_dir="$(gf_init_repo rhn)" || return 1
}

##
# Build a 5-commit linear repository whose HEAD~2 loose object is removed;
# used by T-RS-RHN-07. With N=3, step 2 must read HEAD~2 to reach HEAD~3, so
# HEAD~N cannot be resolved although HEAD (and a history longer than N) exists;
# the first-parent count fails on the same missing object (R-RES-013).
# Sets: _rhn_dir — the repository path.
# Prints nothing on stdout.
# @return 0 on success, 1 when any fixture step fails
_rhn_build_missing_ancestor() {
  local _oid
  _rhn_dir="$(gf_linear_repo rhn 5)" || return 1
  _oid="$(gf_git "$_rhn_dir" rev-parse HEAD~2)" || return 1
  gf_remove_object "$_rhn_dir" "$_oid" || return 1
}

##
# Build a <depth>-deep shallow clone (file://) of a 5-commit linear origin; used
# by T-RS-RHN-11, T-RS-RHN-12. The clone holds HEAD .. HEAD~(<depth>-1), and its
# oldest commit is the shallow boundary (the origin history continues past it).
# Sets: _rhn_dir — the clone path, _rhn_head — the clone's HEAD commit OID,
#       _rhn_before — the commit OID of <rev> read from the full origin (only
#       when <rev> is given).
# Prints nothing on stdout.
# @arg $1 depth — clone depth
# @arg $2 rev   — optional revision whose origin commit OID is the expected before
# @return 0 on success, 1 when any fixture step fails
_rhn_build_shallow() {
  local _origin
  _origin="$(gf_linear_repo rhn-origin 5)" || return 1
  _rhn_dir="$(gf_shallow_clone "$_origin" rhn "$1")" || return 1
  _rhn_head="$(gf_git "$_rhn_dir" rev-parse HEAD)" || return 1
  if [[ -n "${2:-}" ]]; then
    _rhn_before="$(gf_git "$_origin" rev-parse --verify "${2}^{commit}")" || return 1
  fi
}

##
# Build a <depth>-deep shallow clone (file://) of an origin whose HEAD is a
# --no-ff merge of a <side>-commit side branch into a <main>-commit main branch;
# used by T-RS-RHN-13, T-RS-RHN-14. Both parent chains of the merge are cut at
# <depth> generations, so which chain hits the shallow boundary first depends on
# the arguments: with 3 3 2 the first-parent chain (main-3) is the boundary; with
# 2 4 3 the first-parent chain reaches the root (history end) and only the
# second-parent chain (side-3) is the boundary.
# Sets: _rhn_dir — the clone path, _rhn_head — the clone's HEAD (merge) OID,
#       _rhn_before — the commit OID of <rev> read from the full origin (only
#       when <rev> is given).
# Prints nothing on stdout.
# @arg $1 main  — number of main-branch commits (including the root)
# @arg $2 side  — number of side-branch commits
# @arg $3 depth — clone depth
# @arg $4 rev   — optional revision whose origin commit OID is the expected before
# @return 0 on success, 1 when any fixture step fails
_rhn_build_merge_shallow() {
  local _origin
  _origin="$(gf_merge_repo rhn-origin "$1" "$2")" || return 1
  _rhn_dir="$(gf_shallow_clone "$_origin" rhn "$3")" || return 1
  _rhn_head="$(gf_git "$_rhn_dir" rev-parse HEAD)" || return 1
  if [[ -n "${4:-}" ]]; then
    _rhn_before="$(gf_git "$_origin" rev-parse --verify "${4}^{commit}")" || return 1
  fi
}

##
# Run resolve_sha [args...] with <dir> as the working directory, in a subshell
# so the cwd never leaks between examples. The host's global / system git config
# is ignored (only inside the subshell) so the result does not depend on the
# host; the host's GIT_* environment has already been cleared by gf_setup.
# Requires: the directory has been built by an _rsh_build_* builder.
# @arg $1 dir     — directory to run resolve_sha in
# @arg $2.. args  — arguments passed to resolve_sha
# @return resolve_sha's exit code, or 99 when cd into <dir> fails
_rsh_in() {
  (
    cd "$1" || exit 99
    shift
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 resolve_sha "$@"
  )
}

##
# Build the fixture with <builder> [builder-args...], then run resolve_sha with
# the arguments after "--" in the directory it built (_rsh_dir); used by
# T-RS-RSH-01 .. T-RS-RSH-34. Each argument of the form "@<rev>" is replaced by the commit OID
# of <rev> in _rsh_dir before the call. It is called by `When call` (no
# subshell), so _rsh_dir is visible to the assertions that follow (_rsh_oid).
# _rsh_dir is reset first so a half-run builder cannot leave a stale value.
# A builder or "@<rev>" resolution failure returns _RSH_SETUP_FAILED instead of
# running resolve_sha.
# Requires: gf_setup has been called (BeforeEach).
# Sets: _rsh_dir (through the builder).
# @arg $1 builder       — one of the _rsh_build_* functions
# @arg $2.. builder-args — arguments passed to <builder>, terminated by "--"
# @arg ... args          — arguments passed to resolve_sha ("@<rev>" resolved)
# @stderr a setup-failure message when the fixture setup fails
# @return resolve_sha's exit code, 99 when cd fails,
#         or _RSH_SETUP_FAILED (98) when the fixture setup fails
_rsh_run() {
  local _rsh_builder="$1" _rsh_arg
  local -a _rsh_builder_args=() _rsh_args=()
  shift
  while [[ "$#" -gt 0 && "$1" != "--" ]]; do
    _rsh_builder_args+=("$1")
    shift
  done
  shift
  _rsh_dir=''
  "$_rsh_builder" "${_rsh_builder_args[@]}" || _rsh_setup_failed || return
  for _rsh_arg in "$@"; do
    if [[ "$_rsh_arg" == @* ]]; then
      _rsh_arg="$(_rsh_oid "${_rsh_arg#@}")" || _rsh_setup_failed || return
    fi
    _rsh_args+=("$_rsh_arg")
  done
  _rsh_in "$_rsh_dir" "${_rsh_args[@]}"
}

##
# Report a fixture setup failure for _rsh_run; used by T-RS-RSH-01 .. T-RS-RSH-34.
# @stderr "resolve_sha fixture setup failed"
# @return _RSH_SETUP_FAILED (98)
_rsh_setup_failed() {
  echo "resolve_sha fixture setup failed" >&2
  return "$_RSH_SETUP_FAILED"
}

##
# Print the commit OID of <rev> in the fixture repository (_rsh_dir); used by
# _rsh_run to resolve "@<rev>" arguments and by the T-RS-RSH-01 .. T-RS-RSH-08,
# T-RS-RSH-27 .. T-RS-RSH-30, T-RS-RSH-33, T-RS-RSH-34 assertions to build the expected output.
# Requires: _rsh_dir has been set by an _rsh_build_* builder.
# @arg $1 rev — revision to resolve
# @stdout the commit OID as one line
# @return 0 on success, non-zero when <rev> does not resolve to a commit
_rsh_oid() {
  gf_git "$_rsh_dir" rev-parse --verify "${1}^{commit}"
}

##
# Build a <count>-commit linear repository; used by T-RS-RSH-01 .. T-RS-RSH-13, T-RS-RSH-17 .. T-RS-RSH-34.
# Sets: _rsh_dir — the repository path. Prints nothing on stdout.
# @arg $1 count — number of commits
# @return 0 on success, 1 when the fixture step fails
_rsh_build_linear() {
  _rsh_dir="$(gf_linear_repo rsh "$1")" || return 1
}

##
# Build a --filter=blob:none partial clone (promisor remote) of a <count>-commit
# linear origin; used by T-RS-RSH-14, T-RS-RSH-15. "@<rev>" arguments are resolved in the
# clone, whose commits are identical to the origin's.
# Sets: _rsh_dir — the clone path. Prints nothing on stdout.
# @arg $1 count — number of commits in the origin
# @return 0 on success, 1 when any fixture step fails
_rsh_build_partial() {
  local _rsh_origin

  _rsh_origin="$(gf_linear_repo origin "$1")" || return 1
  _rsh_dir="$(gf_partial_clone "$_rsh_origin" partial)" || return 1
}

##
# Build a <count>-commit linear repository whose .git/config is unparsable
# (is_partial_clone returns 2); used by T-RS-RSH-16. No "@<rev>" argument can
# be resolved in it.
# Sets: _rsh_dir — the repository path. Prints nothing on stdout.
# @arg $1 count — number of commits
# @return 0 on success, 1 when any fixture step fails
_rsh_build_broken() {
  _rsh_dir="$(gf_linear_repo rsh "$1")" || return 1
  gf_break_config "$_rsh_dir" || return 1
}

##
# Create a per-example GF_TMP_ROOT and an empty output file in it; used as the
# BeforeEach of the emit_outputs group (T-RS-EO-01 .. T-RS-EO-14).
# Sets: _eo_file — the empty output file path (${GF_TMP_ROOT}/github_output).
# @return 0 on success, 1 when gf_setup fails
_eo_setup() {
  gf_setup || return 1
  _eo_file="${GF_TMP_ROOT}/github_output"
  : >"$_eo_file"
}

##
# Pre-fill <file> with the single line _EO_EXISTING_LINE, then run emit_outputs
# with all the arguments; used by T-RS-EO-02.
# Requires: _eo_setup has run (the directory of <file> exists).
# @arg $1 file       — output file path
# @arg $2 before     — before value
# @arg $3 after      — after value
# @arg $4 resolution — resolution value
# @return emit_outputs's exit code
_eo_run_with_existing() {
  printf '%s\n' "$_EO_EXISTING_LINE" >"$1"
  emit_outputs "$@"
}

##
# Replace write_output with a stub whose 2nd call returns 2 (a write failure)
# while calls 1 and 3+ really append "<key>=<value>" to <file>, then run
# emit_outputs with all the arguments; used by T-RS-EO-08.
# The override stays in effect for the rest of the example (When call runs in
# the example's subshell, so it never leaks into other examples).
# Sets: _eo_wo_calls — the number of write_output calls so far.
# @arg $1 file       — output file path
# @arg $2 before     — before value
# @arg $3 after      — after value
# @arg $4 resolution — resolution value
# @return emit_outputs's exit code
_eo_run_failing_second_write() {
  _eo_wo_calls=0
  write_output() {
    _eo_wo_calls=$((_eo_wo_calls + 1))
    [[ "$_eo_wo_calls" -eq 2 ]] && return 2
    printf '%s=%s\n' "$2" "$3" >>"$1"
  }
  emit_outputs "$@"
}

##
# Source resolve-sha.lib.sh in a fresh bash process and print the observable
# state; used by the load guard group (T-RS-RLG-01, T-RS-RLG-04).
# The spec shell has already loaded the library via Include, so the source runs
# in a new process with RESOLVE_SHA_LIB_LOADED, VALIDATION_LIB_LOADED and
# OUTPUT_LIB_LOADED unset; if $1 is given, RESOLVE_SHA_LIB_LOADED is preset to it.
# @arg $1 preset — optional value assigned to RESOLVE_SHA_LIB_LOADED before sourcing
# @stdout one per line:
#         "loaded=<RESOLVE_SHA_LIB_LOADED>",
#         "rs_error=<defined|undefined>",
#         "validate_positive_int=<defined|undefined>",
#         "normalize_commit_count=<defined|undefined>",
#         "source_status=<exit status of the source>"
# @return exit status of the fresh bash process
_rlg_source_lib_in_fresh_shell() {
  bash -c '
    unset RESOLVE_SHA_LIB_LOADED VALIDATION_LIB_LOADED OUTPUT_LIB_LOADED
    [ "$#" -ge 2 ] && RESOLVE_SHA_LIB_LOADED="$2"
    . "$1"
    _source_status=$?
    echo "loaded=${RESOLVE_SHA_LIB_LOADED:-}"
    for _fn in rs_error validate_positive_int normalize_commit_count; do
      if declare -F "$_fn" >/dev/null; then
        echo "${_fn}=defined"
      else
        echo "${_fn}=undefined"
      fi
    done
    echo "source_status=${_source_status}"
  ' _ "$_RLG_LIB_PATH" "$@"
}

##
# Source resolve-sha.lib.sh twice in a fresh bash process; used by the load guard
# group (T-RS-RLG-02). RESOLVE_SHA_LIB_LOADED, VALIDATION_LIB_LOADED and
# OUTPUT_LIB_LOADED are unset first, so the first source loads the library and
# the second one hits the guard.
# @stdout nothing
# @stderr whatever either source writes to stderr
# @return exit status of the second source
_rlg_resource_lib_in_fresh_shell() {
  bash -c '
    unset RESOLVE_SHA_LIB_LOADED VALIDATION_LIB_LOADED OUTPUT_LIB_LOADED
    . "$1"
    . "$1"
  ' _ "$_RLG_LIB_PATH"
}

##
# Copy resolve-sha.lib.sh alone into GF_TMP_ROOT and source the copy in a fresh
# bash process; used by the load guard group (T-RS-RLG-03).
# The copy lives at ${GF_TMP_ROOT}/action/scripts/_libs/, so its relative path
# ../../../_libs/validation.lib.sh resolves to ${GF_TMP_ROOT}/_libs/, which does
# not exist (neither does output.lib.sh). RESOLVE_SHA_LIB_LOADED,
# VALIDATION_LIB_LOADED and OUTPUT_LIB_LOADED are unset before sourcing.
# Requires: gf_setup has been called (BeforeEach).
# @stdout whatever the source writes to stdout
# @stderr whatever the source writes to stderr
# @return exit status of the source of the copy
_rlg_source_isolated_copy() {
  local _copy_dir="${GF_TMP_ROOT}/action/scripts/_libs"
  mkdir -p "$_copy_dir" || return 1
  cp "$_RLG_LIB_PATH" "${_copy_dir}/resolve-sha.lib.sh" || return 1
  bash -c '
    unset RESOLVE_SHA_LIB_LOADED VALIDATION_LIB_LOADED OUTPUT_LIB_LOADED
    . "$1"
  ' _ "${_copy_dir}/resolve-sha.lib.sh"
}

# --- テスト本体 ---

##
# resolve-sha.lib.sh: helper functions for the _ca-resolve-sha composite action.
# Assigned test IDs: T-RS-RE-01 .. T-RS-RE-09, T-RS-NCC-01 .. T-RS-NCC-09,
#                    T-RS-VOV-01 .. T-RS-VOV-16, T-RS-IPC-01 .. T-RS-IPC-10,
#                    T-RS-IC-01 .. T-RS-IC-07, T-RS-VC-01 .. T-RS-VC-06,
#                    T-RS-RHN-01 .. T-RS-RHN-17, T-RS-RSH-01 .. T-RS-RSH-34,
#                    T-RS-EO-01 .. T-RS-EO-14, T-RS-RLG-01 .. T-RS-RLG-04
Describe 'resolve-sha.lib.sh'
  ##
  # rs_error: emit one "::error::" annotation line to stderr, in the normal form
  # "::error::<target>: <problem> (got: '<value>')" or, when the value is omitted,
  # the empty form "::error::<target>: value must not be empty".
  # Scenarios: the normal form is written to stderr only (stdout stays empty);
  #            an explicitly passed empty value still uses the normal form;
  #            an omitted value uses the empty form;
  #            a value carrying LF cannot inject a workflow command line;
  #            "%", CR and LF in the value become "%25", "%0D" and "%0A",
  #            with "%" encoded first.
  Describe 'rs_error'
    # 正常系: the normal form (value passed) and the empty form (value omitted)
    Context 'When: 正常系'
      It '[Normal] T-RS-RE-01: 通常の形式で stderr に 1 行出す'
        When call rs_error commit-count invalid 0
        The status should equal 0
        The stderr should equal "::error::commit-count: invalid (got: '0')"
        The lines of stderr should equal 1
      End

      It '[Normal] T-RS-RE-02: stdout には何も出さない'
        When call rs_error commit-count invalid 0
        The status should equal 0
        The stdout should equal ''
        The stderr should be present
      End

      It '[Normal] T-RS-RE-03: 空文字列の値は通常の形式で出す'
        When call rs_error after-sha "one side only" ""
        The status should equal 0
        The stderr should start with "::error::after-sha: one side only"
        The stderr should end with "(got: '')"
        The lines of stderr should equal 1
      End

      It '[Normal] T-RS-RE-04: 値を省略すると空の形式で出す'
        When call rs_error GITHUB_EVENT_NAME empty
        The status should equal 0
        The stderr should equal "::error::GITHUB_EVENT_NAME: value must not be empty"
        The lines of stderr should equal 1
      End
    End

    # 異常系: values that try to inject a workflow command into the log
    Context 'When: 異常系'
      It '[Error] T-RS-RE-05: LF とコマンドを含む値を 1 行に収める'
        When call rs_error before-sha bad "$_RE_INJECTED_VALUE"
        The status should equal 0
        The lines of stderr should equal 1
        The stderr should not include "${SHELLSPEC_LF}::add-mask::"
        The stderr should include "(got: 'x%0A::add-mask::secret')"
      End
    End

    # エッジケース: how "%", CR and LF in the value are encoded
    Context 'When: エッジケース'
      It '[Edge] T-RS-RE-06: % を %25 にする'
        When call rs_error t p "a%b"
        The stderr should include "(got: 'a%25b')"
      End

      It '[Edge] T-RS-RE-07: CR を %0D にする'
        When call rs_error t p "$_RE_CR_VALUE"
        The stderr should include "(got: 'a%0Db')"
      End

      It '[Edge] T-RS-RE-08: LF を %0A にする'
        When call rs_error t p "$_RE_LF_VALUE"
        The stderr should include "(got: 'a%0Ab')"
      End

      It '[Edge] T-RS-RE-09: % を先に置き換える'
        When call rs_error t p "%0A"
        The stderr should include "(got: '%250A')"
      End
    End
  End

  ##
  # normalize_commit_count: confirm the commit-count input and print it on stdout
  # as one line.
  # Scenarios: an explicit empty string uses the default 1;
  #            a valid value (including the upper bound 1000) is printed as is;
  #            0, a value over 1000, a leading zero or a non-numeric value is
  #            rejected with a "::error::commit-count:" line and nothing on stdout;
  #            a whitespace-only value is not trimmed nor defaulted and is rejected;
  #            a 20-digit value cannot overflow past the upper bound.
  Describe 'normalize_commit_count'
    # 正常系: values that are confirmed and printed on stdout
    Context 'When: 正常系'
      It '[Normal] T-RS-NCC-01: 空文字列は既定値 1 にする'
        When call normalize_commit_count ""
        The status should equal 0
        The stdout should equal 1
      End

      It '[Normal] T-RS-NCC-02: 有効な値はそのまま確定する'
        When call normalize_commit_count "3"
        The status should equal 0
        The stdout should equal 3
      End

      It '[Normal] T-RS-NCC-03: 上限値 1000 を確定する'
        When call normalize_commit_count "1000"
        The status should equal 0
        The stdout should equal 1000
      End
    End

    # 異常系: values rejected by the positive-integer check (1 .. 1000)
    Context 'When: 異常系'
      It '[Error] T-RS-NCC-04: 0 はエラーになる'
        When call normalize_commit_count "0"
        The status should be failure
        The stderr should start with '::error::commit-count:'
        The stderr should end with "(got: '0')"
      End

      It '[Error] T-RS-NCC-05: 4 桁で上限を超える値はエラーになる'
        When call normalize_commit_count "1001"
        The status should be failure
        The stdout should equal ''
        The stderr should include "(got: '1001')"
      End

      It '[Error] T-RS-NCC-06: 先頭ゼロはエラーになる'
        When call normalize_commit_count "01"
        The status should be failure
        The stderr should start with '::error::commit-count:'
      End

      It '[Error] T-RS-NCC-07: エラー時は stdout に何も出さない'
        When call normalize_commit_count "abc"
        The stdout should equal ''
        The status should be failure
        The stderr should start with '::error::commit-count:'
      End
    End

    # エッジケース: values that look unspecified or overflow but are not the empty string
    Context 'When: エッジケース'
      It '[Edge] T-RS-NCC-08: 空白のみの値はエラーになる'
        When call normalize_commit_count "   "
        The status should be failure
        The stderr should start with '::error::commit-count:'
      End

      It '[Edge] T-RS-NCC-09: 20 桁の数字列はエラーになる'
        When call normalize_commit_count "18446744073709551617"
        The status should be failure
        The stdout should equal ''
        The stderr should start with '::error::commit-count:'
      End
    End
  End

  ##
  # validate_override: decide whether the before-sha / after-sha override is used
  # and print "none" or "override" on stdout.
  # Scenarios: both inputs empty prints "none";
  #            both inputs valid 40-digit lowercase hex OIDs prints "override";
  #            exactly one input specified is an error targeting the empty side;
  #            a specified input that is not a full 40-digit lowercase hex OID is
  #            an error targeting that input (before-sha first), with empty stdout;
  #            identical valid OIDs are accepted; the one-side error wins over a
  #            format error (one stderr line); a whitespace-only value counts as
  #            specified and fails the format check; 39 / 41 hex digits and a
  #            non-hex character are rejected; when both inputs are malformed only
  #            before-sha is reported (one stderr line).
  Describe 'validate_override'
    # 正常系: input pairs that are accepted
    Context 'When: 正常系'
      It '[Normal] T-RS-VOV-01: 両方が空なら none'
        When call validate_override "" ""
        The status should equal 0
        The stdout should equal none
      End

      It '[Normal] T-RS-VOV-02: 両方が有効 OID なら override'
        When call validate_override "$_VOV_OID_A" "$_VOV_OID_B"
        The status should equal 0
        The stdout should equal override
      End
    End

    # 異常系: exactly one input specified, or an input with an invalid OID format
    Context 'When: 異常系'
      It '[Error] T-RS-VOV-03: before のみ指定はエラーで、対象は after-sha'
        When call validate_override "$_VOV_OID_A" ""
        The status should be failure
        The stderr should equal '::error::after-sha: value must not be empty'
      End

      It '[Error] T-RS-VOV-04: after のみ指定はエラーで、対象は before-sha'
        When call validate_override "" "$_VOV_OID_A"
        The status should be failure
        The stderr should equal '::error::before-sha: value must not be empty'
      End

      It '[Error] T-RS-VOV-05: リビジョン式を拒否する'
        When call validate_override "HEAD~1" "$_VOV_OID_A"
        The status should be failure
        The stderr should start with '::error::before-sha:'
        The stderr should include "(got: 'HEAD~1')"
      End

      It '[Error] T-RS-VOV-06: 7 桁の短縮 SHA を拒否する'
        When call validate_override "$_VOV_OID_SHORT" "$_VOV_OID_A"
        The status should be failure
        The stderr should start with '::error::before-sha:'
      End

      It '[Error] T-RS-VOV-07: 大文字を含む 40 桁を拒否する'
        When call validate_override "$_VOV_OID_UPPER" "$_VOV_OID_A"
        The status should be failure
        The stderr should start with '::error::before-sha:'
      End

      It '[Error] T-RS-VOV-08: after 側の形式違反は after-sha を対象にする'
        When call validate_override "$_VOV_OID_A" "HEAD"
        The status should be failure
        The stderr should start with '::error::after-sha:'
      End

      It '[Error] T-RS-VOV-09: エラー時は stdout に何も出さない'
        When call validate_override "HEAD~1" "$_VOV_OID_A"
        The stdout should equal ''
        The status should be failure
        The stderr should start with '::error::before-sha:'
      End
    End

    # エッジケース: boundary combinations of identical, mixed and whitespace-only inputs,
    # OID length / character-class boundaries, and both inputs malformed
    Context 'When: エッジケース'
      It '[Edge] T-RS-VOV-10: 同一の有効 OID の組を受け付ける'
        When call validate_override "$_VOV_OID_A" "$_VOV_OID_A"
        The status should equal 0
        The stdout should equal override
      End

      It '[Edge] T-RS-VOV-11: 片方のみで値も不正なら片方のみのエラーを優先する'
        When call validate_override "HEAD~1" ""
        The status should be failure
        The stderr should start with '::error::after-sha:'
        The lines of stderr should equal 1
      End

      It '[Edge] T-RS-VOV-12: 空白のみの値は指定ありとして形式エラーにする'
        When call validate_override "  " "$_VOV_OID_B"
        The status should be failure
        The stderr should start with '::error::before-sha:'
        The stderr should include "(got: '  ')"
      End

      It '[Edge] T-RS-VOV-13: 39 桁の小文字 16 進を拒否する'
        When call validate_override "$_VOV_OID_39" "$_VOV_OID_A"
        The status should be failure
        The stdout should equal ''
        The stderr should start with '::error::before-sha:'
        The stderr should include "(got: '$_VOV_OID_39')"
      End

      It '[Edge] T-RS-VOV-14: 41 桁の小文字 16 進を拒否する'
        When call validate_override "$_VOV_OID_41" "$_VOV_OID_A"
        The status should be failure
        The stdout should equal ''
        The stderr should start with '::error::before-sha:'
        The stderr should include "(got: '$_VOV_OID_41')"
      End

      It '[Edge] T-RS-VOV-15: 16 進でない文字を含む 40 桁を拒否する'
        When call validate_override "$_VOV_OID_NONHEX" "$_VOV_OID_A"
        The status should be failure
        The stdout should equal ''
        The stderr should start with '::error::before-sha:'
        The stderr should include "(got: '$_VOV_OID_NONHEX')"
      End

      It '[Edge] T-RS-VOV-16: 両方とも形式違反なら before-sha を先に報告する'
        When call validate_override "HEAD~1" "HEAD"
        The status should be failure
        The stdout should equal ''
        The stderr should start with '::error::before-sha:'
        The stderr should include "(got: 'HEAD~1')"
        The lines of stderr should equal 1
      End
    End
  End

  ##
  # is_partial_clone: decide from git config alone whether the repository of the
  # current working directory is a partial clone (exit 0 / 1 / 2, prints nothing).
  # Each example builds real repositories under its own GF_TMP_ROOT, inside
  # `When` via _ipc_run, so a fixture failure surfaces as status 98 (never expected).
  # Scenarios: a normal clone and a shallow clone are not partial clones;
  # a --filter=blob:none clone (promisor remote) is a partial clone;
  # a broken .git/config and an unreadable (mode 000) .git/config are read
  # failures (2) with nothing on stderr (the latter is skipped where a mode 000
  # file stays readable, e.g. as root or on NTFS / drvfs without metadata);
  # extensions.partialClone alone is a partial clone, and a non-git directory
  # is not (later validation reports the error); a promisor key on a remote
  # not named origin is a partial clone, and a different key that merely starts
  # with "promisor" (remote.origin.promisorx) is not (exact key match).
  Describe 'is_partial_clone'
    BeforeEach 'gf_setup'
    AfterEach 'gf_cleanup'

    # 正常系: only clones with a promisor remote are partial clones
    Context 'When: 正常系'
      It '[Normal] T-RS-IPC-01: 通常の clone は該当なし'
        When call _ipc_run _ipc_build_normal_clone
        The status should equal 1
        The stdout should equal ''
        The stderr should equal ''
      End

      It '[Normal] T-RS-IPC-02: shallow clone は該当なし'
        When call _ipc_run _ipc_build_shallow_clone
        The status should equal 1
        The stdout should equal ''
        The stderr should equal ''
      End

      It '[Normal] T-RS-IPC-03: promisor remote を持つ clone は該当あり'
        When call _ipc_run _ipc_build_partial_clone
        The status should equal 0
        The stdout should equal ''
        The stderr should equal ''
      End
    End

    # 異常系: an unreadable git config is a read failure (2), reported silently
    Context 'When: 異常系'
      It '[Error] T-RS-IPC-04: 設定ファイルが壊れていれば終了コード 2'
        When call _ipc_run _ipc_build_broken_config
        The status should equal 2
        The stdout should equal ''
      End

      It '[Error] T-RS-IPC-05: 判定に失敗しても stderr に何も出さない'
        When call _ipc_run _ipc_build_broken_config
        The stderr should equal ''
        The stdout should equal ''
        The status should equal 2
      End

      It '[Error] T-RS-IPC-10: 設定ファイルを読み取れなければ終了コード 2'
        Skip if "file permissions are not enforced (chmod 000 file stays readable)" _ipc_cannot_enforce_unreadable
        When call _ipc_run _ipc_build_unreadable_config
        The status should equal 2
        The stdout should equal ''
        The stderr should equal ''
      End
    End

    # エッジケース: the boundaries of the decision (extensions key alone, non-git dir,
    # config key boundaries: any remote name, exact promisor key match)
    Context 'When: エッジケース'
      It '[Edge] T-RS-IPC-06: extensions.partialClone だけの設定も該当あり'
        When call _ipc_run _ipc_build_extensions_only
        The status should equal 0
        The stdout should equal ''
        The stderr should equal ''
      End

      It '[Edge] T-RS-IPC-07: git リポジトリでないディレクトリは該当なし'
        When call _ipc_run _ipc_build_non_git_dir
        The status should equal 1
        The stdout should equal ''
        The stderr should equal ''
      End

      It '[Edge] T-RS-IPC-08: origin 以外の名前の promisor remote も該当あり'
        When call _ipc_run _ipc_build_upstream_promisor
        The status should equal 0
        The stdout should equal ''
        The stderr should equal ''
      End

      It '[Edge] T-RS-IPC-09: promisor に似た別のキーは該当なし'
        When call _ipc_run _ipc_build_near_miss_key
        The status should equal 1
        The stdout should equal ''
        The stderr should equal ''
      End
    End
  End

  ##
  # is_commit: decide whether <sha> names an existing commit object in the
  # repository of the current working directory (git cat-file -e "<sha>^{commit}";
  # exit 0 / non-zero, prints nothing, never calls rs_error).
  # Each example builds a real repository under its own GF_TMP_ROOT, inside
  # `When` via the _ic_run* wrappers, so a fixture failure surfaces as status 98.
  # Scenarios: an existing commit (the HEAD OID) is a commit (0);
  # a valid-format OID absent from the repository and an empty string are
  # rejected (non-zero) with nothing on stderr;
  # a non-commit object (the empty tree, RS_EMPTY_TREE_SHA), the 40-digit
  # zero OID and an existing tree object (HEAD^{tree}) are not commits (non-zero);
  # a working directory that is not a git repository rejects (non-zero) silently.
  Describe 'is_commit'
    BeforeEach 'gf_setup'
    AfterEach 'gf_cleanup'

    # 正常系: an OID that names an existing commit
    Context 'When: 正常系'
      It '[Normal] T-RS-IC-01: 存在するコミットは 0'
        When call _ic_run_head
        The status should equal 0
        The stdout should equal ''
        The stderr should equal ''
      End
    End

    # 異常系: values that name no object at all are rejected silently
    Context 'When: 異常系'
      It '[Error] T-RS-IC-02: 存在しない OID は 0 以外'
        When call _ic_run "$_IC_OID_MISSING"
        The status should not equal 0
        The stdout should equal ''
        The stderr should equal ''
      End

      It '[Error] T-RS-IC-03: 空文字列は 0 以外'
        When call _ic_run ""
        The status should not equal 0
        The stdout should equal ''
        The stderr should equal ''
      End
    End

    # エッジケース: values that look like objects but do not name a commit
    Context 'When: エッジケース'
      It '[Edge] T-RS-IC-04: 空ツリー SHA は 0 以外'
        When call _ic_run "$RS_EMPTY_TREE_SHA"
        The status should not equal 0
        The stdout should equal ''
        The stderr should equal ''
      End

      It '[Edge] T-RS-IC-05: 40 桁の 0 は 0 以外'
        When call _ic_run "$_IC_OID_ZERO"
        The status should not equal 0
        The stdout should equal ''
        The stderr should equal ''
      End

      It '[Edge] T-RS-IC-06: 実在するツリーの OID は 0 以外'
        When call _ic_run_tree
        The status should not equal 0
        The stdout should equal ''
        The stderr should equal ''
      End

      It '[Edge] T-RS-IC-07: git リポジトリでないディレクトリでは 0 以外'
        When call _ic_run_non_git "$_IC_OID_MISSING"
        The status should not equal 0
        The stdout should equal ''
        The stderr should equal ''
      End
    End
  End

  ##
  # verify_commit: confirm that <sha> names an existing commit object in the
  # repository of the current working directory, reporting any failure as one
  # "::error::<field>:" line (built on is_commit and rs_error).
  # Each example builds a real repository under its own GF_TMP_ROOT, inside
  # `When` via the _vc_run* wrappers, so a fixture failure surfaces as status 98.
  # Scenarios: an existing commit (the HEAD OID) succeeds with nothing on
  # stdout or stderr; an empty value is reported in the empty form and a
  # valid-format OID absent from the repository as "commit not found" with
  # <field> as the target; the empty tree SHA (RS_EMPTY_TREE_SHA) is not exempt
  # on either side, and every error leaves stdout empty.
  Describe 'verify_commit'
    BeforeEach 'gf_setup'
    AfterEach 'gf_cleanup'

    # 正常系: an OID that names an existing commit
    Context 'When: 正常系'
      It '[Normal] T-RS-VC-01: 存在するコミットは成功し、何も出さない'
        When call _vc_run_head GITHUB_BASE_SHA
        The status should equal 0
        The stdout should equal ''
        The stderr should equal ''
      End
    End

    # 異常系: an empty value or an OID that names no commit is reported as an error
    Context 'When: 異常系'
      It '[Error] T-RS-VC-02: 空の値は空の形式でエラー'
        When call _vc_run "" GITHUB_HEAD_SHA
        The status should not equal 0
        The stdout should equal ''
        The stderr should equal '::error::GITHUB_HEAD_SHA: value must not be empty'
      End

      It '[Error] T-RS-VC-03: 存在しない OID は field を対象にエラー'
        When call _vc_run "$_VC_OID_MISSING" before-sha
        The status should not equal 0
        The stdout should equal ''
        The stderr should start with '::error::before-sha:'
        The stderr should include "(got: '$_VC_OID_MISSING')"
      End
    End

    # エッジケース: the empty tree SHA is not exempt, and errors keep stdout empty
    Context 'When: エッジケース'
      It '[Edge] T-RS-VC-04: before 側の空ツリー SHA もエラー'
        When call _vc_run "$RS_EMPTY_TREE_SHA" before-sha
        The status should not equal 0
        The stdout should equal ''
        The stderr should start with '::error::before-sha:'
        The stderr should include "(got: '${RS_EMPTY_TREE_SHA}')"
      End

      It '[Edge] T-RS-VC-05: after 側の空ツリー SHA もエラー'
        When call _vc_run "$RS_EMPTY_TREE_SHA" after-sha
        The status should not equal 0
        The stdout should equal ''
        The stderr should start with '::error::after-sha:'
        The stderr should include "(got: '${RS_EMPTY_TREE_SHA}')"
      End

      It '[Edge] T-RS-VC-06: エラー時は stdout に何も出さない'
        When call _vc_run "$_VC_OID_MISSING" before-sha
        The status should not equal 0
        The stdout should equal ''
        The stderr should start with '::error::before-sha:'
      End
    End
  End

  ##
  # resolve_head_n: resolve the HEAD~N range of the repository of the current
  # working directory and print "<before> <after> <resolution>" on stdout as one
  # line (after is the HEAD OID resolved once; only the first-parent chain counts).
  # Assigned test IDs: T-RS-RHN-01 .. T-RS-RHN-17.
  # Each fixture example builds a real repository under its own GF_TMP_ROOT,
  # inside `When call` via _rhn_run (or _rhn_run_untrusted), so a fixture failure
  # surfaces as status 98. `When call` runs without a subshell, so the expected
  # OIDs the builder sets (_rhn_head / _rhn_before) reach the assertions that
  # follow. States a real repository cannot produce use _rhn_run_mocked, which
  # replaces git with a function inside a subshell run from GF_TMP_ROOT; an
  # unexpected git call or a missing first-parent count call adds a stderr line.
  # Scenarios: in a linear history HEAD~N resolves (including N = history - 1,
  # the root) as fallback-head-n; at a merge commit the first parent is
  # followed; after is the full 40-digit lowercase hex HEAD OID. Outside a
  # repository, with no commits, or in a work directory git does not trust
  # (dubious ownership), HEAD is reported as an error; with history
  # but a missing ancestor object, HEAD~N is reported as an error (never the
  # empty tree), and every error leaves stdout empty with one stderr line.
  # When the first-parent chain holds N commits or fewer (a short history, or a
  # shallow clone whose first-parent chain hits the boundary), the result is the
  # empty tree (empty-tree); a shallow boundary on the second-parent chain only
  # does not matter, and a shallow clone deep enough still resolves HEAD~N.
  # With git mocked: a first-parent count greater than N while HEAD~N does not
  # resolve, and a non-numeric count, are both reported as HEAD~N errors.
  Describe 'resolve_head_n'
    BeforeEach 'gf_setup'
    AfterEach 'gf_cleanup'

    # 正常系: HEAD~N resolves to a commit and is used as before (fallback-head-n)
    Context 'When: 正常系'
      It '[Normal] T-RS-RHN-01: 直線履歴で N=1 を解決する'
        When call _rhn_run 1 _rhn_build_linear 5 HEAD~1
        The status should equal 0
        The output should equal "$_rhn_before $_rhn_head fallback-head-n"
        The stderr should equal ''
      End

      It '[Normal] T-RS-RHN-02: 履歴がちょうど N+1 コミットなら解決する'
        When call _rhn_run 4 _rhn_build_linear 5 HEAD~4
        The status should equal 0
        The output should equal "$_rhn_before $_rhn_head fallback-head-n"
        The stderr should equal ''
      End

      It '[Normal] T-RS-RHN-03: merge コミットでは第一親をたどる'
        When call _rhn_run 1 _rhn_build_merge
        The status should equal 0
        The output should equal "$_rhn_before $_rhn_head fallback-head-n"
        The stderr should equal ''
      End

      It '[Normal] T-RS-RHN-04: after は解決した HEAD の完全長 OID である'
        When call _rhn_run 1 _rhn_build_linear 3 HEAD~1
        The status should equal 0
        The output should equal "$_rhn_before $_rhn_head fallback-head-n"
        The word 2 of stdout should equal "$_rhn_head"
        The word 2 of stdout should match pattern "$_RHN_OID40_PATTERN"
        The stderr should equal ''
      End
    End

    # 異常系: HEAD or HEAD~N cannot be resolved, reported as one ::error:: line
    Context 'When: 異常系'
      It '[Error] T-RS-RHN-05: git リポジトリでない場合はエラー'
        When call _rhn_run 1 _rhn_build_non_git
        The status should not equal 0
        The stdout should equal ''
        The stderr should start with '::error::HEAD:'
        The stderr should include "(got: 'HEAD')"
        The lines of stderr should equal 1
      End

      It '[Error] T-RS-RHN-06: コミットが無いリポジトリはエラー'
        When call _rhn_run 1 _rhn_build_empty
        The status should not equal 0
        The stdout should equal ''
        The stderr should start with '::error::HEAD:'
        The stderr should include "(got: 'HEAD')"
        The lines of stderr should equal 1
      End

      It '[Error] T-RS-RHN-07: 履歴があるのに HEAD~N を解決できない場合はエラー'
        When call _rhn_run 3 _rhn_build_missing_ancestor
        The status should not equal 0
        The stdout should equal ''
        The stderr should start with '::error::HEAD~N:'
        The stderr should not include "$RS_EMPTY_TREE_SHA"
        The lines of stderr should equal 1
      End

      It '[Error] T-RS-RHN-17: git が信頼しない作業ディレクトリはエラー'
        When call _rhn_run_untrusted 1 _rhn_build_linear 1
        The status should not equal 0
        The stdout should equal ''
        The stderr should start with '::error::HEAD:'
        The stderr should include "(got: 'HEAD')"
        The lines of stderr should equal 1
      End
    End

    # エッジケース: a first-parent history of N commits or fewer is classified as the empty tree
    Context 'When: エッジケース'
      It '[Edge] T-RS-RHN-08: 初回コミットのみで N=1 は empty-tree'
        When call _rhn_run 1 _rhn_build_linear 1
        The status should equal 0
        The output should equal "$RS_EMPTY_TREE_SHA $_rhn_head empty-tree"
        The stderr should equal ''
      End

      It '[Edge] T-RS-RHN-09: 初回コミットのみで N=3 は empty-tree'
        When call _rhn_run 3 _rhn_build_linear 1
        The status should equal 0
        The output should equal "$RS_EMPTY_TREE_SHA $_rhn_head empty-tree"
        The stderr should equal ''
      End

      It '[Edge] T-RS-RHN-10: 2 コミットで N=3 は empty-tree'
        When call _rhn_run 3 _rhn_build_linear 2
        The status should equal 0
        The output should equal "$RS_EMPTY_TREE_SHA $_rhn_head empty-tree"
        The stderr should equal ''
      End

      It '[Edge] T-RS-RHN-11: depth 3 の shallow clone で N=2 は解決する'
        When call _rhn_run 2 _rhn_build_shallow 3 HEAD~2
        The status should equal 0
        The output should equal "$_rhn_before $_rhn_head fallback-head-n"
        The stderr should equal ''
      End

      It '[Edge] T-RS-RHN-12: depth 2 の shallow clone で N=2 は empty-tree'
        When call _rhn_run 2 _rhn_build_shallow 2
        The status should equal 0
        The output should equal "$RS_EMPTY_TREE_SHA $_rhn_head empty-tree"
        The stderr should equal ''
      End

      It '[Edge] T-RS-RHN-13: merge で第一親の系列が shallow 境界に達する場合は empty-tree'
        When call _rhn_run 2 _rhn_build_merge_shallow 3 3 2
        The status should equal 0
        The output should equal "$RS_EMPTY_TREE_SHA $_rhn_head empty-tree"
        The stderr should equal ''
      End

      It '[Edge] T-RS-RHN-14: merge で第二親の系列だけが shallow 境界に達する場合は解決する'
        When call _rhn_run 2 _rhn_build_merge_shallow 2 4 3 HEAD~2
        The status should equal 0
        The output should equal "$_rhn_before $_rhn_head fallback-head-n"
        The stderr should equal ''
      End
    End

    # 異常系 (git をモック): states a real repository cannot produce, reported as one ::error::HEAD~N: line
    Context 'When: 異常系 (git をモック)'
      It '[Error] T-RS-RHN-15: 世代数が N を超えるのに HEAD~N を解決できない場合はエラー'
        When call _rhn_run_mocked 2 5
        The status should not equal 0
        The stdout should equal ''
        The stderr should start with '::error::HEAD~N:'
        The stderr should include "(got: '2')"
        The lines of stderr should equal 1
      End

      It '[Error] T-RS-RHN-16: 世代数が数値でなければエラー'
        When call _rhn_run_mocked 2 abc
        The status should not equal 0
        The stdout should equal ''
        The stderr should start with '::error::HEAD~N:'
        The stderr should include "(got: '2')"
        The lines of stderr should equal 1
      End
    End
  End

  ##
  # resolve_sha: resolve the before / after commit range for the triggering
  # event and print "<before> <after> <resolution>" on stdout as one line.
  # Assigned test IDs: T-RS-RSH-01 .. T-RS-RSH-34.
  # Each example builds a real repository under its own GF_TMP_ROOT inside
  # `When call` via _rsh_run, so a fixture failure surfaces as status 98;
  # "@<rev>" arguments are resolved to commit OIDs in that repository, and the
  # expected OIDs are read back with _rsh_oid in the assertions.
  # Scenarios: both before-sha and after-sha overrides set use them as the
  # range (override);
  # a push whose before commit exists uses the event range (event);
  # a push with an empty, 40-digit zero, or non-commit before resolves with
  # HEAD~N (fallback-head-n);
  # a pull_request uses its base and head as-is (event); any other event
  # (including pull_request_target) resolves with HEAD~N (fallback-head-n);
  # an empty event name is an error (empty form), even when both overrides
  # are set (the event check runs first);
  # a push without an override whose ref is outside refs/heads/ (a tag push)
  # is a GITHUB_REF error;
  # a deletion push (tag or branch) is a GITHUB_EVENT_DELETED error, while an
  # empty deleted flag is not a deletion (only the exact value true is);
  # a partial clone working directory is a repository error, even when both
  # overrides are set (the repository check runs before the override route);
  # a working directory whose git config cannot be read is a repository error;
  # an override before that is not a commit is a before-sha error;
  # an override after that is not a commit is an after-sha error (the
  # before is verified first);
  # a push whose before commit exists but whose after is empty is a
  # GITHUB_AFTER_SHA error (empty form), with no HEAD~N fallback;
  # a pull_request whose base is empty is a GITHUB_BASE_SHA error (empty form);
  # a pull_request whose base is not a commit is a GITHUB_BASE_SHA error;
  # a pull_request whose base exists but whose head is empty is a
  # GITHUB_HEAD_SHA error (empty form);
  # a tag push with both overrides set still resolves (override), since the
  # push ref check applies only without an override;
  # a push whose before equals its after is not special-cased (event);
  # a pull_request whose base and head are both absent reports only the
  # GITHUB_BASE_SHA error (verification stops at the base);
  # any other event, or a push with a 40-digit zero before, whose history is
  # shorter than N resolves with the empty tree as before (empty-tree, passed
  # through from resolve_head_n).
  Describe 'resolve_sha'
    BeforeEach 'gf_setup'
    AfterEach 'gf_cleanup'

    # 正常系: the range is taken from the overrides (override), the event payload (event) or HEAD~N (fallback-head-n)
    Context 'When: 正常系'
      It '[Normal] T-RS-RSH-01: push で before が存在すれば event を返す'
        When call _rsh_run _rsh_build_linear 5 -- push 1 "" "" @HEAD~2 @HEAD "" "" refs/heads/main false
        The status should equal 0
        The output should equal "$(_rsh_oid HEAD~2) $(_rsh_oid HEAD) event"
        The stderr should equal ''
      End

      It '[Normal] T-RS-RSH-02: pull_request は base と head をそのまま使う'
        When call _rsh_run _rsh_build_linear 5 -- pull_request 1 "" "" "" "" @HEAD~3 @HEAD~1 refs/heads/main false
        The status should equal 0
        The output should equal "$(_rsh_oid HEAD~3) $(_rsh_oid HEAD~1) event"
        The stderr should equal ''
      End

      It '[Normal] T-RS-RSH-03: その他のイベント (workflow_dispatch) は HEAD~N で解決する'
        When call _rsh_run _rsh_build_linear 5 -- workflow_dispatch 1 "" "" "" "" "" "" refs/heads/main false
        The status should equal 0
        The output should equal "$(_rsh_oid HEAD~1) $(_rsh_oid HEAD) fallback-head-n"
        The stderr should equal ''
      End

      It '[Normal] T-RS-RSH-04: pull_request_target はその他のイベントとして HEAD~N で解決する'
        When call _rsh_run _rsh_build_linear 5 -- pull_request_target 1 "" "" "" "" "$_RSH_OID_MISSING" "$_RSH_OID_MISSING2" refs/heads/main false
        The status should equal 0
        The output should equal "$(_rsh_oid HEAD~1) $(_rsh_oid HEAD) fallback-head-n"
        The stderr should equal ''
      End

      It '[Normal] T-RS-RSH-05: push で before が空なら HEAD~N で解決する'
        When call _rsh_run _rsh_build_linear 5 -- push 2 "" "" "" @HEAD "" "" refs/heads/main false
        The status should equal 0
        The output should equal "$(_rsh_oid HEAD~2) $(_rsh_oid HEAD) fallback-head-n"
        The stderr should equal ''
      End

      It '[Normal] T-RS-RSH-06: push で before が 40 桁の 0 なら HEAD~N で解決する'
        When call _rsh_run _rsh_build_linear 5 -- push 2 "" "" "$_RSH_OID_ZERO" @HEAD "" "" refs/heads/main false
        The status should equal 0
        The output should equal "$(_rsh_oid HEAD~2) $(_rsh_oid HEAD) fallback-head-n"
        The stderr should equal ''
      End

      It '[Normal] T-RS-RSH-07: push で before が存在しないなら HEAD~N で解決する'
        When call _rsh_run _rsh_build_linear 5 -- push 2 "" "" "$_RSH_OID_MISSING" @HEAD "" "" refs/heads/main false
        The status should equal 0
        The output should equal "$(_rsh_oid HEAD~2) $(_rsh_oid HEAD) fallback-head-n"
        The stderr should equal ''
      End

      It '[Normal] T-RS-RSH-08: before-sha と after-sha が両方指定されていれば override を返す'
        When call _rsh_run _rsh_build_linear 5 -- push 1 @HEAD~2 @HEAD "" @HEAD "" "" refs/heads/main false
        The status should equal 0
        The output should equal "$(_rsh_oid HEAD~2) $(_rsh_oid HEAD) override"
        The stderr should equal ''
      End
    End

    # 異常系: the range cannot be resolved, reported as one ::error:: line with stdout empty
    Context 'When: 異常系'
      It '[Error] T-RS-RSH-09: イベント名が空ならエラー'
        When call _rsh_run _rsh_build_linear 5 -- "" 1 "" "" "" "" "" "" refs/heads/main false
        The status should not equal 0
        The stdout should equal ''
        The stderr should equal '::error::GITHUB_EVENT_NAME: value must not be empty'
        The lines of stderr should equal 1
      End

      It '[Error] T-RS-RSH-10: オーバーライドがあってもイベント名が空ならエラー'
        When call _rsh_run _rsh_build_linear 5 -- "" 1 @HEAD~1 @HEAD "" "" "" "" refs/heads/main false
        The status should not equal 0
        The stdout should equal ''
        The stderr should start with '::error::GITHUB_EVENT_NAME:'
        The lines of stderr should equal 1
      End

      It '[Error] T-RS-RSH-11: オーバーライドなしでタグの push はエラー'
        When call _rsh_run _rsh_build_linear 5 -- push 1 "" "" @HEAD~1 @HEAD "" "" refs/tags/v1.0.0 false
        The status should not equal 0
        The stdout should equal ''
        The stderr should start with '::error::GITHUB_REF:'
        The stderr should include "(got: 'refs/tags/v1.0.0')"
        The lines of stderr should equal 1
      End

      It '[Error] T-RS-RSH-12: タグの削除は削除のエラーを出す'
        When call _rsh_run _rsh_build_linear 5 -- push 1 "" "" @HEAD~1 @HEAD "" "" refs/tags/v1.0.0 true
        The status should not equal 0
        The stdout should equal ''
        The stderr should start with '::error::GITHUB_EVENT_DELETED:'
        The lines of stderr should equal 1
      End

      It '[Error] T-RS-RSH-13: ブランチの削除は削除のエラーを出す'
        When call _rsh_run _rsh_build_linear 5 -- push 1 "" "" @HEAD~1 @HEAD "" "" refs/heads/main true
        The status should not equal 0
        The stdout should equal ''
        The stderr should start with '::error::GITHUB_EVENT_DELETED:'
        The lines of stderr should equal 1
      End

      It '[Error] T-RS-RSH-14: partial clone の作業ディレクトリはエラー'
        When call _rsh_run _rsh_build_partial 5 -- workflow_dispatch 1 "" "" "" "" "" "" refs/heads/main false
        The status should not equal 0
        The stdout should equal ''
        The stderr should start with '::error::repository:'
        The lines of stderr should equal 1
      End

      It '[Error] T-RS-RSH-15: オーバーライドがあっても partial clone はエラー'
        When call _rsh_run _rsh_build_partial 5 -- push 1 @HEAD~1 @HEAD "" @HEAD "" "" refs/heads/main false
        The status should not equal 0
        The stdout should equal ''
        The stderr should start with '::error::repository:'
        The lines of stderr should equal 1
      End

      It '[Error] T-RS-RSH-16: 設定ファイルが壊れていればエラー'
        When call _rsh_run _rsh_build_broken 5 -- workflow_dispatch 1 "" "" "" "" "" "" refs/heads/main false
        The status should not equal 0
        The stdout should equal ''
        The stderr should start with '::error::repository:'
        The lines of stderr should equal 1
      End

      It '[Error] T-RS-RSH-17: オーバーライドの before が存在しなければエラー'
        When call _rsh_run _rsh_build_linear 5 -- push 1 "$_RSH_OID_MISSING" @HEAD "" @HEAD "" "" refs/heads/main false
        The status should not equal 0
        The stdout should equal ''
        The stderr should start with '::error::before-sha:'
        The stderr should include "(got: '$_RSH_OID_MISSING')"
        The lines of stderr should equal 1
      End

      It '[Error] T-RS-RSH-18: オーバーライドの after が存在しなければエラー'
        When call _rsh_run _rsh_build_linear 5 -- push 1 @HEAD "$_RSH_OID_MISSING" "" @HEAD "" "" refs/heads/main false
        The status should not equal 0
        The stdout should equal ''
        The stderr should start with '::error::after-sha:'
        The stderr should include "(got: '$_RSH_OID_MISSING')"
        The lines of stderr should equal 1
      End

      It '[Error] T-RS-RSH-19: オーバーライドの before が空ツリー SHA ならエラー'
        When call _rsh_run _rsh_build_linear 5 -- push 1 "$RS_EMPTY_TREE_SHA" @HEAD "" @HEAD "" "" refs/heads/main false
        The status should not equal 0
        The stdout should equal ''
        The stderr should start with '::error::before-sha:'
        The stderr should include "(got: '${RS_EMPTY_TREE_SHA}')"
        The lines of stderr should equal 1
      End

      It '[Error] T-RS-RSH-20: オーバーライドの after が空ツリー SHA ならエラー'
        When call _rsh_run _rsh_build_linear 5 -- push 1 @HEAD "$RS_EMPTY_TREE_SHA" "" @HEAD "" "" refs/heads/main false
        The status should not equal 0
        The stdout should equal ''
        The stderr should start with '::error::after-sha:'
        The stderr should include "(got: '${RS_EMPTY_TREE_SHA}')"
        The lines of stderr should equal 1
      End

      It '[Error] T-RS-RSH-21: push で after が空ならエラー'
        When call _rsh_run _rsh_build_linear 5 -- push 1 "" "" @HEAD~1 "" "" "" refs/heads/main false
        The status should not equal 0
        The stdout should equal ''
        The stderr should equal '::error::GITHUB_AFTER_SHA: value must not be empty'
        The lines of stderr should equal 1
      End

      It '[Error] T-RS-RSH-22: push で after が存在しないコミットならエラー'
        When call _rsh_run _rsh_build_linear 5 -- push 1 "" "" @HEAD~1 "$_RSH_OID_MISSING" "" "" refs/heads/main false
        The status should not equal 0
        The stdout should equal ''
        The stderr should start with '::error::GITHUB_AFTER_SHA:'
        The stderr should include "(got: '$_RSH_OID_MISSING')"
        The lines of stderr should equal 1
      End

      It '[Error] T-RS-RSH-23: pull_request で base が空ならエラー'
        When call _rsh_run _rsh_build_linear 5 -- pull_request 1 "" "" "" "" "" @HEAD refs/heads/main false
        The status should not equal 0
        The stdout should equal ''
        The stderr should equal '::error::GITHUB_BASE_SHA: value must not be empty'
        The lines of stderr should equal 1
      End

      It '[Error] T-RS-RSH-24: pull_request で head が空ならエラー'
        When call _rsh_run _rsh_build_linear 5 -- pull_request 1 "" "" "" "" @HEAD~1 "" refs/heads/main false
        The status should not equal 0
        The stdout should equal ''
        The stderr should equal '::error::GITHUB_HEAD_SHA: value must not be empty'
        The lines of stderr should equal 1
      End

      It '[Error] T-RS-RSH-25: pull_request で base が存在しなければエラー'
        When call _rsh_run _rsh_build_linear 5 -- pull_request 1 "" "" "" "" "$_RSH_OID_MISSING" @HEAD refs/heads/main false
        The status should not equal 0
        The stdout should equal ''
        The stderr should start with '::error::GITHUB_BASE_SHA:'
        The stderr should include "(got: '$_RSH_OID_MISSING')"
        The lines of stderr should equal 1
      End

      It '[Error] T-RS-RSH-26: pull_request で head が存在しなければエラー'
        When call _rsh_run _rsh_build_linear 5 -- pull_request 1 "" "" "" "" @HEAD~1 "$_RSH_OID_MISSING" refs/heads/main false
        The status should not equal 0
        The stdout should equal ''
        The stderr should start with '::error::GITHUB_HEAD_SHA:'
        The stderr should include "(got: '$_RSH_OID_MISSING')"
        The lines of stderr should equal 1
      End
    End

    # エッジケース: inputs at a rule boundary (the push ref check is skipped by an override or a non-push event; only deleted=true is a deletion; an identical before / after is not special-cased; the pull_request base is reported before the head; a history shorter than N falls back to the empty tree)
    Context 'When: エッジケース'
      It '[Edge] T-RS-RSH-27: オーバーライドがあればタグの push でも解決する'
        When call _rsh_run _rsh_build_linear 5 -- push 1 @HEAD~1 @HEAD "" @HEAD "" "" refs/tags/v1.0.0 false
        The status should equal 0
        The output should equal "$(_rsh_oid HEAD~1) $(_rsh_oid HEAD) override"
        The stderr should equal ''
      End

      It '[Edge] T-RS-RSH-28: push 以外のイベントは ref がタグでも解決する'
        When call _rsh_run _rsh_build_linear 5 -- workflow_dispatch 1 "" "" "" "" "" "" refs/tags/v1.0.0 false
        The status should equal 0
        The output should equal "$(_rsh_oid HEAD~1) $(_rsh_oid HEAD) fallback-head-n"
        The stderr should equal ''
      End

      It '[Edge] T-RS-RSH-29: 削除フラグが空のブランチ push は通過する'
        When call _rsh_run _rsh_build_linear 5 -- push 1 "" "" "" @HEAD "" "" refs/heads/main ""
        The status should equal 0
        The output should equal "$(_rsh_oid HEAD~1) $(_rsh_oid HEAD) fallback-head-n"
        The stderr should equal ''
      End

      It '[Edge] T-RS-RSH-30: before と after が同一でも event で解決する'
        When call _rsh_run _rsh_build_linear 5 -- push 1 "" "" @HEAD @HEAD "" "" refs/heads/main false
        The status should equal 0
        The output should equal "$(_rsh_oid HEAD) $(_rsh_oid HEAD) event"
        The stderr should equal ''
      End

      It '[Edge] T-RS-RSH-31: pull_request で base と head が両方不在なら base のエラーだけを出す'
        When call _rsh_run _rsh_build_linear 5 -- pull_request 1 "" "" "" "" "$_RSH_OID_MISSING" "$_RSH_OID_MISSING2" refs/heads/main false
        The status should not equal 0
        The stdout should equal ''
        The stderr should start with '::error::GITHUB_BASE_SHA:'
        The lines of stderr should equal 1
      End

      It '[Edge] T-RS-RSH-32: オーバーライドの両方が不在なら before のエラーだけを出す'
        When call _rsh_run _rsh_build_linear 5 -- push 1 "$_RSH_OID_MISSING" "$_RSH_OID_MISSING2" "" @HEAD "" "" refs/heads/main false
        The status should not equal 0
        The stdout should equal ''
        The stderr should start with '::error::before-sha:'
        The lines of stderr should equal 1
      End

      It '[Edge] T-RS-RSH-33: その他イベントで履歴が N に満たなければ empty-tree で解決する'
        When call _rsh_run _rsh_build_linear 1 -- workflow_dispatch 3 "" "" "" "" "" "" refs/heads/main false
        The status should equal 0
        The output should equal "$RS_EMPTY_TREE_SHA $(_rsh_oid HEAD) empty-tree"
        The stderr should equal ''
      End

      It '[Edge] T-RS-RSH-34: push で before が無効かつ履歴が N に満たなければ empty-tree で解決する'
        When call _rsh_run _rsh_build_linear 1 -- push 3 "" "" "$_RSH_OID_ZERO" @HEAD "" "" refs/heads/main false
        The status should equal 0
        The output should equal "$RS_EMPTY_TREE_SHA $(_rsh_oid HEAD) empty-tree"
        The stderr should equal ''
      End
    End
  End

  ##
  # emit_outputs: append before_sha / after_sha / resolution to the output file
  # (GITHUB_OUTPUT) in this order.
  # Assigned test IDs: T-RS-EO-01 .. T-RS-EO-14.
  # Scenarios: valid values are written as exactly 3 lines and succeed; existing
  # contents of the output file are kept and the 3 lines are appended after them;
  # an empty output file path and an output file path that is a directory are
  # rejected with one ::error:: line; a before value containing an LF and an
  # after value containing a lone CR are rejected with one ::error:: line and
  # nothing is written; a resolution outside the 4 known values is rejected
  # with one ::error:: line and nothing is written; a failing 2nd write stops
  # immediately with one ::error:: line, keeping only the 1st written line; the
  # known resolution values override, fallback-head-n and empty-tree (with the
  # empty tree SHA as before) are written as is; the resolution match is
  # case-sensitive, so an upper-case EVENT is rejected and nothing is written;
  # a resolution with a trailing LF is rejected before the first write, so
  # nothing is written; a successful call writes nothing to stderr.
  Describe 'emit_outputs'
    BeforeEach '_eo_setup'
    AfterEach 'gf_cleanup'

    # 正常系: the 3 output lines are written
    Context 'When: 正常系'
      It '[Normal] T-RS-EO-01: 3 行を書いて成功する'
        When call emit_outputs "$_eo_file" "$_EO_OID_BEFORE" "$_EO_OID_AFTER" event
        The status should equal 0
        The contents of file "$_eo_file" should include "before_sha=${_EO_OID_BEFORE}"
        The contents of file "$_eo_file" should include "after_sha=${_EO_OID_AFTER}"
        The contents of file "$_eo_file" should include "resolution=event"
        The lines of contents of file "$_eo_file" should equal 3
      End

      It '[Normal] T-RS-EO-02: 既存の内容を残して追記する'
        When call _eo_run_with_existing "$_eo_file" "$_EO_OID_BEFORE" "$_EO_OID_AFTER" event
        The status should equal 0
        The line 1 of contents of file "$_eo_file" should equal "$_EO_EXISTING_LINE"
        The lines of contents of file "$_eo_file" should equal 4
        The contents of file "$_eo_file" should include "before_sha=${_EO_OID_BEFORE}"
        The contents of file "$_eo_file" should include "after_sha=${_EO_OID_AFTER}"
        The contents of file "$_eo_file" should include "resolution=event"
      End
    End

    # 異常系: invalid arguments are rejected before anything is written
    Context 'When: 異常系'
      It '[Error] T-RS-EO-03: 出力先が空ならエラー'
        When call emit_outputs "" "$_EO_OID_BEFORE" "$_EO_OID_AFTER" event
        The status should not equal 0
        The stdout should equal ''
        The stderr should equal '::error::GITHUB_OUTPUT: value must not be empty'
        The lines of stderr should equal 1
      End

      It '[Error] T-RS-EO-04: 出力先が書き込めなければエラー'
        When call emit_outputs "$GF_TMP_ROOT" "$_EO_OID_BEFORE" "$_EO_OID_AFTER" event
        The status should not equal 0
        The stdout should equal ''
        The stderr should start with '::error::GITHUB_OUTPUT:'
        The lines of stderr should equal 1
      End

      It '[Error] T-RS-EO-05: before が LF を含めばエラーで、何も書かない'
        When call emit_outputs "$_eo_file" "$_EO_VALUE_LF" "$_EO_OID_AFTER" event
        The status should not equal 0
        The stdout should equal ''
        The stderr should start with '::error::before_sha:'
        The lines of stderr should equal 1
        The file "$_eo_file" should be empty file
      End

      It '[Error] T-RS-EO-06: after が単独の CR を含めばエラーで、何も書かない'
        When call emit_outputs "$_eo_file" "$_EO_OID_BEFORE" "$_EO_VALUE_CR" event
        The status should not equal 0
        The stdout should equal ''
        The stderr should start with '::error::after_sha:'
        The lines of stderr should equal 1
        The file "$_eo_file" should be empty file
      End

      It '[Error] T-RS-EO-07: resolution が 4 値以外ならエラーで、何も書かない'
        When call emit_outputs "$_eo_file" "$_EO_OID_BEFORE" "$_EO_OID_AFTER" bogus
        The status should not equal 0
        The stdout should equal ''
        The stderr should start with '::error::resolution:'
        The lines of stderr should equal 1
        The file "$_eo_file" should be empty file
      End

      It '[Error] T-RS-EO-08: 2 回目の書き込みが失敗したら直ちに止まり、1 件目が残る'
        When call _eo_run_failing_second_write "$_eo_file" "$_EO_OID_BEFORE" "$_EO_OID_AFTER" event
        The status should not equal 0
        The stdout should equal ''
        The stderr should start with '::error::after_sha:'
        The lines of stderr should equal 1
        The lines of contents of file "$_eo_file" should equal 1
        The contents of file "$_eo_file" should equal "before_sha=${_EO_OID_BEFORE}"
      End
    End

    # エッジケース: each known resolution value other than event is written as is, the match is case-sensitive, a newline in the resolution is caught before any write, and success is silent on stderr
    Context 'When: エッジケース'
      It '[Edge] T-RS-EO-09: override を書く'
        When call emit_outputs "$_eo_file" "$_EO_OID_BEFORE" "$_EO_OID_AFTER" override
        The status should equal 0
        The contents of file "$_eo_file" should include "resolution=override"
      End

      It '[Edge] T-RS-EO-10: fallback-head-n を書く'
        When call emit_outputs "$_eo_file" "$_EO_OID_BEFORE" "$_EO_OID_AFTER" fallback-head-n
        The status should equal 0
        The contents of file "$_eo_file" should include "resolution=fallback-head-n"
      End

      It '[Edge] T-RS-EO-11: empty-tree と空ツリー SHA の before を書く'
        When call emit_outputs "$_eo_file" "$RS_EMPTY_TREE_SHA" "$_EO_OID_AFTER" empty-tree
        The status should equal 0
        The contents of file "$_eo_file" should include "before_sha=4b825dc642cb6eb9a060e54bf8d69288fbee4904"
        The contents of file "$_eo_file" should include "resolution=empty-tree"
      End

      It '[Edge] T-RS-EO-12: 大文字の resolution は拒否する'
        When call emit_outputs "$_eo_file" "$_EO_OID_BEFORE" "$_EO_OID_AFTER" EVENT
        The status should not equal 0
        The stdout should equal ''
        The stderr should start with '::error::resolution:'
        The lines of stderr should equal 1
        The file "$_eo_file" should be empty file
      End

      It '[Edge] T-RS-EO-13: 1 件目の値の改行も事前検査で止める'
        When call emit_outputs "$_eo_file" "$_EO_OID_BEFORE" "$_EO_OID_AFTER" "$_EO_RESOLUTION_LF"
        The status should not equal 0
        The stdout should equal ''
        The stderr should start with '::error::resolution:'
        The lines of stderr should equal 1
        The file "$_eo_file" should be empty file
      End

      It '[Edge] T-RS-EO-14: 成功時は stderr に何も出さない'
        When call emit_outputs "$_eo_file" "$_EO_OID_BEFORE" "$_EO_OID_AFTER" event
        The status should equal 0
        The stderr should equal ''
      End
    End
  End

  ##
  # load guard: RESOLVE_SHA_LIB_LOADED prevents the library body from being
  # re-evaluated, and the first source loads the shared libraries
  # validation.lib.sh and output.lib.sh. Every example sources the library in a
  # fresh bash process (via the _rlg_* helpers), because the spec shell has
  # already loaded it via Include.
  # Assigned test IDs: T-RS-RLG-01 .. T-RS-RLG-04
  # Scenarios: the first source returns 0, sets the guard to 1 and defines the
  #            library's own functions (rs_error) and those of the shared
  #            libraries (validate_positive_int); a second source returns 0
  #            with empty stderr; a missing shared library (validation.lib.sh)
  #            makes the source fail; a preset guard makes the source return 0
  #            early without defining the library's functions.
  Describe 'load guard'
    # 正常系: the first source in a fresh process sets the guard and defines the functions
    Context 'When: 正常系'
      It '[Normal] T-RS-RLG-01: 1 回目の読み込みでガード変数が設定される'
        When call _rlg_source_lib_in_fresh_shell
        The status should equal 0
        The line 1 of output should equal 'loaded=1'
        The line 2 of output should equal 'rs_error=defined'
        The line 3 of output should equal 'validate_positive_int=defined'
        The line 5 of output should equal 'source_status=0'
      End

      It '[Normal] T-RS-RLG-02: 2 回目の読み込みでもエラーにならない'
        When call _rlg_resource_lib_in_fresh_shell
        The status should equal 0
        The stderr should equal ''
      End
    End

    # 異常系: a shared library is missing, so loading must fail instead of continuing
    Context 'When: 異常系'
      BeforeEach 'gf_setup'
      AfterEach 'gf_cleanup'

      It '[Error] T-RS-RLG-03: validation.lib.sh が見つからなければ読み込みを失敗させる'
        When call _rlg_source_isolated_copy
        The status should not equal 0
        The stderr should include 'validation.lib.sh'
      End
    End

    # エッジケース: the guard is already set, so the source returns without defining functions
    Context 'When: エッジケース'
      It '[Edge] T-RS-RLG-04: ガード変数が設定済みなら関数を定義せずに戻る'
        When call _rlg_source_lib_in_fresh_shell 1
        The status should equal 0
        The line 4 of output should equal 'normalize_commit_count=undefined'
        The line 5 of output should equal 'source_status=0'
      End
    End
  End
End
