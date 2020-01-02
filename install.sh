#!/bin/sh
# file: install-script.sh
# author: Daniel Tschertkow <daniel.tschertkow@posteo.de>
# Installs archlinux after my taste

_DISK="/dev/sda"
_SOURCE="archlinux.org"  # TODO replace with sensible default
_ZONEINFO="/Europe/Berlin"
_KEYMAP="de-latin1"
_LANG="en_US.UTF-8"
_LOCALE="en_US.UTF-8 UTF-8"
_HOSTNAME="forge"

usage () {
    cat <<EOF
Arch install script.
Usage: install.sh [options]"
Options:
    -h, --help                 Print this message
    -d, --disk <path to disk>  The disk to install the system on.
    -s, --source <url>         Source of config files and other data.
EOF
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

check_inet_conn() {
    echo -n "checking internet connection ..."
    if ping $_SOURCE -c 4 -W 1 > /dev/null 2>&1; then
	echo "done."
	return 0
    else
	echo "failed. Source unreachable."
	return 1
    fi
}

init_live_system() {
    timedatectl set-ntp true
    return 0
}

__setup_small_disk() {
    local _MNT
    _MNT=/mnt

    if lsblk ${_DISK}1 2>&1 \
	   && [ -n $(lsblk -lin -o MOUNTPOINT ${_DISK}1 2> /dev/null) ]
    then
	echo "${_DISK}1 is mounted. Unmounting..."
	umount -l ${_DISK}1 || echo "${_DISK} is busy! Aborting."; return 1
    fi

    # 2097152 = 2 MiB, room for the bootloader
    if parted --script ${_DISK} mkpart primary ext4 2MiB 99% \
	    && mkfs.ext4 -F -L system -q ${_DISK}1; then

	mount ${_DISK}1 $_MNT \
	    && fallocate -l 512M $_MNT/swapfile \
	    && chmod 0600 $_MNT/swapfile \
	    && mkswap -f $_MNT/swapfile \

	umount -l $_MNT
	return $?
    fi
    return 1
}

partition_disks() {
    echo "Creating partition table on: $_DISK..."
    _DSIZE=$(fdisk $_DISK -l | sed 1q | awk -F,\  '{print $2}' | awk '{print $1}')
    parted -s ${_DISK} mklabel msdos

    if [ $_DSIZE -le 137439000000 ]  # smaller than 128 GiB
    then  # everything on a single partition with swapfile
	echo "Setting up a partition format for a small disk (< 128 GiB)"
	if ! __setup_small_disk; then
	    echo "__setup_small_disk failed"
	    exit 1
	fi
    fi
}

__set_basic_target_system_params() {
    local _MNT
    _MNT=${1:-/mnt}

    if [ -e $_MNT/swapfile ] && [ $(grep -c '^/swapfile' $_MNT/etc/fstab) -eq 0 ]
    then
	echo -n "/swapfile none swap defaults 0 0\n" >> $_MNT/etc/fstab
    fi

    echo "LANG=$_LANG" > $_MNT/etc/locale.conf
    echo "$_LOCALE" > $_MNT/etc/locale.gen
    echo "KEYMAP=$_KEYMAP" >> $_MNT/etc/vconsole.conf
    echo "$_HOSTNAME" > $_MNT/etc/hostname
    echo -e "127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.1.1\t$_HOSTNAME.localdomain $_HOSTNAME" > $_MNT/etc/hosts

    return $?
}

__chroot_run() {
    ln -sf $_MNT/usr/share/zoneinfo${_ZONEINFO} $_MNT/etc/localtime
    hwclock --systohc \
	&& locale-gen \
	&& usermod --password $(openssl passwd -6 password) root

    return $?
}

__lock_params() {
    local _MNT
    _MNT=${1:-/mnt}

    export -f __chroot_run
    export _ZONEINFO
    arch-chroot ${_MNT} /bin/sh -c "__chroot_run"

    return $?
}

__install_grub() {
    local _MNT
    _MNT=${1:-/mnt}

    grub-install --target=i386-pc --root-directory=${_MNT} ${_DISK} \
    && arch-chroot ${_MNT} /bin/sh -c "grub-mkconfig -o /boot/grub/grub.cfg"
    return $?
}

bootstrap_system() {
    local _MNT
    _MNT="/mnt"

    echo "installing arch linux. this could take a while."
    if mount ${_DISK}1 ${_MNT} \
	    && pacstrap ${_MNT} base linux linux-firmware grub > /dev/null \
	    && genfstab -U ${_MNT} > $_MNT/etc/fstab
    then
	echo -e "\t\tsuccess mounting and bootstrapping"
	__set_basic_target_system_params $_MNT \
	    && __lock_params $_MNT \
	    && __install_grub $_MNT
    else echo -e "\t\tarch linux install failed"
    fi
    umount -lR $_MNT

    return $?
}

echo -e "\n[bootstrapping the basic system]"
if init_live_system \
	&& partition_disks \
	&& bootstrap_system
then
    echo -e "\tSuccessfully installed base system\n"
    exit 0
else
    echo -e "\tfailure\n"
    exit 1
fi
