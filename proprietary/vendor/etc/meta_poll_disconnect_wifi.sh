#! /system/bin/sh

rssi_disconnect_threshold=-60

log_file="/sdcard/mtklog/mw_disconnect.log"

LOG_INIT()
{
	rm  $log_file;
	echo "`date -u` log path=$log_file">$log_file;
	echo "===================================">>$log_file;
}

LOG()
{
	echo "`date -u`: $1" >>$log_file;
}

LOG_INIT;

LOG "rssi_disconnect_threshold=$rssi_disconnect_threshold";


STATUS=`/system/bin/wpa_cli -iwlan0 -p /data/misc/wifi/sockets status | grep 'wpa_state=COMPLETED'`
if [ -z "$STATUS" ]; then
	LOG "current status is disconnected already,exit(1).";
	exit 1
else
	LOG "start polling rssi to disconnect.";
	conn_rssi=`/system/bin/wpa_cli -iwlan0 -p /data/misc/wifi/sockets SIGNAL_POLL|grep 'RSSI'| grep -e '-[0-9]*' -o`
	LOG "current rssi is $conn_rssi";
	while [ "$conn_rssi" != "" ] && [ $conn_rssi -gt $rssi_disconnect_threshold ];do
		conn_rssi=`/system/bin/wpa_cli -iwlan0 -p /data/misc/wifi/sockets SIGNAL_POLL|grep 'RSSI'| grep -e '-[0-9]*' -o`
	done
	LOG "current rssi is $conn_rssi ,and it is time to disconnect.";

	LOG "disable network";
	/system/bin/wpa_cli -iwlan0 -p /data/misc/wifi/sockets disable_network 0

	networks=`/system/bin/wpa_cli -iwlan0 -p /data/misc/wifi/sockets LIST_NETWORKS`
  LOG "after disable networks,LIST_NETWORKS $networks";

	LOG "start polling disconected state.";
	STATUS=`/system/bin/wpa_cli -iwlan0 -p /data/misc/wifi/sockets status | grep 'wpa_state=COMPLETED'`
	LOG "STATUS = $STATUS";
	while [ "$STATUS" != "" ];do
	echo "STATUS = $STATUS"
	STATUS=`/system/bin/wpa_cli -iwlan0 -p /data/misc/wifi/sockets status | grep 'wpa_state=COMPLETED'`
	done

	LOG "supplicant disconnect done.";
	LOG "turn off driver";
	echo 0 > /dev/wmtWifi
	LOG "exit(0).";
	exit 0
fi

