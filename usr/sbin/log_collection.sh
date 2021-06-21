#!/bin/sh

redundancy_mode=`uci get misc.log.redundancy_mode`
LOG_TMP_MEMINFO="/tmp/meminfo.log"
LOG_TMP_FILE_PATH="/tmp/xiaoqiang.log"
LOG_ZIP_FILE_PATH="/tmp/log.tar.gz"

WIRELESS_FILE_PATH="/etc/config/wireless"
WIRELESS_STRIP='/tmp/wireless.conf'
NETWORK_FILE_PATH="/etc/config/network"
NETWORK_STRIP="/tmp/network.conf"
MACFILTER_FILE_PATH="/etc/config/macfilter"
CRONTAB="/etc/crontabs/root"
NVRAM_FILE_PATH="/tmp/nvram.txt"
BDATA_FILE_PATH="/tmp/bdata.txt"

LOG_DIR="/data/usr/log/"
LOGREAD_FILE_PATH="/data/usr/log/messages"
LOGREAD0_FILE_PATH="/data/usr/log/messages.0"
LOG_WIFI_AYALYSIS="/data/usr/log/wifi_analysis.log"
LOG_WIFI_AYALYSIS0="/data/usr/log/wifi_analysis.log.0.gz"
PANIC_FILE_PATH="/data/usr/log/panic.message"
TMP_LOG_FILE_PATH="/tmp/messages"
TMP_WIFI_LOG_ANALYSIS="/tmp/wifi_analysis.log"
TMP_WIFI_LOG="/tmp/wifi.log"
DHCP_LEASE="/tmp/dhcp.leases"
IPTABLES_SAVE="/tmp/iptables_save.log"
TRAFFICD_LOG="/tmp/trafficd.log"
PLUGIN_LOG="/tmp/plugin.log"
LOG_MEMINFO="/proc/meminfo"
DNSMASQ_CONF="/var/etc/dnsmasq.conf.cfg01411c"
QOS_CONF="/etc/config/miqos"
WIFISHARE_CONF="/etc/config/wifishare"
MICLOUD_LOG="/tmp/micloudBackup.log"
GZ_LOGS=""

hardware=`uci get /usr/share/xiaoqiang/xiaoqiang_version.version.HARDWARE`

# $1 plugin install path
# $2 output file path
list_plugin(){
    for file in `ls $1 | grep [^a-zA-Z]\.manifest$`
    do
        if [ -f $1/$file ];then
            status=$(grep -n "^status " $1/$file | cut -d'=' -f2 | cut -d'"' -f2)
            plugin_id=$(grep "name" $1/$file | cut -d'=' -f2 | cut -d'"' -f2)
            if [ "$status"x = "5"x ]; then
		echo "$plugin_id" >> $2 # eanbled
        fi
        fi
    done
}

rm -f $LOG_TMP_FILE_PATH

cat $TMP_LOG_FILE_PATH >> $LOGREAD_FILE_PATH
> $TMP_LOG_FILE_PATH

cat $TMP_WIFI_LOG_ANALYSIS >> $LOG_WIFI_AYALYSIS
> $TMP_WIFI_LOG_ANALYSIS

echo "==========SN" >> $LOG_TMP_FILE_PATH
nvram get SN >> $LOG_TMP_FILE_PATH

echo "==========uptime" >> $LOG_TMP_FILE_PATH
uptime >> $LOG_TMP_FILE_PATH

echo "==========df -h" >> $LOG_TMP_FILE_PATH
df -h >> $LOG_TMP_FILE_PATH

echo "==========bootinfo" >> $LOG_TMP_FILE_PATH
bootinfo >> $LOG_TMP_FILE_PATH

