#!/bin/bash
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo \
  https://download.docker.com/linux/centos/docker-ce.repo
yum update -y && yum install -y \
  containerd.io-1.2.13 \
  docker-ce-19.03.11 \
  docker-ce-cli-19.03.11
mkdir /etc/docker
# Set up the Docker daemon
cat <<EOF | tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ]
}
EOF
mkdir -p /etc/systemd/system/docker.service.d

# 安装指定版本的 kubelet/kubectl/kubeadm
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
# yum autoremove -y kubelet kubeadm kubectl --disableexcludes=kubernetes 
# yum install -y kubelet-1.18.10-0 kubeadm-1.18.10-0 kubectl-1.18.10-0 --disableexcludes=kubernetes 
yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes 
# 设置开机启动
systemctl daemon-reload && systemctl enable docker && systemctl restart docker
systemctl enable --now kubelet

# echo "1" > /proc/sys/net/bridge/bridge-nf-call-iptables
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system

sed -i '/swap/d' /etc/fstab
swapoff -a

# 配置系统环境
echo "export LC_ALL=en_US.UTF-8"  >>  /etc/profile
source /etc/profile

# 将 SELinux 禁用
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=disabled/' /etc/selinux/config