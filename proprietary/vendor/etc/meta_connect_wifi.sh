#! /system/bin/sh

rssi_threshold=-40
meta_ssid="SoftAP"
static_ip="181.157.137.137"
router_ap_ip="181.157.137.1"
scan_para="TYPE=ONLY"
conn_para=""
# 2437-channel 6

log_file="/sdcard/mtklog/mw_connect.log"

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

LOG "meta_ssid=$meta_ssid";
LOG "static_ip=$static_ip";
LOG "router_ap_ip=$router_ap_ip";
LOG "scan_para=$scan_para";
LOG "conn_para=$conn_para";

LOG "power on driver";
echo 1 > /dev/wmtWifi
sleep 3

LOG "start supplicant";
/system/bin/wpa_supplicant -iwlan0 -dd -Dnl80211 -c /vendor/etc/meta_wpa_supplicant.conf &
LOG "start supplicant ret=$?(`ps|grep wpa_supplicant`)";

/system/bin/wpa_supplicant -iwlan0 -Dnl80211 -c /system/etc/wifi/meta_wpa_supplicant.conf &

LOG "polling wpa_supplicant on";

STATUS=`/system/bin/wpa_cli -iwlan0 -p /data/misc/wifi/sockets status | grep 'wpa_state'`
while [ -z "$STATUS" ];do
	STATUS=`/system/bin/wpa_cli -iwlan0 -p /data/misc/wifi/sockets status | grep 'wpa_state'`
done
LOG "STATUS=$STATUS";

LOG "disable network";
/system/bin/wpa_cli -iwlan0 -p /data/misc/wifi/sockets disable_network 0

LOG "start polling rssi to connect";

LOG "start check 1.";
rssi=-99
while [ $rssi -lt $rssi_threshold ] || [ "$rssi" -eq "" ] ;do
	/system/bin/wpa_cli -iwlan0 -p /data/misc/wifi/sockets scan "$scan_para"
	rssi_list=`/system/bin/wpa_cli -iwlan0 -p /data/misc/wifi/sockets scan_result|grep "$meta_ssid"| grep -e '-[0-9]*' -o`

	echo "$meta_ssid :rssi_list = $rssi_list"
	let max_rssi=-200;

	echo "find max rssi"
	for i in $rssi_list
	do
	echo "i = $i"
	if [ $i -gt $max_rssi ] && [ "$i" -ne "" ]
	then
	let max_rssi=i;
	fi
	done

	echo "max rssi is $max_rssi"

	if [ $max_rssi -ne -200 ]
	then
	let rssi=max_rssi;
	else
	let rssi=-99;
	fi

	echo "rssi is $rssi"
done

LOG "start check 2.";
rssi=-99
while [ $rssi -lt $rssi_threshold ] || [ "$rssi" -eq "" ] ;do
	/system/bin/wpa_cli -iwlan0 -p /data/misc/wifi/sockets scan "$scan_para"
	rssi_list=`/system/bin/wpa_cli -iwlan0 -p /data/misc/wifi/sockets scan_result|grep "$meta_ssid"| grep -e '-[0-9]*' -o`

	echo "$meta_ssid :rssi_list = $rssi_list"
	let max_rssi=-200;

	echo "find max rssi"
	for i in $rssi_list
	do
	echo "i = $i"
	if [ $i -gt $max_rssi ] && [ "$i" -ne "" ]
	then
	let max_rssi=i;
	fi
	done

	echo "max rssi is $max_rssi"

	if [ $max_rssi -ne -200 ]
	then
	let rssi=max_rssi;
	else
	let rssi=-99;
	fi

	echo "rssi is $rssi"
done

LOG "rssi_list = $rssi_list ";
LOG "rssi = $rssi now, we can enable network";
/system/bin/wpa_cli -iwlan0 -p /data/misc/wifi/sockets enable_network 0
#after android N, setlect_network is required.
/system/bin/wpa_cli -iwlan0 -p /data/misc/wifi/sockets select_network 0
/system/bin/wpa_cli -iwlan0 -p /data/misc/wifi/sockets scan "$conn_para"

networks=`/system/bin/wpa_cli -iwlan0 -p /data/misc/wifi/sockets LIST_NETWORKS`
LOG "networks = $networks";

STATUS=`/system/bin/wpa_cli -iwlan0 -p /data/misc/wifi/sockets status | grep 'wpa_state=COMPLETED'`
LOG "before connect $STATUS";
while [ -z "$STATUS" ];do
	/system/bin/wpa_cli -iwlan0 -p /data/misc/wifi/sockets scan "$conn_para"
	STATUS=`/system/bin/wpa_cli -iwlan0 -p /data/misc/wifi/sockets status | grep 'wpa_state=COMPLETED'`
	echo "STATUS = $STATUS"
done
LOG "after connect $STATUS";

if [ -z "$STATUS" ]; then
	LOG "associated network failed.";
	exit 1
else
	LOG "associated network successfully.";
fi

LOG "before set ip address $static_ip.";
ifconfig wlan0 "$static_ip" netmask 255.255.255.0
i=0;
IP=`ifconfig wlan0| grep $static_ip`
while [  -z "$IP" ] && [ "$i" != "10" ];do
	echo "try grep  $i"
	IP=`ifconfig wlan0| grep $static_ip`
	i=$(($i+1))
done
LOG "set ip ok($i), get ip info from ifconfig wlan0 $IP";

LOG "ping 2 times to update ARP list.";
ping -c 1 "$router_ap_ip"&
ping -c 1 "$static_ip"&

if [ -z "$IP" ] ; then
	LOG "connect to $meta_ssid fail. exit(1).";
	exit 1
else
	LOG "connect to $meta_ssid ok.exit(0).";
	exit 0
fi
