#!/usr/bin/env bash
# Tests the board-scoped Armbian hook functions of the config-partition extension.
#
# Each scenario is a function with `local` variables so the dynamically-scoped hook
# functions mutate those locals — and the assertions run in the runner shell so the
# pass/fail counters propagate (a subshell would swallow them).

run_tests() {
    # shellcheck disable=SC1090
    source "${HERE}/../../userpatches/extensions/theos-config-partition.sh"
    _hooks_scenario_q6a
    _hooks_scenario_other
}

_hooks_scenario_q6a() {
    local BOARD="radxa-dragon-q6a"
    local BOOTFS_TYPE="fat" BOOTSIZE="256" BOOTPART_REQUIRED="no"
    local UEFISIZE=0 EXTRA_ROOTFS_MIB_SIZE=0 rootpart=2 USE_HOOK_FOR_PARTITION="no"

    pre_prepare_partitions__theos_config_partition
    prepare_image_size__theos_config_partition

    assert_equals "0"   "$BOOTSIZE"               "q6a: BOOTSIZE forced to 0"
    assert_equals ""    "$BOOTFS_TYPE"            "q6a: BOOTFS_TYPE neutralized"
    assert_equals "yes" "$USE_HOOK_FOR_PARTITION" "q6a: USE_HOOK_FOR_PARTITION=yes"
    assert_equals "3"   "$rootpart"               "q6a: rootpart forced to 3"
    assert_equals "128" "$EXTRA_ROOTFS_MIB_SIZE"  "q6a: image size grows by 128 MiB"
    assert_gt "$UEFISIZE" 0 "q6a: UEFISIZE>0 (ESP guaranteed)"
}

_hooks_scenario_other() {
    local BOARD="orangepi-zero3"
    local BOOTFS_TYPE="fat" BOOTSIZE="256"
    local UEFISIZE=0 EXTRA_ROOTFS_MIB_SIZE=0 rootpart=2 USE_HOOK_FOR_PARTITION="no"

    pre_prepare_partitions__theos_config_partition
    prepare_image_size__theos_config_partition

    assert_equals "fat" "$BOOTFS_TYPE"            "other: BOOTFS_TYPE untouched"
    assert_equals "256" "$BOOTSIZE"               "other: BOOTSIZE untouched"
    assert_equals "no"  "$USE_HOOK_FOR_PARTITION" "other: hook not enabled"
    assert_equals "2"   "$rootpart"               "other: rootpart untouched"
    assert_equals "0"   "$EXTRA_ROOTFS_MIB_SIZE"  "other: image size untouched"
}
