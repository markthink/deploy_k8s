# 编译 Linux 内核

> Time: 2020.11.13

本文基于 Centos7.8 编译新版本内核，由于本 Kubernetes 集群选择基于 BPF 的 Cilium 容器网络。
由于 `Cilium` 需要高于 `Linux 4.8.0` 内核的操作系统才能支持，而 Centos7.8 内置的内核版本为 `3.10.0-1127.el7.x86_64`。
因此需要对 `centos/7` 操作系统进行内核编译升级..

目前官网可用的内核版本为：linux-5.9.8 

- OS: Centos 7.8
- Kernel: linux-5.9.8

## Step1. 准备基本编译环境

准备 Vagrantfile 文件
```bash
IMAGE_NAME = "centos/7"
# N = 2

Vagrant.configure("2") do |config|
    config.ssh.insert_key = false

    config.vm.provider "virtualbox" do |v|
        v.memory = 8192
        v.cpus = 4
    end
      
    config.vm.define "k8s-master" do |master|
        master.vm.box = IMAGE_NAME
        master.vm.network "private_network", ip: "192.168.50.10"
        master.vm.hostname = "k8s-master"
        # master.vm.provision "ansible" do |ansible|
        #     ansible.playbook = "kubernetes-setup/master-playbook.yml"
        #     ansible.extra_vars = {
        #         node_ip: "192.168.50.10",
        #     }
        # end
    end

    # (1..N).each do |i|
    #     config.vm.define "node-#{i}" do |node|
    #         node.vm.box = IMAGE_NAME
    #         node.vm.network "private_network", ip: "192.168.50.#{i + 10}"
    #         node.vm.hostname = "node-#{i}"
    #         node.vm.provision "ansible" do |ansible|
    #             ansible.playbook = "kubernetes-setup/node-playbook.yml"
    #             ansible.extra_vars = {
    #                 node_ip: "192.168.50.#{i + 10}",
    #             }
    #         end
    #     end
    # end
end
```

在本地下载好 Linux kernel 源代码

```bash
├── Vagrantfile
├── linux-5.9.8.tar.xz
```
启动虚拟机，切换至 /vagrant 目录

```bash
# vagrant ssh k8s-master
[vagrant@k8s-master ~]$ ls
[vagrant@k8s-master ~]$ sudo su
[root@k8s-master vagrant]# cd /vagrant/
[root@k8s-master vagrant]# ls
Vagrantfile  linux-5.9.8.tar.xz
[root@k8s-master vagrant]# tar xvf linux-5.9.8.tar.xz
```

准备基础编译环境：

```bash
yum groupinstall -y "Development Tools"
yum install -y ncurses-devel zlib-devel binutils-devel openssl-devel dwarves hmaccalc elfutils-libelf-devel bc
```

## Step2. 准备内核编译配置

```bash
[root@k8s-master vagrant]# cd linux-5.9.8/
[root@k8s-master linux-5.9.8]# cp /boot/config-3.10.0-1127.el7.x86_64 .config
[root@k8s-master linux-5.9.8]# yes ""|make oldconfig
[root@k8s-master linux-5.9.8]# make menuconfig
# device drivers > virtualization drivers - yes
# file systems > miscellaneous filesystems > minix file system support
# file systems > miscellaneous filesystems > virtualbox guest shared folder(vboxsf) support
[root@k8s-master linux-5.9.8]# make bzImage -j4
./include/linux/compiler-gcc.h:15:3: 错误：#error Sorry, your compiler is too old - please upgrade it.
```

由于 gcc 版本比较低，需要升级安装 gcc。
gcc有三个依赖包gmp、mpfr、mpc,要首先编译安装（虽然原本就有，不过如果编译高版本gcc，这三个依赖包不装新版本的话也会报错）

先去下载好三个依赖包源码包及gcc源码包

```bash
mkdir /vagrant/gcc && cd /vagrant/gcc

wget https://gmplib.org/download/gmp/gmp-6.2.0.tar.xz 
wget https://www.mpfr.org/mpfr-current/mpfr-4.1.0.tar.gz
wget https://ftp.gnu.org/gnu/mpc/mpc-1.2.1.tar.gz
wget https://ftp.gnu.org/gnu/gcc/gcc-10.2.0/gcc-10.2.0.tar.xz
```

