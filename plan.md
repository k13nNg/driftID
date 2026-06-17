# Plan — Parallel task orchestrator (container-per-task)

Spin up one container per `T###` task so multiple agents can code in parallel, sharing a
single prebuilt toolchain image but with isolated source, processes, and ports.

## Core model

```
base / dev image  →  conda env, Flutter SDK, Playwright, gh  (rebuild on dep change; code-free)
SprintBase image  →  FROM dev; bakes a PINNED end-of-sprint commit as a WARM SEED + pre-built
                     artifacts at a seed path (NOT the live workspace path); rebuilt once per sprint
run mode          →  HOW the image is launched — bind-mount (interactive) vs orchestrator (no mount)
live source       →  the code that actually ships comes from `git fetch && checkout` at RUNTIME;
                     the baked seed only makes that fast (warm git + warm build cache)
```

Non-negotiables:
- **`base`/`dev` stays code-free.** No `git clone` / `COPY . .` of source there — it only copies
  lockfiles today. Keep it that way so the expensive toolchain layers stay cached across sprints.
- **Baked source is a seed, never the authoritative runtime code.** The worker always
  `git fetch && checkout main` on top before working; the bake just avoids a cold start.
- **Seed lives at a non-workspace path** (e.g. `/opt/seed/driftID`), never at `/workspaces/driftID` —
  otherwise the locked named volume mount would shadow it (same trap as a bind-mount).
- **Auth is injected at runtime, never baked.** Secrets/tokens never go into any image layer.
- Each task gets its **own port block** to avoid `uvicorn` / Flutter web / Playwright collisions.

## Two run modes of the one image

### A. Interactive mode (bind-mount) — existing
- Launched via `.devcontainer/devcontainer.json` ("Open Folder in Container").
- Host workspace bind-mounted at `/workspaces/driftID`; edits persist to host.
- For hands-on solo work. **No change needed.**

### B. Orchestrator mode (no bind-mount) — new
- Launched by the orchestrator via `docker run` from `driftid-sprint:S###`, **no source mount**.
- Source lives on a **[LOCKED] per-task named Docker volume** (`driftid-<T###>`) mounted at
  `/workspaces/driftID` — survives `docker rm`, re-attachable, crash-safe; `down` removes it.
- **Warm start from the baked seed:** entrypoint, when the volume is empty, seeds it from the image's
  `/opt/seed/driftID` (`git clone --reference /opt/seed/driftID` for object reuse + copy warm build
  dirs like `.dart_tool`), then `git fetch && git switch main && git pull --ff-only`.
- Edit by **VS Code/Cursor → "Attach to Running Container"** (no mount required).
- **Persistence = `git push`** before teardown (push is the sync mechanism); the volume is the net.

> Note: prefer **clone-per-task over git worktrees** for containers. A worktree's `.git` is a *file*
> pointing at the parent repo's `.git/worktrees/...`; if only the worktree path is used, git can't
> resolve that pointer and breaks. A plain clone has a real self-contained `.git`. (Worktrees remain
> fine for the lightweight, single-container path — e.g. Cursor parallel agents.)

### Image layering
```
base       (current Dockerfile: conda, Flutter SDK, Playwright)            ← rebuild on dep change
  └─ dev   (current: + gh CLI, warm npm/Playwright caches)
       └─ SprintBase   FROM dev; ARG SPRINT_REF (pinned end-of-sprint commit/tag)
                       clone pinned commit → /opt/seed/driftID  (full or --filter=blob:none, NOT --depth 1)
                       warm builds: flutter pub get, build_runner, flutter build web, fetch model artifacts
                       tag: driftid-sprint:S###                            ← rebuild once per sprint
```
Worker image = `driftid-sprint:S###`. Auth (gh token) injected at runtime, never baked.

## Action items

### 1. Publish the base/dev toolchain image
- [ ] Build the `dev` target: `docker build --target dev -t driftid-dev:latest -f .devcontainer/Dockerfile .`
- [ ] Tag for registry: `ghcr.io/<owner>/driftid-dev:<git-sha>` and `:latest`.
- [ ] Push to GHCR (`gh auth token` / `docker login ghcr.io`).
- [ ] Document the rebuild trigger: **only** rebuild/repush when `.devcontainer/Dockerfile`,
      `.devcontainer/environment.yml`, `ui/package.json`, or `ui/package-lock.json` change.

### 2. Add the `SprintBase` stage (warm seed per sprint)
- [ ] New stage `FROM dev AS sprint-base` with `ARG SPRINT_REF` (the pinned end-of-sprint commit/tag).
- [ ] Clone the pinned ref into **`/opt/seed/driftID`** — full or `--filter=blob:none`, **never `--depth 1`**
      (the worker needs history for `git switch main && git pull` and diffs).
