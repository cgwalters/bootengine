
# for Fedora
    dnf install -y dracut-network git-core gdisk
    dnf install -y --nogpgcheck --repofrompath 'copr,https://copr-be.cloud.fedoraproject.org/results/dustymabe/ignition/fedora-$releasever-$basearch/' ignition

# for centos
    yum install -y dracut-network git-core gdisk
    curl -L https://copr.fedorainfracloud.org/coprs/dustymabe/ignition/repo/epel-7/dustymabe-ignition-epel-7.repo > /etc/yum.repos.d/copr.repo
    yum install -y ignition
    rm /etc/yum.repos.d/copr.repo

git clone https://github.com/dustymabe/bootengine.git
rsync -avh ./bootengine/dracut/* /usr/lib/dracut/modules.d/

dracut --force --verbose -N

rm /etc/machine-id
add 'ip=dhcp rd.neednet=1 enforcing=0 coreos.first_boot' to /boot/grub2/grub.cfg

reboot
