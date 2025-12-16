# base debian container with dev tools

FROM debian:bookworm-slim

# prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

LABEL maintainer="viviridian <dev@vvn.space>"

# install base packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server \
    sudo \
    curl \
    wget \
    git \
    bash \
    bash-completion \
    ca-certificates \
    gnupg \
    xz-utils \
    unzip \
    procps \
    locales \
    iptables \
    && rm -rf /var/lib/apt/lists/*

# set up locales
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8
ENV SHELL=/bin/bash TERM=xterm-256color COLORTERM=truecolor

# create user
RUN useradd -U -m -u 1000 -s /bin/bash vivlim \
    && echo 'vivlim ALL=(ALL:ALL) NOPASSWD: ALL' >> /etc/sudoers \
    && mkdir -p /run/sshd

# configure ssh - listen on all interfaces
RUN sed -i 's/#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config \
    && sed -i 's/#GatewayPorts.*/GatewayPorts yes/' /etc/ssh/sshd_config \
    && sed -i 's/#Port 22/Port 22/' /etc/ssh/sshd_config \
    && sed -i 's/#ListenAddress 0.0.0.0/ListenAddress 0.0.0.0/' /etc/ssh/sshd_config \
    && sed -i 's/#ListenAddress ::/ListenAddress ::/' /etc/ssh/sshd_config \
    && mkdir -p /etc/ssh/keys

# install tailscale
RUN curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg -o /usr/share/keyrings/tailscale-archive-keyring.gpg \
    && curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.tailscale-keyring.list -o /etc/apt/sources.list.d/tailscale.list \
    && apt-get update \
    && apt-get install -y tailscale \
    && rm -rf /var/lib/apt/lists/*

# install ripgrep, fd-find, and common utilities from debian repos
RUN apt-get update && apt-get install -y --no-install-recommends \
    ripgrep \
    fd-find \
    file \
    jq \
    p7zip-full \
    unar \
    fzf \
    tree \
    less \
    htop \
    ncdu \
    rsync \
    make \
    patch \
    diffutils \
    man-db \
    openssh-client \
    netcat-openbsd \
    dnsutils \
    iputils-ping \
    iproute2 \
    vim-tiny \
    nano \
    strace \
    lsof \
    tcpdump \
    socat \
    openssl \
    bind9-host \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s $(which fdfind) /usr/local/bin/fd

# install node.js and npm
ARG NODE_VERSION=22
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# install-tool.py for verified binary installations
COPY install-tool.py /usr/local/bin/install-tool.py
RUN chmod +x /usr/local/bin/install-tool.py

# add launch script
COPY debian/launch.sh /launch.sh
RUN chmod +x /launch.sh

# install base tools via install-tool.py (as root for /usr/local/bin)
# helix is installed separately as vivlim so runtime goes to ~/.config/helix/runtime
RUN install-tool.py install zellij yazi starship uv direnv just --dest /usr/local/bin

# do stuff as user now
USER vivlim
WORKDIR /home/vivlim
RUN curl -L https://nixos.org/nix/install | sh -s -- --no-daemon
# nix binaries are a fallback
ENV PATH="/home/vivlim/bin:/home/vivlim/.local/bin:${PATH}:/home/vivlim/.nix-profile/bin"

RUN mkdir -p ~/bin && install-tool.py install helix --dest ~/bin

COPY dotfiles/.bashrc /home/vivlim/.bashrc
COPY dotfiles/.bash_profile /home/vivlim/.bash_profile
COPY dotfiles/.bashrc.d /home/vivlim/.bashrc.d
COPY dotfiles/.config /home/vivlim/.config

EXPOSE 22
CMD ["/launch.sh"]
