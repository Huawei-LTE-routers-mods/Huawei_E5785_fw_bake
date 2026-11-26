#!/bin/sh
#
# Generate a matching AmneziaWG client (this router) + server config pair.
#
# AmneziaWG = WireGuard + traffic obfuscation. The S1, S2 and H1-H4 values
# MUST be identical on both sides; Jc/Jmin/Jmax only affect the sender but we
# use the same values on both ends for simplicity.

SERVER="$1"
PORT=40000

if [ -z "$SERVER" ]; then
    echo "Usage:   ./vpn_gen_configs.sh <your_vpn_server_ip>"
    echo "Example: ./vpn_gen_configs.sh 1.2.3.4"
    exit 1
fi

umask 077

if [ -f /online/vpn.conf ]; then
    echo "Please delete /online/vpn.conf first"
    exit 1
fi

if ! command -v awg >/dev/null 2>&1; then
    echo "awg tool not found (expected /system/xbin/awg)"
    exit 1
fi

# Random unsigned 32-bit integer.
rand_u32() {
    r="$(od -An -N4 -tu4 /dev/urandom 2>/dev/null | tr -d ' \n')"
    if [ -z "$r" ]; then
        r="$(awk -v s="$$$(date +%s)" 'BEGIN { srand(s); printf "%u", int(rand() * 4294967295) }')"
    fi
    echo "$r"
}

# Random unsigned 16-bit integer (keeps shell arithmetic far from overflow
# even if busybox was built with 32-bit signed math).
rand_u16() {
    r="$(od -An -N2 -tu2 /dev/urandom 2>/dev/null | tr -d ' \n')"
    if [ -z "$r" ]; then
        r="$(awk -v s="$$$(date +%s)" 'BEGIN { srand(s); printf "%u", int(rand() * 65535) }')"
    fi
    echo "$r"
}

# Random integer in [min, max] (max - min must be < 65536).
rand_range() {
    echo $(( $(rand_u16) % ($2 - $1 + 1) + $1 ))
}

# Magic header value: must be > 4 (1-4 are the stock WireGuard message types).
rand_header() {
    h=0
    while [ "$h" -le 4 ]; do
        h="$(rand_u32)"
    done
    echo "$h"
}

JC="$(rand_range 4 12)"
JMIN="$(rand_range 8 64)"
JMAX="$(rand_range 80 1000)"
S1="$(rand_range 15 150)"
S2="$(rand_range 15 150)"
# A junk-padded init packet must not end up the same size as a response.
while [ $((S1 + 56)) -eq "$S2" ]; do
    S2="$(rand_range 15 150)"
done

# H1-H4 must all be different from each other.
H1="$(rand_header)"
H2="$H1"; while [ "$H2" = "$H1" ]; do H2="$(rand_header)"; done
H3="$H1"; while [ "$H3" = "$H1" ] || [ "$H3" = "$H2" ]; do H3="$(rand_header)"; done
H4="$H1"; while [ "$H4" = "$H1" ] || [ "$H4" = "$H2" ] || [ "$H4" = "$H3" ]; do H4="$(rand_header)"; done

OBFS="Jc = ${JC}
Jmin = ${JMIN}
Jmax = ${JMAX}
S1 = ${S1}
S2 = ${S2}
H1 = ${H1}
H2 = ${H2}
H3 = ${H3}
H4 = ${H4}"

CLIENT_PRIVATE_KEY="$(awg genkey)"
SERVER_PRIVATE_KEY="$(awg genkey)"

CLIENT_PUBLIC_KEY="$(echo "$CLIENT_PRIVATE_KEY" | awg pubkey)"
SERVER_PUBLIC_KEY="$(echo "$SERVER_PRIVATE_KEY" | awg pubkey)"

echo "[Interface]
PrivateKey = ${CLIENT_PRIVATE_KEY}
${OBFS}
[Peer]
PublicKey = ${SERVER_PUBLIC_KEY}
Endpoint = ${SERVER}:${PORT}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
" > /online/vpn.conf

echo "Client config is written to /online/vpn.conf"
echo ""

SERVER_CONF="[Interface]
PrivateKey = ${SERVER_PRIVATE_KEY}
ListenPort = ${PORT}
${OBFS}
[Peer]
PublicKey = ${CLIENT_PUBLIC_KEY}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
"

echo "Server setup example (Ubuntu 22.04 / 24.04, AmneziaWG kernel module):"
echo "add-apt-repository -y ppa:amnezia/ppa"
echo "apt update && apt install -y amneziawg"
echo ""
echo "umask 077"
echo "echo \"${SERVER_CONF}\" > /root/vpn.conf"
echo ""
echo "ip link add dev awg0 type amneziawg"
echo "awg setconf awg0 /root/vpn.conf"
echo "ip link set up dev awg0"
echo "ip route replace 192.168.8.0/24 dev awg0"
echo ""
echo "echo 1 > /proc/sys/net/ipv4/ip_forward"
echo "iptables -t nat -A POSTROUTING -s 192.168.8.0/24 -j MASQUERADE"
