### 为 Kube-apiserver 创建负载均衡器

- 在云环境中，应该将控制平面节点放置在 TCP 后面转发负载平衡。 该负载均衡器将流量分配给目标列表中所有运行状况良好的控制平面节点。健康检查 apiserver 是在 kube-apiserver 监听端口(默认值 :6443)上的一个 TCP 检查。
- 不建议在云环境中直接使用 IP 地址。
- 负载均衡器必须能够在 apiserver 端口上与所有控制平面节点通信。它还必须允许其监听端口的传入流量。
- 确保负载均衡器的地址始终匹配 kubeadm 的 ControlPlaneEndpoint 地址。

#### keepalived 和 haproxy

为了提供 VIP 负载均衡，keepalived 和 haproxy的组合已经存在了很时间，并且可以认为是众所周知的，并且已经过测试

- keepalived 服务提供可配置的运行状态检查并管理 VIP，由于使用虚拟 IP 的实现方式，协商的虚拟IP必须与节点IP位于同一个 IP 子网中..
- 可以将 haproxy 服务配置为基于流的简单负载均衡，从而允许 TLS 终止其后面的 API Server 实例的处理..

该组合即可以作为操作系统上的服务运行，也可以作为控制平面主机上的静态容器运行，两种情况下的服务配置都是相同的。

##### keepalived 配置

keepalived 配置包含两个文件，服务配置文件和运行状态检查脚本，检查脚本会定期调用以验证拥有虚拟IP的节点是否仍在运行...

```bash
! /etc/keepalived/keepalived.conf
! Configuration File for keepalived
global_defs {
    router_id LVS_DEVEL
}
vrrp_script check_apiserver {
  script "/etc/keepalived/check_apiserver.sh"
  interval 3
  weight -2
  fall 10
  rise 2
}

vrrp_instance VI_1 {
    state ${STATE}
    interface ${INTERFACE}
    virtual_router_id ${ROUTER_ID}
    priority ${PRIORITY}
    authentication {
        auth_type PASS
        auth_pass ${AUTH_PASS}
    }
    virtual_ipaddress {
        ${APISERVER_VIP}
    }
    track_script {
        check_apiserver
    }
}
```

- ${STATE}:对应于一个主机是 MASTER, 对于其他主机是 BACKUP 因此 VIP 最初分配给 MASTER
- ${INTERFACE}: 参与 VIP 协商的网络接口 例如 eth0
- ${ROUTER_ID}: 对于所有保持活动状态的集群主机，此参数应相同，并且在同一子网中的所有集群，此参数也应相同，许多发行版将其值预先置为 51
- ${PRIORITY}: 优先级，应该 MASTER 服务器高于 BACKUP 服务器..
- ${AUTH_PASS}: 对于所有保持活动状态的集群主机应相同，例如 42
- ${APISERVER_VIP}: 保持活动状态的集群主机之间的协商 VIP 地址.

接下来看一下 check_apiserver.sh 检查脚本:

```bash
#!/bin/sh

errorExit() {
    echo "*** $*" 1>&2
    exit 1
}

curl --silent --max-time 2 --insecure https://localhost:${APISERVER_DEST_PORT}/ -o /dev/null || errorExit "Error GET https://localhost:${APISERVER_DEST_PORT}/"
if ip addr | grep -q ${APISERVER_VIP}; then
    curl --silent --max-time 2 --insecure https://${APISERVER_VIP}:${APISERVER_DEST_PORT}/ -o /dev/null || errorExit "Error GET https://${APISERVER_VIP}:${APISERVER_DEST_PORT}/"
fi
```
- ${APISERVER_VIP}: 保持活动状态的集群主机之间的协商 VIP 地址.
- ${APISERVER_DEST_PORT}: Kubernetes 将通过该端口与API服务器通信..

##### haproxy 配置

haproxy 配置由一个文件组成

```bash
# /etc/haproxy/haproxy.cfg
#---------------------------------------------------------------------
# Global settings
#---------------------------------------------------------------------
global
    log /dev/log local0
    log /dev/log local1 notice
    daemon

#---------------------------------------------------------------------
# common defaults that all the 'listen' and 'backend' sections will
# use if not designated in their block
#---------------------------------------------------------------------
defaults
    mode                    http
    log                     global
    option                  httplog
    option                  dontlognull
    option http-server-close
    option forwardfor       except 127.0.0.0/8
    option                  redispatch
    retries                 1
    timeout http-request    10s
    timeout queue           20s
    timeout connect         5s
    timeout client          20s
    timeout server          20s
    timeout http-keep-alive 10s
    timeout check           10s

#---------------------------------------------------------------------
# apiserver frontend which proxys to the masters
#---------------------------------------------------------------------
frontend apiserver
    bind *:${APISERVER_DEST_PORT}
    mode tcp
    option tcplog
    default_backend apiserver

#---------------------------------------------------------------------
# round robin balancing for apiserver
#---------------------------------------------------------------------
backend apiserver
    option httpchk GET /healthz
    http-check expect status 200
    mode tcp
    option ssl-hello-chk
    balance     roundrobin
        server ${HOST1_ID} ${HOST1_ADDRESS}:${APISERVER_SRC_PORT} check
        # [...]
```

同样， 有一些 bash 变量样式的占位符可以扩展:

- ${APISERVER_DEST_PORT}: Kubernetes 将通过该端口与API服务器通信..
- ${APISERVER_SRC_PORT}: API 服务器实例使用的端口
- ${HOST1_ID}: 第一个负载均衡的 API 服务器主机的主机名
- ${HOST1_ADDRESS}: 第一个负载均衡的 API 服务器主机的可解析地址(DNS名称，IP地址)..

