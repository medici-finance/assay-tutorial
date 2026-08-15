#!/usr/bin/env bash
# selftest.sh — proof that the graders can FAIL.
#
# A grading harness is a check that grades checks, so every way a check can lie
# applies to it twice over. This file is the evidence that they do not:
#
#   POSITIVE CONTROLS  For each lesson, an INCOMPLETE submission that must grade
#                      checked-failed and a COMPLETE one that must grade
#                      checked-clean. A grader that cannot tell those two apart
#                      grades nothing.
#   COULD-NOT-CHECK    For each lesson, a tree the harness genuinely cannot
#                      evaluate (no answer key / no tool), which must grade
#                      could-not-check — never "fail", never "pass".
#   MUTATION TESTS     For each graded ARM, one mutation of the COMPLETE fixture
#                      that must redden THAT ARM BY NAME. Asserting only the exit
#                      code would let one arm's red stand in for another's.
#
# Every expectation names the arm. A mutation that reddens the run but not its
# own arm is reported as a FAILURE of this selftest, because that is the shape
# where a check passes for the wrong reason.
#
# Run:  bash scripts/grade/selftest.sh        (from the repo root)
# Exit: 0 all expectations held / 1 at least one did not.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/grade-selftest.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0

say()  { printf '%s\n' "$*"; }
ok()   { PASS=$((PASS + 1)); printf '  ok    %s\n' "$*"; }
bad()  { FAIL=$((FAIL + 1)); printf '  FAIL  %s\n' "$*"; }

# ---------------------------------------------------------------------------
# stub tools. `statusgen` and `gh` are not installed on a bare machine, and a
# lesson arm that depends on them renders could-not-check. The stubs let the
# selftest exercise the CLEAN and FAILED arms too; the could-not-check arm is
# tested by taking the stub away again.
# ---------------------------------------------------------------------------
STUBS="$WORK/stubs"
mkdir -p "$STUBS"
cat > "$STUBS/statusgen" <<'STUB'
#!/bin/sh
[ "${STUB_STATUSGEN_RC:-0}" = 0 ] || echo "lint: fixture-forced failure" >&2
exit "${STUB_STATUSGEN_RC:-0}"
STUB
cat > "$STUBS/gh" <<'STUB'
#!/bin/sh
case "${STUB_GH_MODE:-draft}" in
  draft)    echo '[{"number":1,"isDraft":true}]'  ;;
  ready)    echo '[{"number":1,"isDraft":false}]' ;;
  none)     echo '[]'                             ;;
  offline)  echo "could not resolve host" >&2; exit 1 ;;
esac
STUB
chmod +x "$STUBS/statusgen" "$STUBS/gh"

# ---------------------------------------------------------------------------
# run <fixture-dir> <lesson> -> prints grader output, sets RC
# ---------------------------------------------------------------------------
RC=0
OUT=""
run() {
  local dir="$1" lesson="$2"
  OUT="$(cd "$dir" && PATH="$STUB_PATH" bash scripts/grade/"$lesson".sh 2>&1)"
  RC=$?
}

expect_rc() {
  local what="$1" want="$2"
  if [ "$RC" -eq "$want" ]; then ok "$what -> exit $RC"
  else bad "$what -> exit $RC, expected $want"; printf '%s\n' "$OUT" | sed 's/^/        /'; fi
}

expect_arm() {
  # expect_arm <what> <state> <arm-id>
  local what="$1" state="$2" arm="$3"
  if printf '%s\n' "$OUT" | grep -qE "^\[$state\][[:space:]]+$(printf '%s' "$arm" | sed 's/\./\\./g')[[:space:]]"; then
    ok "$what -> arm $arm is $state"
  else
    bad "$what -> arm $arm is NOT $state"
    printf '%s\n' "$OUT" | grep -E "[[:space:]]$(printf '%s' "$arm" | sed 's/\./\\./g')[[:space:]]" | sed 's/^/        /'
  fi
}

expect_verdict() {
  local what="$1" want="$2"
  if printf '%s\n' "$OUT" | grep -qx "GRADE_STATE=$want"; then ok "$what -> GRADE_STATE=$want"
  else bad "$what -> GRADE_STATE is not $want"; fi
}

# ---------------------------------------------------------------------------
# fixture scaffolding
# ---------------------------------------------------------------------------
die() { printf '\nSELFTEST COULD-NOT-RUN: %s\n' "$*" >&2; exit 2; }

