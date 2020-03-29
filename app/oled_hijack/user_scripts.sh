#!/bin/sh

create_example() {
    cp /app/oled_hijack/example.sh /online/scripts/example.sh
    chmod 755 /online/scripts/example.sh
}

create_vpn() {
    cp /app/oled_hijack/VPN.sh /online/scripts/VPN.sh
    chmod 755 /online/scripts/VPN.sh
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

fi

echo "text:In /online/scripts:"
cd /online/scripts && print_scripts
