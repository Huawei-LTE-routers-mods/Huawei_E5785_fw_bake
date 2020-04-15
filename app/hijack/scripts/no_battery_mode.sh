#!/system/bin/busybox sh

NVTOOL="/system/xbin/balong-nvtool"

if [ "$#" -eq 0 ]; then
    echo "text:Battery:"

    PRODUCT="$(cat /proc/productname)"
    case "$PRODUCT" in
        E5885*)
            echo "text: Not detachable"
            exit 0
            ;;
    esac

    if $NVTOOL -d 50364 | grep -q '00 00 00 00'; then
        echo "item:<Enable>:enable"
        echo "item: Disable:disable"
    else
        echo "item: Enable:enable"
        echo "item:<Disable>:disable"
    fi
fi

if [ "$#" -eq 1 ]; then
    case "$1" in
        enable )
            if $NVTOOL -m 50364:00:00:00:00 | grep -q отредактирована; then
                echo "text:Battery enabled"
                echo "text:Insert and reboot"
            else
                echo "text:Error"
            fi
            ;;
        disable )
            if $NVTOOL -m 50364:01:00:00:00 | grep -q отредактирована; then
                echo "text:Battery disabled"
                echo "text:Remove and reboot"
            else
                echo "text:Error"
            fi
            ;;
        * )
            echo "text: wrong command mode"
            exit 1;;
    esac
fi
