#!/usr/bin/env bash
# Verifies the Dragon Q6A build config actually enables the THEOS config-partition
# extension. Armbian sources an extension only when its basename is listed in
# ENABLE_EXTENSIONS — dropping the file into userpatches/extensions/ is not enough.

run_tests() {
    _assert_enables radxa_dragon_q6a_trixie
    _assert_enables radxa_dragon_q6a_trixie_nightly
}

_assert_enables() {
    local board="$1"
    local cfgdir="${HERE}/../../configs"
    local combined ext
    combined="$(mktemp)"
    # Reproduce the build-image action: config-default.conf then the board config.
    cat "${cfgdir}/config-default.conf" "${cfgdir}/board-${board}.conf" > "${combined}"
    ext="$(set +u; source "${combined}" >/dev/null 2>&1; echo "${ENABLE_EXTENSIONS:-}")"
    assert_contains "${ext}" "theos-config-partition" \
        "${board}: ENABLE_EXTENSIONS includes theos-config-partition"
    rm -f "${combined}"
}
