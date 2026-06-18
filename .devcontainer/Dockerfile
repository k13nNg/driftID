# ----------------------------------------------------------------------------
# base: heavy, rarely-changing toolchain (system deps, node, flutter, conda env)
# This stage is expensive to build but its layers stay cached as long as the
# instructions below don't change. Don't add fast-moving tools here.
# ----------------------------------------------------------------------------
FROM mcr.microsoft.com/devcontainers/miniconda:1-3 AS base

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    chromium \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

ENV CHROME_EXECUTABLE=/usr/bin/chromium

RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

ENV FLUTTER_HOME=/opt/flutter
ENV FLUTTER_ROOT=/opt/flutter
RUN git clone https://github.com/flutter/flutter.git -b stable --depth 1 ${FLUTTER_HOME} \
    && git config --global --add safe.directory ${FLUTTER_HOME} \
    && chown -R vscode:vscode ${FLUTTER_HOME}

RUN conda config --remove channels defaults || true \
    && conda config --add channels conda-forge \
    && conda config --set channel_priority strict

COPY .devcontainer/environment.yml /tmp/environment.yml
RUN conda env create -f /tmp/environment.yml \
    && conda clean -afy

RUN printf '%s\n' \
    'export PATH=/opt/flutter/bin:/opt/conda/envs/gpu-env/bin:$PATH' \
    > /etc/profile.d/99-driftid-path.sh

USER vscode

ENV PATH=/opt/flutter/bin:/opt/conda/envs/gpu-env/bin:${PATH}

RUN flutter config --enable-web --no-analytics \
    && flutter precache --web

RUN echo 'source /opt/conda/etc/profile.d/conda.sh' >> ~/.bashrc \
    && echo "conda activate gpu-env" >> ~/.bashrc

# ----------------------------------------------------------------------------
# dev: lightweight, fast-changing layer on top of the cached base.
# Add CLI tools and small tweaks here — rebuilding this stage is cheap and
# never invalidates the expensive base layers above.
# ----------------------------------------------------------------------------
FROM base AS dev

USER root

# GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# ffmpeg: transcode Playwright .webm demo recordings to .mp4 so they play in
# every browser (incl. Safari) when opened from a PR. Used by ui/scripts/upload-demos.sh.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*

USER vscode

# Pre-warm the npm cache and Playwright browser download for the ui/ test
# tooling. The workspace is bind-mounted at runtime, so ui/node_modules is
# recreated by postCreate's `npm ci`; but the npm cache (~/.npm) and the
# Playwright browsers (~/.cache/ms-playwright) live outside the mount and
# persist in the image, so those postCreate steps become fast/offline.
# Only the lockfiles are copied, so this layer is cached until they change.
COPY --chown=vscode:vscode ui/package.json ui/package-lock.json /tmp/ui-deps/
RUN cd /tmp/ui-deps \
    && npm ci \
    && npx playwright install chromium \
    && cd / \
    && rm -rf /tmp/ui-deps

# ----------------------------------------------------------------------------
# sprint-base: per-sprint WARM SEED on top of dev (orchestrator run mode).
# Bakes a PINNED commit at a NON-workspace path (/opt/seed/driftID) plus warm
# Flutter/HF caches, so a per-task container can cold-start fast. The seed is
# never authoritative — the entrypoint always `git fetch && switch main &&
# pull` on top at runtime. Rebuilt once per sprint. The clone token is a
# BuildKit secret (never baked into a layer); no auth is stored in the image.
#
# Build with BuildKit + a token secret, e.g.:
#   GH_TOKEN=$(gh auth token) DOCKER_BUILDKIT=1 docker build \
#     --target sprint-base --build-arg SPRINT_REF=<commit-or-tag> \
#     --secret id=gh_token,env=GH_TOKEN -t driftid-sprint:S### \
#     -f .devcontainer/Dockerfile .
# (or use ./orchestrate.sh build-sprint S### <ref>)
# ----------------------------------------------------------------------------
FROM dev AS sprint-base

ARG SPRINT_REF=main
ARG REPO_URL=https://github.com/k13nNg/driftID.git

USER root
# vscode-owned mountpoints. /workspaces so a fresh per-task named volume inherits
# vscode ownership (Docker seeds an empty named volume's perms from the image
# path); /opt/seed so the (non-root) vscode user can clone the seed into it.
RUN mkdir -p /workspaces/driftID /opt/seed \
    && chown -R vscode:vscode /workspaces /opt/seed
COPY .devcontainer/orchestrator-entrypoint.sh /usr/local/bin/orchestrator-entrypoint.sh
RUN chmod +x /usr/local/bin/orchestrator-entrypoint.sh

USER vscode

# Clone the pinned ref into the seed path using a build-time token secret. The
# token is read only from the secret mount; the stored remote is rewritten to a
# tokenless URL so nothing sensitive lands in an image layer. FULL clone (NOT
# --depth 1) so the worker keeps history for switch/pull/diff. NOTE: no `set -x`
# around the token so it never gets echoed into the build log.
RUN --mount=type=secret,id=gh_token,uid=1000,mode=0400 \
    set -eu; \
    git clone "https://x-access-token:$(cat /run/secrets/gh_token)@${REPO_URL#https://}" /opt/seed/driftID; \
    cd /opt/seed/driftID; \
    git checkout "${SPRINT_REF}"; \
    git remote set-url origin "${REPO_URL}"; \
    git config --global --add safe.directory /opt/seed/driftID

# Warm Flutter deps + a release web build, and pre-download the timm/HF DINOv3
# backbone into ~/.cache so the first build/inference in a worker is fast. A
# failed pre-warm is non-fatal (it just falls back to a runtime download).
RUN set -eux; \
    cd /opt/seed/driftID/ui; \
    flutter pub get; \
    flutter build web --release; \
    python -c "import timm; timm.create_model('vit_base_patch16_dinov3', pretrained=True, num_classes=0)" \
      || echo "[sprint-base] WARN: backbone pre-warm failed; worker will download at runtime"

ENV TASK_ID=""
# Land in the repo (on the per-task volume) by default — so `docker exec`, the
# orchestrator's `attach`, and "Attach to Running Container" terminals open in
# /workspaces/driftID rather than the home dir. The named volume mounts over
# this path at runtime; the dir is pre-created vscode-owned above.
WORKDIR /workspaces/driftID
# Hint for the Dev Containers "Attach to Running Container" flow to open the repo
# folder rather than the container home.
LABEL devcontainer.metadata='[{"workspaceFolder":"/workspaces/driftID"}]'
ENTRYPOINT ["/usr/local/bin/orchestrator-entrypoint.sh"]
