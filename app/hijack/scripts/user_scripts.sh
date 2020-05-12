#!/bin/sh

create_example() {
    cp /app/hijack/scripts/example.sh /online/scripts/example.sh
    chmod 755 /online/scripts/example.sh
}

create_vpn() {
    cp /app/hijack/scripts/vpn.sh /online/scripts/VPN.sh
    chmod 755 /online/scripts/VPN.sh
}

create_pinger() {
    cp /app/hijack/scripts/pinger.sh /online/scripts/pinger.sh
    chmod 755 /online/scripts/pinger.sh
}

create_fix_cell() {
    cp /app/hijack/scripts/fix_cell.sh /online/scripts/fix_cell.sh
    chmod 755 /online/scripts/fix_cell.sh
}

print_scripts() {
    for script in *.sh; do
        FIRST="$(echo -n "${script:0:1}" | sed 'y/abcdefghijklmnopqrstuvwxyz/ABCDEFGHIJKLMNOPQRSTUVWXYZ/')"
        REST="$(echo -n "${script:1}" | sed 's/_/ /g' | sed 's/.sh$//')"
        echo "item:${FIRST}${REST}:/online/scripts/$script"
    done
}

mkdir -p /online/scripts
chmod 755 /online/scripts/*.sh

if [ $? -ne 0 ]; then
    if [ ! -f /online/scripts/example.sh ]; then
        create_example
    fi
    if [ ! -f /online/scripts/VPN.sh ]; then
        create_vpn
    fi
    if [ ! -f /online/scripts/pinger.sh ]; then
        create_pinger
    fi
    if [ ! -f /online/scripts/fix_cell.sh ]; then
        create_fix_cell
    fi

fi

echo "text:In /online/scripts:"
cd /online/scripts && print_scripts
