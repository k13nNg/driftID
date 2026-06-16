FROM mcr.microsoft.com/devcontainers/miniconda:1-3

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

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
