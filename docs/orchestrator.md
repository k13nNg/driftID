# Orchestrator mode — parallel, container-per-task development

Run several `T###` tasks in parallel, each in its own isolated container, all sharing one
prebuilt toolchain image. The host-side driver is [`orchestrate.sh`](../orchestrate.sh); the
image is defined in [`.devcontainer/Dockerfile`](../.devcontainer/Dockerfile).

## Quick start

Run everything **on the host** (Docker Desktop), from the repo root. See
[Prerequisites](#prerequisites) for the one-time auth setup.

### 1. Authenticate (one time)

```bash
gh auth login --hostname github.com --git-protocol https --scopes write:packages
gh auth token | docker login ghcr.io -u <your-github-username> --password-stdin
```

Logs `gh` in (so the build can clone the private repo) and logs Docker into **GHCR** (so you can
push/pull images). Skip the second line if you don't intend to push images to the registry.

### 2. Build the toolchain image (rarely)

```bash
./orchestrate.sh build-dev --push
```

Builds the `dev` image (conda env, Flutter SDK, Playwright, `gh`). You only repeat this when a
toolchain dep file changes — otherwise the layers stay cached. Drop `--push` to keep it local.

### 3. Build the sprint seed (once per sprint)

```bash
./orchestrate.sh build-sprint S002 $(git rev-parse origin/main) --push
```

Bakes a warm seed (a clone of the given commit + a prebuilt Flutter web bundle + the DINOv3
backbone) so task containers start fast. The commit is **required** — here we pin the current tip
of `main`. Re-run with a new commit to refresh the seed.

### 4. Start a task container

```bash
./orchestrate.sh up T012
```

Creates the `driftid-T012` volume + container, seeds the workspace, brings it up to date with
`main`, runs `flutter pub get`, and parks ready. Watch it warm up with `./orchestrate.sh logs T012`.

### 5. Attach and do the work

In Cursor/VS Code: **Cmd+Shift+P → Dev Containers: Attach to Running Container → `driftid-T012`**.

The repo lives at **`/workspaces/driftID`** (on the per-task volume). `up` writes a host-side
attached-container config so the attach opens that folder automatically (terminals also open there
via the image `WORKDIR`); if the editor ever lands in the container home instead, use
**File → Open Folder → `/workspaces/driftID`**. Then run the
[`implement-task`](../.cursor/skills/implement-task/SKILL.md) skill for the task — it branches,
implements, tests, and opens the PR. (Repeat steps 4–5 for each task you want in flight.)

### 6. Tear down (after the PR merges)

```bash
./orchestrate.sh down T012
```

Removes the container and its volume. It refuses if there are uncommitted or unpushed changes
unless you pass `--force`.

## Two run modes of one image

The same image runs two ways:

| Mode | How it's launched | Source | Use |
|------|-------------------|--------|-----|
| **Interactive** | _Dev Containers: Reopen in Container_ | host workspace **bind-mounted** at `/workspaces/driftID` | hands-on solo work |
| **Orchestrator** | `./orchestrate.sh up <T###>` (host) | per-task **named volume**, no host mount | running several tasks in parallel |

`orchestrate.sh` runs **on the host** (Docker Desktop) — the dev container has no Docker daemon.

## Image layering

```
base  (conda env, Flutter SDK, Playwright, Chromium)   ← rebuild only on dep changes
 └─ dev  (+ gh CLI, warm npm/Playwright caches)         ← target used by the dev container
     └─ sprint-base  (bakes a PINNED commit at /opt/seed/driftID + warm builds)  ← rebuilt per sprint
```

- **`base`/`dev` stay code-free.** They only copy lockfiles, so the expensive toolchain layers stay
  cached across sprints. They rebuild only when `.devcontainer/Dockerfile`,
  `.devcontainer/environment.yml`, `ui/package.json`, or `ui/package-lock.json` change.
- **`sprint-base` bakes a seed**, not authoritative code: a clone of a pinned commit at
  `/opt/seed/driftID` (a **non-workspace** path, so the per-task volume can't shadow it) plus warm
  Flutter/HF caches. At runtime the worker always `git fetch && switch main && pull` on top.
- **Auth is never baked.** `GH_TOKEN` is a BuildKit secret at build time and an injected env var at
  runtime; it never lands in an image layer.

## Prerequisites

- **Docker Desktop** running on the host.
- **`gh` logged in** so `gh auth token` resolves a token with `repo` scope (used as the BuildKit
  clone secret). `orchestrate.sh` falls back to `gh auth token` when `GH_TOKEN` is unset.
- **For `--push` to GHCR**, log Docker into GHCR specifically (plain `docker login` only touches
  Docker Hub):

  ```bash
  gh auth login --hostname github.com --git-protocol https --scopes write:packages
  gh auth token | docker login ghcr.io -u <your-github-username> --password-stdin
  ```

  `IMAGE_OWNER` must be a **GitHub** account you can write packages to (not a Docker Hub handle).
  New GHCR packages default to **private** — make them public or grant access in the package
  settings if another account or CI needs to pull them.

## Building the images

```bash
./orchestrate.sh build-dev [--push]                          # base/dev toolchain image
./orchestrate.sh build-sprint <S###> <commit-sha> [--push] [--no-cache]   # per-sprint warm seed
```

`build-sprint` takes **two required args** — the sprint name and an explicit commit (or
branch/tag) — so a seed is always pinned to a known commit, never an implicit `main`. To pin the
current tip of main:

```bash
./orchestrate.sh build-sprint S002 $(git rev-parse origin/main) --push
```

### Config (env overrides)

| Var | Default | Meaning |
|-----|---------|---------|
| `REGISTRY` | `ghcr.io` | registry host |
| `IMAGE_OWNER` | `raywang999` | GHCR namespace (your GitHub account) |
| `SPRINT` | `S002` | sprint tag `up` launches from |
| `REPO_URL` | `https://github.com/k13nNg/driftID.git` | repo cloned into the seed / at runtime |
| `API_PORT` / `WEB_PORT` | `8000` / `8080` | constant in-container ports |
| `GH_TOKEN` | (from `gh auth token`) | clone + runtime auth |

## Resetting / re-pinning a seed

`build-sprint` resolves the ref to a concrete SHA and tags the image **twice**:

- `:S###` — moving tag, the latest seed for that sprint (what `up` launches from)
- `:S###-<sha>` — immutable snapshot, so an old seed is never silently lost

To refresh a seed, re-run `build-sprint S### <newcommit>`. Because it pins to the resolved SHA, the
clone + warm-build layers correctly bust and reseed. Pass `--no-cache` to force a full reclone even
at the same commit.

> **Cache trap (why the SHA matters):** a Docker layer's cache key includes the values of any
> `ARG`s it references. A moving ref like `main` has a *stable* key (`"main" == "main"`), so Docker
> would reuse a **stale** cached seed even after main advances. Pinning to the commit SHA is what
> makes a reseed actually take effect. Rotating `GH_TOKEN` does **not** bust the cache — secret
> contents are excluded from the cache key.

## Running a task container

```bash
./orchestrate.sh up T012        # create volume + container, warm-start, park for attach
./orchestrate.sh logs T012      # follow the warm-start (seed → fetch main → pub get)
./orchestrate.sh ls             # list task containers
./orchestrate.sh attach T012    # open a shell (or use Attach to Running Container)
./orchestrate.sh down T012      # stop+remove container AND volume; guards unsynced work
```

`up` does all the environment plumbing then parks the container at `sleep infinity` — it does
**not** auto-start an agent. `down` refuses to destroy a volume that has uncommitted changes or
unpushed commits unless you pass `--force`.

### Ports & networking

Containers publish **no ports** (`-p`) — each has its own network namespace, so in-container ports
never collide and stay constant (`API_PORT=8000`, `WEB_PORT=8080`). Reach the app/API by attaching
with **Dev Containers: Attach to Running Container**, which forwards the ports for you.

### Persistence

Persistence is **`git push`**. The named volume (`driftid-<T###>`) survives `docker rm` and is the
crash-safety net; pushing your branch is the real sync mechanism. `down` removes the volume.

## Intended workflow, per task

1. **Build images** — `build-dev` (rare), `build-sprint` (once per sprint).
2. **`./orchestrate.sh up T###`** — provisions the volume + container, seeds from
   `/opt/seed/driftID`, brings the workspace to latest `main`, runs `flutter pub get`, wires the
   injected token into git, and parks ready on `main`.
3. **Attach** in Cursor/VS Code → _Attach to Running Container_ → `driftid-T###`.
4. **Run the [`implement-task`](../.cursor/skills/implement-task/SKILL.md) skill** for the task. It
   branches `<owner>/T###` off main, implements, runs `flutter analyze`/`test` + Playwright demos,
   ticks the task criteria, moves the task to `done/`, commits, pushes, and opens the PR.
5. **Merge → main**, then `./orchestrate.sh down T###`.

Parallelism comes from running multiple `up`s and attaching an agent to each.

## CI

[`.github/workflows/images.yml`](../.github/workflows/images.yml) keeps the images fresh:

- **`driftid-dev`** is rebuilt + pushed automatically when a toolchain dep file changes on `main`.
- **`driftid-sprint:S###`** is built + pushed on demand via `workflow_dispatch` (inputs: `sprint`,
  `ref`), using `GITHUB_TOKEN` as the clone secret and GHA layer caching.

## Troubleshooting

| Symptom | Cause / fix |
|---------|-------------|
| `error from registry: denied` on push | Not logged into **GHCR** (plain `docker login` only does Docker Hub), or the token lacks `write:packages`. Run the GHCR login in [Prerequisites](#prerequisites). |
| `error from registry: not_found: owner not found` | `IMAGE_OWNER` isn't a real GitHub account (e.g. a Docker Hub handle). Set it to your GitHub username. |
| Reseed didn't pick up new code | You re-ran with a moving ref and hit the cache. Pin the commit SHA, or pass `--no-cache`. See the cache-trap note above. |
| `could not create leading directories of '/opt/seed/...'` (build) | Build the current Dockerfile — `sprint-base` creates `/opt/seed` as vscode-owned before cloning. |
| `up` says repo isn't there | Check `./orchestrate.sh logs <T###>` — the seed/fetch runs at container start and may still be in progress or have logged a warning. |
| Attach opens `/home/vscode`, not the repo | Cursor's attach folder comes from a host-side attached-container config, not the image `WORKDIR`/label. `up` now writes `…/globalStorage/anysphere.remote-containers/nameConfigs/driftid-<T###>.json` with `workspaceFolder`. If you started the container before this change (or on another host), re-run `down`+`up`, or `F1 → Dev Containers: Open Attached Container Configuration File` and set `"workspaceFolder": "/workspaces/driftID"`. |
