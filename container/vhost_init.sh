#! /bin/bash
#
# This script runs inside a "multipass" VM to initialize it with
# the apropriate "apt-get, etc".
#
# This script is usually called by ./multipass_vhost_setup.sh
#
# Usage:
#
# bash vhost_init.sh <vhost> <http_proxy> <https_proxy> <verbose>
#
# See ./multipass_vhost_setup.sh for valid names for <vhost>
#
# <http_proxy> and <https_proxy> are optional. If specified, we configure various tools
#            to use these proxies (apt, docker, podman, etc)
#
# <verbose> is optional. If non-empty, the script prints more info about what it's doing.
#
# E.g.
#   bash vhost_init.sh master http://proxy.domain.com:80/ http://proxy.domain.com:80/
#   bash vhost_init.sh master http://proxy.domain.com:80/ http://proxy.domain.com:80/ verbose

vhost=$1

# remove trailing /
export http_proxy=$(echo $2 | sed -e 's/\/$//')
export https_proxy=$(echo $2 | sed -e 's/\/$//')
VERBOSE=$4

function ddebug () {
    if test "$VERBOSE" != ""; then
        echo $@
    fi
}

function apt_update () {
    if test "$APT_UPDATED" = ""; then
        (set -x; sudo apt-get update) || exit 1
        APT_UPDATE=1
    fi
}

ddebug checking initialization status for vhost "$vhost". Proxies = $http_proxy $https_proxy

#-------------------------------------------------------------------------------
# Need to set proxies if you're inside a corporate firewall
ddebug checking apt proxy

if test "$http_proxy" != "" || test "$https_proxy" != ""; then
    cat > /tmp/apt_proxy_conf <<END
Acquire {
  HTTP::proxy "$http_proxy";
  HTTPS::proxy "$https_proxy";
}
END
    cmp -s /tmp/apt_proxy_conf /etc/apt/apt.conf.d/proxy.conf || sudo cp -v /tmp/apt_proxy_conf /etc/apt/apt.conf.d/proxy.conf || exit 1

    # ------------------------------ /etc/profile.d/proxy.sh 

    cat > /tmp/proxy_profile <<EOF
export http_proxy="$http_proxy"
export https_proxy="$https_proxy"
# For curl
export HTTP_PROXY="\$http_proxy"
export HTTPS_PROXY="\$https_proxy"
# For cubectl
export no_proxy="localhost,127.0.0.0/8,192.0.0.0/8,10.0.0.0/8,172.0.0.0/8"
export NO_PROXY="\$no_proxy"
EOF

    (set -x; cat /tmp/proxy_profile)

    cmp -s /tmp/proxy_profile /etc/profile.d/proxy.sh  || sudo mv -v /tmp/proxy_profile /etc/profile.d/proxy.sh 

    # ------------------------------ ~/.docker/config.json
    cat > /tmp/docker_config <<EOF
{
 "proxies":
 {
   "default":
   {
     "httpProxy": "$http_proxy",
     "httpsProxy": "$https_proxy"
   }
 }
}
EOF

    cmp -s /tmp/docker_config ~/.docker/config.json || (mkdir -p ~/.docker; mv -v /tmp/docker_config ~/.docker/config.json)


    # ------------------------------ /etc/systemd/system/docker.service.d/10_docker_proxy.conf
    cat > /tmp/docker_proxy_conf <<EOF
[Service]
Environment=HTTP_PROXY=$http_proxy
Environment=HTTPS_PROXY=$https_proxy
EOF

    cmp -s /tmp/docker_proxy_conf /etc/systemd/system/docker.service.d/10_docker_proxy.conf || \
        (
        sudo mkdir -p /etc/systemd/system/docker.service.d
        sudo mv -v /tmp/docker_proxy_conf /etc/systemd/system/docker.service.d/10_docker_proxy.conf
        # Restart the docker daemon in case it is already running.
        sudo systemctl daemon-reload 2> /dev/null
        sudo systemctl restart docker 2> /dev/null
    ) 
fi

#-------------------------------------------------------------------------------
if [[ $vhost =~ podman ]]; then
    # Not really needed by the Kubernetes installation below
    # Also, the docker installation below will remove podman (WTF!)
    ddebug checking podman

    if type podman 2>/dev/null >/dev/null; then
        ddebug podman is installed
    else
        apt_update
        sudo apt-get -y install podman || exit 1
        echo podman is installed
        podman -v
    fi
fi

