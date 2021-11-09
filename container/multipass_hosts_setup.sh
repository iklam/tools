#! /bin/bash
#
# This script creates a few virtual hosts using multipass.
# This script has been tested on: Ubuntu 16.04.6 LTS
#
# See:
#  https://snapcraft.io/docs/installing-snap-on-ubuntu
#  https://multipass.run/


# This is a script for setting up a multipass VM, for the purpose of testing Java and containers
#
# TODO: make it possible to specify different:
#       - OS image version (currently hard-coded to Ubuntu 20.10)
#
# Benefits:
#    - remove all the manual steps of setting up a Linux VM for various types of container technologies
#    - support for http/s proxies, important when testing inside a firewall
#    - (future) easily test combinations of different versions of JDK x different OS distros
#
# Usage:
#    bash multipass_hosts_setup.sh <host>
#
#    Currently supported hosts are:
#       master          - Ubuntu 20.10, Kubernetes master, using docker for containers
#       docker-tester   - Ubuntu 20.10 + docker
#       podman-tester   - Ubuntu 20.10 + podman

inst=$1

if test "$inst" = ""; then
    echo Usage: bash $0 host
    exit 1
fi


supported="master worker podman docker"
found=0
for i in $supported; do
    if [[ "$inst" =~ "$i" ]]; then
        found=1
        break
    fi
done

if test "$found" = "0"; then
    echo Unsupported host $inst
    exit 1
fi

echo ======================================================================
echo "Setting up host \"$inst\""
echo http_proxy=$http_proxy
echo https_proxy=$https_proxy

if test "$http_proxy" = "" || test "$https_proxy" = ""; then
    echo "#"
    echo "# are you inside a firewall?"
    echo "# if so, make sure the env variables http_proxy and https_proxy are set properly"
    echo "#"
fi
echo  ======================================================================

function ddebug () {
    if test "$VERBOSE" != ""; then
        echo $@
    fi
}

function create_if_needed () {
    local inst=$1
    if instance_exist $inst; then
        ddebug "Instance \"$inst\" already exists"
        return
    fi
    # So we can easily build Java inside the VM, run testsm etc:
    #     - Use the same number of CPUs as the physical machine
    #     - Use 16GB RAM / 32GB disk
    # To change it, you can
    # multipass stop <hostname>
    # snap stop multipass.multipassd 
    # edit /var/snap/multipass/common/data/multipassd/multipassd-vm-instances.json
    # snap start multipass.multipassd 
    # multipass start <hostname>
    (set -x; multipass launch --name $inst -c $(cat /proc/cpuinfo | grep processor | wc -l) -m 16G -d 32G 21.10)
}

function instance_exist () {
    multipass list | grep -q ^$1
}

function init_if_needed () {
    local inst=$1

    if multipass list | grep -q ^$inst.*Running; then
        ddebug "Instance \"$inst\" already running"
    else
        multipass start $inst || exit 1
    fi

    ddebug "Initialize \"$inst\" if needed"
    # Don't use 'multipass transfer' as it may not be able to read local files outside of home dir, /mnt, etc.
    # https://askubuntu.com/questions/1348251/multipass-source-path-does-not-exist
    cat vm_init | multipass exec $inst -- bash -c 'cat > vm_init'
    if multipass exec $inst -- bash -c "bash vm_init $inst \"$http_proxy\" \"$https_proxy\" $VERBOSE"; then
        ddebug "Instance \"$inst\" is properly initialized"
        return 0
    else
        ddebug "Instance \"$inst\" has failed to initialize"
        return 1
    fi
}

create_if_needed $inst
init_if_needed $inst
