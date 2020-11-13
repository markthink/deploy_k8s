yum -y install yum-utils
package-cleanup -y --oldkernels --count=1
yum -y autoremove
yum -y remove yum-utils
yum clean all
rm -rf /tmp/*
rm -f /var/log/wtmp /var/log/btmp
# Zero free space to aid VM compression
dd if=/dev/zero of=/EMPTY bs=1M
rm -f /EMPTY
cat /dev/null > ~/.bash_history && history -c