# Ansible 部署 Kubernetes

> Time: 2020.11.11 

使用 Kubeadm 部署 Kubernetes...

> 需要注意 Mac 上安装好 ansible/vagrant 

## Step1. 准备测试环境

安装 Virtualbox/Vagrant 之后，还需要安装好 ansible `brew install ansible`

## Step2. 下载 ansible 代码，并启动 Kubernetes 集群

```
git clone https://github.com/markthink/deploy_k8s.git
cd deploy_k8s
vagrant up
```

```bash
vagrant ssh k8s-master
Welcome to Ubuntu 16.04.7 LTS (GNU/Linux 4.4.0-193-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage


This system is built by the Bento project by Chef Software
More information can be found at https://github.com/chef/bento
Last login: Wed Nov 11 05:42:14 2020 from 10.0.2.2
vagrant@k8s-master:~$ kubectl get po -A
NAMESPACE     NAME                                 READY   STATUS    RESTARTS   AGE
kube-system   coredns-f9fd979d6-68spq              1/1     Running   0          104m
kube-system   coredns-f9fd979d6-dsdm9              1/1     Running   0          104m
kube-system   etcd-k8s-master                      1/1     Running   0          104m
kube-system   kube-apiserver-k8s-master            1/1     Running   0          104m
kube-system   kube-controller-manager-k8s-master   1/1     Running   0          104m
kube-system   kube-flannel-ds-2d5p9                1/1     Running   0          104m
kube-system   kube-flannel-ds-7vq59                1/1     Running   0          25m
kube-system   kube-proxy-l7dgd                     1/1     Running   0          25m
kube-system   kube-proxy-sblgp                     1/1     Running   0          104m
kube-system   kube-scheduler-k8s-master            1/1     Running   0          104m
vagrant@k8s-master:~$ kubectl get po -A -o wide
NAMESPACE     NAME                                 READY   STATUS    RESTARTS   AGE    IP              NODE         NOMINATED NODE   READINESS GATES
kube-system   coredns-f9fd979d6-68spq              1/1     Running   0          104m   192.168.0.2     k8s-master   <none>           <none>
kube-system   coredns-f9fd979d6-dsdm9              1/1     Running   0          104m   192.168.0.3     k8s-master   <none>           <none>
kube-system   etcd-k8s-master                      1/1     Running   0          104m   192.168.50.10   k8s-master   <none>           <none>
kube-system   kube-apiserver-k8s-master            1/1     Running   0          104m   192.168.50.10   k8s-master   <none>           <none>
kube-system   kube-controller-manager-k8s-master   1/1     Running   0          104m   192.168.50.10   k8s-master   <none>           <none>
kube-system   kube-flannel-ds-2d5p9                1/1     Running   0          104m   192.168.50.10   k8s-master   <none>           <none>
kube-system   kube-flannel-ds-7vq59                1/1     Running   0          25m    192.168.50.12   node-2       <none>           <none>
kube-system   kube-proxy-l7dgd                     1/1     Running   0          25m    192.168.50.12   node-2       <none>           <none>
kube-system   kube-proxy-sblgp                     1/1     Running   0          104m   192.168.50.10   k8s-master   <none>           <none>
kube-system   kube-scheduler-k8s-master            1/1     Running   0          104m   192.168.50.10   k8s-master   <none>           <none>
```


## 网络测试

```bash
# - --iface=enp0s8
# https://www.jianshu.com/p/bcceb799eef6
iptables -nvL 
iptables -F
iptables -P FORWARD ACCEPT


hostA:
  nc -u 10.93.0.131 (host B) 8472
hostB:
  tcpdump -i eth0 -nn host hostA
```


