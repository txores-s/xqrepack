#!/bin/sh
#

#$1 - file; $2 - size; $3 - offset
read_value() {
    v=$(dd if="$1" bs=1 count=$2 skip=${3:-0} 2>/dev/null)
    printf $((0x$(eval printf $(printf '%%02x%.0s' $(seq 1 $2)) $(printf '"\"${v:%d:1}\"" ' $(seq $(($2-1)) -1 0)))))
}
#$1 - kernel; #2 - rootfs; $3 - output; $4 - data flag (true if not empty); $5 - image sequence number
create_ubi_image() {
	ROOTFS_SIG=`hexdump -n 4 -e '"%_p"' "$2"`
	[ "$ROOTFS_SIG" = "hsqs" ] || { echo "rootfs is not squashfs."; exit 1; }

	KERNEL_SIG=`hexdump -n 4 -e '1/1 "%02x"' "$1"`
	[ "$KERNEL_SIG" = "d00dfeed" ] || { echo "invalid kernel img"; exit 1; }

	UBICFG=`mktemp /tmp/r3600-ubicfg-$image_seq.XXXXXX`

	cat <<CFGEND > $UBICFG
[kernel]
mode=ubi
image=$1
vol_id=0
vol_type=dynamic
vol_name=kernel
[rootfs]
mode=ubi
image=$2
vol_id=1
vol_type=dynamic
vol_name=ubi_rootfs
CFGEND

	[ -n "$4" ] && cat <<CFGEND2 >> $UBICFG
[data]
mode=ubi
vol_size=1
vol_id=2
vol_type=dynamic
vol_name=rootfs_data
vol_flags=autoresize
CFGEND2

	[ -z "$5" ] && \
	{ ubinize -m 2048 -p 128KiB -o "$3" "$UBICFG" >/dev/null; } || \
	{ ubinize -Q $5 -m 2048 -p 128KiB -o "$3" "$UBICFG" >/dev/null; }
}

image="$1"
no_rpseg="$2"
image_seq="$3"
rpxqimage_ext="${4:-/etc/rpxqimage_ext.sh}"

[ -f "$image" ] || {
	echo 'Image not found.'
	echo 'Usage: rpxqimage.sh FILE [--no-rpseg|--force] [-Q[N]] [SCRIPT]'
	echo '$1 - path to image file.'
	echo '$2 - one of 2 flags:'
	echo '     --no-rpseg - do not add "rpxqimage" segment'
	echo '     --force    - force repack images with "rpxqimage" segment'
	echo '$3 - image sequence number.'
	echo '     If invalid of empty value tries to find sequence number in image file.'
	echo '     If N is not set generates random value.'
	echo '$4 - path to optional script file.'
	echo '     If not set default path is used: "/etc/rpxqimage_ext.sh".'
	echo '     Takes 2 arguments:'
	echo '        $1 - path to rw upper layer'
	echo '        $2 - path to ro lower layer'
	echo 'Set "xiaoqiang.common.rpxqimage" variable to 0 to disable "rpxqimage.sh" on fw update:'
	echo '     uci set xiaoqiang.common.rpxqimage=0'
	exit 1
}

mkxqimage.elf -rc "$image" -f "rpxqimage" >/dev/null && {
	[ "$no_rpseg" = "--force" ] && no_rpseg="--no-rpseg" || exit 0
}

work_dir="$(dirname $image)/rpxqimage_workdir"
rootfs_rw_dir="$work_dir/merged"
rootfs_ro_dir="$work_dir/lower"
segments="$work_dir/segments"

[ -d "$rootfs_rw_dir" ] && umount -f "$rootfs_rw_dir" 2>/dev/null
[ -d "$rootfs_ro_dir" ] && umount -f "$rootfs_ro_dir" 2>/dev/null
[ -d "$work_dir" ] && { umount -f "$work_dir" 2>/dev/null; rm -rf "$work_dir" 2>/dev/null; }

set -e

[ "${image_seq:0:2}" = "-Q" ] && {
	image_seq="${image_seq:2}"
	[ -z "$image_seq" ] || image_seq=$((image_seq))
} || {
	image_seq=$((0x$(mkxqimage.elf -rnx "$image" -f root.ubi | head -c28 | tail -c4 | hexdump -n4 -e '1/1 "%02x"')))
}

mkdir -p "$work_dir"
mount -t tmpfs tmpfs "$work_dir"
mkdir -p "$rootfs_ro_dir" "$work_dir/upper" "$rootfs_rw_dir" "$work_dir/work" "$segments"

