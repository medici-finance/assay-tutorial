#!/usr/bin/env bash
# Lesson 1 — "read the board".
#
# Completion signal (from the lesson brief education/12): the learner installs
# the pinned statusgen, renders the board, and answers three board-reading
# questions in lessons/answers/1.md.
#
# Grades REPO STATE only. Nothing here reads which agent, model or editor
# produced the tree — that is what makes the tutorial harness-neutral.
#
# ARMS OWNED ELSEWHERE (each renders could-not-check until its owner lands):
#   1.5 answers-correct — needs scripts/grade/keys/1.key, whose contents are
#       derived from the example-app corpus (education/08) and the lesson text
#       (education/12).

set -uo pipefail
G_LESSON=1
. "$(dirname "$0")/lib.sh"

ANSWERS=lessons/answers/1.md
KEY="$(dirname "$0")/keys/1.key"

echo "grading lesson 1 (read the board) against $(pwd)"
echo

g_assert_file 1.1 board-rendered STATUS.md \
  "the board has not been rendered — lesson 1 asks you to run statusgen and commit STATUS.md"

if [ "$(g_state_of 1.1)" = clean ]; then
  g_assert_matches 1.2 board-has-streams STATUS.md '^\| *[0-9]+ *\|' \
    "STATUS.md carries no brief rows — it looks like an empty or placeholder board"
else
  g_blocked 1.2 board-has-streams 1.1
fi

g_assert_file 1.3 answers-file "$ANSWERS" \
  "no answers file — lesson 1 asks you to answer three questions in $ANSWERS"

if [ "$(g_state_of 1.3)" = clean ]; then
  # Three slots, checked one at a time so the failure names WHICH answer is
  # missing rather than reporting a bare count.
  for n in 1 2 3; do
    if ! grep -qE "^## *A${n}\b" "$ANSWERS"; then
      g_fail "1.4.$n" "answer-A${n}" "no '## A${n}' section in $ANSWERS"
      continue
    fi
    # The body of the slot: lines after '## An' up to the next '## '.
    body="$(awk -v want="## A${n}" '
      $0 ~ "^" want "([^0-9]|$)" { grab=1; next }
      grab && /^## / { exit }
      grab { print }
    ' "$ANSWERS" | tr -d '[:space:]')"
    if [ -z "$body" ]; then
      g_fail "1.4.$n" "answer-A${n}" "the '## A${n}' section in $ANSWERS is empty"
    elif printf '%s' "$body" | grep -qiE 'YOURANSWERHERE|TODO|FIXME|\.\.\.\.'; then
      g_fail "1.4.$n" "answer-A${n}" "the '## A${n}' section in $ANSWERS still holds the template placeholder"
    else
      g_clean "1.4.$n" "answer-A${n}" "answered (${#body} non-space chars)"
    fi
  done
else
  g_blocked 1.4 answers-filled 1.3
fi

g_require_key 1.5k answer-key "$KEY" "education/08 (corpus) + education/12 (lesson 1)"
if [ "$(g_state_of 1.3)" != clean ]; then
  # Same guard as 2.sh/4.sh: an answers file the learner never wrote is a
  # finding about the tree, not a limit of the harness, so it must not be
  # allowed to reach the key loop and surface as could-not-check.
  g_blocked 1.5 answers-correct 1.3
elif [ "$(g_state_of 1.5k)" = clean ]; then
  # Key format, one per line: A<n>=<extended regex the answer must match>
  # The key is TEMPLATE-side; the answers are LEARNER-side. They are different
  # files on purpose: a check whose fixture supplies its own answer grades
  # nothing.
  nkey=0
  while IFS= read -r line; do
    case "$line" in ''|'#'*) continue ;; esac
    slot="${line%%=*}"; want="${line#*=}"
    nkey=$((nkey + 1))
    got="$(awk -v want="## ${slot}" '
      $0 ~ "^" want "([^0-9]|$)" { grab=1; next }
      grab && /^## / { exit }
      grab { print }
    ' "$ANSWERS" 2>/dev/null)"
    if [ -z "$got" ]; then
      g_fail "1.5.$slot" "answer-${slot}-correct" "nothing to grade in $ANSWERS for ${slot}"
    elif printf '%s' "$got" | grep -qiE "$want"; then
      g_clean "1.5.$slot" "answer-${slot}-correct" "matches the key"
    else
      g_fail "1.5.$slot" "answer-${slot}-correct" "does not match the key for ${slot}"
    fi
  done < "$KEY"
  if [ "$nkey" -eq 0 ]; then
    g_unknown 1.5 answers-correct "$KEY is present but declares no A<n>= lines"
  fi
else
  g_blocked 1.5 answers-correct 1.5k
fi

g_verdict
