#!/bin/sh

ACTION="$1"

FILE="/online/ovpn.conf"
AUTORUN_FILE="/system/etc/autorun.d/ovpn.sh"

VPN_ON_SCRIPT="#!/bin/sh

if [ ! -f "${FILE}" ]; then
    echo No config
    exit 1
fi

openvpn --mktun --dev ovpn --dev-type tun
ip link set dev ovpn up
ip route add default dev ovpn table 29500
openvpn "${FILE}" &
"

VPN_OFF_SCRIPT="#!/bin/sh
killall -9 openvpn
ip link del dev ovpn
"

is_vpn_up() {
    ip route show default dev ovpn table 29500 | grep -q default
}

is_vpn_on_boot() {
    test -f /system/etc/autorun.d/ovpn.sh
}

case "$ACTION" in
    "")
        echo "text:OpenVPN:"
        if is_vpn_up; then
            echo "item:<Enable>:VPN_ENABLE"
            echo "item:Disable:VPN_DISABLE"
        else
            echo "item:Enable:VPN_ENABLE"
            echo "item:<Disable>:VPN_DISABLE"
        fi

        echo "text:Start on boot"
        if is_vpn_on_boot; then
            echo "item:<Yes>:VPN_ON_BOOT_ENABLE"
            echo "item: No:VPN_ON_BOOT_DISABLE"
        else
            echo "item: Yes:VPN_ON_BOOT_ENABLE"
            echo "item:<No>:VPN_ON_BOOT_DISABLE"
        fi
    ;;
    VPN_ENABLE)
        if [ ! -f "$FILE" ]; then
            echo "text:Config needed"
            echo "text: "
            echo "text:Use SSH and run"
            echo "text:openvpn_gen_configs.sh"
            echo "text:in the /etc/ dir"
            exit 0
        fi
        echo "$VPN_ON_SCRIPT" | /bin/sh
        if is_vpn_up; then
            echo "text: Success"
        else
            echo "text: Failed"
        fi
    ;;
    VPN_DISABLE)
        echo "$VPN_OFF_SCRIPT" | /bin/sh
        if is_vpn_up; then
            echo "text: Failed"
        else
            echo "text: Success"
        fi
    ;;
    VPN_ON_BOOT_ENABLE)
        mount -o remount,rw /system
        mkdir -p /system/etc/autorun.d
        echo "$VPN_ON_SCRIPT" > "$AUTORUN_FILE"
        chmod 755 "$AUTORUN_FILE"
        mount -o remount,ro /system

        if is_vpn_on_boot; then
            echo "text: Success"
        else
            echo "text: Failed"
        fi
    ;;
    VPN_ON_BOOT_DISABLE)
        mount -o remount,rw /system
        rm "$AUTORUN_FILE"
        mount -o remount,ro /system

        if is_vpn_on_boot; then
            echo "text: Failed"
        else
            echo "text: Success"
        fi
    ;;
esac
