# Answer keys — the half of the grade that this repo does not have yet

Each `<N>.key` is the **template side** of a lesson's grade: what a correct
answer looks like. The learner's side lives in `lessons/answers/<N>.md`. They are
deliberately two different files. A check whose fixture supplies its own answer
grades nothing, and that is not a hypothetical — a `--probe` table keyed by repo
name once passed every offline test in a sibling repo because the fixture *was*
the key.

**No `<N>.key` file is shipped with this template.** That is not an oversight and
it is not a placeholder to be filled with something plausible: the answers depend
on a worked corpus and on lesson text that have not landed. While a key is
absent, the arms that need it render **could-not-check** and name the brief that
owns them. They never render pass, and they never render fail.

| Key | Arms it unlocks | Owner |
|-----|-----------------|-------|
| `1.key` | `1.5.*` — are lesson 1's three board-reading answers correct | education/08 (the corpus the answers describe) + education/12 (the questions) |
| `2.key` | `2.6.*` — does the write-up name the lint rule that caught each break | education/12 (lesson 2 chooses the three breaks) |
| `4.key` | `4.3` — where the FINDINGS register lives; `4.6.*` — do the learner's verdicts match the seeded defects | education/08 (register path) + education/11 (the seeded PR and its answer key) |

Lesson 3 has no key. Its `3.2` arm instead needs `../baseline/briefs.txt`; see
that directory's README.

## Formats

`1.key` — one line per answer slot, `A<n>=<extended regex>`. The regex is matched
case-insensitively against the body of the `## A<n>` section of
**lessons/answers/1.md**.

```
A1=three
A2=ground-truth/02
```

`2.key` — one extended regex per line. Each must appear somewhere in
**lessons/answers/2.md**. Blank lines and `#` comments are ignored. Write one
pattern per break so a failure names *which* break went unexplained; a single
pattern covering all three cannot.

`4.key` — `findings-path=<repo-relative path>` exactly once, then one
`verdict=<extended regex>` line per graded defect, each of which must appear in
**lessons/answers/4.md**.

## Two rules for whoever fills these in

1. **No alternation.** `|` is an ordinary character in a basic regex and a table
   delimiter in markdown, and the escape `\|` renders as a bare `|`, so a pattern
   written as an alternation is a different pattern on the rendered page than in
   the source. Write one line per thing you want matched. The loops here already
   number each line separately, which is what makes a failure name the missing
   item instead of reporting a bare count.
2. **Prove the key is read.** **scripts/grade/selftest.sh** carries, for each key,
   a mutation that changes the KEY alone and asserts the previously-clean arm
   goes red. A key file nothing consults would pass every other test in that
   file. Add the same mutation for any line you add.