再挨个编译安装三个依赖包（注意这三个依赖包也有依赖关系，需先安装gmp，再安装mpfr，之后再装mpc）

先来第一个，编译安装 GMP

```bash
cd gmp-6.2.0/
./configure --prefix=/usr/local/gcc/gmp --build=x86_64-linux
make && make install
```
编译安装 mpfr

```bash
cd mpfr-4.1.0/
./configure --prefix=/usr/local/gcc/mpfr --with-gmp=/usr/local/gcc/gmp
make && make install
```

编译安装 mpc

```bash
cd mpc-1.2.1/
./configure --prefix=/usr/local/gcc/mpc --with-gmp=/usr/local/gcc/gmp -with-mpfr=/usr/local/gcc/mpfr
make && make install
```

编译 GCC

```bash
cd gcc-10.2.0/
./configure --prefix=/usr/local/gcc --enable-threads=posix --disable-checking --disable-multilib --enable-languages=c,c++ --with-gmp=/usr/local/gcc/gmp --with-mpfr=/usr/local/gcc/mpfr --with-mpc=/usr/local/gcc/mpc
make -j4
make install
```

```bash
/vagrant/gcc/gcc-10.2.0/host-x86_64-pc-linux-gnu/gcc/cc1: error while loading shared libraries: libmpfr.so.6: cannot open shared object file: No such file or directory
```
由于依赖包路径找不到，需要配置依赖包路径, 在/etc/profile里面加上以下内容 

```bash
echo "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/gcc/mpc/lib:/usr/local/gcc/gmp/lib:/usr/local/gcc/mpfr/lib" >> /etc/profile
source /etc/profile
```

移除默认 gcc 版本..

```bash
mv /usr/bin/gcc /usr/bin/gcc-bak
mv /usr/bin/g++ /usr/bin/g++-bak
mv /usr/bin/c++ /usr/bin/c++-bak
```

建立新的 GCC 软链接

```bash
ln -s /usr/local/gcc/bin/gcc /usr/bin/gcc
ln -s /usr/local/gcc/bin/g++ /usr/bin/g++
ln -s /usr/local/gcc/bin/c++ /usr/bin/c++
ln -s /usr/local/gcc/lib64/libstdc++.so.6.0.28 /usr/lib64/libstdc++.so.6
```

查看 gcc 版本..

```bash
[root@k8s-master gcc-10.2.0]# gcc --version
gcc (GCC) 10.2.0
Copyright © 2020 Free Software Foundation, Inc.
本程序是自由软件；请参看源代码的版权声明。本软件没有任何担保；
包括没有适销性和某一专用目的下的适用性担保。
```


## Step3. 编译新版本内核

继续编译内核

```bash
[root@k8s-master vagrant]# cd linux-5.9.8/
[root@k8s-master linux-5.9.8]# make mrproper
[root@k8s-master linux-5.9.8]# make clean
[root@k8s-master linux-5.9.8]# cp /boot/config-3.10.0-1127.el7.x86_64 .config
[root@k8s-master linux-5.9.8]# yes ""|make oldconfig
[root@k8s-master linux-5.9.8]# make menuconfig
# device drivers > virtualization drivers - yes
# file systems > miscellaneous filesystems > minix file system support
# file systems > miscellaneous filesystems > virtualbox guest shared folder(vboxsf) support
[root@k8s-master linux-5.9.8]# make bzImage -j4
[root@k8s-master linux-5.9.8]# make modules -j4
[root@k8s-master linux-5.9.8]# make modules_install -j4
# 内核模块将会被安装到/lib/modules下面
[root@k8s-master linux-5.9.8]# ls /lib/modules
3.10.0-1127.el7.x86_64  5.9.8
```

## Step4. 安装新版本内核

```bash
[root@k8s-master linux-5.9.8]# make install
sh ./arch/x86/boot/install.sh 5.9.8 arch/x86/boot/bzImage \
	System.map "/boot"
# 列出系统开机时显示的所有选项
[root@k8s-master linux-5.9.8]# awk -F\' '$1=="menuentry " {print i++ " : " $2}' /etc/grub2.cfg
0 : CentOS Linux (5.9.8) 7 (Core)
1 : CentOS Linux (3.10.0-1127.el7.x86_64) 7 (Core)
[root@k8s-master linux-5.9.8]# grep "^menuentry" /boot/grub2/grub.cfg | cut -d "'" -f2
CentOS Linux (5.9.8) 7 (Core)
CentOS Linux (3.10.0-1127.el7.x86_64) 7 (Core)
[root@k8s-master vagrant]# grub2-editenv list
saved_entry=CentOS Linux (3.10.0-1127.el7.x86_64) 7 (Core)
```

