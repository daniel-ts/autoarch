#!/bin/sh
# file: install-script.sh
# author: Daniel Tschertkow <daniel.tschertkow@posteo.de>
# Installs archlinux after my taste

DISK="/dev/sda"  # read from command line

DATA_SOURCE="archlinux.org"  # TODO replace with something useful
echo -n "checking internet connection ..."
if ping $DATA_SOURCE -c 4 -W 0.5 > /dev/null; then
    echo "done."
else
    echo "failed."
    # TODO: code for establishing a connection
    exit 1
fi

timedatectl set-ntp true
# TODO add disk encryption
