# 基于 BPF 的网络方案 cilium 部署

> Time: 2020.11.12

Cilium 要求 linux kernel 4.8.0 以上的版本支持，因此我们

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

## Step3. 下载 helm 安装 cilium 

```bash
wget https://get.helm.sh/helm-v3.4.1-linux-amd64.tar.gz
tar xvf helm-v3.4.1-linux-amd64.tar.gz
ls linux-amd64/

helm repo add cilium https://helm.cilium.io/
helm install cilium cilium/cilium --version 1.9.0       \
  --namespace kube-system                               \
  --set externalWorkloads.enabled=true                  \
  --set clustermesh.apiserver.tls.auto.method=cronJob
```

命令输出...


```bash
[vagrant@k8s-master ~]$ helm repo add cilium https://helm.cilium.io/
"cilium" has been added to your repositories
[vagrant@k8s-master ~]$ helm install cilium cilium/cilium --version 1.9.0       \
>   --namespace kube-system                               \
>   --set externalWorkloads.enabled=true                  \
>   --set clustermesh.apiserver.tls.auto.method=cronJob
NAME: cilium
LAST DEPLOYED: Fri Nov 13 12:34:24 2020
NAMESPACE: kube-system
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
You have successfully installed Cilium with Hubble.

Your release version is 1.9.0.

For any further help, visit https://docs.cilium.io/en/v1.9/gettinghelp
```

```bash
The cilium_net: Caught tx_queue_len zero misconfig is harmless, by the way.
```