#-------------------------------------------------------------------------------
# https://www.virtualizationhowto.com/2021/07/setup-kubernetes-ubuntu-20-04-step-by-step-cluster-configuration/
function init_docker () {
    ddebug checking docker

    if type docker 2>/dev/null >/dev/null; then
        ddebug docker is installed
    else
        sudo groupadd docker 2> /dev/null
        sudo usermod -aG docker ${USER}

        # First get some stuff needed by the below steps
        apt_update
        sudo apt-get install -y \
            apt-transport-https \
            ca-certificates \
            curl \
            gnupg \
            lsb-release || exit 1

        if ! test -f /usr/share/keyrings/docker-archive-keyring.gpg; then
            sudo rm -f /tmp/docker-archive-keyring.gpg
            (set -x; curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
                sudo gpg --dearmor -o /tmp/docker-archive-keyring.gpg) || exit 1
            sudo mv -v /tmp/docker-archive-keyring.gpg /usr/share/keyrings/docker-archive-keyring.gpg || exit 1
        fi

        # impish is ubuntu 20.10
        if ! test -f /etc/apt/sources.list.d/docker.list; then
            echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
                | sudo tee /etc/apt/sources.list.d/docker.list || exit 1
        fi

        apt_update    
        (set -x; sudo apt-get install -y docker-ce docker-ce-cli containerd.io) || exit 1

        if ! test -f; then
            cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF
        fi
    fi
}

#----------------------------------------------------------------------
function init_kubectl () {
    ddebug checking kubectl

    if type kubectl 2>/dev/null >/dev/null; then
        ddebug kubectl is installed
    else
        echo Installing kubectl
        kub_tmp=/tmp/kub_keyring.tmp
        kub_keyring=/usr/share/keyrings/kubernetes-archive-keyring.gpg
        kub_list=/etc/apt/sources.list.d/kubernetes.list

        if ! test -f $kub_keyring; then
            rm -f $kub_tmp || exit 1
            curl -fsSLo $kub_tmp https://packages.cloud.google.com/apt/doc/apt-key.gpg || exit 1
            sudo chown root $kub_tmp || exit 1
            sudo mv -v $kub_tmp $kub_keyring || exit 1
        fi

        if ! test -f $kub_list; then
            (echo "deb [signed-by=$kub_keyring] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee $kub_list) || exit 1
        fi

        apt_update
        sudo apt-get install -y kubelet kubeadm kubectl || exit 1
        sudo apt-mark hold kubelet kubeadm kubectl || exit 1
    fi
}

function init_minikube () {
    # See:
    # https://nextgentips.com/2021/12/24/how-to-install-and-configure-minikube-on-ubuntu-21-10/
    (set -x;
     curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
     sudo install minikube-linux-amd64 /usr/local/bin/minikube
     curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
     chmod +x ./kubectl
     sudo mv ./kubectl /usr/local/bin/kubectl
    )

    # At this point, $USER may have just been added to the "docker" group,
    # but this doesn't take effect until the user logs in again. What a pain.
    # We need to do this in a subshell:

cat > test_minikube.sh <<EOF
    echo "no_proxy must be set for some of the following commands to work"
    (set -x; bash -c 'env | grep -i no_proxy')
    (set -x; minikube start)

    (set -x; kubectl cluster-info)
    (set -x; kubectl get po -A)

    (set -x; kubectl create deployment hello-minikube --image=k8s.gcr.io/echoserver:1.4)
    (set -x; kubectl expose deployment hello-minikube --type=NodePort --port=8080)
    (set -x; kubectl get services hello-minikube)
    (set -x; minikube service --url hello-minikube)
    echo ------------------------------------------------------------
    echo Check if hello-minikube is working correctly
    echo ------------------------------------------------------------
    hello_url=\$(minikube service --url hello-minikube)
    echo wait for the server to start ...
    (set -x; sleep 10)
    (set -x; wget -q -O - --no-proxy \$hello_url)
    echo '**********'
    echo "If you see something like \"CLIENT VALUES:...\", you're good to go"
EOF
    (set -x; sudo -E bash -c ". /etc/profile.d/proxy.sh; sudo -E -u $USER bash test_minikube.sh")
    echo "You can run test_minikube.sh again if you restarted this host"
}

if [[ $vhost =~ master ]]; then
    init_docker
    init_kubectl
fi

if [[ $vhost =~ worker ]]; then
    init_docker
    init_kubectl
fi

if [[ $vhost =~ docker ]]; then
    init_docker
fi

if [[ $vhost =~ minikube ]]; then
    init_docker
    init_minikube
fi
