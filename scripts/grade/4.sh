#!/usr/bin/env bash
# Lesson 4 — "verify someone else's work + run a small wave".
#
# Completion signal (from the lesson brief education/14):
#   Part A — review the seeded almost-right PR, render checked-clean /
#            checked-failed / could-not-check per Verify row, file the finding
#            in the corpus FINDINGS register.
#   Part B — run a two-brief wave, merge as the human, then verify AS
#            NON-IMPLEMENTER: re-run the Verify tables, fill Evidence, flip the
#            cells. The runner on the verify witness must differ from the runner
#            on the implement witness — that difference IS the lesson.
#
# ARMS OWNED ELSEWHERE (each renders could-not-check until its owner lands):
#   4.3 findings-entry  — needs findings-path= in scripts/grade/keys/4.key; the
#       register's path is the corpus's (education/08), and the seeded defect is
#       education/11's.
#   4.6 verdicts-match-key — needs verdict= lines in the same key file; the
#       answer key for the seeded PR is education/11's deliverable.

set -uo pipefail
G_LESSON=4
. "$(dirname "$0")/lib.sh"

VERDICTS=lessons/answers/4.md
KEY="$(dirname "$0")/keys/4.key"

echo "grading lesson 4 (verify + run a wave) against $(pwd)"
echo

# --- Part A: the verdicts ---------------------------------------------------
g_assert_file 4.1 verdicts-file "$VERDICTS" \
  "no verdicts file — lesson 4 asks you to record a per-row verdict in $VERDICTS"

if [ "$(g_state_of 4.1)" = clean ]; then
  # Three separate patterns, never one alternation: in a BASIC regex `|` is an
  # ordinary character, and the markdown escape `\|` renders as a bare `|`, so
  # an alternation written in a table cell is a different command on the page
  # than in the source. Three -e patterns read the same in both.
  i=0
  for state in checked-clean checked-failed could-not-check; do
    i=$((i + 1))
    g_assert_matches "4.2.$i" "three-state-$state" "$VERDICTS" "$state" \
      "$VERDICTS never renders '$state' — a two-state review cannot say 'I could not tell', which is the verdict lesson 4 exists to teach"
  done
  unset i state
  g_assert_count_ge 4.2r reproducing-commands "$VERDICTS" '`[^`]+`' 1 \
    "$VERDICTS carries no backticked reproducing command — a verdict nobody can re-run is an opinion"
else
  g_blocked 4.2 three-state-vocab 4.1
  g_blocked 4.2r reproducing-commands 4.1
fi

# --- Part A: the filed finding ----------------------------------------------
FINDINGS=""
if [ -f "$KEY" ]; then
  FINDINGS="$(grep -E '^findings-path=' "$KEY" 2>/dev/null | head -1)"
  FINDINGS="${FINDINGS#findings-path=}"
fi
if [ -z "$FINDINGS" ]; then
  g_unknown 4.3 findings-entry \
    "no findings-path= in $KEY (owned by education/08 corpus + education/11 seeded PR) — the harness does not know which register to read"
elif [ ! -f "$FINDINGS" ]; then
  g_fail 4.3 findings-entry "the FINDINGS register at $FINDINGS does not exist in your copy"
else
  g_assert_count_ge 4.3 findings-entry "$FINDINGS" '^\| *F-' 1 \
    "no F- entry in $FINDINGS — part A ends by FILING the finding, not just noticing it"
fi

# --- Part B: the wave, and the non-implementer rule --------------------------
if [ ! -d docs/streams ]; then
  g_fail 4.4 two-verified-cells "no docs/streams/ — there is no board for the wave to have moved"
  g_blocked 4.5 verifier-not-implementer 4.4
else
  VERIFIED_BRIEFS=""
  n_verified=0
  for readme in $(find docs/streams -type f -name README.md 2>/dev/null | LC_ALL=C sort); do
    dir="$(dirname "$readme")"
    while IFS= read -r row; do
      # Status cell is `verified` or `done`; pull the linked brief filename out
      # of the same row.
      case "$row" in
        *'| verified |'*|*'| done |'*) ;;
        *) continue ;;
      esac
      f="$(printf '%s' "$row" | sed -n 's/.*(\.\/\(brief-[^)]*\.md\)).*/\1/p')"
      [ -n "$f" ] || continue
      [ -f "$dir/$f" ] || continue
      n_verified=$((n_verified + 1))
      VERIFIED_BRIEFS="${VERIFIED_BRIEFS}${dir}/${f}
"
    done < "$readme"
  done
  if [ "$n_verified" -ge 2 ]; then
    g_clean 4.4 two-verified-cells "$n_verified brief row(s) carry a verified/done cell"
  else
    g_fail 4.4 two-verified-cells \
      "found $n_verified verified/done row(s), need 2 — part B ends with BOTH wave briefs verified by you as non-implementer"
  fi

  if [ "$n_verified" -eq 0 ]; then
    g_blocked 4.5 verifier-not-implementer 4.4
  else
    j=0
    while IFS= read -r b; do
      [ -n "$b" ] || continue
      j=$((j + 1))
      # Runner is the last cell of an Evidence witness row. Extract the section
      # first so a Verify-table row can never be mistaken for a witness.
      runners="$(awk '/^## +Evidence/{grab=1;next} grab && /^## /{exit} grab' "$b" \
        | grep -E '^\|' \
        | sed -e 's/ *| *$//' -e 's/.*| *//' \
        | grep -vE '^(Runner|-+)$' \
        | LC_ALL=C sort -u \
        | grep -c .)"
      if [ "$runners" -ge 2 ]; then
        g_clean "4.5.$j" "verifier-not-implementer" "$b: $runners distinct Evidence runners"
      elif [ "$runners" -eq 0 ]; then
        g_fail "4.5.$j" "verifier-not-implementer" \
          "$b is marked verified but its Evidence section holds no witness row — a verified cell with no witness is a claim, not a check"
      else
        g_fail "4.5.$j" "verifier-not-implementer" \
          "$b has only $runners Evidence runner — the verify run must be recorded by someone other than the implement run. You are the human here; that asymmetry is the lesson."
      fi
    done <<EOF
$VERIFIED_BRIEFS
EOF
    unset j runners
  fi
  unset VERIFIED_BRIEFS n_verified
fi

# --- Part A: verdicts against education/11's answer key ----------------------
if [ "$(g_state_of 4.1)" != clean ]; then
  # See the same guard in 2.sh: grading the key against a verdicts file the
  # learner never wrote produces could-not-check, which then outranks the
  # checked-failed on arm 4.1 and tells a learner who did nothing that the
  # harness could not read their tree. It could; there was nothing there.
  g_blocked 4.6 verdicts-match-key 4.1
elif [ ! -f "$KEY" ]; then
  g_unknown 4.6 verdicts-match-key \
    "no key at $KEY — the answer key for the seeded PR is education/11's deliverable, which has not landed"
else
  k=0
  while IFS= read -r line; do
    case "$line" in ''|'#'*|findings-path=*) continue ;; esac
    case "$line" in verdict=*) ;; *) continue ;; esac
    k=$((k + 1))
    g_assert_matches "4.6.$k" "verdict-$k" "$VERDICTS" "${line#verdict=}" \
      "$VERDICTS does not carry the verdict the answer key expects for defect $k"
  done < "$KEY"
  if [ "$k" -eq 0 ]; then
    g_unknown 4.6 verdicts-match-key "$KEY declares no verdict= lines — education/11's answer key has not been transcribed into it"
  fi
  unset k
fi

g_verdict
