#!/usr/bin/env bash
# Tests the pure sfdisk-script emitter from the THEOS config-partition extension.

run_tests() {
    local ext="${HERE}/../../userpatches/extensions/theos-config-partition.sh"
    # shellcheck disable=SC1090
    source "${ext}"

    local out
    # theos_partition_script OFFSET UEFISIZE CONFIG_MIB ROOT_TYPE_UUID
    out="$(theos_partition_script 4 256 128 B921B045-1DF0-41C3-AF44-4C6F280D3FAE)"

    assert_contains "$out" "label: gpt" "declares a GPT label"
    assert_equals 3 "$(echo "$out" | grep -cE '^[0-9]+ :')" "emits exactly three partitions"
    assert_contains "$out" '1 : name="efi", start=4MiB, size=256MiB, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B' "p1 is the ESP"
    assert_contains "$out" '2 : name="theos", start=260MiB, size=128MiB, type=EBD0A0A2-B9E5-4433-87C0-68B6B72699C7' "p2 is the THEOS MS Basic Data FAT"
    assert_contains "$out" '3 : name="rootfs", start=388MiB, type=B921B045-1DF0-41C3-AF44-4C6F280D3FAE' "p3 is root, no size (grows to fill)"
    assert_not_contains "$(echo "$out" | grep '3 :')" "size=" "root line carries no size= argument"

    local last
    last="$(echo "$out" | grep -E '^[0-9]+ :' | tail -1)"
    assert_contains "$last" '3 : name="rootfs"' "root is the last partition"
}
