#!/usr/sbin/bash
cd /home/vivlim
vcsh clone git@github.com:vivlim/vcsh_mr.git mr
mr up

# starting tmux
tmux -2 new-session -d

# Update vim plugins in the background.
tmux new-window -d -n vimconfig -t 9 bash
tmux send-keys -t 9 "cd /home/vivlim/.vim \
&& git submodule init \
&& git submodule update \
&& vim -E -c 'source ~/.vimrc' -c PluginInstall -c qall \
&& curl https://sh.rustup.rs | bash -s -- -y \
&& source ~/.cargo/env \
&& rustup default stable \
&& rustup component add rls rust-analysis rust-src \
&& rustup default nightly" C-m

tmux new-window -t 1 zsh
tmux kill-window -t 0

# check if password has been set and prompt if not
passwd --status vivlim | grep -q NP
if [ $? == 0 ]; then
  echo "No password is set. You will be prompted for one when you connect."
  tmux send-keys -t 1 "passwd vivlim" C-m
fi
