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
# vagrant ssh k8s-master
[vagrant@k8s-master ~]$ kubectl get no -o wide
NAME         STATUS   ROLES    AGE   VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE                KERNEL-VERSION           CONTAINER-RUNTIME
k8s-master   Ready    master   17m   v1.19.4   192.168.50.10   <none>        CentOS Linux 7 (Core)   3.10.0-1127.el7.x86_64   docker://19.3.11
node-1       Ready    <none>   14m   v1.19.4   192.168.50.11   <none>        CentOS Linux 7 (Core)   3.10.0-1127.el7.x86_64   docker://19.3.11
node-2       Ready    <none>   11m   v1.19.4   192.168.50.12   <none>        CentOS Linux 7 (Core)   3.10.0-1127.el7.x86_64   docker://19.3.11
[vagrant@k8s-master ~]$ kubectl get po -A -o wide
NAMESPACE     NAME                                 READY   STATUS    RESTARTS   AGE     IP              NODE         NOMINATED NODE   READINESS GATES
kube-system   coredns-f9fd979d6-9t6pr              1/1     Running   0          18m     192.168.0.3     k8s-master   <none>           <none>
kube-system   coredns-f9fd979d6-t4thb              1/1     Running   0          18m     192.168.0.2     k8s-master   <none>           <none>
kube-system   etcd-k8s-master                      1/1     Running   0          18m     192.168.50.10   k8s-master   <none>           <none>
kube-system   kube-apiserver-k8s-master            1/1     Running   0          18m     192.168.50.10   k8s-master   <none>           <none>
kube-system   kube-controller-manager-k8s-master   1/1     Running   0          18m     192.168.50.10   k8s-master   <none>           <none>
kube-system   kube-flannel-ds-4d2c7                1/1     Running   0          12m     192.168.50.12   node-2       <none>           <none>
kube-system   kube-flannel-ds-j5f66                1/1     Running   3          15m     192.168.50.11   node-1       <none>           <none>
kube-system   kube-flannel-ds-mzm8p                1/1     Running   0          18m     192.168.50.10   k8s-master   <none>           <none>
kube-system   kube-proxy-ntlmj                     1/1     Running   0          15m     192.168.50.11   node-1       <none>           <none>
kube-system   kube-proxy-p8jcx                     1/1     Running   0          12m     192.168.50.12   node-2       <none>           <none>
kube-system   kube-proxy-zjzcs                     1/1     Running   0          18m     192.168.50.10   k8s-master   <none>           <none>
kube-system   kube-scheduler-k8s-master            1/1     Running   0          18m     192.168.50.10   k8s-master   <none>           <none>
```

```bash
# 查看 fdb 表项
bridge fdb show dev flannel.1
# 查看 ARP 表项
ip neigh show dev flannel.1
# 查看 flannel.1 网卡信息
ip -d link show flannel.1

# ip link set dev eth1 up
# arp 获取 mac 地址
arp -e
# 查询 mac 地址下一跳
bridge fdb show|grep ee:34:4b:ed:b1:23

# start up a cluster
KUBERNETES_PROVIDER=vagrant ./cluster/kube-up.sh

# start a simple vagrant cluster
NUM_NODES=1 KUBERNETES_PROVIDER=vagrant KUBE_ENABLE_CLUSTER_MONITORING=none KUBE_ENABLE_CLUSTER_UI=false ./cluster/kube-up.sh

# validate cluster 
./cluster/validate-cluster.sh
kubectl cluster-info

# delete all rc & svc
kubectl delete svc,rc --all
kubectl delete $(kubectl get rc,svc -o name)

# watch for events
kubectl get ev -w

# schema / avaiable fields for rc/pods/svc ...
https://github.com/kubernetes/kubernetes/blob/master/pkg/api/types.go

# a simple service
https://github.com/kubernetes/kubernetes/blob/master/docs/user-guide/walkthrough/service.yaml

# available signals for a pod
https://github.com/luebken/httplog/blob/signals/rc.yml

# debug
kubectl logs --previous <pod>

# start a simple container
kubectl run busybox --image=busybox

# get system services
kubectl get svc --all-namespaces

# a debug container
kubectl run curlpod --image=radial/busyboxplus:curl --command -- /bin/sh -c "while true; do echo hi; sleep 10; done"
kubectl exec -it curlpod-5f0mh nslookup redis

# upload files
kubectl exec -i ghost-deployment-1955090760-zivlz -- /bin/bash -c 'cat > /tmp/testmail.msg' < testmail.msg

# more debug
http://kubernetes.io/v1.1/docs/user-guide/debugging-services.html

# create a new config
PROJECT_ID='mdl-k8s'
CLUSTER='cluster-4'
CLUSTER_ZONE='europe-west1-c'

gcloud config set project $PROJECT_ID
gcloud config set container/cluster $CLUSTER
gcloud config set compute/zone $CLUSTER_ZONE
gcloud container clusters get-credentials $CLUSTER

kubectl config use-context gke_${PROJECT_ID}_${CLUSTER_ZONE}_${CLUSTER}

kubectl run -i --tty --rm debug --image=busybox --restart=Never -- sh
```

> [参考资源](https://www.cnblogs.com/xuxinkun/p/11003375.html)