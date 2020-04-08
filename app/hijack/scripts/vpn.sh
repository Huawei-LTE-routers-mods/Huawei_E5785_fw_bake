#!/bin/sh

ACTION="$1"

FILE="/online/vpn.conf"
AUTORUN_FILE="/system/etc/autorun.d/vpn.sh"

VPN_ON_SCRIPT="#!/bin/sh

if [ ! -f "${FILE}" ]; then
    echo No config
    exit 1
fi

insmod /system/modules/ip_tunnel.ko 2>/dev/null
insmod /system/modules/wireguard.ko 2>/dev/null

ip link add dev wg0 type wireguard
wg setconf wg0 "${FILE}"
ip link set dev wg0 up
ip route add default dev wg0 table 29500
"

VPN_OFF_SCRIPT="#!/bin/sh
ip link del dev wg0
"

is_vpn_up() {
    ip route show default dev wg0 table 29500 | grep -q default
}

is_vpn_on_boot() {
    test -f /system/etc/autorun.d/vpn.sh
}

case "$ACTION" in
    "")
        echo "text:WireGuard VPN:"
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
            echo "text: Config needed"
            echo "text: "
            echo "text: Use SSH and run"
            echo "item: vpn_gen_configs.sh:PRINT_SSH_WARNING"
            echo "text: in the /etc/ dir"
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
    PRINT_SSH_WARNING)
        echo "text: Yes, with SSH"
        echo "text: Not from here"
    ;;
esac