echo "==========tmp dir" >> $LOG_TMP_FILE_PATH
ls -lh /tmp/ >> $LOG_TMP_FILE_PATH
du -sh /tmp/* >> $LOG_TMP_FILE_PATH

echo "==========ifconfig" >> $LOG_TMP_FILE_PATH
ifconfig >> $LOG_TMP_FILE_PATH

echo "==========/proc/net/dev" >> $LOG_TMP_FILE_PATH
cat /proc/net/dev >> $LOG_TMP_FILE_PATH

echo "==========/proc/bus/pci/devices" >> $LOG_TMP_FILE_PATH
cat /proc/bus/pci/devices >> $LOG_TMP_FILE_PATH

echo "==========route" >> $LOG_TMP_FILE_PATH
route -n >> $LOG_TMP_FILE_PATH

echo "==========ip -6 route" >> $LOG_TMP_FILE_PATH
ip -6 route >> $LOG_TMP_FILE_PATH

cat $NETWORK_FILE_PATH | grep -v -e'password' -e'username' > $NETWORK_STRIP

cat $WIRELESS_FILE_PATH | grep -v 'key' > $WIRELESS_STRIP

echo "==========ps" >> $LOG_TMP_FILE_PATH
ps -w >> $LOG_TMP_FILE_PATH

echo "==========nvram" >> $NVRAM_FILE_PATH
nvram show >> $NVRAM_FILE_PATH

echo "==========bdata" >> $BDATA_FILE_PATH
bdata show >> $BDATA_FILE_PATH


log_exec()
{
    echo "========== $1" >>$LOG_TMP_FILE_PATH
    eval "$1" >> $LOG_TMP_FILE_PATH
}

flog_exec()
{
    echo "========== $1" >>$2

    eval "$1" >> $2
}


list_messages_gz(){
    for file in `ls /data/usr/log/ | grep ^messages\.[1-4]\.gz$`; do
        GZ_LOGS=${GZ_LOGS}" /data/usr/log/"${file}
    done
}

if [ "$hardware" = "R1D" ] || [ "$hardware" = "R2D" ]; then
    /sbin/wifi_rate.sh 6 1 >> $LOG_TMP_FILE_PATH
    local wps_proc_status
    for count in `seq 0 3`; do
        i=$(($count%2))
        wps_proc_status=`nvram get wps_proc_status`

        if [ "$wps_proc_status" = "0" ]; then
            log_exec "acs_cli -i wl$i dump bss"
        else
            echo "========== wps is running!" >>$LOG_TMP_FILE_PATH
        fi
        log_exec "iwinfo wl$i info"
        log_exec "iwinfo wl$i assolist"
        log_exec "wl -i wl$i dump wlc"
        log_exec "wl -i wl$i dump bsscfg"
        log_exec "wl -i wl$i dump scb"
        log_exec "wl -i wl$i dump ampdu"
        log_exec "wl -i wl$i dump dma"
        log_exec "wl -i wl$i chanim_stats"
        log_exec "wl -i wl$i counters"
        log_exec "wl -i wl$i dump stats"
        log_exec "wl -i wl$i curpower"
        sleep 1
    done
elif [ "$hardware" = "R3D" ]; then
    for i in `seq 0 1`; do
        # wifi
        log_exec "athstats -i wifi$i >> $LOG_TMP_FILE_PATH"
    done
    for i in 0 1 13 14; do
        # wl
        log_exec "iwinfo wl$i info >> $LOG_TMP_FILE_PATH"
        log_exec "iwinfo wl$i assolist >> $LOG_TMP_FILE_PATH"
        log_exec "iwinfo wl$i txpowerlist >> $LOG_TMP_FILE_PATH"
        log_exec "iwinfo wl$i freqlist >> $LOG_TMP_FILE_PATH"
        log_exec "wlanconfig wl$i list >> $LOG_TMP_FILE_PATH"
        log_exec "80211stats -a -i wl$i >> $LOG_TMP_FILE_PATH"
	log_exec "iwpriv wl$i txrx_fw_stats 1"
	log_exec "iwpriv wl$i txrx_fw_stats 3"
	log_exec "iwpriv wl$i txrx_fw_stats 19"
	log_exec "iwpriv wl$i txrx_fw_stats 20"
    done
    /usr/sbin/getneighbor.sh ${LOG_TMP_FILE_PATH} > /dev/null 2>&1
elif [ "$hardware" = "R3600" ]; then
	log_exec "cat /proc/meminfo >> $LOG_TMP_MEMINFO"
    for i in `seq 0 1`; do
        # wifi
        log_exec "athstats -i wifi$i >> $LOG_TMP_FILE_PATH"
    done
    for i in 0 1 13 14; do
        # wl
        log_exec "iwinfo wl$i info >> $LOG_TMP_FILE_PATH"
        log_exec "iwinfo wl$i assolist >> $LOG_TMP_FILE_PATH"
        log_exec "iwinfo wl$i txpowerlist >> $LOG_TMP_FILE_PATH"
        log_exec "iwinfo wl$i freqlist >> $LOG_TMP_FILE_PATH"
        log_exec "wlanconfig wl$i list >> $LOG_TMP_FILE_PATH"
        log_exec "iwconfig wl$i >> $LOG_TMP_FILE_PATH"
    log_exec "iwpriv wl$i txrx_stats 9"
    log_exec "iwpriv wl$i txrx_stats 10"
    done
    #/usr/sbin/getneighbor.sh ${LOG_TMP_FILE_PATH} > /dev/null 2>&1
elif [ "$hardware" = "D01" ]; then
    for i in `seq 0 1`; do
        # wifi
        log_exec "athstats -i wifi$i >> $LOG_TMP_FILE_PATH"
    done

    local list="0 1 13"
    ifconfig wl14 >/dev/null 2>&1
    [ $? = 0 ] && list="$list 14"
    whcal isre && list="$list 01 11"
    echo "list:$list" >> $LOG_TMP_FILE_PATH

    for i in $list; do
        echo "  @@@@ iwinfo wl$i @@@@" >> $LOG_TMP_FILE_PATH
        echo "  @@@@ iwinfo wl$i @@@@" > /dev/console
        # wl
        log_exec "iwinfo wl$i info >> $LOG_TMP_FILE_PATH"
        log_exec "iwinfo wl$i assolist >> $LOG_TMP_FILE_PATH"
        log_exec "iwinfo wl$i txpowerlist >> $LOG_TMP_FILE_PATH"
        log_exec "iwinfo wl$i freqlist >> $LOG_TMP_FILE_PATH"
        log_exec "wlanconfig wl$i list >> $LOG_TMP_FILE_PATH"
        log_exec "80211stats -a -i wl$i >> $LOG_TMP_FILE_PATH"
	log_exec "iwpriv wl$i txrx_fw_stats 1"
	log_exec "iwpriv wl$i txrx_fw_stats 3"
	log_exec "iwpriv wl$i txrx_fw_stats 19"
	log_exec "iwpriv wl$i txrx_fw_stats 20"
    done
    # TODO other wifi 
    /usr/sbin/getneighbor.sh ${LOG_TMP_FILE_PATH} > /dev/null 2>&1


    ### log info for whc serives and state
    flog_exec "  @@@@ whc info log @@@@" "$WHC_LOG"
    flog_exec "#hyctl show: " "$WHC_LOG"
    hyctl show >> $WHC_LOG
    flog_exec "#hyctl gethatbl br-lan: " "$WHC_LOG"
    hyctl gethatbl br-lan 5000 >> "$WHC_LOG"

    flog_exec "#brctl showmacs detail info: " "$WHC_LOG"
    brctl showmacs br-lan >> $WHC_LOG
    flog_exec "#brctl showstp detail info: " "$WHC_LOG"
    brctl showstp br-lan >> $WHC_LOG

    flog_exec "###hyd info:td s2, pc s D, hy ha, hy hd, he s, stadb s phy, bandmon s, \
estimator s, steeralg s, steerexec s, ps s, ps p, ps f" "$WHC_LOG"
    (echo "@hyt_td_s2:"; echo td s2; sleep 3) | hyt >> $WHC_LOG
    (echo "@pc_s_D:";echo pc s D; sleep 2) | hyt >> $WHC_LOG
    (echo "@hy_ha_hd:"; echo hy ha; sleep 3; echo hy hd; sleep 2) | hyt >> $WHC_LOG
    (echo "@he_s:"; echo he u; sleep 1; echo he s; sleep 3 ) | hyt >> $WHC_LOG
    (echo "@ps_s_p_f:"; echo ps s; sleep 1; echo ps p; sleep 1; echo ps f; sleep 1) | hyt >> $WHC_LOG
    (echo "@stadb_s_phy:"; echo stadb s phy; sleep 3 ) | hyt >> $WHC_LOG
    (echo "@bandmon_s:"; echo bandmon s; sleep 1) | hyt >> $WHC_LOG
    (echo "@estimator_s"; echo estimator s; sleep 1) | hyt >> $WHC_LOG


    flog_exec "### swconfig info" "$WHC_LOG"
    swconfig dev switch0 show >> $WHC_LOG


    # plchost info
    flog_exec "### plc info"  "$WHC_LOG"
    flog_exec "#plchost -r" "$WHC_LOG"
    timeout -t 5 plchost -i br-lan -r 2>&1 >> $WHC_LOG
    flog_exec "#plchost -m" "$WHC_LOG"
    timeout -t 5 plchost -i br-lan -m 2>&1 >> $WHC_LOG
    flog_exec "#plchost -I" "$WHC_LOG"
    timeout -t 5 plchost -i br-lan -I 2>&1 >> $WHC_LOG
    flog_exec "#plctool -m" "$WHC_LOG"
    timeout -t 5 plctool -i br-lan -m 2>&1 >> $WHC_LOG

else
#On R1CM, The follow cmd will print result to dmesg.
    for i in `seq 0 3`; do
            log_exec "iwinfo wl$i info"
            log_exec "iwinfo wl$i assolist"
            log_exec "iwinfo wl$i txpowerlist"
            log_exec "iwinfo wl$i freqlist"
            log_exec "iwpriv wl$i stat"
            log_exec "iwpriv wl$i show stat"
            log_exec "iwpriv wl$i show stainfo"
            log_exec "iwpriv wl$i rf"
            log_exec "iwpriv wl$i bbp"
    done
    /usr/sbin/getneighbor.sh ${LOG_TMP_FILE_PATH} > /dev/null 2>&1

fi



#On R1D, the follow print to UART.
echo "==========dmesg:" >> $LOG_TMP_FILE_PATH
dmesg >> $LOG_TMP_FILE_PATH
sleep 1
echo "==========meminfo" >> $LOG_TMP_FILE_PATH
cat $LOG_MEMINFO >> $LOG_TMP_FILE_PATH

echo "==========topinfo" >> $LOG_TMP_FILE_PATH
top -b -n1 >> $LOG_TMP_FILE_PATH

#dump ppp and vpn status
log_exec "cat /tmp/pppoe.log"
log_exec "cat /tmp/vpn.stat.msg"
log_exec "ubus call turbo_ccgame get_pass"


iptables-save -c > $IPTABLES_SAVE

echo "    trafficd hw info:" > $TRAFFICD_LOG
ubus call trafficd hw '{"debug":true}' >> $TRAFFICD_LOG
echo "    trafficd ip info:" >> $TRAFFICD_LOG
ubus call trafficd ip '{"debug":true}' >> $TRAFFICD_LOG
echo "    tbus list:" >> $TRAFFICD_LOG
tbus list -v >> $TRAFFICD_LOG


# list enabled plugin's name
list_plugin /userdisk/appdata/app_infos $PLUGIN_LOG

list_messages_gz

MICLOUD_LOG_PATH="/userdisk/data/.pluginConfig/2882303761517344979/micloudBackup.log"

[ -f $MICLOUD_LOG_PATH ] && {
    FILE_SIZE=`ls -l $MICLOUD_LOG_PATH | awk '{print $5}'`
    [ $FILE_SIZE -lt 4194304 ] && {
        cp $MICLOUD_LOG_PATH $MICLOUD_LOG
    }
}

# busybox's tar requires every source file existing!!
[ -e "$IPTABLES_SAVE" ] || IPTABLES_SAVE=
[ -e "$TRAFFICD_LOG" ] || TRAFFICD_LOG=
[ -e "$PLUGIN_LOG" ] || PLUGIN_LOG=
[ -e "$NETWORK_STRIP" ] || NETWORK_STRIP=
[ -e "$MICLOUD_LOG" ] || MICLOUD_LOG=
[ -e "$NVRAM_FILE_PATH" ] || NVRAM_FILE_PATH=
[ -e "$BDATA_FILE_PATH" ] || BDATA_FILE_PATH=
move_files="$LOG_TMP_MEMINFO $LOG_TMP_FILE_PATH $IPTABLES_SAVE $TRAFFICD_LOG $PLUGIN_LOG $NETWORK_STRIP $WIRELESS_STRIP $MICLOUD_LOG $NVRAM_FILE_PATH $BDATA_FILE_PATH"
[ -e "$DHCP_LEASE" ] || DHCP_LEASE=
[ -e "$DNSMASQ_CONF" ] || DNSMASQ_CONF=
[ -e "$MACFILTER_FILE_PATH" ] || MACFILTER_FILE_PATH=
[ -e "$CRONTAB" ] || CRONTAB=
[ -e "$QOS_CONF" ] || QOS_CONF=
[ -e "$WIFISHARE_CONF" ] || WIFISHARE_CONF=
dup_files="$DHCP_LEASE $DNSMASQ_CONF $MACFILTER_FILE_PATH $CRONTAB $QOS_CONF $WIFISHARE_CONF"

[ -e "$LOGREAD_FILE_PATH" ] || LOGREAD_FILE_PATH=
[ -e "$LOGREAD0_FILE_PATH" ] || LOGREAD0_FILE_PATH=
[ -e "$PANIC_FILE_PATH" ] || PANIC_FILE_PATH=
[ -e "$LOG_WIFI_AYALYSIS" ] || LOG_WIFI_AYALYSIS=
[ -e "$LOG_WIFI_AYALYSIS0" ] || LOG_WIFI_AYALYSIS0=
[ -e "$GZ_LOGS" ] || GZ_LOGS=
[ -e "$LOG_DIR" ] || LOG_DIR=
[ -e "$TMP_WIFI_LOG" ] || TMP_WIFI_LOG=



if [ "$redundancy_mode" = "1" ]; then
    redundancy_files="$LOGREAD_FILE_PATH $LOGREAD0_FILE_PATH $PANIC_FILE_PATH $LOG_WIFI_AYALYSIS $LOG_WIFI_AYALYSIS0 $GZ_LOGS"
else
    redundancy_files="$LOG_DIR $PANIC_FILE_PATH $TMP_WIFI_LOG"
fi

[ "$hardware" = "R3600" ] && {
    redundancy_files="$redundancy_files "/tmp/log/" "/tmp/run/""

    for ff in lbd.conf resolv.conf; do
        conf_files="$conf_files `ls /tmp/$ff 2>/dev/null`"
    done

    dup_files="$dup_files $conf_files"
}

echo logfile=$LOG_ZIP_FILE_PATH
echo movefile=$move_files
echo dupfile=$dup_files
echo redfile=$redundancy_files

tar -zcf $LOG_ZIP_FILE_PATH $move_files $dup_files $redundancy_files
rm -f $move_files > /dev/null