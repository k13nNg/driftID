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
regression it names). For UI tasks that is the two-phase model from `AGENTS.md`:

```bash
cd ui
flutter analyze && flutter test
npx playwright test --project=check    # headless gate: functional E2E must pass
npx playwright test --project=record   # smaller curated subset, with video
```

Fix failures and `flutter analyze` / linter warnings before moving on. Use the
`ReadLints` tool on files you edited.

**The `check` project is the gate; the `record` project produces the PR proof.**
Only `ui/demos/record-*.spec.ts` record video — if the task adds a *new* flow worth
showing, add a `record-*.spec.ts`; otherwise re-record the existing relevant clip.

After the record run, **publish the clips and surface them**:

```bash
./scripts/upload-demos.sh   # from ui/ — transcodes to mp4, uploads to a
                            # demos-T### prerelease, prints a markdown URL block
```

- Keep the printed `### Demo recordings` block — it goes verbatim into the PR body (step 7).
- Also embed a local recording (or a screenshot) in your chat summary with `![demo](<absolute-path>)` so it renders inline (find them: `ls ui/test-results/**/video.webm`).

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
- <commands run, e.g. flutter analyze, flutter test, playwright --project=check>

### Demo recordings
- [<flow>](<release-asset URL from ./scripts/upload-demos.sh>)
EOF
)"
```

Paste the `### Demo recordings` block exactly as `upload-demos.sh` printed it.

Return the PR URL. Do **not** merge, force-push, or commit unrelated changes.

## Notes

- Only create the commit/PR as part of this workflow — never commit other in-flight changes.
- If the user's request doesn't map to an existing `T###.md`, say so and ask whether to add one (from `template-task.md`) before building.