newfix() {
  # newfix <name> -> prints the path; copies the REAL grade scripts in, so the
  # selftest can never drift from the shipped ones.
  #
  # Aborts the whole run rather than continuing on a scaffolding error. MEASURED:
  # a full disk made three mkdir/cp calls fail, the fixtures came out empty, and
  # the mutations that depended on them were reported as "arm 4.5.1 is NOT
  # checked-failed" — i.e. as a defect in the GRADER. A selftest that cannot
  # build its own fixture has not measured the grader; it must say so, not
  # convert its own breakage into a finding about the thing under test.
  local d="$WORK/$1"
  rm -rf "$d"
  mkdir -p "$d/scripts/grade" || die "cannot create fixture $1 (disk full?)"
  cp "$HERE"/lib.sh "$HERE"/ci-step.sh "$HERE"/1.sh "$HERE"/2.sh "$HERE"/3.sh "$HERE"/4.sh "$d/scripts/grade/" \
    || die "cannot populate fixture $1 (disk full?)"
  printf '%s' "$d"
}

STUB_PATH="$STUBS:$PATH"

say "=== lib.sh — the primitives themselves ====================================="

# The measured trap this exists to close: `grep PATTERN missing-file` exits 2 and
# prints NOTHING, so an assertion phrased "the output must be empty" is satisfied
# BY THE ERROR and reports clean having measured nothing. Case (c) below is that
# exact tree, and it must render could-not-check.
LIBFIX="$(newfix lib-primitives)"
mkdir -p "$LIBFIX/lessons" || die "cannot build the lib fixture"
printf 'a line with FORBIDDEN in it\n' > "$LIBFIX/has.md"
printf 'a clean line\n'                > "$LIBFIX/hasnt.md"
cat > "$LIBFIX/libprobe.sh" <<'PROBE'
set -uo pipefail
G_LESSON=lib
. scripts/grade/lib.sh
g_assert_absent L.a absent-when-present has.md   'FORBIDDEN' 'the token is there'
g_assert_absent L.b absent-when-absent  hasnt.md 'FORBIDDEN' 'the token is there'
g_assert_absent L.c absent-in-missing   gone.md  'FORBIDDEN' 'the token is there'
g_assert_matches L.d match-in-missing   gone.md  'anything'  'no match'
g_assert_count_ge L.e count-in-missing  gone.md  'anything' 1 'too few'
g_verdict
PROBE
OUT="$(cd "$LIBFIX" && bash libprobe.sh 2>&1)"; RC=$?
expect_arm "lib g_assert_absent, token present"  checked-failed  L.a
expect_arm "lib g_assert_absent, token absent"   checked-clean   L.b
expect_arm "lib g_assert_absent, FILE MISSING"   could-not-check L.c
expect_arm "lib g_assert_matches, FILE MISSING"  could-not-check L.d
expect_arm "lib g_assert_count_ge, FILE MISSING" could-not-check L.e
expect_rc  "lib primitives on a missing subject" 2

say ""
say "=== lesson 1 — read the board ==============================================="

mk_l1() {
  local d; d="$(newfix "$1")"
  mkdir -p "$d/lessons/answers" "$d/scripts/grade/keys"
  cat > "$d/scripts/grade/keys/1.key" <<'K'
# answer key — TEMPLATE side. The learner's answers live in lessons/answers/1.md.
A1=three
A2=ground-truth/02
A3=could-not-check
K
  printf '%s' "$d"
}

# -- incomplete: nothing done -----------------------------------------------
D="$(mk_l1 l1-incomplete)"
run "$D" 1
expect_rc      "lesson1 incomplete" 1
expect_verdict "lesson1 incomplete" checked-failed
expect_arm     "lesson1 incomplete" checked-failed 1.1
expect_arm     "lesson1 incomplete" checked-failed 1.3
expect_arm     "lesson1 incomplete" blocked 1.2

# -- complete ----------------------------------------------------------------
mk_l1_complete() {
  local d; d="$(mk_l1 "$1")"
  cat > "$d/STATUS.md" <<'M'
# Board
| # | Brief | Status |
|---|-------|--------|
| 1 | [a](./a.md) | todo |
M
  cat > "$d/lessons/answers/1.md" <<'M'
# Lesson 1 answers

## A1
three streams are active.

## A2
the next-up brief is ground-truth/02.

## A3
the cell renders could-not-check.
M
  printf '%s' "$d"
}
D="$(mk_l1_complete l1-complete)"
run "$D" 1
expect_rc      "lesson1 complete" 0
expect_verdict "lesson1 complete" checked-clean

