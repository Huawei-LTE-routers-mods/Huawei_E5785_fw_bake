#!/bin/sh

ACTION="$1"

get_fixed_cell_pci () {
    PCI1="$(balong-nvtool -d 53810 | grep 00000000 | cut -d' ' -f 10)"
    PCI2="$(balong-nvtool -d 53810 | grep 00000000 | cut -d' ' -f 11)"
    
    echo "$((16#$PCI2 * 256 + 16#$PCI1))"
}


case "$ACTION" in
    "")
        FIXED_PCI="$(get_fixed_cell_pci)"
        PCI="$(atc 'AT^CECELLID?' | grep 'CECELLID' | cut -d, -f3)"
        BAND="$(atc 'AT^HFREQINFO?'| grep 'HFREQINFO'| cut -d, -f3)"
        DLFREQ="$(atc 'AT^HFREQINFO?'| grep 'HFREQINFO'| cut -d, -f5)"
        
        echo "text:Fix current cell:"
        if [[ "$FIXED_PCI" -ne 0 ]] ; then
            echo "item:<Fix cell $PCI>:FIX_CELL $PCI $BAND $DLFREQ"
            echo "item: Unfix cell $FIXED_PCI:UNFIX_CELL"
        else
            echo "item: Fix cell $PCI:FIX_CELL $PCI $BAND $DLFREQ"
            echo "item: <Unfix>:UNFIX_CELL"
        fi
        echo "text: "
        if [[ "$DLFREQ" -gt 0 ]] then
            busyboxx printf "text:Current cell: %d, B%d, %d.%dMhz" $PCI $BAND "$(($DLFREQ / 10))" "$(( $DLFREQ % 10))"
        else
            echo "text:Current cell is unknown"
        fi
    ;;
    FIX_CELL)
        PCI="$2"
        BAND="$3"
        DLFREQ="$4"
        
        if [ -z "$PCI" -o -z "$BAND" -o -z "$DLFREQ" ]; then
            echo "text: Status: failed"
            echo "text: "
            echo "text:Not enough current cell info"
            exit 0
        fi
        
        PARAMS="$(busyboxx printf 53810:03:00:00:00:%02x:01:%02x:01:%02x:%02x:%02x:%02x:00:00:00:00 "$BAND" "$BAND" "$((PCI%256))" "$((PCI/256))" "$((DLFREQ%256))" "$((DLFREQ/256))")"
        balong-nvtool -m "$PARAMS"
        
        FIXED_PCI="$(get_fixed_cell_pci)"
        
        if [[ "$FIXED_PCI" -eq "$PCI" ]]; then
            echo "text: Success"
            echo "text: Reboot is needed"
        else
            echo "current: $FIXED_PCI"
            echo "text: Failed"        
        fi
    ;;
    UNFIX_CELL)
        PARAMS="53810:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00"
        balong-nvtool -m "$PARAMS"
        
        FIXED_PCI="$(get_fixed_cell_pci)"
        
        if [[ "$FIXED_PCI" -eq "0" ]]; then
            echo "text: Success"
            echo "text: Reboot is needed"
        else
            echo "text: Failed"        
        fi
    ;;
esac
