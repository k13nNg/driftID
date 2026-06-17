---
name: implement-task
description: >-
  Implement a DriftID task (T###.md) end-to-end and open a pull request. Use when
  the user asks to implement, build, or work on a task by id (e.g. "implement T006",
  "do T007", "ship the next task") and wants a PR up at the end.
---

# Implement a DriftID task

Take a single task spec (`bookkeeping/task_management/T###.md`) from planned to a
pushed branch with an open PR, following the repo's task-management conventions.

## Workflow

Copy this checklist and track progress:

```
- [ ] 1. Read context (user stories → sprint → task + deps)
- [ ] 2. Create a task branch
- [ ] 3. Implement only what the task requires
- [ ] 4. Run the task's verification commands
- [ ] 5. Verify acceptance criteria + tick boxes
- [ ] 6. Move task to done/ and update the sprint
- [ ] 7. Commit, push, open the PR
```

### 1. Read context, in this order

1. `bookkeeping/stories/user-stories.md` — the `US-##` stories under the task's **Maps to**.
2. The owning sprint `S###.md` — goal, architecture, conventions, scope.
3. The task `T###.md` — the source of truth for *how* and *when done*.
4. Every task listed under **Depends on** (read those `T###.md` too — they may be in `done/`).

Do not start coding until you can name the task's deliverable, its acceptance
criteria, and its **Out of scope** list.

### 2. Create a task branch

Match the existing branch convention (`git branch -a`, `git log --oneline`); to
date that is `<owner>/T###` (e.g. `rayw/T004`). Branch off the up-to-date base:

```bash
git switch main && git pull --ff-only   # or the sprint's base branch
git switch -c <owner>/T<id>
```

### 3. Implement only what the task requires

- Build exactly the **Proposed files** / behavior in the task; honor **Out of scope** in both the task and sprint.
- UI work is **simple and flat** (visual only) per `AGENTS.md`; reuse existing tokens (`DriftColors`, `DriftSpacing`, `kDriftRadius`) and keep every existing `Key`/`Semantics` selector intact.
- Match existing `src/` Python style (`ROOT`-based paths, `timm` transforms, device auto-detection); don't hardcode paths or commit secrets/large artifacts.
- Keep diffs small and focused; reuse `Predictor.predict_top_k` for inference behavior.

### 4. Run the task's verification commands

Run the exact commands from the task's **Run** section (and any sprint
regression it names). For UI tasks that is typically:

```bash
cd ui && flutter analyze && flutter test
SLOWMO=0 npx playwright test   # existing + new demos must pass
```

Fix failures and `flutter analyze` / linter warnings before moving on. Use the
`ReadLints` tool on files you edited.

**Always run the relevant Playwright demo(s), not just unit tests** — the WebM
recording is the user-facing proof of what changed. After the run, surface the
artifact so the user can see it:

- Find the recording(s): `ls ui/test-results/**/video.webm`.
- Embed it (or a screenshot) in your summary with `![demo](<absolute-path>)` so it renders inline in chat.
- If the task adds a *new* flow (e.g. the task names a new demo spec), record that clip; otherwise run the existing demo(s) the task lists as regression.

**Flutter gotcha:** `IndexedStack` builds every tab, so placeholder/section text
in an off-screen tab still lives in the widget tree — avoid strings that collide
with existing `find.text(...)` assertions in `ui/test/`.

### 5. Verify acceptance criteria

- Tick a checkbox in `T###.md` **only** when its criterion is actually met and verified.
- Leave any **Human:** criterion unchecked — those need explicit reviewer sign-off. Call them out in the PR body instead.
- If you cannot satisfy a non-Human criterion, stop and report it rather than checking it.

### 6. Move the task to done and update the sprint

When all non-Human criteria pass:

- Set the task header to `**Status:** done`.
- Move the file: `git mv bookkeeping/task_management/T<id>.md bookkeeping/task_management/done/T<id>.md`.
- Update the owning `S###.md` task-table link to point at `done/T<id>.md`, and tick the sprint-level boxes the task completes.
- Fix any other `T###.md` that links the moved file (e.g. a **Depends on** reference) to the new `done/` path.

### 7. Commit, push, open the PR

Stage only the task's own paths (e.g. `git add ui/ bookkeeping/`) — never
`git add -A`, which would sweep in unrelated in-flight changes.

```bash
git add <task paths>
git status --short            # confirm nothing unrelated is staged
git commit -m "$(cat <<'EOF'
T<id>: <short imperative summary>
EOF
)"
git push -u origin HEAD
```

If `gh auth status` shows you're not logged in, run `gh auth login` (or tell the
user to). **Push auth fallback:** if the push fails with `Permission denied
(publickey)` because the remote is SSH and no key is configured, but `gh` has a
token, wire `gh` into git over HTTPS without touching the fetch URL:

```bash
gh auth setup-git
git remote set-url --push origin https://github.com/<owner>/<repo>.git
git push -u origin HEAD
```

Then create the PR:

```bash
gh pr create --title "T<id> — <task title>" --body "$(cat <<'EOF'
## Summary
- <what this task delivered, mapped to US-## where relevant>

## Acceptance criteria
- [x] <criterion met>
- [ ] **Human:** <reviewer sign-off still needed>

## Test plan
- <commands run, e.g. flutter analyze, npx playwright test>
EOF
)"
```

Return the PR URL. Do **not** merge, force-push, or commit unrelated changes.

## Notes

- Only create the commit/PR as part of this workflow — never commit other in-flight changes.
- If the user's request doesn't map to an existing `T###.md`, say so and ask whether to add one (from `template-task.md`) before building.