缺省的项目是通过 /etc/default/grub 档内的 GRUB_DEFAULT 行来定义。不过，要是 GRUB_DEFAULT 行被设置为 saved，这个选项便存储在 /boot/grub2/grubenv 档内, 可以这样查看它。

将新编译的内核设置为默认启动项..

```bash
[root@k8s-master vagrant]# awk -F\' '$1=="menuentry " {print i++ " : " $2}' /etc/grub2.cfg
0 : CentOS Linux (5.9.8) 7 (Core)
1 : CentOS Linux (3.10.0-1127.el7.x86_64) 7 (Core)
[root@k8s-master vagrant]# grub2-set-default 0
[root@k8s-master vagrant]# cat /boot/grub2/grubenv
# GRUB Environment Block
saved_entry=0
```

重启系统，查看内核版本...

```bash
# vagrant ssh k8s-master
Last login: Fri Nov 13 09:28:41 2020 from 10.0.2.2
[vagrant@k8s-master ~]$ uname -r
5.9.8
[vagrant@k8s-master ~]$ lsmod
Module                  Size  Used by
rfkill                 28672  0
snd_intel8x0           49152  0
snd_ac97_codec        180224  1 snd_intel8x0
ac97_bus               16384  1 snd_ac97_codec
snd_pcm               139264  2 snd_intel8x0,snd_ac97_codec
intel_rapl_msr         20480  0
intel_rapl_common      32768  1 intel_rapl_msr
intel_pmc_core_pltdrv    16384  0
intel_pmc_core         45056  0
crc32_pclmul           16384  0
ghash_clmulni_intel    16384  0
snd_timer              49152  1 snd_pcm
sunrpc                577536  1
snd                   110592  4 snd_intel8x0,snd_timer,snd_ac97_codec,snd_pcm
aesni_intel           372736  0
joydev                 28672  0
e1000                 167936  0
sg                     45056  0
soundcore              16384  1 snd
crypto_simd            16384  1 aesni_intel
video                  53248  0
cryptd                 28672  2 crypto_simd,ghash_clmulni_intel
glue_helper            16384  1 aesni_intel
vboxguest              53248  0
i2c_piix4              28672  0
pcspkr                 16384  0
ip_tables              32768  0
xfs                  1552384  1
libcrc32c              16384  1 xfs
sd_mod                 57344  2
t10_pi                 16384  1 sd_mod
crc_t10dif             20480  1 t10_pi
crct10dif_generic      16384  0
ata_generic            16384  0
pata_acpi              16384  0
ata_piix               40960  1
libata                299008  3 ata_piix,pata_acpi,ata_generic
crct10dif_pclmul       16384  1
crct10dif_common       16384  3 crct10dif_generic,crc_t10dif,crct10dif_pclmul
crc32c_intel           24576  1
serio_raw              20480  0
```

## Step5. 创建 Box 模板推送到 Vagrant 平台


> [参考资源](https://medium.com/@gevorggalstyan/creating-own-custom-vagrant-box-ae7e94043a4e)

清理资源 clean.sh

```bash
yum -y install yum-utils
package-cleanup -y --oldkernels --count=1
yum -y autoremove
yum -y remove yum-utils
yum clean all
rm -rf /tmp/*
rm -f /var/log/wtmp /var/log/btmp
cat /dev/null > ~/.bash_history && history -c
```

关机，导出 box 

```bash
[root@k8s-master vagrant]# shutdown -h now
# vagrant package --output centos.box
==> k8s-master: Clearing any previously set forwarded ports...
==> k8s-master: Exporting VM...
==> k8s-master: Compressing package to: /Volumes/works/deploy_k8s/ansible_k8s_centos_cilium/centos.box

# vagrant box add centos-kernel ./centos.box
==> box: Box file was not detected as metadata. Adding it directly...
==> box: Adding box 'centos-kernel' (v0) for provider:
    box: Unpacking necessary files from: file:///Volumes/works/deploy_k8s/ansible_k8s_centos_cilium/centos.box
==> box: Successfully added box 'centos-kernel' (v0) for 'virtualbox'!
```



