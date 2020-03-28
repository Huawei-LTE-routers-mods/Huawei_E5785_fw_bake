import cpio
import os

SYSTEM_FILES_RENAME = [

]

SYSTEM_FILES = [
    ("bin/busyboxx", 0, 0, 0o104775),
    ("bin/xtables-multi", 0, 0, 0o100775),
    ("xbin/atc", 0, 0, 0o100755),
    ("xbin/adbd", 0, 0, 0o100755),
    ("xbin/dropbear", 0, 0, 0o100755),
    ("xbin/sftp-server", 0, 0, 0o100755),
    ("xbin/scp", 0, 0, 0o100755),
    ("xbin/balong-nvtool", 0, 0, 0o100755),
    ("xbin/imei_generator", 0, 0, 0o100755),
    ("xbin/tinyproxy", 0, 0, 0o100755),
    ("etc/fix_ttl.sh", 0, 0, 0o100755),
    ("etc/fix_ttl", 0, 0, 0o100774),
    ("etc/disable_spe", 0, 0, 0o100774),
    ("etc/autorun.sh", 0, 0, 0o100500),
]

APP_FILES_RENAME = [
    ("bin/device", "bin/device.orig"),
    ("bin/oled", "bin/oled.orig"),
]

APP_FILES = [
    ("config/wifi/countryChannel.xml", 1000, 1000, 0o100775),
    ("bin/device", 1000, 1000, 0o100775),
    ("bin/oled", 1000, 1000, 0o100775),
    ("oled_hijack", 1000, 1000, 0o40755),
    ("oled_hijack/oled_hijack.so", 1000, 1000, 0o100775),
    ("oled_hijack/web_hook.so", 1000, 1000, 0o100775),
    ("oled_hijack/web_hook_client", 1000, 1000, 0o100775),
    ("oled_hijack/ttl_and_imei.sh", 1000, 1000, 0o100775),
    ("oled_hijack/no_battery_mode.sh", 1000, 1000, 0o100775),
    ("oled_hijack/radio_mode.sh", 1000, 1000, 0o100775),
    ("oled_hijack/user_scripts.sh", 1000, 1000, 0o100775),
    ("prometheus", 1000, 1000, 0o40755),
    ("prometheus/tinyproxy.conf", 1000, 1000, 0o100775),
    ("prometheus/start_exporter.sh", 1000, 1000, 0o100775),
    ("prometheus/httpd_root", 1000, 1000, 0o40755),
    ("prometheus/httpd_root/index.html", 1000, 1000, 0o40644),
    ("prometheus/httpd_root/cgi-bin", 1000, 1000, 0o40755),
    ("prometheus/httpd_root/cgi-bin/prometheus.cgi", 1000, 1000, 0o100775),

]


system = cpio.Cpio("System.bin")
os.chdir("system")

for file_from, file_to in SYSTEM_FILES_RENAME:
    system.rename_file(file_from, file_to)
for file, uid, gid, mode in SYSTEM_FILES:
    system.inject_fs_file(file, uid, gid, mode)

os.chdir("..")
system.write_chunks("System.mod.bin")

app = cpio.Cpio("APP.bin")
os.chdir("app")

for file_from, file_to in APP_FILES_RENAME:
    app.rename_file(file_from, file_to)
for file, uid, gid, mode in APP_FILES:
    app.inject_fs_file(file, uid, gid, mode)

os.chdir("..")
app.write_chunks("APP.mod.bin")
