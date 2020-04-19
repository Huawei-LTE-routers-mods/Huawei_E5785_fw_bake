#!/bin/sh

ACTION="$1"

AUTORUN_FILE="/system/etc/autorun.d/ping.sh"
PINGER_UP_FILE="/var/pinger_up"

PINGER_ON_SCRIPT='#!/bin/sh

reconnect() {
    atc "AT+CFUN=0"
    while ! atc "AT+CFUN=1" | grep -i OK; do
        sleep 0.5
    done
}

loop() {
    if [ -f /var/pinger_up ]; then
        return
    else
        while ! echo "$$" > /var/pinger_up; do
            sleep 0.5
        done
    fi

    while [ -f /var/pinger_up ]; do
        oping -c 300 -i 0.2 -w 1 -Z 50 8.8.8.8 > /dev/null
        if [ $? -eq 1 ] ; then
            reconnect
        fi

        # reconnect if not 4g
        # if ! /app/hijack/bin/device_webhook_client device signal 1 1 | grep rsrp | grep -i dbm; then
        #  reconnect
        # fi
        sleep 5
    done
}

loop&
'

PINGER_OFF_SCRIPT="#!/bin/sh
rm "$PINGER_UP_FILE"
sleep 0.2
killall -9 oping
"

is_pinger_up() {
    test -f "$PINGER_UP_FILE"
}

is_pinger_on_boot() {
    test -f "$AUTORUN_FILE"
}

case "$ACTION" in
    "")
        echo "text:Pinger:"
        if is_pinger_up; then
            echo "item:<Enable>:PINGER_ENABLE"
            echo "item:Disable:PINGER_DISABLE"
        else
            echo "item:Enable:PINGER_ENABLE"
            echo "item:<Disable>:PINGER_DISABLE"
        fi

        echo "text:Start on boot"
        if is_pinger_on_boot; then
            echo "item:<Yes>:PINGER_ON_BOOT_ENABLE"
            echo "item: No:PINGER_ON_BOOT_DISABLE"
        else
            echo "item: Yes:PINGER_ON_BOOT_ENABLE"
            echo "item:<No>:PINGER_ON_BOOT_DISABLE"
        fi
    ;;
    PINGER_ENABLE)
        echo "$PINGER_ON_SCRIPT" | /bin/sh

        for i in 1 2 3 4 5; do
            if ! is_pinger_up; then
                sleep 0.5
            else
                echo "text: Success"
                exit 0
            fi
        done

        echo "text: Failed"
    ;;
    PINGER_DISABLE)
        echo "$PINGER_OFF_SCRIPT" | /bin/sh
        if is_pinger_up; then
            echo "text: Failed"
        else
            echo "text: Success"
        fi
    ;;
    PINGER_ON_BOOT_ENABLE)
        mount -o remount,rw /system
        mkdir -p /system/etc/autorun.d
        echo "$PINGER_ON_SCRIPT" > "$AUTORUN_FILE"
        chmod 755 "$AUTORUN_FILE"
        mount -o remount,ro /system

        if is_pinger_on_boot; then
            echo "text: Success"
        else
            echo "text: Failed"
        fi
    ;;
    PINGER_ON_BOOT_DISABLE)
        mount -o remount,rw /system
        rm "$AUTORUN_FILE"
        mount -o remount,ro /system

        if is_pinger_on_boot; then
            echo "text: Failed"
        else
            echo "text: Success"
        fi
    ;;
esac
