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
- **`orchestrate.sh` runs on the host** (Docker Desktop), not inside the dev container — the
  dev container has no Docker daemon. It drives `docker run`/`docker rm` on the host.
- **No published ports (`-p`).** Each task is its own container with its own network namespace,
  so in-container ports never collide across tasks — they stay constant (`API_PORT=8000`,
  `WEB_PORT=8080`). Reach the app/API via VS Code/Cursor **"Attach to Running Container"**
  (it forwards container ports and resolves host-side collisions automatically).
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

> Header note (decided): orchestrator runs **host-side**; containers are **attach-only** (no `-p`),
> so per-task port derivation is dropped and in-container ports stay constant. Repo is **private** —
> `SprintBase` must clone the seed with a build-time token (BuildKit `--mount=type=secret`, not baked),
> and warm the **timm/HF DINOv3 backbone download** (`features_extractor.py`), not `data/artifacts/`
> (already committed in git).

## Action items

### 1. Publish the base/dev toolchain image
> Tooling shipped: `./orchestrate.sh build-dev [--push]` builds, tags (`:latest` + `:<git-sha>`),
> and optionally pushes. CI (`.github/workflows/images.yml`) does the same on dep-file changes.
> Pushed to GHCR namespace **`raywang999`** (GitHub account; auth via `docker login ghcr.io` + a
> `write:packages` token). Package defaults to **private**.
- [x] Build the `dev` target — `./orchestrate.sh build-dev`.
- [x] Tag for registry: `ghcr.io/<owner>/driftid-dev:<git-sha>` and `:latest` (done by `build-dev`).
- [x] Push to GHCR — `./orchestrate.sh build-dev --push` → `ghcr.io/raywang999/driftid-dev:{latest,00daaac}`.
- [x] Document the rebuild trigger: CI `paths:` + README pin it to `.devcontainer/Dockerfile`,
      `.devcontainer/environment.yml`, `ui/package.json`, `ui/package-lock.json`.

### 2. Add the `SprintBase` stage (warm seed per sprint)
- [x] New stage `FROM dev AS sprint-base` with `ARG SPRINT_REF` (pinned end-of-sprint commit/tag).
- [x] Clone the pinned ref into **`/opt/seed/driftID`** — **full clone** (NOT `--depth 1`), token via
      BuildKit secret, remote rewritten tokenless after clone.
- [x] Warm builds against the seed: `flutter pub get`, `flutter build web`, and pre-download the
      timm/HF DINOv3 backbone into `~/.cache` (artifacts are already in git via the full clone).
- [x] Build + tag per sprint: `./orchestrate.sh build-sprint S### <ref> [--push]` (run once per sprint).
      S002 built + pushed → `ghcr.io/raywang999/driftid-sprint:S002` (seed pinned to `6ecafb8`, ~10.9 GB).