这里将 Keepalived、haproxy 以静态容器的方式在 Master 节点运行。。

```bash
# /etc/kubernetes/manifests 
# /etc/kubernetes/manifests/keepalived.yaml
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  name: keepalived
  namespace: kube-system
spec:
  containers:
  - image: osixia/keepalived:1.3.5-1
    name: keepalived
    resources: {}
    securityContext:
      capabilities:
        add:
        - NET_ADMIN
        - NET_BROADCAST
        - NET_RAW
    volumeMounts:
    - mountPath: /usr/local/etc/keepalived/keepalived.conf
      name: config
    - mountPath: /etc/keepalived/check_apiserver.sh
      name: check
  hostNetwork: true
  volumes:
  - hostPath:
      path: /etc/keepalived/keepalived.conf
    name: config
  - hostPath:
      path: /etc/keepalived/check_apiserver.sh
    name: check
status: {}
```

```bash
# /etc/kubernetes/manifests 
# /etc/kubernetes/manifests/haproxy.yaml
apiVersion: v1
kind: Pod
metadata:
  name: haproxy
  namespace: kube-system
spec:
  containers:
  - image: haproxy:2.1.4
    name: haproxy
    livenessProbe:
      failureThreshold: 8
      httpGet:
        host: localhost
        path: /healthz
        port: ${APISERVER_DEST_PORT}
        scheme: HTTPS
    volumeMounts:
    - mountPath: /usr/local/etc/haproxy/haproxy.cfg
      name: haproxyconf
      readOnly: true
  hostNetwork: true
  volumes:
  - hostPath:
      path: /etc/haproxy/haproxy.cfg
      type: FileOrCreate
    name: haproxyconf
status: {}
```

### Kube-vip

作为传统 Keepalived 和 haproxy 方法的替代方法，kube-vip 在一项服务中同时实现了VIP的管理和负载均衡。

与 keepalived 一样，协商 VIP 的主机也必须位于同一IP子网中，同样与 haproxy 一样，基于流的负载均衡允许 TLS 终止其背后的 API Server 实例处理。

```bash
# /etc/kube-vip/config.yaml 
localPeer:
  id: ${ID}
  address: ${IPADDR}
  port: 10000
remotePeers:
- id: ${PEER1_ID}
  address: ${PEER1_IPADDR}
  port: 10000
# [...]
vip: ${APISERVER_VIP}
gratuitousARP: true
singleNode: false
startAsLeader: ${IS_LEADER}
interface: ${INTERFACE}
loadBalancers:
- name: API Server Load Balancer
  type: tcp
  port: ${APISERVER_DEST_PORT}
  bindToVip: false
  backends:
  - port: ${APISERVER_SRC_PORT}
    address: ${HOST1_ADDRESS}
  # [...]
```

- ${ID}: 当前主机的符号名称
- ${IPADDR}: 当前主机的 IP 地址
- ${PEER1_ID}: 第一个 VIP 对等方的符号名
- ${PEER1_IPADDR}: 第一个 VIP 对等方的 IP 地址
- ${APISERVER_VIP}: 虚拟 VIP
- ${IS_LEADER}: 节点的角色
- ${INTERFACE}: 参与虚拟 VIP 协商的网络接口 例如：eth0
- ${APISERVER_DEST_PORT}: k8s 将通过该端口与API服务器通信
- ${APISERVER_SRC_PORT}: API服务器实例使用的端口
- ${HOST1_ADDRESS}: 第一个负载均衡的AIP SERVER 主机的条目


```bash

apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  name: kube-vip
  namespace: kube-system
spec:
  containers:
  - command:
    - /kube-vip
    - start
    - -c
    - /vip.yaml
    image: 'plndr/kube-vip:0.1.1'
    name: kube-vip
    resources: {}
    securityContext:
      capabilities:
        add:
        - NET_ADMIN
        - SYS_TIME
    volumeMounts:
    - mountPath: /vip.yaml
      name: config
  hostNetwork: true
  volumes:
  - hostPath:
      path: /etc/kube-vip/config.yaml
    name: config
status: {}
```

添加第一个控制平台节点到负载均衡器并测试连接

```bash
#nc -v LOAD_BALANCER_IP PORT
nc -v 192.168.20.150 6443
```

- [kubeadm 高可用集群](https://zhuanlan.zhihu.com/p/234585262)


```bash
sysctl -w net.unix.max_dgram_qlen=100
sysctl -w net.ipv4.ip_nonlocal_bind=1
sysctl -p

# kube-apiserver.yaml SVC CIDR
--service-cluster-ip-range=10.96.0.0/12
# kube-controller-manager.yaml POD CIDR
--allocate-node-cidrs=true
--cluster-cidr=10.244.0.0/16
# 在所有节点添加两条静态路由，解决默认网卡走 eth0 的问题..
cat <<EOF > /etc/sysconfig/network-scripts/route-eth1
10.244.0.0/16 via 192.168.20.1 dev eth1
10.96.0.0/12 via 192.168.20.1 dev eth1
EOF
systemctl restart network
```

查看 master-1/master-2/master-3 节点，发现 kubeadm 默认创建了 Kuberentes svc 的 CIDR, 但并未指定 POD 的 CIDR 范围

因此需要手动增加 `--cluster-cidr=10.244.0.0/16` 参数到 `kube-controller-manager.yaml` 
此 CIDR 段是 POD 分配的IP 网段，需要与 canal 里的配置一致...
