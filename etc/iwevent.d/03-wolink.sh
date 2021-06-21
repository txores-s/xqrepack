#!/bin/sh

if [ -n "$STA" ]; then
	devId=`nvram get devId`
	hostname=`cat /tmp/dhcp.leases | grep -i "$STA" | awk '{print $4}'`
	time=`date -u "+%Y%m%dT%H%M%SZ"`
	if [ "$ACTION" = "ASSOC" ]; then
		stat=0
	elif [ "$ACTION" = "DISASSOC" ]; then
		stat=1
	else
		return
        fi
	echo "[{\"devId\":\"$devId\",\"services\":[{\"data\":{\"mac\":\"$STA\",\"name\":\"$hostname\",\"time\":\"$time\",\"type\":$stat}}]}]" > /tmp/wolink.iwevent
        wolink_pid=`ps w | grep "/usr/sbin/wolink" | grep -v "grep" | awk '{print $1}'`
        [ -n "$wolink_pid" ] && kill -s SIGUSR1 $wolink_pid
	return
fi
