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
create_byedpi() {
    cp /app/hijack/scripts/Byedpi.sh /online/scripts/Byedpi.sh
    chmod 755 /online/scripts/Byedpi.sh
}
print_scripts() {
    for script in *.sh; do
        FIRST="$(echo -n "${script:0:1}" | sed 'y/abcdefghijklmnopqrstuvwxyz/ABCDEFGHIJKLMNOPQRSTUVWXYZ/')"
        REST="$(echo -n "${script:1}" | sed 's/_/ /g' | sed 's/.sh$//')"
        echo "item:${FIRST}${REST}:/online/scripts/$script"
    done
}

mkdir -p /online/scripts

# Install each bundled script on its own if it is missing, so scripts added in
# a newer firmware (e.g. Byedpi.sh) also show up for users who already have
# older scripts in /online/scripts. Existing (possibly user-edited) copies are
# left alone.
[ -f /online/scripts/example.sh ]  || create_example
[ -f /online/scripts/VPN.sh ]      || create_vpn
[ -f /online/scripts/pinger.sh ]   || create_pinger
[ -f /online/scripts/fix_cell.sh ] || create_fix_cell
[ -f /online/scripts/Byedpi.sh ]   || create_byedpi

# Older firmware shipped a VPN.sh that loads wireguard.ko, which this build no
# longer has. Replace that stale copy with the AmneziaWG version.
if grep -q "wireguard.ko" /online/scripts/VPN.sh 2>/dev/null; then
    create_vpn
fi

# Older Byedpi.sh copies have no "Start on boot" toggle or QUIC handling.
if ! grep -q "BOOT_ENABLE" /online/scripts/Byedpi.sh 2>/dev/null; then
    create_byedpi
fi

chmod 755 /online/scripts/*.sh 2>/dev/null

echo "text:In /online/scripts:"
cd /online/scripts && print_scripts
