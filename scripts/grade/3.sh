#!/usr/bin/env bash
# Lesson 3 — "author and ship one brief".
#
# Completion signal (from the lesson brief education/13): the learner authors a
# brief with runnable Verify rows, drives ANY agent to implement it in an
# isolated workspace, stops at `implemented`, and opens a DRAFT PR. The grade
# script asserts the brief lints, its Verify rows are literal commands, the PR
# is draft, and the lifecycle cell says implemented and NOT verified —
# self-verification is the anti-lesson.
#
# ARMS OWNED ELSEWHERE (each renders could-not-check until its owner lands):
#   3.2 brief-is-new — needs scripts/grade/baseline/briefs.txt, the list of
#       briefs SHIPPED with the template. Owned by education/08, which is the
#       brief that creates the corpus there is currently none of. Without it the
#       harness cannot tell the learner's brief from a shipped one, so it cannot
#       name the file the rest of the arms should read.
#
# ENVIRONMENT ARMS (could-not-check off-Actions or without network):
#   3.6 pr-draft — needs `gh` and a reachable API.
#   3.7 lint     — needs the pinned statusgen from .assay-versions.

set -uo pipefail
G_LESSON=3
. "$(dirname "$0")/lib.sh"

BASELINE="$(dirname "$0")/baseline/briefs.txt"

echo "grading lesson 3 (author and ship one brief) against $(pwd)"
echo

if [ ! -d docs/streams ]; then
  g_fail 3.1 brief-present "no docs/streams/ directory — lesson 3 asks you to author a brief under docs/streams/<stream>/"
  ALL_BRIEFS=""
else
  ALL_BRIEFS="$(find docs/streams -type f -name 'brief-*.md' 2>/dev/null | LC_ALL=C sort)"
  if [ -n "$ALL_BRIEFS" ]; then
    g_clean 3.1 brief-present "$(printf '%s\n' "$ALL_BRIEFS" | grep -c .) brief file(s) under docs/streams/"
  else
    g_fail 3.1 brief-present "no brief-*.md under docs/streams/ — lesson 3 asks you to author one"
  fi
fi

# --- which brief is the LEARNER's? ------------------------------------------
LEARNER_BRIEF=""
if [ ! -f "$BASELINE" ]; then
  g_unknown 3.2 brief-is-new \
    "no baseline at $BASELINE (shipped-brief list, owned by education/08) — the harness cannot tell your brief from a shipped one"
elif [ -z "$ALL_BRIEFS" ]; then
  g_blocked 3.2 brief-is-new 3.1
else
  NEW=""
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if ! grep -qxF "$f" "$BASELINE"; then
      NEW="${NEW}${f}
"
    fi
  done <<EOF
$ALL_BRIEFS
EOF
  n_new="$(printf '%s' "$NEW" | grep -c . )"
  if [ "$n_new" -eq 1 ]; then
    LEARNER_BRIEF="$(printf '%s' "$NEW" | head -1)"
    g_clean 3.2 brief-is-new "your brief: $LEARNER_BRIEF"
  elif [ "$n_new" -eq 0 ]; then
    g_fail 3.2 brief-is-new "every brief under docs/streams/ is one the template shipped — none of them is yours"
  else
    LEARNER_BRIEF="$(printf '%s' "$NEW" | head -1)"
    g_fail 3.2 brief-is-new "$n_new briefs are new, not 1 — lesson 3 ships exactly one; grading the first ($LEARNER_BRIEF)"
  fi
  unset NEW n_new
fi

# --- the brief's own shape --------------------------------------------------
if [ -n "$LEARNER_BRIEF" ]; then
  # A Verify table row whose Command cell holds a backticked literal command.
  # `grep -c` is captured and compared with `test`; a pipeline into `wc` would
  # exit 0 whatever it counted.
  g_assert_count_ge 3.3 verify-rows-literal "$LEARNER_BRIEF" '^\| *[0-9]+ *\| *`[^`]+` *\|' 1 \
    "no Verify row in $LEARNER_BRIEF carries a backticked literal command — a row with no command is a hope, not a DoD item"
  g_assert_matches 3.3b verify-section "$LEARNER_BRIEF" '^## +Verify' \
    "$LEARNER_BRIEF has no '## Verify' section"
  for field in brief title wave effort gate; do
    g_assert_matches "3.4.$field" "frontmatter-$field" "$LEARNER_BRIEF" "^${field}:" \
      "$LEARNER_BRIEF frontmatter has no '${field}:' key"
  done