# -- could-not-check: no answer key -----------------------------------------
D="$(mk_l1_complete l1-nokey)"; rm -f "$D/scripts/grade/keys/1.key"
run "$D" 1
expect_rc      "lesson1 no-key" 2
expect_verdict "lesson1 no-key" could-not-check
expect_arm     "lesson1 no-key" could-not-check 1.5k

# -- mutations ---------------------------------------------------------------
D="$(mk_l1_complete l1-m1)"; rm -f "$D/STATUS.md"
run "$D" 1; expect_arm "lesson1 MUT board removed" checked-failed 1.1

D="$(mk_l1_complete l1-m2)"; printf '# Board\nno rows here\n' > "$D/STATUS.md"
run "$D" 1; expect_arm "lesson1 MUT board empty" checked-failed 1.2

D="$(mk_l1_complete l1-m3)"
perl -0pi -e 's/## A2\nthe next-up brief is ground-truth\/02\./## A2\n/' "$D/lessons/answers/1.md"
run "$D" 1; expect_arm "lesson1 MUT A2 blanked" checked-failed 1.4.2

D="$(mk_l1_complete l1-m4)"
perl -0pi -e 's/three streams are active\./TODO/' "$D/lessons/answers/1.md"
run "$D" 1; expect_arm "lesson1 MUT A1 left as placeholder" checked-failed 1.4.1

D="$(mk_l1_complete l1-m5)"
perl -0pi -e 's/the cell renders could-not-check\./the cell renders red./' "$D/lessons/answers/1.md"
run "$D" 1; expect_arm "lesson1 MUT A3 wrong answer" checked-failed 1.5.A3

# The key must be READ, not decorative: change the KEY alone and the previously
# clean answer must redden. Without this, a key file that is never consulted
# would pass every test above.
D="$(mk_l1_complete l1-m6)"
perl -pi -e 's/^A1=three$/A1=seventeen/' "$D/scripts/grade/keys/1.key"
run "$D" 1; expect_arm "lesson1 MUT key changed (proves the key is read)" checked-failed 1.5.A1

say ""
say "=== lesson 2 — trust the lint =============================================="

mk_l2() {
  local d; d="$(newfix "$1")"
  mkdir -p "$d/lessons/answers" "$d/scripts/grade/keys"
  cat > "$d/scripts/grade/keys/2.key" <<'K'
# one extended regex per line; each must appear in lessons/answers/2.md
missing-verify-row
checkmark-DoD
sequence-contiguity
K
  printf '%s' "$d"
}
mk_l2_complete() {
  local d; d="$(mk_l2 "$1")"
  cat > "$d/lessons/answers/2.md" <<'M'
# Lesson 2 write-up

## Break 1
Deleted a Verify row. The lint said missing-verify-row. Reverted.

## Break 2
Marked a cell with a bare tick. The lint said checkmark-DoD. Reverted.

## Break 3
Renumbered a register entry. The lint said sequence-contiguity. Reverted.

## The flip
Flipped one Evidence claim and the cell rendered could-not-check, not red.
M
  printf '%s' "$d"
}

D="$(mk_l2 l2-incomplete)"
run "$D" 2
expect_rc      "lesson2 incomplete" 1
expect_verdict "lesson2 incomplete" checked-failed
expect_arm     "lesson2 incomplete" checked-failed 2.3
expect_arm     "lesson2 incomplete" checked-clean 2.2

D="$(mk_l2_complete l2-complete)"
run "$D" 2
expect_rc      "lesson2 complete" 0
expect_verdict "lesson2 complete" checked-clean

# could-not-check: statusgen not installed
D="$(mk_l2_complete l2-notool)"
OUT="$(cd "$D" && PATH="/usr/bin:/bin" bash scripts/grade/2.sh 2>&1)"; RC=$?
expect_rc      "lesson2 no statusgen" 2
expect_verdict "lesson2 no statusgen" could-not-check
expect_arm     "lesson2 no statusgen" could-not-check 2.1
expect_arm     "lesson2 no statusgen" could-not-check 2.2

# mutations
D="$(mk_l2_complete l2-m1)"
OUT="$(cd "$D" && PATH="$STUB_PATH" STUB_STATUSGEN_RC=1 bash scripts/grade/2.sh 2>&1)"; RC=$?
expect_arm "lesson2 MUT lint red" checked-failed 2.2
expect_rc  "lesson2 MUT lint red" 1

