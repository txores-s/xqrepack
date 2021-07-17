#!/bin/sh
#

arg1="$1"
arg2="$2"
arg3="$3"

rpx_en="$(uci -q get xiaoqiang.common.rpxqimage)"
[ ${rpx_en:-1} -eq 0 ] || command -v rpxqimage.sh >/dev/null && rpxqimage.sh "$arg1" >/dev/null

set -e

flash_do_upgrade.sh "$arg1" "$arg2" "$arg3"
