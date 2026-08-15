#!/usr/bin/env bash
# lib.sh — three-state grading primitives shared by scripts/grade/<N>.sh.
#
# THE CONTRACT
# ------------
# A grade script reports one of three states, never two:
#
#   exit 0  checked-clean     every arm was evaluated and every arm passed
#   exit 1  checked-failed    every arm was evaluated and at least one FAILED,
#                             each with a named reason
#   exit 2  could-not-check   at least one arm could not be evaluated at all
#
# Rule that decides between 1 and 2, and why it is written this way: a learner
# told "you failed" because the grader could not read their tree is the worst
# outcome this harness can produce. So an arm the harness could not evaluate
# outranks a failed arm in the rollup — exit 2 wins over exit 1.
#
# BLOCKED IS NOT COULD-NOT-CHECK.
# That rule has one exception, and without it exit 2 would swallow every real
# finding. If arm 1.4 ("the three answers are filled in") cannot run because arm
# 1.3 ("the answers file exists") already FAILED, then the harness did evaluate
# the learner's tree — it found the file missing. Such an arm is recorded
# `blocked`, is reported, and does NOT push the rollup to could-not-check. Only
# an arm defeated by a HARNESS limitation — a missing tool, an absent answer
# key, an unreadable path — is could-not-check.
#
# WHY EVERY HELPER GUARDS THE PATH FIRST
# --------------------------------------
# `grep PATTERN missing-file` exits 2 and prints nothing. An assertion phrased
# as "the output must be empty" is therefore SATISFIED BY THE ERROR, and the
# arm reports clean having measured nothing. Every helper below establishes that
# its subject exists before it looks inside it, and reports could-not-check when
# it does not. The same reason is why nothing here ends in `| wc -l`: a pipeline
# into `wc` exits 0 whatever it counted, so the count has to be compared with
# `test`, never inferred from the exit status.
#
# PORTABILITY
# -----------
# bash 3.2 (macOS system bash) — no associative arrays, no `mapfile`, no
# `readarray`. GNU-only tools are avoided throughout; see the toolkit's
# brief-rules rule 29.

# Deliberately NOT `set -e`: a failing assertion must be RECORDED and the run
# continued, so the learner gets every named reason at once rather than the
# first one.
set -uo pipefail

G_LESSON="${G_LESSON:-?}"

# Arm state is kept in a flat string, ";<id>=<state>;...", because bash 3.2 has
# no associative arrays.
G_STATES=";"
G_N_CLEAN=0
G_N_FAILED=0
G_N_UNKNOWN=0
G_N_BLOCKED=0

g_state_of() {
  # g_state_of <arm-id> -> prints clean|failed|unknown|blocked|none
  case "$G_STATES" in
    *";$1=clean;"*)   printf 'clean'   ;;
    *";$1=failed;"*)  printf 'failed'  ;;
    *";$1=unknown;"*) printf 'unknown' ;;
    *";$1=blocked;"*) printf 'blocked' ;;
    *)                printf 'none'    ;;
  esac
}

_g_record() {
  # _g_record <arm-id> <state> <label> <detail>
  local id="$1" state="$2" label="$3" detail="$4" tag
  G_STATES="${G_STATES}${id}=${state};"
  case "$state" in
    clean)   tag='[checked-clean]  '; G_N_CLEAN=$((G_N_CLEAN + 1))     ;;
    failed)  tag='[checked-failed] '; G_N_FAILED=$((G_N_FAILED + 1))   ;;
    unknown) tag='[could-not-check]'; G_N_UNKNOWN=$((G_N_UNKNOWN + 1)) ;;
    blocked) tag='[blocked]        '; G_N_BLOCKED=$((G_N_BLOCKED + 1)) ;;
  esac
  printf '%s %-6s %-26s %s\n' "$tag" "$id" "$label" "$detail"
}

g_clean()   { _g_record "$1" clean   "$2" "$3"; }
g_fail()    { _g_record "$1" failed  "$2" "$3"; }
g_unknown() { _g_record "$1" unknown "$2" "$3"; }

g_blocked() {
  # g_blocked <arm-id> <label> <blocking-arm-id>
  # Use ONLY when the blocking arm's own state is `failed` — i.e. the harness
  # did look at the tree. If the blocker is `unknown`, propagate unknown.
  local blocker_state
  blocker_state="$(g_state_of "$3")"
  if [ "$blocker_state" = unknown ]; then
    _g_record "$1" unknown "$2" "not evaluated: arm $3 could not be checked"
  else
    _g_record "$1" blocked "$2" "not evaluated: arm $3 is checked-failed"
  fi
}