mkxqimage_cmd="mkxqimage.mkimg.sh -o $image"
mkxqimage_cmd_bkp="mkxqimage.mkimg.sh -o $image"

for word in $(echo $(mkxqimage.elf -c "$image"))
do
	mkxqimage.elf -c "$image" -f "$word" >/dev/null && {
		[ "$word" != "root.ubi" ] && mkxqimage.elf -rnx "$image" -f "$word" > "$segments/$word"
		mkxqimage_cmd="$mkxqimage_cmd -f $segments/$word"
	}
done

dd if="$image" of="$segments/$(basename $image).sig" bs=1 skip=$(read_value "$image" 4 4) 2>/dev/null
mkxqimage_cmd="$mkxqimage_cmd -s $segments/$(basename $image).sig"
mkxqimage_cmd_bkp="$mkxqimage_cmd"

[ "$no_rpseg" != "--no-rpseg" ] && {
	dd if="/dev/zero" of="$segments/rpxqimage" bs=1 count=16 2>/dev/null
	mkxqimage_cmd="$mkxqimage_cmd -f $segments/rpxqimage"
}

ubireader_extract_images.lua -w -o "$work_dir/volumes" "$image"
kernel="$work_dir/volumes/$(ls $work_dir/volumes | grep kernel)"
rootfs="$work_dir/volumes/$(ls $work_dir/volumes | grep rootfs)"

restore_image() {
	set +e
	mkxqimage.elf -rnx "$image" >/dev/null 2>/dev/null || {
		create_ubi_image "$kernel" "$rootfs" "$segments/root.ubi" "$(ls $work_dir/volumes | grep rootfs_data)" $image_seq
		eval "$mkxqimage_cmd_bkp"
	}
	umount -f "$rootfs_rw_dir"
	umount -f "$rootfs_ro_dir"
	umount -f "$work_dir"
	rm -rf "$work_dir"
}
trap restore_image EXIT

rm -f "$image"

squashfuse "$rootfs" "$rootfs_ro_dir"
mount -t overlay overlay -o lowerdir="$rootfs_ro_dir",upperdir="$work_dir/upper",workdir="$work_dir/work" "$rootfs_rw_dir"

cp -fp "$rootfs_rw_dir/bin/flash.sh" "$rootfs_rw_dir/bin/flash_do_upgrade.sh"
cp -fp "$rootfs_rw_dir/bin/mkxqimage" "$rootfs_rw_dir/bin/mkxqimage.elf"

while IFS= read -r file_path
do
	cp -fp "$file_path" "$rootfs_rw_dir/$file_path"
done << END
/bin/flash.sh
/bin/mkxqimage
/bin/mkxqimage.mkimg.sh
/bin/rpxqimage.sh
/bin/tar
/usr/sbin/ubireader_extract_images.lua
/usr/sbin/mksquashfs
/usr/sbin/unsquashfs
/usr/bin/squashfuse
/usr/bin/xz
/usr/bin/xzcat
/usr/bin/lzma
/usr/bin/unlzma
/usr/bin/lzcat
/usr/bin/unxz
/usr/lib/libzstd.so.1.4.5
/usr/lib/libzstd.so.1
/usr/lib/libzstd.so
/usr/lib/libulockmgr.so.1.0.1
/usr/lib/libulockmgr.so.1
/usr/lib/libsquashfuse_ll.so.0.0.0
/usr/lib/libsquashfuse_ll.so.0
/usr/lib/libsquashfuse.so.0.0.0
/usr/lib/libsquashfuse.so.0
/usr/lib/liblz4.so.1.9.2
/usr/lib/liblz4.so.1
/usr/lib/libfuseprivate.so.0.0.0
/usr/lib/libfuseprivate.so.0
/usr/lib/libfuse.so.2.9.7
/usr/lib/libfuse.so.2
END

sed -i 's/channel=.*/channel=\\"debug\\"/g' "$rootfs_rw_dir/etc/init.d/dropbear"

command -v $rpxqimage_ext >/dev/null && $rpxqimage_ext "$rootfs_rw_dir" "$rootfs_ro_dir"

mksquashfs "$rootfs_rw_dir" "$rootfs.new" -comp xz -b 256K -no-xattrs -quiet

create_ubi_image "$kernel" "$rootfs.new" "$segments/root.ubi" "$(ls $work_dir/volumes | grep rootfs_data)" "$image_seq"
eval "$mkxqimage_cmd"
