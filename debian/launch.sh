#!/bin/bash
set -e

# usage: /launch.sh [--init-only]
#   --init-only: run initialization and exit (useful for testing)
#
# environment variables:
#   ENABLE_SSH=1        - start sshd (default: disabled)

INIT_ONLY=false

for arg in "$@"; do
    case $arg in
        --init-only) INIT_ONLY=true ;;
    esac
done

# ssh setup only if sshd will be started
if [ "$ENABLE_SSH" = "1" ]; then
    # generate ssh host keys if they don't exist
    if [ ! "$(ls -A /etc/ssh/keys 2>/dev/null)" ]; then
        echo "generating ssh host keys..."
        sudo ssh-keygen -A
        sudo mv /etc/ssh/ssh_host_* /etc/ssh/keys/ 2>/dev/null || true
    fi

    # link host keys
    for key in /etc/ssh/keys/ssh_host_*; do
        if [ -f "$key" ]; then
            sudo ln -sf "$key" /etc/ssh/
        fi
    done

    # set up user authorized_keys - merge from github and any mounted local keys
    setup_authorized_keys() {
        mkdir -p ~/.ssh
        chmod 700 ~/.ssh
        
        # start fresh
        : > ~/.ssh/authorized_keys.tmp
        
        # fetch from github
        echo "fetching ssh keys from github..."
        if curl -fsSL https://github.com/vivlim.keys >> ~/.ssh/authorized_keys.tmp 2>/dev/null; then
            echo "fetched github keys successfully."
        else
            echo "warning: could not fetch github keys."
        fi
        
        # merge any existing mounted keys (e.g., from volume mount)
        if [ -f ~/.ssh/authorized_keys ] && [ -s ~/.ssh/authorized_keys ]; then
            echo "merging existing authorized_keys..."
            cat ~/.ssh/authorized_keys >> ~/.ssh/authorized_keys.tmp
        fi
        
        # deduplicate and finalize
        sort -u ~/.ssh/authorized_keys.tmp > ~/.ssh/authorized_keys
        rm -f ~/.ssh/authorized_keys.tmp
        chmod 644 ~/.ssh/authorized_keys
    }

    setup_authorized_keys
fi

# source user environment
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi

echo "initialization complete."

if [ "$INIT_ONLY" = true ]; then
    echo "init-only mode, exiting."
    exit 0
fi

# start sshd if enabled
if [ "$ENABLE_SSH" = "1" ]; then
    echo "starting sshd..."
    exec sudo /usr/sbin/sshd -D -e
fi

# default: interactive shell
exec bash -l
