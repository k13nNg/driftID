FROM mcr.microsoft.com/devcontainers/miniconda:1-3

USER root

RUN conda config --remove channels defaults || true \
    && conda config --add channels conda-forge \
    && conda config --set channel_priority strict

COPY .devcontainer/environment.yml /tmp/environment.yml
RUN conda env create -f /tmp/environment.yml \
    && conda clean -afy

USER vscode

RUN echo "conda activate gpu-env" >> ~/.bashrc

ENV PATH=/opt/conda/envs/gpu-env/bin:${PATH}