D="$(mk_l2_complete l2-m2)"; perl -pi -e 's/^## Break 2$/## Notes/' "$D/lessons/answers/2.md"
run "$D" 2; expect_arm "lesson2 MUT break 2 unwritten" checked-failed 2.4.2

D="$(mk_l2_complete l2-m3)"; perl -pi -e 's/could-not-check, not red/red/' "$D/lessons/answers/2.md"
run "$D" 2; expect_arm "lesson2 MUT three-state flip missing" checked-failed 2.5

D="$(mk_l2_complete l2-m4)"; perl -pi -e 's/sequence-contiguity/RENUMBERED/' "$D/lessons/answers/2.md"
run "$D" 2; expect_arm "lesson2 MUT lint rule 3 unnamed" checked-failed 2.6.3

D="$(mk_l2_complete l2-m5)"; perl -pi -e 's/^checkmark-DoD$/bare-tick-cell/' "$D/scripts/grade/keys/2.key"
run "$D" 2; expect_arm "lesson2 MUT key changed (proves the key is read)" checked-failed 2.6.2

say ""
say "=== lesson 3 — author and ship one brief ==================================="

mk_l3() {
  local d; d="$(newfix "$1")"
  mkdir -p "$d/docs/streams/example-app" "$d/scripts/grade/baseline"
  cat > "$d/docs/streams/example-app/brief-01-shipped.md" <<'M'
---
brief: example-app/01
title: a brief the template shipped
wave: 0
effort: S
gate: model
---
# Brief 01
## Verify
| # | Command | Expect |
|---|---------|--------|
| 1 | `test -f README.md` | exit 0 |
M
  printf 'docs/streams/example-app/brief-01-shipped.md\n' \
    > "$d/scripts/grade/baseline/briefs.txt"
  ( cd "$d" && git init -q . && git symbolic-ref HEAD refs/heads/lesson-3 )
  printf '%s' "$d"
}
mk_l3_complete() {
  local d; d="$(mk_l3 "$1")"
  cat > "$d/docs/streams/example-app/brief-02-learner.md" <<'M'
---
brief: example-app/02
title: the brief the learner authored
wave: 1
effort: S
gate: model
---
# Brief 02
## Verify
| # | Command | Expect |
|---|---------|--------|
| 1 | `test -f example-app/go.mod` | exit 0 |
M
  cat > "$d/docs/streams/example-app/README.md" <<'M'
# example-app

| # | Brief | Wave | Effort | Status | Verified | Reviewed |
|---|-------|------|--------|--------|----------|----------|
| 01 | [shipped](./brief-01-shipped.md) | 0 | S | done | 2026-01-01 someone | 2026-01-01 someone |
| 02 | [learner](./brief-02-learner.md) | 1 | S | implemented | — | — |
M
  printf '%s' "$d"
}

D="$(mk_l3 l3-incomplete)"
run "$D" 3
expect_rc      "lesson3 incomplete" 1
expect_verdict "lesson3 incomplete" checked-failed
expect_arm     "lesson3 incomplete" checked-failed 3.2
expect_arm     "lesson3 incomplete" blocked 3.3

D="$(mk_l3_complete l3-complete)"
run "$D" 3
expect_rc      "lesson3 complete" 0
expect_verdict "lesson3 complete" checked-clean

# could-not-check: no baseline -> the harness cannot identify the learner's brief
D="$(mk_l3_complete l3-nobaseline)"; rm -f "$D/scripts/grade/baseline/briefs.txt"
run "$D" 3
expect_rc      "lesson3 no baseline" 2
expect_verdict "lesson3 no baseline" could-not-check
expect_arm     "lesson3 no baseline" could-not-check 3.2

# could-not-check: no gh
D="$(mk_l3_complete l3-nogh)"
OUT="$(cd "$D" && PATH="$STUBS/nonexistent:/usr/bin:/bin" bash scripts/grade/3.sh 2>&1)"; RC=$?
expect_rc      "lesson3 no gh/statusgen" 2
expect_verdict "lesson3 no gh/statusgen" could-not-check
expect_arm     "lesson3 no gh/statusgen" could-not-check 3.6t

