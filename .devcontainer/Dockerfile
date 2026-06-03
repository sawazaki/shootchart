FROM mcr.microsoft.com/devcontainers/base:bookworm

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    jq \
    less \
    ripgrep \
    unzip \
    zsh \
  && rm -rf /var/lib/apt/lists/*

USER vscode
