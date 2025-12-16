# debian-full: extended version with language servers and k8s tools
# inherits from debian base image

ARG BASE_IMAGE=debian-dev

FROM ${BASE_IMAGE}

LABEL maintainer="viviridian <dev@vvn.space>"
LABEL variant="full"

# switch to root for system-level installs
USER root

# install k8s tools via install-tool.py (with sha256 verification)
RUN install-tool.py install --group k8s --dest /usr/local/bin

# install database clients for debugging
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-client \
    default-mysql-client \
    redis-tools \
    && rm -rf /var/lib/apt/lists/*

# install typescript/javascript language server via npm (as root for global install)
RUN npm install -g typescript typescript-language-server

# install python language servers via uv (as vivlim user)
USER vivlim
WORKDIR /home/vivlim
RUN uv tool install pyright \
    && uv tool install ruff

# copy helix languages.toml for lsp configuration
USER root
COPY dotfiles-full/.config/helix/languages.toml /home/vivlim/.config/helix/languages.toml
RUN chown vivlim:vivlim /home/vivlim/.config/helix/languages.toml

# switch back to vivlim
USER vivlim
WORKDIR /home/vivlim

EXPOSE 22
CMD ["/launch.sh"]
