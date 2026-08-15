#!/usr/bin/env bash
# ci-step.sh <lesson-number> — the body of the lesson workflows' "Grade" step.
#
# It lives here rather than inline in each lesson-<N>.yml for one reason: shell
# embedded in YAML cannot be run by the selftest, so its own three-state
# translation would be the one unproven link in a harness whose entire claim is
# that it can fail. selftest.sh exercises this file directly.
#
# Contract:
#   stdout        the grader's full output
#   $GITHUB_OUTPUT   state=<checked-clean|checked-failed|could-not-check>
#                    reasons=<the named [checked-failed]/[could-not-check] lines>
#   $GITHUB_STEP_SUMMARY  the same output, fenced
#   exit          ALWAYS 0 — the lesson's state is carried by which downstream
#                 job runs, not by this step. A step that exited non-zero on a
#                 could-not-check would paint the learner's run red for a
#                 shortcoming of the grader.

set -uo pipefail

N="${1:?usage: ci-step.sh <lesson-number>}"
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/$N.sh"
: "${GITHUB_OUTPUT:=/dev/null}"
: "${GITHUB_STEP_SUMMARY:=/dev/null}"

emit_state() { printf 'state=%s\n' "$1" >> "$GITHUB_OUTPUT"; }

if [ ! -f "$SCRIPT" ]; then
  printf '::warning::scripts/grade/%s.sh is missing from this copy - nothing to grade with\n' "$N"
  emit_state could-not-check
  {
    printf 'reasons<<GRADE_EOF\n'
    printf '[could-not-check] harness    scripts/grade/%s.sh is not present in this repository\n' "$N"
    printf 'GRADE_EOF\n'
  } >> "$GITHUB_OUTPUT"
  printf '## Lesson %s - could-not-check\n\nThe grade script is missing from this copy.\n' "$N" \
    >> "$GITHUB_STEP_SUMMARY"
  exit 0
fi

out="$(bash "$SCRIPT" 2>&1)"; rc=$?
printf '%s\n' "$out"

# The state is READ BACK from the grader's own last line rather than inferred
# from $rc, so a future change to either cannot make them disagree in silence.
state="$(printf '%s\n' "$out" | sed -n 's/^GRADE_STATE=//p' | tail -1)"
case "$state" in
  checked-clean|checked-failed|could-not-check) ;;
  *)
    printf '::warning::grader exited %s without a GRADE_STATE line\n' "$rc"
    state=could-not-check
    ;;
esac
emit_state "$state"

{
  printf 'reasons<<GRADE_EOF\n'
  # `grep` here can legitimately match nothing (a clean run), which exits 1;
  # that must not abort the block.
  printf '%s\n' "$out" | grep -E '^\[(checked-failed|could-not-check)\]' || true
  printf 'GRADE_EOF\n'
} >> "$GITHUB_OUTPUT"

{
  printf '## Lesson %s - %s\n\n' "$N" "$state"
  case "$state" in
    could-not-check)
      printf 'This is NOT a fail. The grader could not evaluate part of your tree; the\n'
      printf 'could-not-check lines below name what and why. Neither the complete nor the\n'
      printf 'incomplete job runs for this state, so nothing here is red.\n\n' ;;
  esac
  printf '```\n%s\n```\n' "$out"
} >> "$GITHUB_STEP_SUMMARY"

exit 0
