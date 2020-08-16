#!/system/bin/busybox sh

ATC="/system/xbin/atc"
IMEI_GENERATOR="/system/xbin/imei_generator"
IMEI_SAVE_FILE="/root/imei/saved_factory_imei.txt"
IMEI_RE="^[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]"

change_imei () {
    local IMEI="$1"

    PRODUCT="$(cat /proc/productname)"
    case "$PRODUCT" in
        E5885*)
            $ATC "AT^CIMEI=\"$IMEI\"" | grep OK
        ;;
        *)
            $ATC "AT^PHYNUM=IMEI,$IMEI" | grep OK
        ;;
    esac
}

if [ "$#" -eq 0 ]; then
    echo "text:Fix TTL:"

    TTL="$(cat /etc/fix_ttl)"

    if [ "$TTL" -eq 0 ]; then
        echo "item: Yes:TTL_FIX64"
        echo "item:<No>:TTL_NO_FIX"
    else
        echo "item:<Yes>:TTL_FIX64"
        echo "item: No:TTL_NO_FIX"
    fi

    echo "pagebreak:"
    echo "text:Random IMEI:"

    IMEI="$($ATC 'AT+CGSN' | grep -o "$IMEI_RE")"

    if [ "$?" -ne 0 ]; then
        # chould not happen
        echo "text: failed to get IMEI"
        echo "item: OK"
        exit 0
    fi

    FACTORY_IMEI="$(cat $IMEI_SAVE_FILE 2>/dev/null | grep -o "$IMEI_RE")"

    if [ -z "$FACTORY_IMEI" -o "$IMEI" = "$FACTORY_IMEI" ]; then
        echo "item: Yes:IMEI_SET_RANDOM"
        echo "item:<No>:IMEI_SET_FACTORY"
    else
        echo "item:<Yes>:IMEI_SET_RANDOM"
        echo "item:No:IMEI_SET_FACTORY"
    fi

    echo "text:"
    echo "text:IMEI:"
    echo "text: $IMEI"
fi

if [ "$#" -eq 1 ]; then
    case "$1" in
        TTL_NO_FIX )
            mount -o remount,rw /system
            echo 0 > /etc/fix_ttl
            echo 0 > /etc/disable_spe
            mount -o remount,ro /system

            /etc/autorun.d/fix_ttl.sh

            if xtables-multi iptables -t mangle -C OUTPUT -o eth_x -j TTL --ttl-set 64; then
                echo "text:Failed"
            else
                echo "text:Success"
            fi
            ;;
        TTL_FIX64 )
            mount -o remount,rw /system
            echo 64 > /etc/fix_ttl
            echo 1 > /etc/disable_spe
            mount -o remount,ro /system

            /etc/autorun.d/fix_ttl.sh

            if xtables-multi iptables -t mangle -C OUTPUT -o eth_x -j TTL --ttl-set 64; then
                echo "text:Success"
            else
                echo "text:Failed"
            fi
            ;;
        IMEI_SET_FACTORY )
            FACTORY_IMEI="$(cat $IMEI_SAVE_FILE | grep -o "$IMEI_RE")"
            if [ -z "$FACTORY_IMEI" ]; then
                echo "text: failed"
                echo "text: no saved IMEI file"
                exit 0
            fi

            change_imei "$FACTORY_IMEI"

            if [ $? -eq 0 ]; then
                echo "text: Success, new IMEI:"
                echo "text: $FACTORY_IMEI"
                echo "text: "
                echo "text: Reboot is needed"
            else
                echo "text: Failed"
            fi
            ;;
        IMEI_SET_RANDOM )
            if [ ! -f $IMEI_SAVE_FILE ]; then
                IMEI="$($ATC 'AT+CGSN' | grep -o "$IMEI_RE")"

                if [ "$?" -ne 0 ]; then
                    # chould not happen
                    echo "text: failed to get IMEI"
                    exit 0
                fi

                mkdir -p /root/imei
                echo "$IMEI" > $IMEI_SAVE_FILE

                if [ "$?" -ne 0 ]; then
                    # chould not happen
                    echo "text: failed to save IMEI"
                    exit 0
                fi
            fi

            case $((RANDOM % 16)) in
                0) IMEI_TAC=35425510 ;; 1) IMEI_TAC=35247110 ;;
                2) IMEI_TAC=35849009 ;; 3) IMEI_TAC=35340210 ;;
                4) IMEI_TAC=35910609 ;; 5) IMEI_TAC=35798609 ;;
                6) IMEI_TAC=35680809 ;; 7) IMEI_TAC=35921909 ;;
                8) IMEI_TAC=35333710 ;; 9) IMEI_TAC=35280210 ;;
                10) IMEI_TAC=35223510 ;; 11) IMEI_TAC=35463510 ;;
                12) IMEI_TAC=35620509 ;; 13) IMEI_TAC=35750709 ;;
                14) IMEI_TAC=35924309 ;; 15) IMEI_TAC=35621609 ;;
            esac

            NEW_IMEI="$($IMEI_GENERATOR -m "$IMEI_TAC" | grep -o "$IMEI_RE")"
            if [ "$?" -ne 0 ]; then
                # chould not happen
                echo "text: failed to generate new IMEI"
                exit 0
            fi

            change_imei "$NEW_IMEI"

            if [ $? -eq 0 ]; then
                echo "text: Success, new IMEI:"
                echo "text: $NEW_IMEI"
                echo "text: "
                echo "text: Reboot is needed"
            else
                echo "text: Failed"
            fi
            ;;

        * )
            echo "text: wrong command mode"
            exit 1
            ;;
    esac
fi
