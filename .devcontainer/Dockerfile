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
