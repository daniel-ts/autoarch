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
    # exit 1
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

# wie mache ich Partitionen? / part braucht min(50%, 40gb)
# swap braucht 10% oder 4gb
# home braucht den Rest

if [ $_DSIZE -le 137439000000 ]  # smaller than 128 GiB
then  # everything on a single partition with swapfile
    echo "Setting a partition format for a small disk (< 128 GiB)"
    setup_small_disk
    if ! $?; then
	echo "setup_small_disk failed"
    fi
fi

write_config_files() {
    local _MNT
    _MNT=${1:-/mnt}

    if [ -e $_MNT/swapfile ] && grep -c "^/swapfile" $_MNT/etc/fstab; then
	echo "/swapfile none swap defaults 0 0" >> $_MNT/etc/fstab
    fi

    ln -sf $_MNT/usr/share/zoneinfo${_ZONEINFO} $_MNT/etc/localtime
    echo "LANG=$_LANG" > $_MNT/etc/locale.conf
    echo "$_LOCALE" > $_MNT/etc/locale.gen
    echo "KEYMAP=$_KEYMAP" >> $_MNT/etc/vconsole.conf
    echo "$_HOSTNAME" > $_MNT/etc/hostname
    echo -e "127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.1.1\t$_HOSTNAME.localdomain $_HOSTNAME" > /etc/hosts

    return $?
}

set_config() {
    local _MNT
    _MNT=${1:-/mnt}

    ### chroot enter ###
    arch-chroot $_MNT

    hwclock --systohc
    locale-gen
    usermod --password $(openssl passwd -6 password) root
    grub-install --target=i386-pc $_DISK
    grub-mkconfig -o /boot/grub/grub.cfg

    exit
    ### chroot exit ###

    return $?
}

bootstrap_system() {
    local _MNT
    _MNT=/mnt

    mount $_DISK1 $_MNT \
	&& pacstrap $_MNT base linux linux-firmware \
	&& genfstab -U $_MNT > $_MNT/etc/fstab

    write_config_files $_MNT \
	&& set_config $_MNT

    umount -lR $_MNT

    return $?
}
