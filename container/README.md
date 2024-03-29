# Handy Scripts to Set up Container Environments for JDK Developers

The goal of this document is to help you get started with JVM developement
for container environments, without knowing too much about containers ...

Here are some script for setting up various container environments, such as

- [docker](https://www.docker.com/)
- [podman](https://podman.io/)
- a chose of [cgroup v1](https://www.kernel.org/doc/html/latest/admin-guide/cgroup-v1/index.html)
  or [cgroup v2](https://www.kernel.org/doc/html/latest/admin-guide/cgroup-v2.html)
- [minikube](https://minikube.sigs.k8s.io/docs/start/) (a simple environment for testing [Kubernetes](https://kubernetes.io/))

In addition, this document shows a few examples of using Java with containers.
It also has a discussion about CpuShares/CpuQuota, which JDK 17 uses to scale
its threadpools. See [JDK-8281181](https://bugs.openjdk.java.net/browse/JDK-8281181.)

## Requirements

- Ubuntu 16.04 or later

    If you don't have a Ubuntu machine handy, you can run [Ubuntu inside VirtualBox](https://ubuntu.com/tutorials/how-to-run-ubuntu-desktop-on-a-virtual-machine-using-virtualbox)

- [snap](https://snapcraft.io/docs/installing-snap-on-ubuntu)

- [multipass](https://multipass.run/)

## Terminology

- vhost

    As far as these scripts are concerned, a vhost (Virtual Host) is an
    full-blown Ubuntu enviroment that runs inside qemu. The script
    [`multipass_vhost_setup.sh`](multipass_vhost_setup.sh) sets up all the
    software components inside the vhost that are required to run a particular
    container environment (such as minikube).

By using vhosts, we can experiment with different versions of Linux kernel,
cgroup (v1 or v2), Linux distributions (only Ubuntu at the moment ...).

Also, `multipass_vhost_setup.sh` sets up the hosts in a known, reproducible state.
That way, we don't need to worry about behavioral variations that may be introduced
by manual configurations.

Lastly, you main desktop environment will be isolated from any potential disruption
that may happen when you install/tweak critical components such as docker or cgroup.

## HTTP/HTTPS Proxies

If you are running inside a corporate firewall, you need to set up HTTP/HTTPS Proxies.

If you're install a new Ubuntu (either on a physical machine or in VirtualBox), you need to do something like this:

    cat > /etc/apt/apt.conf.d/proxy.conf <<END
    Acquire {
      HTTP::proxy "$http_proxy";
      HTTPS::proxy "$https_proxy";
    }
    END
    apt update

Then, you need to set up the proxies for snap and miltipass:

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

Please make sure your environment variables `http_proxy` and `https_proxy` are set correctly. `multipass_vhost_setup.sh` will use these variables to set up the vhosts.

## Running `multipass_vhost_setup.sh`

To set up a vhost, use the command:

    bash multipass_vhost_setup.sh <vhost>

`<vhost>` can be one of the following:

    vhost            cgroup Ubuntu           Components installed
    ---------------- ------ ---------------- ---------------------------------------------------
    docker-cgv1      v1     Ubuntu 20.04 LTS docker
    docker-cgv2      v2     Ubuntu 21.10     docker
    podman-cgv1      v1     Ubuntu 20.04 LTS podman
    podman-cgv2      v2     Ubuntu 21.10     podman
    minikube-cgv1    v1     Ubuntu 20.04 LTS docker + minikube + kubectl
    minikube-cgv2    v2     Ubuntu 21.10     docker + minikube + kubectl

For example:

    bash multipass_vhost_setup.sh minikube-cgv2


## Versions of installed software components

- `docker` and `podman`: as packaged in the given version of Ubuntu

- `minikube`: https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64

- `kubectl`:

        VERSION=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
        https://storage.googleapis.com/kubernetes-release/release/$VERSION/bin/linux/amd64/kubectl


## Using docker to run Java

    # First install the vhost
    $ bash multipass_vhost_setup.sh dockerv2
    $ multipass shell dockerv2

    # Run some code inside jshell so we don't need to build any classes
    ubuntu@dockerv2:~$ docker run --rm container-registry.oracle.com/java/openjdk:17 \
         bash -c "echo 'System.out.println(ForkJoinPool.commonPool().getParallelism())' | jshell -"
    Unable to find image 'container-registry.oracle.com/java/openjdk:17' locally
    17: Pulling from java/openjdk
    671f9b4a2df1: Pull complete 
    250f17bea156: Pull complete 
    aba0b42c707c: Pull complete 
    Digest: sha256:02171ab90fd958da8b8426d2dfec39113dd96ee38199d906e30c4c7dd0914015
    Status: Downloaded newer image for container-registry.oracle.com/java/openjdk:17
    Feb 03, 2022 10:34:48 PM java.util.prefs.FileSystemPreferences$1 run
    INFO: Created user preferences directory.
    getParallelism() = 31

    # To run your own class files, you need to create your own Docker image.
    # First get a class file into dockerv2:
    ubuntu@dockerv2:~$ exit
    $ cat HelloWorld.class | multipass exec dockerv2 -- bash -c 'cat > HelloWorld.class'

    # Then build my docker image inside dockerv2
    $ multipass shell dockerv2
    ubuntu@dockerv2:~$ cat > Dockerfile
    FROM container-registry.oracle.com/java/openjdk:17
    COPY HelloWorld.class /
    CMD ["bash"]
    ^D

    ubuntu@dockerv2:~$ docker build -t my-openjdk17-image .
    Sending build context to Docker daemon  24.58kB
    Step 1/3 : FROM container-registry.oracle.com/java/openjdk:17
     ---> 115002222065
    Step 2/3 : COPY HelloWorld.class /
     ---> 7b5e59af33d2
    Step 3/3 : CMD ["bash"]
     ---> Running in dc5c98509a3c
    Removing intermediate container dc5c98509a3c
     ---> 6af6fa7ce416
    Successfully built 6af6fa7ce416
    Successfully tagged my-openjdk17-image:latest

    ubuntu@dockerv2:~$ docker run --rm my-openjdk17-image java -cp / HelloWorld
    Hello World

## Using minikube

`multipass_vhost_setup.sh` automatically installed a deployment called `hello-minikube`,
which is a simple HTTP server that echos the incoming connection. Here are some example
commands that you can issue to examine this environment:

    # First install the vhost
    $ bash multipass_vhost_setup.sh minikube-cgv2

    # At this point, the minikube environment is running, and hello-minikube is deployed
    $ multipass shell minikube-cgv2
    ubuntu@minikube-cgv2:~$ kubectl get pod -A
    NAMESPACE     NAME                               READY   STATUS    RESTARTS        AGE
    default       hello-minikube-7bc9d7884c-8ggb4    1/1     Running   0               5m59s
    kube-system   coredns-64897985d-krtzr            1/1     Running   0               5m59s
    kube-system   etcd-minikube                      1/1     Running   0               6m14s
    kube-system   kube-apiserver-minikube            1/1     Running   0               6m13s
    kube-system   kube-controller-manager-minikube   1/1     Running   0               6m11s
    kube-system   kube-proxy-fjtlh                   1/1     Running   0               5m59s
    kube-system   kube-scheduler-minikube            1/1     Running   0               6m11s
    kube-system   storage-provisioner                1/1     Running   1 (5m58s ago)   6m9s
    ubuntu@minikube-cgv2:~$ minikube service --url hello-minikube
    http://192.168.49.2:32692

    # hello-minikube should be running, and will echo back the URL that we request
    ubuntu@minikube-cgv2:~$ wget -q -O - --no-proxy http://192.168.49.2:32692/hello | grep request_uri
    request_uri=http://192.168.49.2:8080/hello

    # minikube simulates a "host" that runs all the docker containers deployed by kubectl.
    # At the level of ubuntu@minikube-cgv2, we see a single docker container.
    ubuntu@minikube-cgv2:~$ docker ps --format '{{.ID}}\t{{.Image}}\t{{.Names}}'
    0dea0ee615e8	gcr.io/k8s-minikube/kicbase:v0.0.29	minikube

    # if we want to examine the individual Kubernetes deployments, we have to get into this container.
    ubuntu@minikube-cgv2:~$ docker exec -it minikube bash
    root@minikube:/# docker ps --format '{{.ID}}\t{{.Names}}'
    309e56bfa2cc	k8s_echoserver_hello-minikube-7bc9d7884c-8ggb4_default_9e46e642-b5a9-417c-9666-99dc19022d01_0
    552e1ef33ae8	k8s_storage-provisioner_storage-provisioner_kube-system_0bf719d1-4252-47b3-801b-8a45fbbcb4c7_1
    7fcd90cb0268	k8s_coredns_coredns-64897985d-krtzr_kube-system_acc00f52-9224-4e8c-858c-0b317639344d_0
    e4375ab65191	k8s_kube-proxy_kube-proxy-fjtlh_kube-system_fede493b-0afa-421a-bdda-7a695636f9f7_0
    baa17bb81c73	k8s_POD_coredns-64897985d-krtzr_kube-system_acc00f52-9224-4e8c-858c-0b317639344d_0
    4f5e7eec3fe4	k8s_POD_hello-minikube-7bc9d7884c-8ggb4_default_9e46e642-b5a9-417c-9666-99dc19022d01_0
    5389e67dda6f	k8s_POD_kube-proxy-fjtlh_kube-system_fede493b-0afa-421a-bdda-7a695636f9f7_0
    3eac95304747	k8s_POD_storage-provisioner_kube-system_0bf719d1-4252-47b3-801b-8a45fbbcb4c7_0
    df7611586fcd	k8s_kube-controller-manager_kube-controller-manager-minikube_kube-system_3db91997554714e5ece3296773cf98a5_0
    3a02f9004eb3	k8s_kube-scheduler_kube-scheduler-minikube_kube-system_b8bdc344ff0000e961009344b94de59c_0
    e6604eb11b16	k8s_kube-apiserver_kube-apiserver-minikube_kube-system_96be69ce9ff7dc0acff6fda2873a009a_0
    8789e8ab2ca8	k8s_etcd_etcd-minikube_kube-system_9d3d310935e5fabe942511eec3e2cd0c_0
    39163108c1e2	k8s_POD_kube-scheduler-minikube_kube-system_b8bdc344ff0000e961009344b94de59c_0
    fdb766b5305d	k8s_POD_kube-controller-manager-minikube_kube-system_3db91997554714e5ece3296773cf98a5_0
    d29f7a304719	k8s_POD_kube-apiserver-minikube_kube-system_96be69ce9ff7dc0acff6fda2873a009a_0
    dd9af66239ed	k8s_POD_etcd-minikube_kube-system_9d3d310935e5fabe942511eec3e2cd0c_0

### Restarting minikube

    # If you stop/restart minikube, or if you reboot the vhost, the hello-minikube
    # deployment will disappear:
    ubuntu@minikube-cgv2:~$ minikube status
    minikube
    type: Control Plane
    host: Running
    kubelet: Running
    apiserver: Running
    kubeconfig: Configured

    ubuntu@minikube-cgv2:~$ minikube stop
    ubuntu@minikube-cgv2:~$ minikube start
    ...
    ubuntu@minikube-cgv2:~$ kubectl get pod -A
    NAMESPACE     NAME                               READY   STATUS             RESTARTS     AGE
    kube-system   coredns-64897985d-rkt6k            1/1     Running            0            6s
    kube-system   etcd-minikube                      1/1     Running            1            18s
    kube-system   kube-apiserver-minikube            1/1     Running            1            18s
    kube-system   kube-controller-manager-minikube   1/1     Running            1            18s
    kube-system   kube-proxy-xnb2h                   1/1     Running            0            7s
    kube-system   kube-scheduler-minikube            1/1     Running            1            18s
    kube-system   storage-provisioner                0/1     CrashLoopBackOff   1 (5s ago)   16s


    # You need to do the following to bring it back
    #
    ubuntu@minikube-cgv2:~$ kubectl create deployment hello-minikube --image=k8s.gcr.io/echoserver:1.4
    deployment.apps/hello-minikube created
    ubuntu@minikube-cgv2:~$ kubectl expose deployment hello-minikube --type=NodePort --port=8080
    service/hello-minikube exposed
    ubuntu@minikube-cgv2:~$ kubectl get services hello-minikube
    NAME             TYPE       CLUSTER-IP   EXTERNAL-IP   PORT(S)          AGE
    hello-minikube   NodePort   10.99.5.8    <none>        8080:31098/TCP   8s
    ubuntu@minikube-cgv2:~$ minikube service --url hello-minikube
    http://192.168.49.2:31098
    ubuntu@minikube-cgv2:~$ kubectl get pod -A
    NAMESPACE     NAME                               READY   STATUS    RESTARTS       AGE
    default       hello-minikube-7bc9d7884c-njqms    1/1     Running   0              44s
    kube-system   coredns-64897985d-rkt6k            1/1     Running   0              3m9s
    kube-system   etcd-minikube                      1/1     Running   1              3m21s
    kube-system   kube-apiserver-minikube            1/1     Running   1              3m21s
    kube-system   kube-controller-manager-minikube   1/1     Running   1              3m21s
    kube-system   kube-proxy-xnb2h                   1/1     Running   0              3m10s
    kube-system   kube-scheduler-minikube            1/1     Running   1              3m21s
    kube-system   storage-provisioner                1/1     Running   2 (3m8s ago)   3m19s

## CpuShares/CpuQuota as Configured by Kubernetes

### minikube + cgroupv2

    # List the CpuShares/CpuQuota of each container
    ubuntu@minikube-cgv2:~$ docker exec -it minikube bash
    root@minikube:/# for i in $(docker ps --format '{{.ID}}'); do \
                         printf "    %s %6d %6d %s\n" $i \
                             $(docker inspect $i --format '{{.HostConfig.CpuShares}}') \
                             $(docker inspect $i --format '{{.HostConfig.CpuQuota}}') \
                             $(docker inspect $i --format '{{.Name}}'); \
                     done
    309e56bfa2cc      2      0 /k8s_echoserver_hello-minikube-7bc9d7884c-8ggb4_default_9e46e642-b5a9-417c-9666-99dc19022d01_0
    552e1ef33ae8      2      0 /k8s_storage-provisioner_storage-provisioner_kube-system_0bf719d1-4252-47b3-801b-8a45fbbcb4c7_1
    7fcd90cb0268    102      0 /k8s_coredns_coredns-64897985d-krtzr_kube-system_acc00f52-9224-4e8c-858c-0b317639344d_0
    e4375ab65191      2      0 /k8s_kube-proxy_kube-proxy-fjtlh_kube-system_fede493b-0afa-421a-bdda-7a695636f9f7_0
    baa17bb81c73      2      0 /k8s_POD_coredns-64897985d-krtzr_kube-system_acc00f52-9224-4e8c-858c-0b317639344d_0
    4f5e7eec3fe4      2      0 /k8s_POD_hello-minikube-7bc9d7884c-8ggb4_default_9e46e642-b5a9-417c-9666-99dc19022d01_0
    5389e67dda6f      2      0 /k8s_POD_kube-proxy-fjtlh_kube-system_fede493b-0afa-421a-bdda-7a695636f9f7_0
    3eac95304747      2      0 /k8s_POD_storage-provisioner_kube-system_0bf719d1-4252-47b3-801b-8a45fbbcb4c7_0
    df7611586fcd    204      0 /k8s_kube-controller-manager_kube-controller-manager-minikube_kube-system_3db91997554714e5ece3296773cf98a5_0
    3a02f9004eb3    102      0 /k8s_kube-scheduler_kube-scheduler-minikube_kube-system_b8bdc344ff0000e961009344b94de59c_0
    e6604eb11b16    256      0 /k8s_kube-apiserver_kube-apiserver-minikube_kube-system_96be69ce9ff7dc0acff6fda2873a009a_0
    8789e8ab2ca8    102      0 /k8s_etcd_etcd-minikube_kube-system_9d3d310935e5fabe942511eec3e2cd0c_0
    39163108c1e2      2      0 /k8s_POD_kube-scheduler-minikube_kube-system_b8bdc344ff0000e961009344b94de59c_0
    fdb766b5305d      2      0 /k8s_POD_kube-controller-manager-minikube_kube-system_3db91997554714e5ece3296773cf98a5_0
    d29f7a304719      2      0 /k8s_POD_kube-apiserver-minikube_kube-system_96be69ce9ff7dc0acff6fda2873a009a_0
    dd9af66239ed      2      0 /k8s_POD_etcd-minikube_kube-system_9d3d310935e5fabe942511eec3e2cd0c_0

    # Note that the CpuShares of 2 for hello-minikube is translated to cpu.weight of 1
    root@minikube:/# docker exec 309e56bfa2cc cat /sys/fs/cgroup/cpu.weight
    1

    # I can't figure out how to get the cpu.weight for each of the containers, but here are
    # the possible values:
    root@minikube:/# find /sys/fs/cgroup -name cpu.weight | xargs cat | sort -n | uniq
    1
    4
    8
    10
    30
    100
    1250

### minikube + cgroupv1

    # The CpuShares/CpuQuota results are identical to cgroupv1. The only difference
    # is instead of cpu.weight, cgroupv1 uses /sys/fs/cgroup/cpu,cpuacct/cpu.shares

    $ multipass shell minikube-cgv1
    ubuntu@minikube-cgv1:~$ docker exec -it minikube bash
    root@minikube:/# for i in $(docker ps --format '{{.ID}}'); do \
                          printf "    %s %6d %6d %s\n" $i \
                              $(docker inspect $i --format '{{.HostConfig.CpuShares}}') \
                              $(docker inspect $i --format '{{.HostConfig.CpuQuota}}') \
                              $(docker inspect $i --format '{{.Name}}'); \
                     done
    36770d423317      2      0 /k8s_echoserver_hello-minikube-7bc9d7884c-zt69j_default_510c4dd8-39d6-45ba-a137-33d54864c577_0
    3cfdd5126d3b      2      0 /k8s_storage-provisioner_storage-provisioner_kube-system_dcfc00c9-fc10-4416-8b4b-2718cf8ce99c_1
    e31c6f6d73d5    102      0 /k8s_coredns_coredns-64897985d-vw4fd_kube-system_9694e3cc-2839-424e-be47-489ea3bbf498_0
    6464c89078f6      2      0 /k8s_POD_hello-minikube-7bc9d7884c-zt69j_default_510c4dd8-39d6-45ba-a137-33d54864c577_0
    5b5fcca1726d      2      0 /k8s_POD_coredns-64897985d-vw4fd_kube-system_9694e3cc-2839-424e-be47-489ea3bbf498_0
    21e487826d9b      2      0 /k8s_kube-proxy_kube-proxy-8vr2q_kube-system_18ee9a7d-63d9-4c73-b168-c063486cf417_0
    4f73b6ecddfb      2      0 /k8s_POD_storage-provisioner_kube-system_dcfc00c9-fc10-4416-8b4b-2718cf8ce99c_0
    5c92b16c3c1c      2      0 /k8s_POD_kube-proxy-8vr2q_kube-system_18ee9a7d-63d9-4c73-b168-c063486cf417_0
    4ccec97fe9c2    102      0 /k8s_etcd_etcd-minikube_kube-system_9d3d310935e5fabe942511eec3e2cd0c_0
    76e4467163f8    102      0 /k8s_kube-scheduler_kube-scheduler-minikube_kube-system_b8bdc344ff0000e961009344b94de59c_0
    73fee351a9e1    256      0 /k8s_kube-apiserver_kube-apiserver-minikube_kube-system_96be69ce9ff7dc0acff6fda2873a009a_0
    cc8963ffd8eb    204      0 /k8s_kube-controller-manager_kube-controller-manager-minikube_kube-system_3db91997554714e5ece3296773cf98a5_0
    951a1e3f3335      2      0 /k8s_POD_kube-apiserver-minikube_kube-system_96be69ce9ff7dc0acff6fda2873a009a_0
    7e62eee1da64      2      0 /k8s_POD_etcd-minikube_kube-system_9d3d310935e5fabe942511eec3e2cd0c_0
    8706e760ee52      2      0 /k8s_POD_kube-scheduler-minikube_kube-system_b8bdc344ff0000e961009344b94de59c_0
    475c1049ab83      2      0 /k8s_POD_kube-controller-manager-minikube_kube-system_3db91997554714e5ece3296773cf98a5_0

    # Note that the cpu.shares matches with Docker's numeric value of HostConfig.CpuShares
    root@minikube:/# docker exec 36770d423317 cat /sys/fs/cgroup/cpu,cpuacct/cpu.shares
    2
    root@minikube:/# find /sys/fs/cgroup -name cpu.shares | xargs cat | sort -n | uniq
    2
    102
    204
    256
    768
    1024
    32768
