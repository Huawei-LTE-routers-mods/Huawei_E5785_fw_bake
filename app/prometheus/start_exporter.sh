#!/system/bin/busybox sh

if [ -f /system/bin/busyboxx ]; then
    busyboxx httpd -p 127.0.0.1:9112 -h /app/prometheus/httpd_root
else
    busybox httpd -p 127.0.0.1:9112 -h /app/prometheus/httpd_root
fi

/system/xbin/tinyproxy -c /app/prometheus/tinyproxy.conf
