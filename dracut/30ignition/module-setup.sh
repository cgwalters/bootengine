#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

depends() {
    echo qemu systemd url-lib network
}

install_ignition_unit() {
    local unit="$1"; shift
    local target="${1:-ignition-complete.target}"; shift
    local instantiated="${1:-$unit}"; shift
    inst_simple "$moddir/$unit" "$systemdsystemunitdir/$unit"
    mkdir -p "$initdir/$systemdsystemunitdir/$target.requires"
    ln_r "../$unit" "$systemdsystemunitdir/$target.requires/$instantiated"
}

install() {
    inst_multiple \
        chroot \
        groupadd \
        id \
        mkfs.ext4 \
        mkfs.vfat \
        mkfs.xfs \
        mkswap \
        mountpoint \
        sgdisk \
        systemd-detect-virt \
        useradd \
        usermod \
        touch

    # This one is optional; https://src.fedoraproject.org/rpms/ignition/pull-request/9
    inst_multiple -o mkfs.btrfs

    inst_script "$moddir/ignition-setup.sh" \
        "/usr/sbin/ignition-setup"

    inst_script "$moddir/coreos-teardown-initramfs-network.sh" \
	"/usr/sbin/coreos-teardown-initramfs-network"

#   inst_script "$moddir/retry-umount.sh" \
#       "/usr/sbin/retry-umount"

    # Distro packaging is expected to install the ignition binary into the
    # module directory.
    inst_simple "$moddir/ignition" \
        "/usr/bin/ignition"
    inst_script "$moddir/ignition-setup-base.sh" \
        "/usr/sbin/ignition-setup-base"
    inst_script "$moddir/ignition-setup-user.sh" \
        "/usr/sbin/ignition-setup-user"

    inst_simple "$moddir/ignition-generator" \
        "$systemdutildir/system-generators/ignition-generator"

    inst_simple "$moddir/coreos-teardown-initramfs-network.service" \
        "$systemdutildir/system/coreos-teardown-initramfs-network.service"

    for x in "complete" "subsequent" "diskful" "diskful-subsequent"; do
        inst_simple "$moddir/ignition-$x.target" \
            "$systemdsystemunitdir/ignition-$x.target"
    done

    install_ignition_unit ignition-setup-base.service
    install_ignition_unit ignition-setup-user.service
    install_ignition_unit ignition-fetch.service
    install_ignition_unit ignition-disks.service
    install_ignition_unit ignition-mount.service
    install_ignition_unit ignition-files.service
    install_ignition_unit ignition-ask-var-mount.service ignition-diskful.target
    install_ignition_unit ignition-remount-sysroot.service ignition-diskful.target

    # needed for openstack config drive support
    inst_rules 60-cdrom_id.rules

    inst_hook pre-pivot 90 "$moddir/persist-ifcfg.sh"
}

has_fw_cfg_module() {
    # this is like check_kernel_config() but it specifically checks for `m` and
    # also checks the OSTree-specific kernel location
    for path in /boot/config-$kernel \
                /usr/lib/modules/$kernel/config \
                /usr/lib/ostree-boot/config-$kernel; do
        if test -f $path; then
            rc=0
            grep -q CONFIG_FW_CFG_SYSFS=m $path || rc=$?
            return $rc
        fi
    done
    return 1
}

installkernel() {
    # We definitely need this one in the initrd to support Ignition cfgs on qemu
    # if available
    if has_fw_cfg_module; then
        instmods -c qemu_fw_cfg
    fi
}
