#!/usr/bin/env bash
# Lesson 2 — "trust the lint".
#
# Completion signal (from the lesson brief education/12): three guided breaks,
# each run through `statusgen --lint` and then reverted, written up in
# lessons/answers/2.md; then one Evidence claim flipped to could-not-check so
# the learner sees the board degrade honestly rather than go red.
#
# ARMS OWNED ELSEWHERE (each renders could-not-check until its owner lands):
#   2.6 breaks-named — needs scripts/grade/keys/2.key, the list of lint rule
#       names the write-up must name. Owned by education/12, because the three
#       breaks are the lesson's to choose.

set -uo pipefail
G_LESSON=2
. "$(dirname "$0")/lib.sh"

NOTES=lessons/answers/2.md
KEY="$(dirname "$0")/keys/2.key"

echo "grading lesson 2 (trust the lint) against $(pwd)"
echo

g_require_tool 2.1 statusgen-available statusgen \
  "lesson 2 grades on the board being lint-clean after your reverts, and only statusgen can say"

if [ "$(g_state_of 2.1)" = clean ]; then
  # Captured, not piped into a counter: a pipeline exits 0 whatever it counted.
  lint_out="$(statusgen --root . --lint 2>&1)"; lint_rc=$?
  if [ "$lint_rc" -eq 0 ]; then
    g_clean 2.2 lint-clean "statusgen --root . --lint exited 0"
  else
    g_fail 2.2 lint-clean \
      "the board is not lint-clean (exit $lint_rc) — revert your three breaks before grading: $(printf '%s' "$lint_out" | head -3 | tr '\n' ' ')"
  fi
  unset lint_out lint_rc
else
  g_blocked 2.2 lint-clean 2.1
fi

g_assert_file 2.3 notes-file "$NOTES" \
  "no write-up — lesson 2 asks you to record what each lint failure said in $NOTES"

if [ "$(g_state_of 2.3)" = clean ]; then
  # Three breaks, three sections, checked individually so a failure names which
  # one is missing.
  for n in 1 2 3; do
    g_assert_matches "2.4.$n" "break-${n}-written-up" "$NOTES" "^## *Break *${n}\b" \
      "no '## Break ${n}' section in $NOTES — record what the lint said and how you reverted it"
  done
  # The three-state flip is the point of the second half of the lesson.
  g_assert_matches 2.5 three-state-flip "$NOTES" 'could-not-check' \
    "$NOTES never records a could-not-check verdict — the second half of lesson 2 is the honest-degradation flip, not another red"
else
  g_blocked 2.4 breaks-written-up 2.3
  g_blocked 2.5 three-state-flip 2.3
fi

g_require_key 2.6k lint-rule-key "$KEY" "education/12 (lesson 2 chooses the three breaks)"
if [ "$(g_state_of 2.3)" != clean ]; then
  # MEASURED, not theorised: without this guard the key loop ran g_assert_matches
  # against a write-up that does not exist, which is could-not-check, which then
  # outranked the checked-failed on arm 2.3 in the rollup. A learner who had done
  # nothing at all was told "could-not-check" instead of "you have not written
  # the file yet" — the mirror image of the harm the exit-2-wins rule exists to
  # prevent. When the subject of an arm is missing BECAUSE the learner has not
  # produced it, that is a finding about the tree, not a limit of the harness.
  g_blocked 2.6 breaks-named 2.3
elif [ "$(g_state_of 2.6k)" = clean ]; then
  # Key format, one extended regex per line; each must appear in the write-up.
  i=0
  while IFS= read -r want; do
    case "$want" in ''|'#'*) continue ;; esac
    i=$((i + 1))
    g_assert_matches "2.6.$i" "lint-rule-named-$i" "$NOTES" "$want" \
      "$NOTES does not name the lint rule that caught break $i"
  done < "$KEY"
  [ "$i" -eq 0 ] && g_unknown 2.6 breaks-named "$KEY is present but declares no patterns"
  unset i
else
  g_blocked 2.6 breaks-named 2.6k
fi

g_verdict
