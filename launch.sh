#!/usr/sbin/bash

if [ "$(ls -A /etc/ssh/keys)" ]; then
    echo "keys exist in /etc/ssh/keys, using those."
else
    echo "generating ssh keys"
    /usr/bin/ssh-keygen -A
    mv /etc/ssh/ssh_host*key* /etc/ssh/keys
    ssh-keygen -t rsa -b 4096 -f /etc/ssh/keys/ssh_host_key
fi

echo "executing user launch script"
su vivlim -c /user_launch.sh

echo "ready for connections!"

/usr/sbin/sshd -D
