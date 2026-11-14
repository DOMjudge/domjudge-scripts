#!/bin/bash
# Build a Vagrant (libvirt) box from an ICPC contest disk image, without root.
#
#   make-icpc-box.sh IMAGE.img [BOXNAME] [EXTRA_GIB]
#
# The original image is only read. In a working copy, root's authorized_keys
# is replaced by the test SSH key (roles/ssh/files/id_ed25519.pub, see
# bootstrap.sh) using debugfs, because the image has no cloud-init and no
# vagrant user. The disk is made EXTRA_GIB (default 16) larger; the
# Vagrantfile grows the root partition and filesystem on first boot, as
# the image only has a few GiB free.
set -euo pipefail
cd "$(dirname "$0")" || exit 1
PATH=$PATH:/usr/sbin:/sbin   # sfdisk and debugfs, also for non-root users

img=${1:?usage: $0 IMAGE.img [BOXNAME] [EXTRA_GIB]}
name=${2:-icpc-image}
extra=${3:-16}
key=../roles/ssh/files/id_ed25519.pub
[ -f "$key" ] || { echo "Run ./bootstrap.sh first (generates the SSH key)." >&2; exit 1; }
[ -f "$img" ] || { echo "$img not found" >&2; exit 1; }
for cmd in sfdisk debugfs qemu-img vagrant python3; do
    command -v "$cmd" >/dev/null || { echo "$cmd is required" >&2; exit 1; }
done

# The root filesystem is the largest partition.
offset=$(sfdisk -J "$img" | python3 -I -c '
import json, sys
t = json.load(sys.stdin)["partitiontable"]
p = max(t["partitions"], key=lambda p: p["size"])
print(p["start"] * t.get("sectorsize", 512))')
echo "Root partition at byte offset $offset"

# Needs about twice the image size; set TMPDIR to use another disk.
work=$(mktemp -d "${TMPDIR:-/var/tmp}/icpc-box.XXXXXX")
trap 'rm -rf "$work"' EXIT

echo "Copying image (sparse)..."
cp --sparse=always "$img" "$work/disk.img"

echo "Installing the test key as /root/.ssh/authorized_keys of the copy..."
cat > "$work/cmds" <<CMDS
mkdir /root/.ssh
sif /root/.ssh mode 040700
sif /root/.ssh uid 0
sif /root/.ssh gid 0
rm /root/.ssh/authorized_keys
write "$(realpath "$key")" /root/.ssh/authorized_keys
sif /root/.ssh/authorized_keys mode 0100600
sif /root/.ssh/authorized_keys uid 0
sif /root/.ssh/authorized_keys gid 0
CMDS
# debugfs carries on after errors (e.g. mkdir of an existing directory), so
# check the result instead.
debugfs -w -f "$work/cmds" "$work/disk.img?offset=$offset" >/dev/null 2>&1
if ! debugfs -R "cat /root/.ssh/authorized_keys" "$work/disk.img?offset=$offset" 2>/dev/null | cmp -s - "$key"; then
    echo "Key was not written correctly" >&2; exit 1
fi

echo "Converting to qcow2 and growing by ${extra}G..."
qemu-img convert -f raw -O qcow2 "$work/disk.img" "$work/box.img"
rm "$work/disk.img"
qemu-img resize "$work/box.img" "+${extra}G" >/dev/null
size=$(qemu-img info --output=json "$work/box.img" | python3 -I -c 'import json,sys; print(-(-json.load(sys.stdin)["virtual-size"] // 2**30))')
printf '{"provider":"libvirt","format":"qcow2","virtual_size":%s}\n' "$size" > "$work/metadata.json"
printf 'Vagrant.configure("2") do |config|\nend\n' > "$work/Vagrantfile"

echo "Packing and adding box '$name'..."
tar -C "$work" -cf "$work/$name.box" metadata.json Vagrantfile box.img
rm "$work/box.img"
vagrant box add --force --name "$name" "$work/$name.box"
echo "Done: box '$name' added."
