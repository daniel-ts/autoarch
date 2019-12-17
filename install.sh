#!/bin/sh
# file: install-script.sh
# author: Daniel Tschertkow <daniel.tschertkow@posteo.de>
# Installs archlinux after my taste

_DISK="/dev/sda"
_SOURCE="archlinux.org"  # TODO replace with sensible default

usage () {
    echo -e "\nArch install script.\nUsage: install.sh [options]"
    echo -e "Options:"
    echo -e "\t-h, --help\t\t\tPrint this message"
    echo -e "\t-d, --disk <path to disk>\tThe disk to install the system on."
    echo -e "\t-s, --source <url>\t\tSource of config files and other data."
    echo -e ""
}

_OPTS=$(getopt -un install.sh --options h,d:,s: --longoptions help,disk:,source: -- $@)
if [ $? -ne 0 ]; then
    exit 1
fi
set -- $_OPTS

while [ -n $1 ]; do
    case $1 in
	-h|--help)
	    shift
	    usage
	    exit 0
	    ;;
	-d|--disk)
	    shift
	    _DISK=$1
	    shift
	    ;;
	-s|--source)
	    shift
	    _SOURCE=$1
	    shift
	    ;;
	--)
	    shift
	    set -- $@
	    break
	    ;;
	*)
	    shift
	    echo "*** Fault in parsing: *) reached. Argument: \$1:$1"
	    usage
	    break
	    ;;
    esac
done

echo -n "checking internet connection ..."
if ping $_SOURCE -c 4 -W 1 > /dev/null 2>&1; then
    echo "done."
else
    echo "failed. Source unreachable."
    # TODO: code for establishing a connection
    exit 1
fi

timedatectl set-ntp true
# TODO add disk encryption

echo "Creating partition table on: $_DISK..."
_DSIZE=$(fdisk $_DISK -l | sed 1q | awk -F,\  '{print $2}' | awk '{print $1}')
parted -s ${_DISK} mklabel msdos

setup_small_disk() {
    local _MNT
    _MNT=/mnt
    # 2097152 = 2 MiB, room for the bootloader ERROR HERE
    parted --script ${_DISK} mkpart primary ext4 2MiB 99% \
	&& mkfs.ext4 -q ${_DISK}1 \
	&& mount ${_DISK}1 $_MNT \
	&& fallocate -l 512M $_MNT/swapfile \
	&& mkswap $_MNT/swapfile \
	&& chmod 0600 $_MNT/swapfile \
	&& swapon $_MNT/swapfile \
	&& umount $_MNT
    return $?
}

# wie mache ich Partitionen? / part braucht min(50%, 40gb)
# swap braucht 10% oder 4gb
# home braucht den Rest

if [ $_DSIZE -le 137439000000 ]  # smaller than 128 GiB
then  # everything on a single partition with swapfile
    echo "Setting a partition format for a small disk (< 128 GiB)"
    setup_small_disk
    echo "setup_small_disk returned: $?"
fi