else
  g_blocked 3.3 verify-rows-literal 3.2
  g_blocked 3.4 frontmatter 3.2
fi

# --- the lifecycle cell -----------------------------------------------------
if [ -n "$LEARNER_BRIEF" ]; then
  README="$(dirname "$LEARNER_BRIEF")/README.md"
  BASE="$(basename "$LEARNER_BRIEF")"
  if [ ! -f "$README" ]; then
    g_unknown 3.5 board-row "no $README to read the lifecycle cell out of"
    g_blocked 3.5b not-self-verified 3.5
  else
    ROW="$(grep -F "$BASE" "$README" | grep -E '^\|' | head -1)"
    if [ -z "$ROW" ]; then
      g_fail 3.5 board-row "$README has no table row linking $BASE — an unlisted brief is invisible to the board"
      g_blocked 3.5b not-self-verified 3.5
    else
      if printf '%s' "$ROW" | grep -qE '\| *implemented *\|'; then
        g_clean 3.5 board-row "the row for $BASE says implemented"
      else
        g_fail 3.5 board-row "the row for $BASE does not say implemented — lesson 3 stops at implemented"
      fi
      # The anti-lesson arm: the implementer must NOT have stamped verified.
      if printf '%s' "$ROW" | grep -qE '\| *(2[0-9]{3}-[0-9]{2}-[0-9]{2}|verified|done)'; then
        g_fail 3.5b not-self-verified \
          "the row for $BASE carries a verified/done stamp — you implemented it, so you are not its verifier. Set the cell back to an em dash."
      else
        g_clean 3.5b not-self-verified "Verified cell is unstamped, as lesson 3 requires"
      fi
    fi
    unset ROW
  fi
  unset README BASE
else
  g_blocked 3.5 board-row 3.2
  g_blocked 3.5b not-self-verified 3.2
fi

# --- the draft PR -----------------------------------------------------------
g_require_tool 3.6t gh-available gh "the draft-PR arm reads the PR through the GitHub API"
if [ "$(g_state_of 3.6t)" != clean ]; then
  g_blocked 3.6 pr-draft 3.6t
else
  # `git branch --show-current`, not `rev-parse --abbrev-ref HEAD`: the latter
  # exits 128 with empty output on an unborn branch, which would render an
  # ordinary fresh repo as could-not-check.
  BRANCH="$(git branch --show-current 2>/dev/null)"
  if [ -z "$BRANCH" ] || [ "$BRANCH" = HEAD ]; then
    g_unknown 3.6 pr-draft "cannot determine the current branch — no PR to look up"
  else
    PRJSON="$(gh pr list --head "$BRANCH" --state all --json number,isDraft --limit 1 2>/dev/null)"; prrc=$?
    if [ "$prrc" -ne 0 ] || [ -z "$PRJSON" ]; then
      g_unknown 3.6 pr-draft "the GitHub API could not be reached (gh exit $prrc) — the PR's draft state is unknown, not wrong"
    elif [ "$PRJSON" = "[]" ]; then
      g_fail 3.6 pr-draft "no PR open from branch $BRANCH — lesson 3 ends with a DRAFT PR"
    elif printf '%s' "$PRJSON" | grep -q '"isDraft":true'; then
      g_clean 3.6 pr-draft "the PR from $BRANCH is a draft"
    else
      g_fail 3.6 pr-draft "the PR from $BRANCH is not a draft — you stop at implemented; the flip to ready is a review decision, not yours"
    fi
    unset PRJSON prrc
  fi
  unset BRANCH
fi

# --- the lint ---------------------------------------------------------------
g_require_tool 3.7t statusgen-available statusgen "the brief must pass the same lint the board runs"
if [ "$(g_state_of 3.7t)" != clean ]; then
  g_blocked 3.7 lint 3.7t
else
  lint_out="$(statusgen --root . --lint 2>&1)"; lint_rc=$?
  if [ "$lint_rc" -eq 0 ]; then
    g_clean 3.7 lint "statusgen --root . --lint exited 0"
  else
    g_fail 3.7 lint "the lint rejects your brief (exit $lint_rc): $(printf '%s' "$lint_out" | head -3 | tr '\n' ' ')"
  fi
  unset lint_out lint_rc
fi

g_verdict
