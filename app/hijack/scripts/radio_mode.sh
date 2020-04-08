#!/system/bin/busybox sh

NETWORK_AUTO='AT^SYSCFGEX="00",3FFFFFFF,2,2,7fffffffffffffff,,'
NETWORK_GSM_ONLY='AT^SYSCFGEX="01",3FFFFFFF,2,2,7fffffffffffffff,,'
NETWORK_UMTS_ONLY='AT^SYSCFGEX="02",3FFFFFFF,2,2,7fffffffffffffff,,'
NETWORK_LTE_ONLY='AT^SYSCFGEX="03",3FFFFFFF,2,2,7fffffffffffffff,,'
NETWORK_LTE_UMTS='AT^SYSCFGEX="0302",3FFFFFFF,2,2,7fffffffffffffff,,'
NETWORK_LTE_GSM='AT^SYSCFGEX="0301",3FFFFFFF,2,2,7fffffffffffffff,,'
NETWORK_UMTS_GSM='AT^SYSCFGEX="0201",3FFFFFFF,2,2,7fffffffffffffff,,'

ATC="/system/xbin/atc"

print_item () {
    DESC="$1"
    MODE="$2"
    CURRENT_MODE="$3"
    SHOW_IF_NOT_SELECTED="$4"

    if [[ "$CURRENT_MODE" == "$MODE" ]]; then
        echo "item:<$DESC>:$MODE"
    else
        if [ "$SHOW_IF_NOT_SELECTED" -eq 1 ]; then
            echo "item: $DESC :$MODE"
        fi
    fi
}

if [ "$#" -eq 0 ]; then
    CURRENT_MODE="$($ATC 'AT^SYSCFGEX?' | grep 'SYSCFGEX' | sed 's/^[^"]*"\([^"]*\)".*/\1/')"
    echo "text:Pick the mode:"
    print_item "Auto" "00" "$CURRENT_MODE" 1
    print_item "4G" "03" "$CURRENT_MODE" 1
    print_item "3G" "02" "$CURRENT_MODE" 1
    print_item "2G" "01" "$CURRENT_MODE" 0
    print_item "4G or 3G" "0302" "$CURRENT_MODE" 1
    print_item "4G or 3G or 2G" "0301" "$CURRENT_MODE" 0
    print_item "3G or 2G" "0201" "$CURRENT_MODE" 0
fi

if [ "$#" -eq 1 ]; then
    case "$1" in
        00   ) $ATC "$NETWORK_AUTO";;
        01   ) $ATC "$NETWORK_GSM_ONLY";;
        02   ) $ATC "$NETWORK_UMTS_ONLY";;
        03   ) $ATC "$NETWORK_LTE_ONLY";;
        0302 ) $ATC "$NETWORK_LTE_UMTS";;
        0301 ) $ATC "$NETWORK_LTE_GSM";;
        0201 ) $ATC "$NETWORK_UMTS_GSM";;
        *) echo "text: wrong mode"; exit 1;; 
    esac

    if [ "$?" -eq 0 ]; then
        echo "text:Success"
    else
        echo "text:Failure code $?"
    fi
fi
