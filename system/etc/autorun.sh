#!/system/bin/busyboxx sh

mkdir bin
ln -s /system/bin/sh /bin/sh

busybox echo 0 > /proc/sys/net/netfilter/nf_conntrack_checksum

temp=$(cat /sys/class/power_supply/battery/temp)
if [ $temp -eq -30 ]; then
	echo -ne '\x00\x00\x82\xe5' | dd of=/dev/mem bs=1 seek=2797765824
fi

mkdir /dev/net && busyboxx mknod /dev/net/tun c 10 200
mkdir -p /data/userdata/ussd
chown 1000:1000 /data/userdata/ussd

g_bAtDataLocked=`grep -w -m1 "g_bAtDataLocked" /proc/kallsyms`
addr=0x${g_bAtDataLocked:0:8}
dd if=/dev/zero of=/dev/kmem bs=1 seek=$((addr)) count=4

for FILE in /etc/autorun.d/*.sh; do
    /bin/sh "$FILE"
done

/etc/huawei_process_start

mv /sbin/adbd /sbin/adbd~

#busyboxx telnetd -l /bin/sh
#adbd &

mkdir -p /data/dropbear
dropbear -R

/app/prometheus/start_exporter.sh
