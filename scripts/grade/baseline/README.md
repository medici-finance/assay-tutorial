# Baseline — what shipped with the template, so the grader can tell it from your work

`briefs.txt` is a plain list of repo-relative paths, one per line, naming every
`docs/streams/**/brief-*.md` that **this template ships**. Lesson 3's arm `3.2`
subtracts it from what it finds on disk; whatever is left is the brief the
learner authored.

**`briefs.txt` is not shipped.** The corpus it would enumerate (`education/08`)
does not exist yet, and a baseline listing files that are not there would let
arm 3.2 identify any file at all as "the learner's brief" — including a file the
learner never wrote. So while it is absent, arm 3.2 renders **could-not-check**
with that reason named, and the arms that need to know *which* brief to read
(3.3, 3.4, 3.5) are reported as not evaluated rather than guessed at.

Regenerate it, from the repo root, whenever the shipped corpus changes:

```
find docs/streams -type f -name 'brief-*.md' | LC_ALL=C sort > scripts/grade/baseline/briefs.txt
```

Matching is exact, whole-line (`grep -qxF`), so paths must be written exactly as
`find` emits them — no leading `./`, no trailing whitespace.
