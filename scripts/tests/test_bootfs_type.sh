#!/usr/bin/env bash
# Verifies the Dragon Q6A build config selects a non-FAT /boot filesystem. With the
# global BOOTFS_TYPE=fat default, the linux-image postinst renames /boot/vmlinuz-<ver>
# to /boot/Image, so grub-mkconfig's vmlinuz-* glob finds nothing and emits no kernel
# entry — failing the GRUB initrd sanity check. ext4 keeps the versioned kernel name.

run_tests() {
    local board
    for board in radxa_dragon_q6a_trixie radxa_dragon_q6a_trixie_nightly; do
        _assert_bootfs_nonfat "${board}"
    done
}

_assert_bootfs_nonfat() {
    local board="$1"
    local cfgdir="${HERE}/../../configs"
    local combined val
    combined="$(mktemp)"
    # Reproduce the build-image action: config-default.conf then the board config.
    cat "${cfgdir}/config-default.conf" "${cfgdir}/board-${board}.conf" > "${combined}"
    val="$(set +u; source "${combined}" >/dev/null 2>&1; echo "${BOOTFS_TYPE:-}")"
    assert_equals "ext4" "${val}" \
        "${board}: BOOTFS_TYPE is ext4 (not fat) so the kernel keeps its versioned name"
    rm -f "${combined}"
}
