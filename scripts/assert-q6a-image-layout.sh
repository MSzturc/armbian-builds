#!/usr/bin/env bash
# Asserts the Dragon Q6A image layout: [ESP p1][THEOS FAT32 p2][ext4 root p3],
# no separate /boot, ESP at /boot/efi. Run on the built .img (needs root for loop).
set -euo pipefail

IMG="${1:?usage: assert-q6a-image-layout.sh <image.img>}"

fail() { echo "LAYOUT FAIL: $*" >&2; exit 1; }

label="$(sfdisk -d "$IMG" | sed -n 's/^label: //p')"
[[ "$label" == "gpt" ]] || fail "expected gpt, got '$label'"

parts="$(sfdisk -d "$IMG" | grep -cE '^[^ ]+ :')"
[[ "$parts" -eq 3 ]] || fail "expected 3 partitions, got $parts"

# p1 must be EFI System, p3 (last) must be Linux/root.
sfdisk -d "$IMG" | grep -qE '\.img1 .*type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B' \
    || fail "p1 is not EFI System"
last_part="$(sfdisk -d "$IMG" | grep -E '^[^ ]+ :' | tail -1)"
echo "$last_part" | grep -q '\.img3 ' || fail "root is not partition 3 (last)"

loop="$(losetup --show --find --partscan "$IMG")"
trap 'umount /mnt/q6a-root 2>/dev/null || true; losetup -d "$loop" 2>/dev/null || true' EXIT

# p2 must be vfat labelled THEOS; p3 must be ext4 (the real root).
p2_fstype="$(blkid -s TYPE -o value "${loop}p2" || true)"
p2_label="$(blkid -s LABEL -o value "${loop}p2" || true)"
[[ "$p2_fstype" == "vfat" ]] || fail "p2 fstype is '$p2_fstype', expected vfat"
[[ "$p2_label" == "THEOS" ]] || fail "p2 label is '$p2_label', expected THEOS"
p3_fstype="$(blkid -s TYPE -o value "${loop}p3" || true)"
[[ "$p3_fstype" == "ext4" ]] || fail "p3 fstype is '$p3_fstype', expected ext4"

# fstab invariants, and that / resolves to p3's UUID.
mkdir -p /mnt/q6a-root
mount -o ro "${loop}p3" /mnt/q6a-root
fstab="$(cat /mnt/q6a-root/etc/fstab)"
p3_uuid="$(blkid -s UUID -o value "${loop}p3")"
echo "$fstab" | grep -qE "^UUID=${p3_uuid}[[:space:]]+/[[:space:]]+ext4" \
    || fail "/ in fstab does not resolve to p3 UUID ${p3_uuid}"
echo "$fstab" | grep -qE '^[^#].*[[:space:]]/boot[[:space:]]+vfat' && fail "found a /boot vfat entry"
echo "$fstab" | grep -qE '/boot/efi[[:space:]]+vfat' || fail "no /boot/efi vfat entry"
echo "$fstab" | grep -qE 'LABEL=THEOS[[:space:]]+/boot/theos-config[[:space:]]+vfat' \
    || fail "no THEOS config-partition fstab entry"

echo "LAYOUT OK"