# --- assertions -------------------------------------------------------------

g_assert_file() {
  # g_assert_file <arm-id> <label> <path> <named-reason-if-missing>
  local id="$1" label="$2" path="$3" why="$4"
  if [ -f "$path" ]; then
    g_clean "$id" "$label" "$path exists"
  else
    g_fail "$id" "$label" "$why (looked for: $path)"
  fi
}

g_assert_matches() {
  # g_assert_matches <arm-id> <label> <path> <ERE> <named-reason-if-absent>
  # Reports could-not-check — never failed — when the path does not exist, so a
  # grep error can never be mistaken for a finding about the learner's work.
  local id="$1" label="$2" path="$3" re="$4" why="$5"
  if [ ! -f "$path" ]; then
    g_unknown "$id" "$label" "cannot read $path — nothing to match against"
    return
  fi
  if grep -qE "$re" "$path"; then
    g_clean "$id" "$label" "$path matches /$re/"
  else
    g_fail "$id" "$label" "$why (no line of $path matches /$re/)"
  fi
}

g_assert_absent() {
  # g_assert_absent <arm-id> <label> <path> <ERE> <named-reason-if-present>
  local id="$1" label="$2" path="$3" re="$4" why="$5"
  if [ ! -f "$path" ]; then
    g_unknown "$id" "$label" "cannot read $path — an absence there is unprovable"
    return
  fi
  if grep -qE "$re" "$path"; then
    g_fail "$id" "$label" "$why (found /$re/ in $path)"
  else
    g_clean "$id" "$label" "$path carries no /$re/"
  fi
}

g_assert_count_ge() {
  # g_assert_count_ge <arm-id> <label> <path> <ERE> <min> <named-reason>
  local id="$1" label="$2" path="$3" re="$4" min="$5" why="$6" n
  if [ ! -f "$path" ]; then
    g_unknown "$id" "$label" "cannot read $path — nothing to count"
    return
  fi
  # `grep -c` exits 1 on zero matches, which would abort a pipeline under -e and
  # is why the count is captured and then compared with `test`.
  n="$(grep -cE "$re" "$path")" || n=0
  if [ "$n" -ge "$min" ]; then
    g_clean "$id" "$label" "$n match(es) of /$re/ in $path (need >= $min)"
  else
    g_fail "$id" "$label" "$why (found $n, need >= $min)"
  fi
}

g_require_tool() {
  # g_require_tool <arm-id> <label> <command> <what-it-is-needed-for>
  local id="$1" label="$2" cmd="$3" why="$4"
  if command -v "$cmd" >/dev/null 2>&1; then
    g_clean "$id" "$label" "$cmd found at $(command -v "$cmd")"
  else
    g_unknown "$id" "$label" "$cmd is not installed — $why"
  fi
}

g_require_key() {
  # g_require_key <arm-id> <label> <key-path> <who-owns-it>
  # An answer key the harness does not have is a HARNESS limitation, so its
  # dependent arms are could-not-check, never failed. Naming the owning brief
  # here is what keeps the cap from being silent.
  local id="$1" label="$2" path="$3" owner="$4"
  if [ -f "$path" ]; then
    g_clean "$id" "$label" "$path present"
  else
    g_unknown "$id" "$label" "no key at $path — supplied by $owner, which has not landed"
  fi
}

# --- rollup -----------------------------------------------------------------

g_verdict() {
  local state rc
  if [ "$G_N_UNKNOWN" -gt 0 ]; then
    state=could-not-check; rc=2
  elif [ "$G_N_FAILED" -gt 0 ]; then
    state=checked-failed; rc=1
  else
    state=checked-clean; rc=0
  fi
  printf '\n'
  printf 'VERDICT lesson-%s %s (exit %s)\n' "$G_LESSON" "$state" "$rc"
  printf '  arms: %s checked-clean, %s checked-failed, %s could-not-check, %s blocked\n' \
    "$G_N_CLEAN" "$G_N_FAILED" "$G_N_UNKNOWN" "$G_N_BLOCKED"
  case "$state" in
    could-not-check)
      printf '  This is NOT a fail. The harness could not evaluate every arm; the\n'
      printf '  could-not-check lines above name exactly what it could not read and why.\n' ;;
    checked-failed)
      printf '  Every checked-failed line above names one concrete thing to fix.\n' ;;
  esac
  # Machine-readable last line for CI to parse.
  printf 'GRADE_STATE=%s\n' "$state"
  return "$rc"
}
