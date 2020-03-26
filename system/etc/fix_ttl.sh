#!/system/bin/busybox sh

ttl=`cat /system/etc/fix_ttl`

if [ 0$ttl -ne 0 ]; then
  (xtables-multi iptables -t mangle -C OUTPUT -o eth_x -j TTL --ttl-set 128 || 
   xtables-multi iptables -t mangle -A OUTPUT -o eth_x -j TTL --ttl-set 128)
  
  (xtables-multi ip6tables -t mangle -C OUTPUT -o eth_x -j HL --hl-set 128 ||
   xtables-multi ip6tables -t mangle -A OUTPUT -o eth_x -j HL --hl-set 128)

  (xtables-multi iptables -t mangle -C POSTROUTING -o eth_x -j TTL --ttl-set 128 ||
   xtables-multi iptables -t mangle -A POSTROUTING -o eth_x -j TTL --ttl-set 128)

  (xtables-multi ip6tables -t mangle -C POSTROUTING -o eth_x -j HL --hl-set 128 ||
   xtables-multi ip6tables -t mangle -A POSTROUTING -o eth_x -j HL --hl-set 128)

  (xtables-multi iptables -t mangle -С PREROUTING -i eth_x -m ttl --ttl 1 -j TTL --ttl-inc 4 ||
   xtables-multi iptables -t mangle -A PREROUTING -i eth_x -m ttl --ttl 1 -j TTL --ttl-inc 4)

  (xtables-multi ip6tables -t mangle -C PREROUTING -i eth_x -m hl --hl-eq 1 -j HL --hl-inc 4 ||
   xtables-multi ip6tables -t mangle -A PREROUTING -i eth_x -m hl --hl-eq 1 -j HL --hl-inc 4)
else
  xtables-multi iptables -t mangle -D OUTPUT -o eth_x -j TTL --ttl-set 128
  xtables-multi ip6tables -t mangle -D OUTPUT -o eth_x -j HL --hl-set 128
  xtables-multi iptables -t mangle -D POSTROUTING -o eth_x -j TTL --ttl-set 128
  xtables-multi ip6tables -t mangle -D POSTROUTING -o eth_x -j HL --hl-set 128
  xtables-multi iptables -t mangle -D PREROUTING -i eth_x -m ttl --ttl 1 -j TTL --ttl-inc 4
  xtables-multi ip6tables -t mangle -D PREROUTING -i eth_x -m hl --hl-eq 1 -j HL --hl-inc 4
fi

disable_spe=`cat /system/etc/disable_spe`

cp /app/bin/cms.real /sbin/cms

if [ 0$disable_spe -ne 0 ]; then
  echo "type=switch switch=off action=set" > /sys/devices/spe_cmd/spe_cmd
  echo -n "off" | dd of=/sbin/cms bs=1 seek=$((0x130A6C)) conv=notrunc 2> /dev/null
else
  echo "type=switch switch=on action=set" > /sys/devices/spe_cmd/spe_cmd
  echo -n "on " | dd of=/sbin/cms bs=1 seek=$((0x130A6C)) conv=notrunc 2> /dev/null
fi
