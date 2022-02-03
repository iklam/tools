# Handy scripts to set up container environments

Here are some script for setting up various container environments, such as

- docker
- podman
- a chose of cgroup v1 or cgroup v2
- minikube (a simple environment for testing Kubernetes)

## Requirements

- Ubuntu 16.04 or later

    If you don't have a Ubuntu machine handy, you can run [Ubuntu inside VirtualBox](https://ubuntu.com/tutorials/how-to-run-ubuntu-desktop-on-a-virtual-machine-using-virtualbox)

- [multipass](https://multipass.run/)

## Terminology

- vhost

    As far as these scripts are concerned, a vhost (Virtual Host) is an full-blown Ubuntu enviroment that runs inside qemu. The script [multipass\_vhost\_setup.sh](multipass_vhost_setup.sh) sets up all the software components inside the vhost that are required to run a particular container environment (such as minikube)

## HTTP/HTTPS Proxies

If you are running inside a corporate firewall, you need to set up HTTP/HTTPS Proxies before using multipass\_vhost\_setup.sh. Here's an example. You may need to modify it to suit your environment.

```
sudo snap set system proxy.http="http://proxy.domain.com:80"
sudo snap set system proxy.https="http://proxy.domain.com:80"

systemctl status snapd
systemctl start snapd

snap install --classic multipass

snap set multipass proxy.http="http://proxy.domain.com:80"
snap set multipass proxy.https="http://proxy.domain.com:80"
snap restart multipass

snap restart multipass.multipassd 
```


