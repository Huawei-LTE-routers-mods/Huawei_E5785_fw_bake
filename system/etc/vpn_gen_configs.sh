#!/bin/sh

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

CLIENT_PRIVATE_KEY="$(wg genkey)"
SERVER_PRIVATE_KEY="$(wg genkey)"

CLIENT_PUBLIC_KEY="$(echo "$CLIENT_PRIVATE_KEY" | wg pubkey)"
SERVER_PUBLIC_KEY="$(echo "$SERVER_PRIVATE_KEY" | wg pubkey)"

echo "[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
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
[Peer]
PublicKey = ${CLIENT_PUBLIC_KEY}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
"

echo "Server setup example (for Ubuntu 18.04):"
echo "add-apt-repository ppa:wireguard/wireguard"
echo "apt update && apt install wireguard"
echo ""
echo "umask 077"
echo "echo \"${SERVER_CONF}\" > /root/vpn.conf"
echo ""
echo "ip link add dev wg0 type wireguard"
echo "wg setconf wg0 /root/vpn.conf"
echo "ip link set up dev wg0"
echo "ip route replace 192.168.8.0/24 dev wg0"
echo ""
echo "echo 1 > /proc/sys/net/ipv4/ip_forward"
echo "iptables -t nat -A POSTROUTING -s 192.168.8.0/24 -j MASQUERADE"
