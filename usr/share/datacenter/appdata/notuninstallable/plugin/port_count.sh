#!/bin/sh
set port1=0;
set port2=0;

while true
do
cat /proc/mt7621/esw_cnt > /tmp/mt7621
all_rx=`cat /tmp/mt7621 | grep GDMA2_RX_GBCNT | awk '{print $4}'`
port1_rx=`cat /tmp/mt7621 | grep 'Rx Unicast Packet' | awk '{printf("%d",('$all_rx'*$7/($7+$8)))}'`
port2_rx=`cat /tmp/mt7621 | grep 'Rx Unicast Packet' | awk '{printf("%d",('$all_rx'*$8/($7+$8)))}'`
port1_p_rx=`cat /tmp/mt7621 | grep 'Rx Unicast Packet' | awk '{print $7}'`
port2_p_rx=`cat /tmp/mt7621 | grep 'Rx Unicast Packet' | awk '{print $8}'`
all_tx=`cat /tmp/mt7621 | grep GDMA2_TX_GBCNT | awk '{print $4}'`
port1_tx=`cat /tmp/mt7621 | grep 'Tx Unicast Packet' | awk '{printf("%d",('$all_tx'*$7/($7+$8)))}`
port2_tx=`cat /tmp/mt7621 | grep 'Tx Unicast Packet' | awk '{printf("%d",('$all_tx'*$8/($7+$8)))}`
port1_p_tx=`cat /tmp/mt7621 | grep 'Tx Unicast Packet' | awk '{print $7}'`
port2_p_tx=`cat /tmp/mt7621 | grep 'Tx Unicast Packet' | awk '{print $8}'`
if [ "port1_p_rx" == "0" ]; then
	port1_add_rx=0
else
	port1_add_rx=$port1_rx	
fi
if [ "port2_p_rx" == "0" ]; then
	port2_add_rx=0
else
	port2_add_rx=$port2_rx	
fi
if [ "port2_p_tx" == "0" ]; then
	port2_add_tx=0
else
	port2_add_tx=$port2_tx	
fi
	
if [ "port1_p_tx" == "0" ]; then
	port1_add_tx=0
else
	port1_add_tx=$port1_tx	
fi

port1_u_now=`cat /tmp/port_count | grep up | awk '{printf("%d",'$port1_add_rx'+$2)}'`
port2_u_now=`cat /tmp/port_count | grep up | awk '{printf("%d",'$port2_add_rx'+$3)}'`
port1_d_now=`cat /tmp/port_count | grep down | awk '{printf("%d",'$port1_add_tx'+$2)}'`
port2_d_now=`cat /tmp/port_count | grep down | awk '{printf("%d",'$port2_add_tx'+$3)}'`

echo "up $port1_u_now $port2_u_now" > /tmp/port_count
echo "down $port1_d_now $port2_d_now" >> /tmp/port_count
sleep 1
done
