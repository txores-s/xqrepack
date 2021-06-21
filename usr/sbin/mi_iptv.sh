#!/bin/sh
# mi_iptv

WAN_IFNAME="eth1"
LAN_IFNAME="eth2 eth3 eth4"

iptv_logger() {
    echo "mi_iptv: $1" > /dev/console
    #logger -t mi_iptv "$1"
}

iptv_usage() {
    echo "usage: ./mi_iptv.sh on|off"
    echo "value: on -- enable iptv "
	echo "value: off -- disable iptv" 
    echo ""
}

# $1: name
is_interface_exist()
{
	local name=$1
	
	[ -z "$name" ] && return
	
	uci -q get network.$name > /dev/null 2>&1
	
	echo $?
}

# $1: name
# $2: ifname
# $3: vid
create_vdevice_interface()
{
	local name=$1
	local ifname=$2
	local vid=$3
	local vif_name="${ifname}.${vid}"
	
	[ -z "$name" -o -z "$ifname" -o $vid -le 0 -o $vid -gt 4094 ] && return
	[ $(is_interface_exist "$name") -eq 0 ] && return
	
	iptv_logger "create interface $name : $vif_name"
	uci -q batch <<EOF
        set network.$name=interface
        set network.$name.ifname="$vif_name"
        commit network
EOF
}

# $1: name
# $2: ifnames
# $3: igmp_snooping
create_bridge_interface()
{
	local name="$1"
	local ifnames="$2"
	local found=0
	
	[ -z "$name" -o -z "$ifnames" ] && return
	
	found=$(is_interface_exist "$name")
	if [ $found -eq 0 ]; then
		iptv_logger "modify bridge br-$name, ifnames: $ifnames"
		uci -q batch <<EOF
			set network.$name.ifname="$ifnames"
			commit network
EOF
	else
		iptv_logger "create bridge br-$name, ifnames: $ifnames"
		uci -q batch <<EOF
			set network.$name=interface
			set network.$name.ifname="$ifnames"
			set network.$name.type=bridge
			commit network
EOF
	fi	
}

# $1: name
delete_interface(){
	local name="$1"
	[ -z "$name" ] && return
	
	[ $(is_interface_exist "$name") -eq 0 ] && {
		iptv_logger "delete interface $name"
		uci -q batch <<EOF
			delete network.$name
			commit network
EOF
	}
}

modify_wan_ifname(){
	local old_wan_ifname="$(uci -q get network.wan.ifname)"
	local wan_ifname="$1"

	iptv_logger "modify wan_ifname : $old_wan_ifname -> $wan_ifname"
	uci -q batch <<EOF
        set network.wan.ifname=$wan_ifname
        commit network
EOF
}

iptv_clean_internet_vlan(){

	delete_interface "internet_wan"
}

iptv_do_internet_vlan(){
    local internet_tag=$(uci -q get mi_iptv.settings.internet_tag)
    local internet_vid=$(uci -q get mi_iptv.settings.internet_vid)
	local wan_ifname=$WAN_IFNAME
	local internet_vif=""
	
	[ $internet_vid -le 0 -o $internet_vid -gt 4094 ] && {
		iptv_logger "invalid internet_vid $internet_vid"
		return
	}
	
	[ "$internet_tag" = "1" ] && {
		create_vdevice_interface "internet_wan" $wan_ifname $internet_vid
		modify_wan_ifname "${wan_ifname}.${internet_vid}"
	}
}

iptv_clean(){
	local wan_ifname=$WAN_IFNAME
	
	iptv_clean_internet_vlan
	
	modify_wan_ifname "$wan_ifname"
}

iptv_off() {
	
	iptv_clean
}

iptv_on() {

	iptv_do_internet_vlan
}

mi_iptv_lock="/var/run/mi_iptv.lock"
trap "lock -u $mi_iptv_lock; exit 1" SIGHUP SIGINT SIGTERM
lock $mi_iptv_lock

case "$1" in
	on)
		iptv_on
		;;

	off)
		iptv_off
		;;
	restart)
		iptv_off
		iptv_on
		;;
	*)
		iptv_usage
		;;
esac

lock -u $mi_iptv_lock

return 0