# could-not-check: gh present but the API unreachable — an offline learner must
# not be told their PR is not a draft.
D="$(mk_l3_complete l3-offline)"
OUT="$(cd "$D" && PATH="$STUB_PATH" STUB_GH_MODE=offline bash scripts/grade/3.sh 2>&1)"; RC=$?
expect_arm     "lesson3 gh offline" could-not-check 3.6
expect_verdict "lesson3 gh offline" could-not-check

# mutations
D="$(mk_l3_complete l3-m1)"
OUT="$(cd "$D" && PATH="$STUB_PATH" STUB_GH_MODE=ready bash scripts/grade/3.sh 2>&1)"; RC=$?
expect_arm "lesson3 MUT PR flipped ready" checked-failed 3.6
expect_rc  "lesson3 MUT PR flipped ready" 1

D="$(mk_l3_complete l3-m2)"
OUT="$(cd "$D" && PATH="$STUB_PATH" STUB_GH_MODE=none bash scripts/grade/3.sh 2>&1)"; RC=$?
expect_arm "lesson3 MUT no PR at all" checked-failed 3.6

D="$(mk_l3_complete l3-m3)"
perl -pi -e 's/\| 1 \| S \| implemented \| — \| — \|/| 1 | S | verified | 2026-01-02 me | — |/' \
  "$D/docs/streams/example-app/README.md"
run "$D" 3
expect_arm "lesson3 MUT learner self-verified" checked-failed 3.5b
expect_arm "lesson3 MUT learner self-verified" checked-failed 3.5

D="$(mk_l3_complete l3-m4)"
perl -pi -e 's/`test -f example-app\/go\.mod`/test -f example-app\/go.mod/' \
  "$D/docs/streams/example-app/brief-02-learner.md"
run "$D" 3; expect_arm "lesson3 MUT Verify command not literal" checked-failed 3.3

# ADDED field, not renamed: renaming `gate:` would also change what the fixture
# IS, and a red that comes from the fixture rather than the assertion proves
# nothing. Deleting the key the arm names is the narrow mutation.
D="$(mk_l3_complete l3-m5)"
perl -ni -e 'print unless /^gate: model$/' "$D/docs/streams/example-app/brief-02-learner.md"
run "$D" 3; expect_arm "lesson3 MUT frontmatter gate removed" checked-failed 3.4.gate

D="$(mk_l3_complete l3-m6)"
OUT="$(cd "$D" && PATH="$STUB_PATH" STUB_STATUSGEN_RC=1 bash scripts/grade/3.sh 2>&1)"; RC=$?
expect_arm "lesson3 MUT lint red" checked-failed 3.7

D="$(mk_l3_complete l3-m7)"; rm -f "$D/docs/streams/example-app/README.md"
run "$D" 3; expect_arm "lesson3 MUT brief not on the board" could-not-check 3.5

say ""
say "=== lesson 4 — verify someone else's work + run a wave ====================="

