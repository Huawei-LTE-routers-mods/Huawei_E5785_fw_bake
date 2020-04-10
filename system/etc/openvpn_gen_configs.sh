#!/bin/sh

SERVER="$1"
PORT=30000

if [ -z "$SERVER" ]; then
    echo "Usage:   ./openvpn_gen_configs.sh <your_vpn_server_ip>"
    echo "Example: ./openvpn_gen_configs.sh 1.2.3.4"
    echo ""
    echo "Important: It is recommended to use WireGuard insted of OpenVPN because it is four time faster"
    exit 1
fi

umask 077

if [ -f /online/ovpn.conf ]; then
    echo "Please delete /online/ovpn.conf first"
    exit 1
fi

openvpn --genkey --secret /tmp/key
KEY="$(cat /tmp/key)"
rm /tmp/key


echo "mode p2p
dev ovpn
dev-type tun
remote ${SERVER} $PORT
keepalive 10 30
nobind
verb 3

tun-mtu 1500
fragment 1300
mssfix

<secret>
${KEY}
</secret>
" > /online/ovpn.conf

echo "Client config is written to /online/ovpn.conf"
echo ""

SERVER_CONF="mode p2p
port ${PORT}
dev ovpn
dev-type tun
ping-timer-rem
persist-tun
persist-key

txqueuelen 1000
tun-mtu 1500
fragment 1300
mssfix

<secret>
${KEY}
</secret>
"

echo "Server setup example (for Ubuntu 18.04):"
echo "apt update && apt install openvpn"
echo ""
echo "umask 077"
echo ""
echo "echo \"${SERVER_CONF}\" > /etc/openvpn/server/ovpn.conf"
echo ""
echo "systemctl start openvpn-server@ovpn"
echo "ip link set up dev ovpn"
echo "ip route replace 192.168.8.0/24 dev ovpn"
echo ""
echo "echo 1 > /proc/sys/net/ipv4/ip_forward"
echo "iptables -t nat -A POSTROUTING -s 192.168.8.0/24 -j MASQUERADE"

if [ ! -f /online/scripts/OpenVPN.sh ]; then
    mkdir -p /online/scripts
    cp /app/hijack/scripts/openvpn.sh /online/scripts/OpenVPN.sh
fi
