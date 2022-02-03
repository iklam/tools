# Handy scripts to set up container environments

Here are some script for setting up various container environments, such as

- docker
- podman
- a chose of cgroup v1 or cgroup v2
- minikube (a simple environment for testing Kubernetes)

## Requirements

- Ubuntu 16.04 or later

    If you don't have a Ubuntu machine handy, you can run [Ubuntu inside VirtualBox](https://ubuntu.com/tutorials/how-to-run-ubuntu-desktop-on-a-virtual-machine-using-virtualbox)

- [snap](https://snapcraft.io/docs/installing-snap-on-ubuntu)

- [multipass](https://multipass.run/)

## Terminology

- vhost

    As far as these scripts are concerned, a vhost (Virtual Host) is an full-blown Ubuntu enviroment that runs inside qemu. The script [multipass\_vhost\_setup.sh](multipass_vhost_setup.sh) sets up all the software components inside the vhost that are required to run a particular container environment (such as minikube)

## HTTP/HTTPS Proxies

If you are running inside a corporate firewall, you need to set up HTTP/HTTPS Proxies before using multipass\_vhost\_setup.sh. Here's an example. You may need to modify it to suit your environment.

    export http_proxy=http://proxy.domain.com:80
    export https_proxy=http://proxy.domain.com:80

    sudo snap set system proxy.http="$http_proxy"
    sudo snap set system proxy.https="$http_proxy"

    systemctl status snapd
    systemctl start snapd

    snap install --classic multipass

    snap set multipass proxy.http="$http_proxy"
    snap set multipass proxy.https="$http_proxy"
    snap restart multipass

    snap restart multipass.multipassd 

Please make sure your environment variables `http_proxy` and `https_proxy` are set correctly. multipass\_vhost\_setup.sh will use these variables to set up the vhosts.

## Running multipass\_vhost\_setup.sh

To set up a vhost, use the command:

    bash multipass\_vhost\_setup.sh <vhost>

`<vhost>` can be one of the following:

    vhost            cgroup Ubuntu           Components installed
    ---------------- ------ ---------------- ---------------------------------------------------
    docker-cgv1      v1     Ubuntu 20.04 LTS docker
    docker-cgv2      v2     Ubuntu 21.10     docker
    podman-cgv1      v1     Ubuntu 20.04 LTS podman
    podman-cgv2      v2     Ubuntu 21.10     podman
    minikube-cgv1    v1     Ubuntu 20.04 LTS docker + minikube + kubectl
    minikube-cgv2    v2     Ubuntu 21.10     docker + minikube + kubectl

