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


