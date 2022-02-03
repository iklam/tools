#! /bin/bash
#
# This script creates a few virtual hosts using multipass.
# This script has been tested on: Ubuntu 16.04.6 LTS
# This script has been tested on: Ubuntu 21.10
#
# See:
#  https://snapcraft.io/docs/installing-snap-on-ubuntu
#  https://multipass.run/

# This is a script for setting up a multipass VM, for the purpose of testing Java and containers
#
# TODO: make it possible to specify different:
#       - OS image version (currently hard-coded to Ubuntu 21.10)
#
# Benefits:
#    - remove all the manual steps of setting up a Linux VM for various types of container technologies
#    - support for http/s proxies, important when testing inside a firewall
#    - (future) easily test combinations of different versions of JDK x different OS distros
#
# Usage:
#    bash multipass_vhost_setup.sh <vhost>
#
#    Currently supported <vhost> are:
#       master          - (cgV2) Ubuntu 21.10, Kubernetes master, using docker for containers
#       docker-tester   - (cgV2) Ubuntu 21.10     + docker
#       podman-tester   - (cgV2) Ubuntu 21.10     + podman
#       minikubev1      - (cgV1) Ubuntu 20.04 LTS + docker + cgroupv1 + minikube + kubectl
#       minikubev2      - (cgV2) Ubuntu 21.10     + docker + cgroupv2 + minikube + kubectl
#       worker          - (cgV2) Ubuntu 21.10     + ????

mydir=$(dirname "$0")
vhost=$1

if test -t 0 && test -t 1 && test -t 2; then
    true
else
    echo "This script doesn't work if stdin/out/err is piped"
    echo "Because some apt-get install steps requires real terminal"
    #exit 1
fi

if test "$vhost" = ""; then
    echo Usage: bash $0 host
    exit 1
fi

supported="master worker podman docker minikube"
found=0
for i in $supported; do
    if [[ "$vhost" =~ "$i" ]]; then
        found=1
        break
    fi
done

if test "$found" = "0"; then
    echo Unsupported host $vhost
    exit 1
fi

echo ======================================================================
echo "Setting up host \"$vhost\""
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
    local vhost=$1
    local ubuntu_version=21.10
    if [[ "$vhost" =~ "v1" ]]; then
        ubuntu_version=20.04
    fi
    if vhost_exist $vhost; then
        ddebug "vhost \"$vhost\" already exists"
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
    (set -x; multipass launch --name $vhost -c $(cat /proc/cpuinfo | grep processor | wc -l) -m 16G -d 32G $ubuntu_version)
}

function vhost_exist () {
    multipass list | grep -q ^$1
}

function init_if_needed () {
    local vhost=$1

    if multipass list | grep -q ^$vhost.*Running; then
        ddebug "vhost \"$vhost\" already running"
    else
        multipass start $vhost || exit 1
    fi

    ddebug "Initialize \"$vhost\" if needed"
    # Don't use 'multipass transfer' as it may not be able to read local files outside of home dir, /mnt, etc.
    # https://askubuntu.com/questions/1348251/multipass-source-path-does-not-exist
    cat $mydir/vhost_init.sh | multipass exec $vhost -- bash -c 'cat > vhost_init.sh'
    if multipass exec $vhost -- bash -c "bash vhost_init.sh $vhost \"$http_proxy\" \"$https_proxy\" $VERBOSE"; then
        ddebug "vhost \"$vhost\" is properly initialized"
        return 0
    else
        ddebug "vhost \"$vhost\" has failed to initialize"
        return 1
    fi
}

create_if_needed $vhost
init_if_needed $vhost
