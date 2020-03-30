#!/bin/sh

ttl="$(cat /system/etc/fix_ttl)"

if [ 0$ttl -ne 0 ]; then
  (xtables-multi iptables -t mangle -C OUTPUT -o eth_x -j TTL --ttl-set 64 || 
   xtables-multi iptables -t mangle -A OUTPUT -o eth_x -j TTL --ttl-set 64)
  
  (xtables-multi iptables -t mangle -C POSTROUTING -o eth_x -j TTL --ttl-set 64 ||
   xtables-multi iptables -t mangle -A POSTROUTING -o eth_x -j TTL --ttl-set 64)
  
  (xtables-multi ip6tables -t mangle -C OUTPUT -o eth_x -j HL --hl-set 64 ||
   xtables-multi ip6tables -t mangle -A OUTPUT -o eth_x -j HL --hl-set 64)

  (xtables-multi ip6tables -t mangle -C POSTROUTING -o eth_x -j HL --hl-set 64 ||
   xtables-multi ip6tables -t mangle -A POSTROUTING -o eth_x -j HL --hl-set 64)

else
  xtables-multi iptables -t mangle -D OUTPUT -o eth_x -j TTL --ttl-set 64
  xtables-multi iptables -t mangle -D POSTROUTING -o eth_x -j TTL --ttl-set 64
  xtables-multi ip6tables -t mangle -D OUTPUT -o eth_x -j HL --hl-set 64
  xtables-multi ip6tables -t mangle -D POSTROUTING -o eth_x -j HL --hl-set 64
fi

disable_spe="$(cat /system/etc/disable_spe)"

if [ 0$disable_spe -ne 0 ]; then
  echo "type=switch switch=off action=set" > /sys/devices/spe_cmd/spe_cmd
else
  echo "type=switch switch=on action=set" > /sys/devices/spe_cmd/spe_cmd
fi
