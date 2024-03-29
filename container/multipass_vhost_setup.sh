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
# Benefits:
#    - remove all the manual steps of setting up a Linux VM for various types of container technologies
#    - support for http/s proxies, important when testing inside a firewall
#    - (future) easily test combinations of different versions of JDK x different OS distros
#
# Usage:
#    bash multipass_vhost_setup.sh <vhost>
#
# vhost can be one of the following:
#
# vhost            cgroup Ubuntu           Components installed
# ---------------- ------ ---------------- ---------------------------------------------------
# docker-cgv1      v1     Ubuntu 20.04 LTS docker
# docker-cgv2      v2     Ubuntu 21.10     docker
# podman-cgv1      v1     Ubuntu 20.04 LTS podman
# podman-cgv2      v2     Ubuntu 21.10     podman
# minikube-cgv1    v1     Ubuntu 20.04 LTS docker + minikube + kubectl
# minikube-cgv2    v2     Ubuntu 21.10     docker + minikube + kubectl

mydir=$(dirname "$0")
vhost=$1

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
    vcpus=$(cat /proc/cpuinfo | grep processor | wc -l)

    if [[ $vhost =~ minikube ]]; then
        # With minikube, to test CPU limits, it's better to use a smaller setup
        # - minikube's built-in docker driver always uses the same cpus/memory as
        #   the vhost. For some reason it cannot be adjusted
        # - It might be possible to run with "minikube start --driver=virtualbox"
        #   and limit the cpus/memory, but VB fails to boot up the minikube node
        #   for me
        vcpus=4
    fi
    # To change it, you can
    # multipass stop <hostname>
    # snap stop multipass.multipassd 
    # edit /var/snap/multipass/common/data/multipassd/multipassd-vm-instances.json
    # snap start multipass.multipassd 
    # multipass start <hostname>
    (set -x; multipass launch --name $vhost -c $vcpus -m 16G -d 32G $ubuntu_version)
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
