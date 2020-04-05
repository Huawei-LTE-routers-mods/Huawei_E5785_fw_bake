import cpio
import os

ATTR_IS_FILE = 0o100000
ATTR_IS_DIR = 0o40000

SRC_SHOULD_EXIST = 1
SRC_CAN_ABSENT = 0

SYSTEM_FILES_RENAME = [

]

SYSTEM_FILES = [
    ("bin/busyboxx", 0, 0, ATTR_IS_FILE | 0o4775),
    ("bin/xtables-multi", 0, 0, ATTR_IS_FILE | 0o775),
    ("xbin/atc", 0, 0, ATTR_IS_FILE | 0o755),
    ("xbin/adbd", 0, 0, ATTR_IS_FILE | 0o755),
    ("xbin/dropbear", 0, 0, ATTR_IS_FILE | 0o755),
    ("xbin/sftp-server", 0, 0, ATTR_IS_FILE | 0o755),
    ("xbin/scp", 0, 0, ATTR_IS_FILE | 0o755),
    ("xbin/balong-nvtool", 0, 0, ATTR_IS_FILE | 0o755),
    ("xbin/imei_generator", 0, 0, ATTR_IS_FILE | 0o755),
    ("xbin/tinyproxy", 0, 0, ATTR_IS_FILE | 0o755),
    ("xbin/openvpn", 0, 0, ATTR_IS_FILE | 0o755),
    ("xbin/luarun", 0, 0, ATTR_IS_FILE | 0o755),
    ("xbin/wg", 0, 0, ATTR_IS_FILE | 0o755),
    ("modules", 0, 0, ATTR_IS_DIR | 0o755),
    ("modules/ip_tunnel.ko", 0, 0, ATTR_IS_FILE | 0o755),
    ("modules/wireguard.ko", 0, 0, ATTR_IS_FILE | 0o755),
    ("etc/fix_ttl", 0, 0, ATTR_IS_FILE | 0o774),
    ("etc/disable_spe", 0, 0, ATTR_IS_FILE | 0o774),
    ("etc/vpn_gen_configs.sh", 0, 0, ATTR_IS_FILE | 0o755),
    ("etc/autorun.sh", 0, 0, ATTR_IS_FILE | 0o500),
    ("etc/autorun.d", 0, 0, ATTR_IS_DIR | 0o755),
    ("etc/autorun.d/fix_ttl.sh", 0, 0, ATTR_IS_FILE | 0o755),
]

APP_FILES_RENAME = [
    ("bin/device", "bin/device.orig", SRC_SHOULD_EXIST),
    ("bin/oled", "bin/oled.orig", SRC_SHOULD_EXIST),
    ("bin/cms.real", "bin/cms", SRC_CAN_ABSENT),
    ("bin/cms", "bin/cms.orig", SRC_SHOULD_EXIST),
]

APP_FILES = [
    ("config/wifi/countryChannel.xml", 1000, 1000, ATTR_IS_FILE | 0o775),
    ("bin/device", 1000, 1000, ATTR_IS_FILE | 0o775),
    ("bin/oled", 1000, 1000, ATTR_IS_FILE | 0o775),
    ("bin/cms", 1000, 1000, ATTR_IS_FILE | 0o775),
    ("hijacks", 1000, 1000, ATTR_IS_DIR | 0o755),
    ("hijacks/bin", 1000, 1000, ATTR_IS_DIR | 0o755),
    ("hijacks/bin/web_hook_client", 1000, 1000, ATTR_IS_FILE | 0o775),
    ("hijacks/lib", 1000, 1000, ATTR_IS_DIR | 0o755),
    ("hijacks/lib/oled_hijack.so", 1000, 1000, ATTR_IS_FILE | 0o775),
    ("hijacks/lib/cms_hijack.so", 1000, 1000, ATTR_IS_FILE | 0o775),
    ("hijacks/lib/web_hook.so", 1000, 1000, ATTR_IS_FILE | 0o775),
    ("hijacks/scripts", 1000, 1000, ATTR_IS_DIR | 0o755),
    ("hijacks/scripts/ttl_and_imei.sh", 1000, 1000, ATTR_IS_FILE | 0o775),
    ("hijacks/scripts/no_battery_mode.sh", 1000, 1000, ATTR_IS_FILE | 0o775),
    ("hijacks/scripts/radio_mode.sh", 1000, 1000, ATTR_IS_FILE | 0o775),
    ("hijacks/scripts/user_scripts.sh", 1000, 1000, ATTR_IS_FILE | 0o775),
    ("hijacks/scripts/vpn.sh", 1000, 1000, ATTR_IS_FILE | 0o775),
    ("hijacks/scripts/example.sh", 1000, 1000, ATTR_IS_FILE | 0o775),
    ("prometheus", 1000, 1000, ATTR_IS_DIR | 0o755),
    ("prometheus/tinyproxy.conf", 1000, 1000, ATTR_IS_FILE | 0o775),
    ("prometheus/start_exporter.sh", 1000, 1000, ATTR_IS_FILE | 0o775),
    ("prometheus/httpd_root", 1000, 1000, ATTR_IS_DIR | 0o755),
    ("prometheus/httpd_root/index.html", 1000, 1000, ATTR_IS_FILE | 0o664),
    ("prometheus/httpd_root/cgi-bin", 1000, 1000, ATTR_IS_DIR | 0o755),
    ("prometheus/httpd_root/cgi-bin/prometheus.cgi", 1000, 1000, ATTR_IS_FILE | 0o775),

]


system = cpio.Cpio("System.bin")
os.chdir("system")

for file_from, file_to, src_should_exist in SYSTEM_FILES_RENAME:
    system.rename_file(file_from, file_to, src_should_exist)
for file, uid, gid, mode in SYSTEM_FILES:
    system.inject_fs_file(file, uid, gid, mode)

os.chdir("..")
system.write_chunks("System.mod.bin")

app = cpio.Cpio("APP.bin")
os.chdir("app")

for file_from, file_to, src_should_exist in APP_FILES_RENAME:
    app.rename_file(file_from, file_to, src_should_exist)
for file, uid, gid, mode in APP_FILES:
    app.inject_fs_file(file, uid, gid, mode)

os.chdir("..")
app.write_chunks("APP.mod.bin")