- [ ] Warm builds against the seed: `flutter pub get`, any `build_runner`, `flutter build web`,
      fetch model artifacts into `data/artifacts/`.
- [ ] Build + tag per sprint: `driftid-sprint:S###`; push to GHCR.
- [ ] **Never** bake auth/secrets; seed path is **not** `/workspaces/driftID` (volume would shadow it).

### 3. CI to keep images fresh (optional but recommended)
- [ ] GH Action: rebuild + push `driftid-dev` on dep-file changes; cache Docker layers.
- [ ] At sprint close, build + push `driftid-sprint:S###` from the pinned ref.

### 4. Orchestrator script (`orchestrate.sh`)
- [ ] `up <T###>`:
  - [ ] Ensure branch `task/<T###>` (or `<owner>/T<id>` per repo convention) exists; create from main if missing.
  - [ ] **[LOCKED]** Derive `N` from the numeric part of `T###`; export `API_PORT=8000+N`,
        `WEB_PORT=9000+N` (3-digit `T###` ⇒ ranges 8000–8999 / 9000–9999 never overlap).
  - [ ] Create/reuse named volume `driftid-<T###>`; mount at `/workspaces/driftID`.
  - [ ] `docker run -d --name driftid-<T###> -v driftid-<T###>:/workspaces/driftID -e API_PORT -e WEB_PORT
        --env GH_TOKEN driftid-sprint:S###` (named volume only — **no host source mount**; auth via env).
  - [ ] Entrypoint: if volume empty, seed from `/opt/seed/driftID` (`git clone --reference` + copy warm
        build dirs) → `git fetch && git switch main && git pull --ff-only` → incremental warm build.
- [ ] `down <T###>`: stop+remove container; **remove the `driftid-<T###>` volume**; warn/guard if the
      branch has unpushed commits before destroying the volume.
- [ ] `ls`: list active task containers + assigned port blocks.
- [ ] `attach <T###>`: print the container name / connect hint for "Attach to Running Container".

### 5. Worker handoff to `implement-task`
- [ ] After the warm-start steps, the worker invokes the **`implement-task`** skill with the `T###`.
- [ ] The skill then owns: branch off main → implement → `flutter analyze`/`test` + Playwright demos →
      tick criteria → move task to `done/` → commit, push, open PR (uses the injected `GH_TOKEN`).

### 6. Port-aware app config
- [ ] `uvicorn` binds to `API_PORT` (env, default 8000).
- [ ] Flutter web dev server + Playwright `baseURL` read `WEB_PORT` / `API_PORT` from env.
- [ ] No hardcoded `:8000` / `:9000` left in UI or test config.

### 7. Merge / teardown flow
- [ ] Worker (via `implement-task`) pushes `task/<T###>` and opens the PR.
- [ ] Verify the task's `T###.md` acceptance criteria (leave **Human:** criteria for reviewer).
- [ ] Merge → main; `orchestrate.sh down <T###>`.

### 8. Docs
- [ ] README section: image layers (base/dev → SprintBase), interactive vs orchestrator mode,
      `up`/`down`/`attach`, port scheme, and the per-sprint `SprintBase` rebuild step.

## Decisions locked
- **Persistence:** per-task **named Docker volume** (`driftid-<T###>`) — survives `docker rm`,
  re-attachable, crash-safe; `down` removes it.
- **Ports:** **derive from `T###`** — `API_PORT=8000+N`, `WEB_PORT=9000+N`, stateless & deterministic.
- **Warm seed:** `SprintBase` bakes a **pinned end-of-sprint commit** + pre-built artifacts at
  `/opt/seed/driftID`; it is a seed only — the worker `git fetch && checkout main` on top. Rebuilt
  once per sprint. Seed path ≠ workspace path (volume would shadow it).

## Open questions
- [ ] Registry: GHCR assumed — confirm.
- [ ] Remote for push/pull in orchestrator mode: the real origin, or a bare local repo on the host?

## Explicitly out of scope (for now)
- GPU scheduling (env is CPU-only: `faiss-cpu` + CPU PyTorch — no contention).
- Baking **secrets/auth** into any image, or baking source into the **`base`/`dev`** layer or at the
  **workspace path** (only `SprintBase` bakes a pinned seed, at `/opt/seed`).
- Treating the baked seed as authoritative runtime code — the worker always updates on top.
- Multi-host / k8s orchestration — single host is enough at current task volume.