- [x] **Never** bake auth/secrets; seed path is `/opt/seed/driftID`, not `/workspaces/driftID`
      (also dropped `set -x` so the clone token isn't echoed to the build log).

### 3. CI to keep images fresh (optional but recommended)
- [x] GH Action (`.github/workflows/images.yml`): rebuild + push `driftid-dev` on dep-file changes;
      Docker layer cache via `type=gha`.
- [x] At sprint close, `workflow_dispatch` builds + pushes `driftid-sprint:S###` from a pinned `ref`
      (uses `GITHUB_TOKEN` as the clone secret).

### 4. Orchestrator script (`orchestrate.sh`)
- [x] `up <T###>`:
  - [~] ~~Ensure branch exists~~ — **dropped on purpose**: `implement-task` (step 2) creates the
        `<owner>/T###` branch with `git switch -c`, so pre-creating it would make that fail. The
        entrypoint lands the workspace on `main`; the worker branches.
  - [x] Create/reuse named volume `driftid-<T###>`; mount at `/workspaces/driftID`.
  - [x] `docker run -d --name driftid-<T###> -v driftid-<T###>:/workspaces/driftID
        -e GH_TOKEN ... driftid-sprint:S###` (named volume only — **no host source mount**, **no `-p`**;
        auth via env). Constant in-container ports (8000/8080); reach via "Attach to Running Container".
  - [x] Entrypoint: if volume empty, seed from `/opt/seed/driftID` (`git clone --reference` + copy warm
        build dirs) → `git fetch && git switch main && git pull --ff-only` → incremental warm build.
- [x] `down <T###>`: stop+remove container; remove the `driftid-<T###>` volume; **guards** dirty tree
      and unpushed commits (`--force` to override) before destroying the volume.
- [x] `ls`: list active task containers (ports are constant per container, not derived — see item 6).
- [x] `attach <T###>`: prints the "Attach to Running Container" hint and opens a shell.
- [x] `logs <T###>`: follow the warm-start output (bonus).

### 5. Worker handoff to `implement-task`
- [x] After warm-start, the entrypoint prints the handoff (`run the implement-task skill for <TASK_ID>`)
      and keeps the container alive (`sleep infinity`) for "Attach to Running Container".
- [x] The skill then owns: branch off main → implement → `flutter analyze`/`test` + Playwright demos →
      tick criteria → move task to `done/` → commit, push, open PR (uses the injected `GH_TOKEN`,
      which the entrypoint wires into a git credential helper over HTTPS).

### 6. Port-aware app config — DONE (env-driven, defaults preserved)
- [x] `uvicorn` binds to `API_PORT` (env, default 8000) — `python -m src.api.server` honors `$API_PORT`.
- [x] Flutter web build + Playwright `baseURL`/`webServer` read `WEB_PORT` / `API_PORT` from env
      (`ui/playwright.config.ts`); the web build is pinned to `API_BASE_URL=http://localhost:$API_PORT`.
- [x] No hardcoded `:8000` / `:8080` left in test config; `api_client.dart` already uses the
      configurable `--dart-define=API_BASE_URL` (default `http://localhost:8000`).
- Note: attach-only model ⇒ ports stay constant per container; **no** `8000+N`/`9000+N` derivation.

### 7. Merge / teardown flow
> Per-task runtime steps (run when a task is actually in flight). The teardown command + the
> unpushed-work guard are shipped (`./orchestrate.sh down <T###>`).
- [ ] Worker (via `implement-task`) pushes `<owner>/T<id>` (e.g. `rayw/T006`) and opens the PR.
- [ ] Verify the task's `T###.md` acceptance criteria (leave **Human:** criteria for reviewer).
- [ ] Merge → main; `./orchestrate.sh down <T###>` (guard refuses if work is unpushed; `--force` overrides).

### 8. Docs
- [x] README **"Orchestrator mode (parallel tasks)"** section: image layers (base/dev → sprint-base),
      interactive vs orchestrator mode, `up`/`down`/`ls`/`attach`/`logs`, constant-port scheme, and the
      per-sprint `build-sprint` rebuild step.

## Decisions locked
- **Persistence:** per-task **named Docker volume** (`driftid-<T###>`) — survives `docker rm`,
  re-attachable, crash-safe; `down` removes it.
- **Ports:** **constant per container** (`API_PORT=8000`, `WEB_PORT=8080`), env-driven so they stay
  overridable. No host publishing (`-p`) and no `T###`-derivation — each container is network-isolated
  and reached via "Attach to Running Container".
- **Orchestrator host:** `orchestrate.sh` runs **on the host** (Docker Desktop); the dev container has
  no daemon.
- **Warm seed:** `SprintBase` bakes a **pinned end-of-sprint commit** + pre-built artifacts at
  `/opt/seed/driftID`; it is a seed only — the worker `git fetch && checkout main` on top. Rebuilt
  once per sprint. Seed path ≠ workspace path (volume would shadow it).

## Open questions
- [x] Registry: **GHCR**, owner `k13nng` (lowercased), private images. Overridable via
      `REGISTRY` / `IMAGE_OWNER` env on `orchestrate.sh`. *(Confirm the owner casing if pushing fails.)*
- [x] Remote for push/pull in orchestrator mode: **the real origin over HTTPS + `GH_TOKEN`**. The
      entrypoint writes a `~/.git-credentials` helper and rewrites `origin` to the tokenless HTTPS URL,
      so both fetch and push use the token (the SSH fetch URL isn't reachable in-container).

## Follow-ups (next iteration)

> Captured after the orchestrator's first successful run. Not yet implemented.

- [ ] **On-start update script.** Have the container run a small start script that `cd /workspaces/driftID`
      then pulls latest `main`. The warm-start entrypoint already does this (step 2: `git fetch && switch main
      && pull --ff-only`); extract it into an explicit, named start script so it's obvious and reusable, and
      confirm it always runs on container start.
- [ ] **Auto-dispatch the agent on `up`.** `./orchestrate.sh up <T###>` should kick off the `implement-task`
      agent for the task automatically (instead of just parking at `sleep infinity` and waiting for a human to
      attach + run the skill).
- [ ] **Keep a non-agent path as `up_classic`.** Preserve the current "provision + park for manual attach"
      behavior under a separate subcommand `./orchestrate.sh up_classic <T###>` for when we don't want an
      agent auto-dispatched.

## Explicitly out of scope (for now)
- GPU scheduling (env is CPU-only: `faiss-cpu` + CPU PyTorch — no contention).
- Baking **secrets/auth** into any image, or baking source into the **`base`/`dev`** layer or at the
  **workspace path** (only `SprintBase` bakes a pinned seed, at `/opt/seed`).
- Treating the baked seed as authoritative runtime code — the worker always updates on top.
- Multi-host / k8s orchestration — single host is enough at current task volume.
