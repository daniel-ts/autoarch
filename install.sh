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

_OPTS=`getopt -n install.sh --options h,d:,s: --longoptions help,disk:,source: -- $@`
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
