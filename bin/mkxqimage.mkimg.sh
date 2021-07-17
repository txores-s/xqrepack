#!/bin/sh
#

#$1 - file; $2 - value; $3 - size; $4 - offset
write_value() {
    printf $(eval printf "$(printf '\\\\x%%02x%.0s' $(seq 1 $3))" $(printf '$(($2>>%d&0xff)) ' $(seq 0 8 $(($3*8-8))))) | \
	dd of="$1" bs=1 count=$3 seek=${4:-0} conv=notrunc 2>/dev/null
}

output=""
signature="/dev/zero"
files=""
state="opt"

for arg in "$@"
do
	case "$state" in
	"opt")
		state="$arg"
		continue;
		;;
	"-f")
		files="$files $arg"
		;;
	"-o")
		output="$arg"
		;;
	"-s")
		signature="$arg"
		;;
	*)
		echo "Invalid option: $arg"
		exit 1
		;;
	esac
	state="opt"
done

[ -z "$output" ] && { echo "-o required"; exit 1; }
[ "$signature" != "/dev/zero" ] && sig_size=$(stat -c%s "$signature") || sig_size=$((0x110))

set -e

printf "\x48\x44\x52\x31\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x18\x00" | dd of="$output" bs=1 count=16 2>/dev/null
dd if=/dev/zero of="$output" bs=16 count=2 seek=1 conv=notrunc 2>/dev/null

seg_offset=16
cur_offset=48

for segment in $(echo $files)
do
	seg_name="$(basename $segment)"
	write_value "$output" $cur_offset 4 $seg_offset
	seg_offset=$(($seg_offset+4))
	printf "\xbe\xba\x00\x00\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\x00\x00" >> "$output"
	printf "$seg_name" >> "$output"
	dd if=/dev/zero bs=1 count=$((32-${#seg_name})) 2>/dev/null >> "$output"
	dd if="$segment" 2>/dev/null >> "$output"
	write_value "$output" $(stat -c%s "$segment") 4 $(($cur_offset+8))
	cur_offset=$(stat -c%s "$output")
	[ $(($cur_offset%4)) -eq 0 ] || { dd if=/dev/zero bs=1 count=$((4-$cur_offset%4)) 2>/dev/null >> "$output"; }
	cur_offset=$(stat -c%s "$output")
done

write_value "$output" $cur_offset 4 4
dd if="$signature" bs=1 count=$sig_size 2>/dev/null >> "$output"
[ "$signature" = "/dev/zero" ] && write_value "$output" $((0x100)) 4 $cur_offset
write_value "$output" $(($(dd if="$output" skip=1 bs=12 2>/dev/null | ubicrc32))) 4 8

mkxqimage -v "$output"
