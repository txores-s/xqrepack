#!/bin/sh
# mi_iptv

iptv_logger() {
    echo "mi_iptv: $1" > /dev/console
    #logger -t mi_iptv "$1"
}

maccel_usage() {
    echo "usage: ./mi_iptv.sh on|off"
    echo "value: on port vlanid -- enable iptv and set iptv port&vlanid "
	echo "value: off port vlanid -- disable iptv and change iptv port&vlanid"
	echo "value: off -- disable iptv" 
    echo ""
}

port_transfer() {
	echo `expr $1 + 1`
}

vlanid_transfer() {
	echo $1
}

string_del_substr() {
	local res=""

	for s in $1
	do
		[ "$s" != "$2" ] && res="${res} ${s}"
	done
	echo $res
}

network_iptv_del() {
	local port=$(port_transfer "$1")
	local vlanid=$(vlanid_transfer "$2")
	local lan_ifn=$(uci -q get network.lan.ifname)
	local wan_ifn=$(uci -q get network.iptv.ifname)
	local wan6_ifn=$(uci -q get network.wan_6.ifname)
	
	if [ "$vlanid" = "0" ]; then
		wan_ifn=$(echo $wan_ifn | awk '{print $1}')
	else
		wan_ifn=$(echo $wan_ifn | awk -F'.' '{print $1}')
	fi
	[ -z "$wan_ifn" ] && wan_ifn='eth1'

	lan_ifn="${lan_ifn} eth${port}"

	if [ -z "$wan6_ifn" ]; then
		uci -q batch <<EOF
        	set network.lan.ifname="$lan_ifn"
        	set network.wan.ifname="$wan_ifn"
        	delete network.iptv
        	commit network
EOF
	else
		uci -q batch <<EOF
        	set network.lan.ifname="$lan_ifn"
        	set network.wan.ifname="$wan_ifn"
			set network.wan_6.ifname="$wan_ifn"
        	delete network.iptv
        	commit network
EOF
	fi
}

network_iptv_add() {
	local port=$(port_transfer "$1")
	local vlanid=$(vlanid_transfer "$2")
	local lan_ifn=$(uci -q get network.lan.ifname)
	local wan_ifn=$(uci -q get network.wan.ifname)
	[ "$wan_ifn" = "br-iptv" ] && return
	local wan6_ifn=$(uci -q get network.wan_6.ifname)

	lan_ifn=$(string_del_substr "$lan_ifn" "eth${port}")

	[ -z "$wan_ifn" ] && wan_ifn='eth1'
	if [ "$vlanid" = "0" ]; then
		wan_ifn="${wan_ifn} eth${port}"
	else
		wan_ifn="${wan_ifn}.${vlanid} eth${port}"
	fi

	if [ -z "$wan6_ifn" ]; then
		uci -q batch <<EOF
			set network.lan.ifname="$lan_ifn"
			set network.wan.ifname=br-iptv
			delete network.iptv
			set network.iptv=interface
			set network.iptv.ifname="$wan_ifn"
			set network.iptv.type=bridge
			commit network
EOF
	else
		uci -q batch <<EOF
			set network.lan.ifname="$lan_ifn"
			set network.wan.ifname=br-iptv
			set network.wan_6.ifname=br-iptv
			delete network.iptv
			set network.iptv=interface
			set network.iptv.ifname="$wan_ifn"
			set network.iptv.type=bridge
			commit network
EOF
	fi
}

network_iptv_chg() {
	local port_old=$(port_transfer "$1")
	local vlanid_old=$(vlanid_transfer "$2")
	local port_new=$(port_transfer "$3")
	local vlanid_new=$(vlanid_transfer "$4")
	local lan_ifn=$(uci -q get network.lan.ifname)
	local wan_ifn=$(uci -q get network.iptv.ifname)
	
	[ "$port_old" != "$port_new" ] && lan_ifn="${lan_ifn} eth${port_old}"
	lan_ifn=$(string_del_substr "$lan_ifn" "eth${port_new}")

	if [ "$vlanid_old" = "0" ]; then
		wan_ifn=$(echo $wan_ifn | awk '{print $1}')
	else
		wan_ifn=$(echo $wan_ifn | awk -F'.' '{print $1}')
	fi
	[ -z "$wan_ifn" ] && wan_ifn='eth1'
	if [ "$vlanid" = "0" ]; then
		wan_ifn="${wan_ifn} eth${port_new}"
	else
		wan_ifn="${wan_ifn}.${vlanid_new} eth${port_new}"
	fi

	uci -q batch <<EOF
		set network.lan.ifname="$lan_ifn"
		set network.iptv.ifname="$wan_ifn"
		commit network
EOF
}

iptv_off() {
    local en_old=$(uci -q get mi_iptv.settings.enabled)
    local port_old=$(uci -q get mi_iptv.settings.port)
    local vlanid_old=$(uci -q get mi_iptv.settings.vlanid)
	local port_new=$2
	local vlanid_new=$3
	
	[ -z "$port_new" ] && port_new=$port_old
	[ -z "$vlanid_new" ] && vlanid_new=$vlanid_old
	
	[ "$en_old" = "1" ] && {
		network_iptv_del "$port_old" "$vlanid_old"
	}

	uci -q batch <<EOF
        set mi_iptv.settings.enabled=0
        set mi_iptv.settings.port="$port_new"
        set mi_iptv.settings.vlanid="$vlanid_new"
        commit mi_iptv
EOF
}

iptv_on() {
    local en_old=$(uci -q get mi_iptv.settings.enabled)
    local port_old=$(uci -q get mi_iptv.settings.port)
    local vlanid_old=$(uci -q get mi_iptv.settings.vlanid)
	
	if [ "$en_old" = "0" ]; then
		network_iptv_add "$1" "$2"
	else
		network_iptv_chg "$port_old" "$vlanid_old" "$1" "$2"
	fi
	
	[ "$en_old" = "0" -o "$1" != "$port_old" -o "$2" != "$vlanid_old" ] && {
        uci -q batch <<EOF
			set mi_iptv.settings.enabled=1
			set mi_iptv.settings.port="$1"
			set mi_iptv.settings.vlanid="$2"
			commit mi_iptv
EOF
	}
}

network_del_iptv() {
	local en=$(uci -q get mi_iptv.settings.enabled)
    local port=$(uci -q get mi_iptv.settings.port)
    local vlanid=$(uci -q get mi_iptv.settings.vlanid)

	[ "$en" = "1" ] && {
		network_iptv_del "$port" "$vlanid"
	}
}

network_add_iptv() {
	local en=$(uci -q get mi_iptv.settings.enabled)
    local port=$(uci -q get mi_iptv.settings.port)
    local vlanid=$(uci -q get mi_iptv.settings.vlanid)

	[ "$en" = "1" ] && {
		network_iptv_add "$port" "$vlanid"
	}
}



[ -z "$1" ] && return 1
[ "$1" = "on" ] && {
	port=$2
	vlanid=$3
	[ -z "$port" ] && port=1
	[ -z "$vlanid" ] && vlanid=0
}

mi_iptv_lock="/var/run/mi_iptv.lock"
trap "lock -u $mi_iptv_lock; exit 1" SIGHUP SIGINT SIGTERM
lock $mi_iptv_lock

case "$1" in
	on)
		iptv_on $2 $3
		;;

	off)
		iptv_off $@
		;;

	net_del_iptv)
		network_del_iptv
		;;

	net_add_iptv)
		network_add_iptv
		;;		

	*)
		iptv_usage
		;;
esac

lock -u $mi_iptv_lock

return 0
