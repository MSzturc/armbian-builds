#!/usr/bin/env bash
# Tests that format_partitions__theos_config_partition materialises the p2 device
# node before formatting it. Armbian only mknod's the partitions it tracks
# (uefi/boot/root) under CONTAINER_COMPAT; the extra THEOS partition (p2) needs the
# framework's own check_loop_device helper, or mkfs.vfat hits a missing node.

run_tests() {
    # shellcheck disable=SC1090
    source "${HERE}/../../userpatches/extensions/theos-config-partition.sh"
    set +eu

    local tmp; tmp="$(mktemp -d)"; mkdir -p "${tmp}/etc"

    # Record framework-helper calls in order; stub them so nothing real runs.
    FMT_CALLS=""
    run_host_command_logged() { FMT_CALLS+="rhcl $*"$'\n'; return 0; }
    check_loop_device() { FMT_CALLS+="check_loop_device $*"$'\n'; return 0; }
    display_alert() { :; }
    exit_with_error() { FMT_CALLS+="exit_with_error $*"$'\n'; return 1; }

    local BOARD="radxa-dragon-q6a" LOOP="/dev/loop0" SDCARD="${tmp}"
    format_partitions__theos_config_partition

    assert_contains "${FMT_CALLS}" "check_loop_device /dev/loop0p2" \
        "format hook ensures the p2 device node exists"
    local before_mkfs="${FMT_CALLS%%rhcl mkfs.vfat*}"
    assert_contains "${before_mkfs}" "check_loop_device /dev/loop0p2" \
        "p2 node is ensured before mkfs.vfat runs"

    rm -rf "${tmp}"
}
