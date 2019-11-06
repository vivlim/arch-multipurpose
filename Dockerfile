FROM archlinux/base:latest
MAINTAINER viviridian <dev@vvn.space>

# update packages
RUN pacman -Syu --noconfirm \
# user
  && useradd -U -m -u 1000 vivlim \
# ssh
  && pacman -S openssh --noconfirm \
  && sed -i s/#PasswordAuthentication.*/PasswordAuthentication\ no/ /etc/ssh/sshd_config \
  && sed -i s/#GatewayPorts.*/GatewayPorts\ yes/ /etc/ssh/sshd_config \
  && sed -ie 's/#Port 22/Port 22/g' /etc/ssh/sshd_config \
  && sed -ri 's/#HostKey \/etc\/ssh\/ssh_host_key/HostKey \/etc\/ssh\/keys\/ssh_host_key/g' /etc/ssh/sshd_config \
  && sed -ir 's/#HostKey \/etc\/ssh\/ssh_host_rsa_key/HostKey \/etc\/ssh\/keys\/ssh_host_rsa_key/g' /etc/ssh/sshd_config \
  && sed -ir 's/#HostKey \/etc\/ssh\/ssh_host_dsa_key/HostKey \/etc\/ssh\/keys\/ssh_host_dsa_key/g' /etc/ssh/sshd_config \
  && sed -ir 's/#HostKey \/etc\/ssh\/ssh_host_ecdsa_key/HostKey \/etc\/ssh\/keys\/ssh_host_ecdsa_key/g' /etc/ssh/sshd_config \
  && sed -ir 's/#HostKey \/etc\/ssh\/ssh_host_ed25519_key/HostKey \/etc\/ssh\/keys\/ssh_host_ed25519_key/g' /etc/ssh/sshd_config \
  && mkdir /etc/ssh/keys \
# sudo
  && pacman -S sudo --noconfirm \
  && echo 'vivlim ALL=(ALL:ALL) ALL' | sudo EDITOR='tee -a' visudo \
# delete user's password so sudo won't prompt for it
  && passwd -d vivlim \
# basic tools
  && pacman -S vim git zsh base-devel man-db tmux vi --noconfirm \
# install an aur helper
  && cd /tmp \
  && git clone https://aur.archlinux.org/yay.git \
  && chown vivlim yay \
  && cd yay \
  && sudo -u vivlim makepkg -si --noconfirm \
  && cd / \
  && rm -rf /tmp/yay \
# clean cache
  && pacman -Scc --noconfirm

# oh-my-zsh
RUN su vivlim -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh) --unattended" \
  && chsh -s /usr/bin/zsh vivlim

# aur packages
RUN su vivlim -c "yay -S --noconfirm --cleanafter vcsh myrepos"

# remove .zshrc because the config will overwrite it.
RUN rm /home/vivlim/.zshrc

# Install languages: python, js, rust, elixir
RUN pacman --noconfirm -Sy npm python-pipenv elixir \
  && pacman -Scc --noconfirm

# patch on some more packages I forgot to add before (if rebuilding, merge up!)
RUN pacman --noconfirm -Sy base iputils inotify-tools \
  && pacman -Scc --noconfirm

COPY launch.sh /launch.sh
COPY user_launch.sh /user_launch.sh

EXPOSE 22
CMD ["/launch.sh"]