mk_l4() {
  local d; d="$(newfix "$1")"
  mkdir -p "$d/lessons/answers" "$d/scripts/grade/keys" \
           "$d/docs/streams/example-app" "$d/docs/registers"
  cat > "$d/scripts/grade/keys/4.key" <<'K'
findings-path=docs/registers/FINDINGS.md
verdict=off-by-one
verdict=unguarded nil
K
  cat > "$d/docs/registers/FINDINGS.md" <<'K'
# FINDINGS
| id | what |
|----|------|
| F-example-app-01 | the seeded defect |
K
  printf '%s' "$d"
}
mk_l4_complete() {
  local d; d="$(mk_l4 "$1")"
  cat > "$d/lessons/answers/4.md" <<'M'
# Lesson 4 verdicts

| row | verdict | reproducing command |
|-----|---------|---------------------|
| 1 | checked-clean | `go test ./... -count=1` |
| 2 | checked-failed | `go test -run Rate ./... -count=1` — off-by-one in the window |
| 3 | could-not-check | `unguarded nil` path is unreachable from the fixture |
M
  for n in 03 04; do
    cat > "$d/docs/streams/example-app/brief-$n-wave.md" <<M
---
brief: example-app/$n
title: wave brief $n
---
# Brief $n
## Verify
| # | Command | Expect |
|---|---------|--------|
| 1 | \`test -f go.mod\` | exit 0 |

## Evidence
| # | Command | Result | Output | Date | Runner |
|---|---------|--------|--------|------|--------|
| 1 | \`test -f go.mod\` | pass exit=0 | sha256:aaaaaaaaaaaa | 2026-01-01 | worker-session |
| 1 | \`test -f go.mod\` | pass exit=0 | sha256:aaaaaaaaaaaa | 2026-01-02 | human:alex |
M
  done
  cat > "$d/docs/streams/example-app/README.md" <<'M'
# example-app

| # | Brief | Status | Verified |
|---|-------|--------|----------|
| 03 | [w3](./brief-03-wave.md) | verified | 2026-01-02 human:alex |
| 04 | [w4](./brief-04-wave.md) | verified | 2026-01-02 human:alex |
M
  printf '%s' "$d"
}

D="$(mk_l4 l4-incomplete)"
run "$D" 4
expect_rc      "lesson4 incomplete" 1
expect_verdict "lesson4 incomplete" checked-failed
expect_arm     "lesson4 incomplete" checked-failed 4.1
expect_arm     "lesson4 incomplete" checked-failed 4.4

D="$(mk_l4_complete l4-complete)"
run "$D" 4
expect_rc      "lesson4 complete" 0
expect_verdict "lesson4 complete" checked-clean

D="$(mk_l4_complete l4-nokey)"; rm -f "$D/scripts/grade/keys/4.key"
run "$D" 4
expect_rc      "lesson4 no key" 2
expect_verdict "lesson4 no key" could-not-check
expect_arm     "lesson4 no key" could-not-check 4.3
expect_arm     "lesson4 no key" could-not-check 4.6

# mutations
D="$(mk_l4_complete l4-m1)"; perl -pi -e 's/could-not-check/checked-failed/' "$D/lessons/answers/4.md"
run "$D" 4; expect_arm "lesson4 MUT third state dropped" checked-failed 4.2.3

D="$(mk_l4_complete l4-m2)"; perl -pi -e 's/human:alex \|$/worker-session |/' "$D/docs/streams/example-app/brief-03-wave.md"
run "$D" 4; expect_arm "lesson4 MUT verifier == implementer" checked-failed 4.5.1

D="$(mk_l4_complete l4-m3)"
perl -ni -e 'print unless /brief-04-wave\.md/' "$D/docs/streams/example-app/README.md"
run "$D" 4; expect_arm "lesson4 MUT only one brief verified" checked-failed 4.4

D="$(mk_l4_complete l4-m4)"; perl -ni -e 'print unless /^\| F-/' "$D/docs/registers/FINDINGS.md"
run "$D" 4; expect_arm "lesson4 MUT finding never filed" checked-failed 4.3

D="$(mk_l4_complete l4-m5)"; perl -pi -e 's/off-by-one in the window/a rounding thing/' "$D/lessons/answers/4.md"
run "$D" 4; expect_arm "lesson4 MUT verdict misses the seeded defect" checked-failed 4.6.1

D="$(mk_l4_complete l4-m6)"; perl -pi -e 's/^verdict=unguarded nil$/verdict=integer overflow/' "$D/scripts/grade/keys/4.key"
run "$D" 4; expect_arm "lesson4 MUT key changed (proves the key is read)" checked-failed 4.6.2

D="$(mk_l4_complete l4-m7)"
perl -0pi -e 's/## Evidence.*//s' "$D/docs/streams/example-app/brief-03-wave.md"
run "$D" 4; expect_arm "lesson4 MUT verified cell with no witness" checked-failed 4.5.1

say ""
say "=== the CI step's three-state translation =================================="

# scripts/grade/ci-step.sh is what each lesson-<N>.yml actually runs. Its job is
# to turn a grade script's exit code into the `state` output the complete /
# incomplete jobs key off. If it mistranslated could-not-check into
# checked-failed, every arm proven above would still be right and the learner
# would still be told they failed.
ci_run() {
  # ci_run <fixture-dir> <lesson>  -> CI_STATE, CI_REASONS, OUT
  local dir="$1" lesson="$2" go gs
  go="$WORK/gh_output.$$"; gs="$WORK/gh_summary.$$"
  : > "$go"; : > "$gs"
  OUT="$(cd "$dir" && PATH="$STUB_PATH" GITHUB_OUTPUT="$go" GITHUB_STEP_SUMMARY="$gs" \
         bash scripts/grade/ci-step.sh "$lesson" 2>&1)"
  RC=$?
  CI_STATE="$(sed -n 's/^state=//p' "$go" | tail -1)"
  CI_REASONS="$(cat "$gs")"
}
expect_ci_state() {
  local what="$1" want="$2"
  if [ "$CI_STATE" = "$want" ]; then ok "$what -> ci state=$want"
  else bad "$what -> ci state='$CI_STATE', expected '$want'"; fi
}

for f in "$HERE"/lib.sh "$HERE"/ci-step.sh; do
  [ -f "$f" ] || die "missing $f"
done

D="$(mk_l1_complete ci-clean)"
ci_run "$D" 1
expect_ci_state "ci step, complete tree" checked-clean
expect_rc       "ci step, complete tree" 0

D="$(mk_l1 ci-failed)"
ci_run "$D" 1
expect_ci_state "ci step, incomplete tree" checked-failed
expect_rc       "ci step, incomplete tree" 0

D="$(mk_l1_complete ci-unknown)"; rm -f "$D/scripts/grade/keys/1.key"
ci_run "$D" 1
expect_ci_state "ci step, unevaluable tree" could-not-check
# The step must exit 0 even here: a non-zero exit would paint the run red for a
# shortcoming of the GRADER, which is the one outcome this harness must not
# produce.
expect_rc "ci step, unevaluable tree exits 0 (never red for a harness gap)" 0
if printf '%s' "$CI_REASONS" | grep -q 'This is NOT a fail'; then
  ok "ci step, unevaluable tree -> summary says it is not a fail"
else
  bad "ci step, unevaluable tree -> summary does not disclaim the fail"
fi

# The grade script deleted from the copy: still could-not-check, still exit 0.
D="$(mk_l1_complete ci-missing-script)"; rm -f "$D/scripts/grade/1.sh"
ci_run "$D" 1
expect_ci_state "ci step, grade script deleted" could-not-check
expect_rc       "ci step, grade script deleted" 0

say ""
say "=== workflow parity ========================================================"

# The four lesson workflows are the same file modulo the lesson number and
# title. Nothing enforces that, so a fix applied to one and forgotten on the
# other three is invisible — and an unfixed grader still reports a verdict.
WFDIR="$(cd "$HERE/../../.github/workflows" 2>/dev/null && pwd)"
if [ -z "${WFDIR:-}" ] || [ ! -d "$WFDIR" ]; then
  bad "workflow parity -> could not locate .github/workflows"
else
  n_wf=0
  for f in "$WFDIR"/lesson-*.yml; do
    [ -f "$f" ] || continue
    n_wf=$((n_wf + 1))
  done
  if [ "$n_wf" -eq 4 ]; then ok "workflow parity -> 4 lesson-*.yml present"
  else bad "workflow parity -> $n_wf lesson-*.yml present, expected 4"; fi

  # Normalise away the lesson number and the human title, then compare.
  norm() {
    sed -e 's/lesson-[1-4]/lesson-N/g' \
        -e 's/ci-step\.sh [1-4]/ci-step.sh N/g' \
        -e 's/Lesson [1-4]/Lesson N/g' \
        -e 's/lesson [1-4]/lesson N/g' \
        -e 's/^          LESSON: .*/          LESSON: "N"/' \
        -e 's/^# Grades lesson N .*/# Grades lesson N/' "$1"
  }
  ref="$(norm "$WFDIR/lesson-1.yml")"
  for k in 2 3 4; do
    if [ "$ref" = "$(norm "$WFDIR/lesson-$k.yml")" ]; then
      ok "workflow parity -> lesson-$k.yml matches lesson-1.yml"
    else
      bad "workflow parity -> lesson-$k.yml has drifted from lesson-1.yml"
      diff <(printf '%s\n' "$ref") <(norm "$WFDIR/lesson-$k.yml") | head -20 | sed 's/^/        /'
    fi
  done

  # The credential guard, asserted where it is cheap to keep true. `grep -l` over
  # a glob that matched nothing would exit 1 and print nothing, which an "output
  # is empty" reading would call clean, so the file count is established first.
  hits=0
  for f in "$WFDIR"/lesson-*.yml; do
    [ -f "$f" ] || continue
    grep -q 'secrets\.' "$f" && hits=$((hits + 1))
  done
  if [ "$n_wf" -eq 4 ] && [ "$hits" -eq 0 ]; then
    ok "workflow parity -> no lesson workflow references a repo/org credential"
  else
    bad "workflow parity -> $hits of $n_wf lesson workflows reference a credential"
  fi
fi

say ""
say "============================================================================"
printf 'selftest: %s expectation(s) held, %s did not\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
