# assay-tutorial

A hands-on, graded tutorial for [Assay](https://github.com/medici-finance/assay) — the
operating model for running fleet-of-agents software work behind machine-checkable gates.
This repo is a **template**, not a library: it exists so you can generate your own copy and
run the lessons against it, without touching Assay's own release cadence.

## What's here (once the lessons land)

- A small **fictional worked corpus** (`example-app`) — a product with real-shaped streams,
  briefs, and registers, so you see the loop (intake → brief → dispatch → draft PR → review
  verdict → human merge → independent verify → evidence row) end to end instead of reading
  about it.
- A **four-lesson graded tutorial**, each lesson checked by GitHub Actions rather than by
  self-report: install and read a board, trust the lint, author and ship one brief, verify
  someone else's work and run a small wave.
- **Dual-track instructions throughout** — every hands-on step is shown concretely for both
  Claude Code and Codex, so the lessons don't assume one harness.

This is a **skeleton commit**: the repo, license, and lint CI exist; the corpus and lessons
above are tracked separately and land in follow-up work. If you're reading this on a fresh
clone and don't see `docs/streams/example-app/` yet, that's expected — check back for
updates to this template.

## Before you start: read this first

Start with **["How Assay works"](https://github.com/medici-finance/assay/blob/main/docs/how-assay-works.md)**
— the standalone explainer that teaches the mental model (why self-reported "done" fails,
what a brief contracts, why the verifier is never the implementer) before you install
anything. It assumes no repo context. (If that link 404s, the explainer hasn't shipped yet —
it's `education/01` in the toolkit's own stream, tracked separately from this repo.)

## Use this template

This repo has GitHub's **"Template repository"** setting enabled, so you get your own copy
with clean history — no forked-repo banner, no shared issues:

```
gh repo create my-assay-tutorial --template medici-finance/assay-tutorial --public --clone
cd my-assay-tutorial
```

or via the web UI: **Use this template → Create a new repository** on this repo's GitHub
page.

Everything you do from there — the lessons, the kata, your own briefs — happens in *your*
copy. Nothing you do here writes back to `medici-finance/assay-tutorial`.

## Your progress

Each lesson is graded by GitHub Actions in **your** copy, on every push. The
grader reads repo state — files, board output, PR shape. It never reads which
agent, model or editor produced the tree, and it has no way to. That is what
makes these lessons harness-neutral rather than merely claiming to be.

| Lesson | Grades | Run it yourself | Owner of the lesson text |
|--------|--------|-----------------|--------------------------|
| 1 — read the board | `.github/workflows/lesson-1.yml` | `bash scripts/grade/1.sh` | education/12 |
| 2 — trust the lint | `.github/workflows/lesson-2.yml` | `bash scripts/grade/2.sh` | education/12 |
| 3 — author and ship one brief | `.github/workflows/lesson-3.yml` | `bash scripts/grade/3.sh` | education/13 |
| 4 — verify someone else's work, run a wave | `.github/workflows/lesson-4.yml` | `bash scripts/grade/4.sh` | education/14 |

The local command and the CI job run the **same script**, so a learner with no
Actions minutes is not locked out of the tutorial. CI only wraps it.

### How to read a result

A lesson has three states, and a green/red job has two, so the state is carried
by **which job ran**:

| What you see | What it means |
|---|---|
| `lesson-N-complete` green | You finished the lesson. |
| `lesson-N-incomplete` red | The grader read your tree and something is missing. The job log names every one. |
| Neither job ran; `grade` is green with a warning | The grader **could not evaluate** part of your tree. Read the run summary: it names exactly what it could not read and why. |

The third row is the one worth understanding, because it is the state most
graders do not have. Being told you failed because the grader could not read
your tree is worse than being told nothing, so a could-not-check never turns
anything red — and it never turns anything green either.

Locally the same three states are the exit code: `0` complete, `1` incomplete
with named reasons, `2` could-not-check. Never a bare non-zero.

> **A caveat, stated rather than hidden:** an Actions *badge* is a two-state
> instrument and cannot render could-not-check — a run where the grader could not
> evaluate your tree still shows a green badge. That is why the table above links
> the workflow rather than embedding a badge. The authoritative verdict is the
> run summary and the `lesson-N-complete` job.

### What the graders cannot grade yet

The lessons themselves land with `education/12`–`14` and the worked corpus with
`education/08`. Until they do, several arms of each grade have nothing to check
against and say so by name — `scripts/grade/keys/README.md` and
`scripts/grade/baseline/README.md` list every one, with the brief that owns it.
Those arms render could-not-check. None of them silently passes.

### Proof that the graders can fail

```
bash scripts/grade/selftest.sh
```

For each lesson it builds an incomplete submission that must grade
checked-failed, a complete one that must grade checked-clean, and a tree the
harness genuinely cannot evaluate that must grade could-not-check; then it
mutates the complete tree once per graded arm and asserts that **that arm by
name** goes red. A grader that cannot tell those apart grades nothing, and the
only way to know is to watch it fail.

## What this repo intentionally does not have

- No house CI beyond the `statusgen` lint below, and no desk GitHub Apps installed —
  keeping the template's CI surface exactly what a learner would set up themselves.
- No content referencing private repos, internal issue trackers, or non-fictional
  organizations. Every name here is fictional (`example-app`, `example-org`, `human:alex`).

## License

Apache License 2.0 — see [`LICENSE`](./LICENSE). Matches the license of the public
[`assay`](https://github.com/medici-finance/assay) repo this tutorial teaches.
