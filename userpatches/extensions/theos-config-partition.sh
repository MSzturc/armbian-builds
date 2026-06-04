#!/usr/bin/env bash
# THEOS Dragon Q6A: dedicated Windows-mountable FAT32 config partition.
#
# Produces a GPT layout [ESP p1][THEOS FAT32 p2][root p3] on a GRUB/UEFI board so
# /boot stays on ext4 root (GRUB enumerates it) while a Microsoft-Basic-Data FAT
# partition is visible to Windows for the headless WiFi handoff file.

# GPT type GUIDs (sfdisk wants full GUIDs for GPT, not gdisk shortcodes).
# Plain (not readonly) so re-sourcing the file in the test runner shell is safe.
THEOS_ESP_TYPE="C12A7328-F81F-11D2-BA4B-00A0C93EC93B"   # EFI System
THEOS_DATA_TYPE="EBD0A0A2-B9E5-4433-87C0-68B6B72699C7"  # Microsoft Basic Data

# theos_partition_script OFFSET UEFISIZE CONFIG_MIB ROOT_TYPE_UUID
# Echoes the full sfdisk script (MiB units). Root carries no size so sfdisk grows
# it to fill the device; it must stay the last partition for downstream resize.
theos_partition_script() {
    local offset="$1" uefisize="$2" config_mib="$3" root_type="$4"
    local p2_start=$((offset + uefisize))
    local p3_start=$((p2_start + config_mib))
    echo "label: gpt"
    echo "1 : name=\"efi\", start=${offset}MiB, size=${uefisize}MiB, type=${THEOS_ESP_TYPE}"
    echo "2 : name=\"theos\", start=${p2_start}MiB, size=${config_mib}MiB, type=${THEOS_DATA_TYPE}"
    echo "3 : name=\"rootfs\", start=${p3_start}MiB, type=${root_type}"
}

# Board this extension applies to. Self-guarded so it is inert for every other board.
# Plain (not readonly) so re-sourcing in the test runner shell is safe.
THEOS_CFG_BOARD="radxa-dragon-q6a"
THEOS_CFG_MIB=128

# Drop the separate /boot and guarantee an ESP, before Armbian computes partitions.
pre_prepare_partitions__theos_config_partition() {
    [[ "${BOARD}" == "${THEOS_CFG_BOARD}" ]] || return 0
    BOOTSIZE=0
    BOOTFS_TYPE=""
    BOOTPART_REQUIRED="no"
    # GRUB/UEFI board needs an ESP; keep the family value if already set.
    [[ "${UEFISIZE:-0}" -lt 1 ]] && UEFISIZE=256
    return 0
}

# Take over partitioning, force root to p3, and budget the extra FAT partition into
# the image size. Runs after Armbian computed rootpart (== 2 here) — reassigning it
# in this dynamically-scoped hook updates prepare_partitions' local.
prepare_image_size__theos_config_partition() {
    [[ "${BOARD}" == "${THEOS_CFG_BOARD}" ]] || return 0
    USE_HOOK_FOR_PARTITION="yes"
    rootpart=3
    EXTRA_ROOTFS_MIB_SIZE=$(( ${EXTRA_ROOTFS_MIB_SIZE:-0} + THEOS_CFG_MIB ))
    return 0
}

# Emit the full GPT table [ESP][THEOS][root] for the board.
create_partition_table__theos_config_partition() {
    [[ "${BOARD}" == "${THEOS_CFG_BOARD}" ]] || return 0
    local root_type="${PARTITION_TYPE_UUID_ROOT:-B921B045-1DF0-41C3-AF44-4C6F280D3FAE}"
    local script
    script="$(theos_partition_script "${OFFSET}" "${UEFISIZE}" "${THEOS_CFG_MIB}" "${root_type}")"
    display_alert "THEOS config partition" "custom GPT [ESP][THEOS][root]" "info"
    # Armbian computes sfdisk_version_num only in its NON-hook branch, yet it reads
    # the same variable later (the post-create losetup --partscan -b "$SECTOR_SIZE").
    # Set the Armbian-named vars here (no `local`, so they are visible to the caller)
    # to both pick the right sfdisk flags and keep the downstream losetup correct.
    sfdisk_version="$(sfdisk --version | awk '/util-linux/ {print $NF}')"
    sfdisk_version_num="$(echo "$sfdisk_version" | awk -F. '{printf "%d%02d%02d\n", $1, $2, $3}')"
    if [[ "${sfdisk_version_num:-0}" -ge "24100" ]]; then
        echo "${script}" | run_host_command_logged sfdisk --sector-size "${SECTOR_SIZE}" "${SDCARD}".raw \
            || exit_with_error "THEOS partitioning failed"
    else
        echo "${script}" | run_host_command_logged sfdisk "${SDCARD}".raw \
            || exit_with_error "THEOS partitioning failed"
    fi
    return 0
}

# Format p2 as FAT32 "THEOS", create its mountpoint, add a non-fatal fstab entry.
# LOOP is set by now; the ESP (p1) and root (p3) are formatted by Armbian itself.
format_partitions__theos_config_partition() {
    [[ "${BOARD}" == "${THEOS_CFG_BOARD}" ]] || return 0
    # Armbian only mknod's the partitions it tracks (uefi/boot/root); p2 is extra,
    # so re-read the table and materialise its node the same way the framework does.
    run_host_command_logged partprobe "${LOOP}"
    check_loop_device "${LOOP}p2"
    display_alert "THEOS config partition" "mkfs.vfat ${LOOP}p2 (label THEOS)" "info"
    run_host_command_logged mkfs.vfat -F 32 -n THEOS "${LOOP}p2" \
        || exit_with_error "THEOS config partition mkfs failed"
    run_host_command_logged mkdir -p "${SDCARD}/boot/theos-config"
    echo 'LABEL=THEOS /boot/theos-config vfat nofail,umask=000 0 0' >> "${SDCARD}/etc/fstab"
    return 0
}
