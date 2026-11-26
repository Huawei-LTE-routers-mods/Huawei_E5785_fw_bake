# Huawei_E5785_fw_bake

Custom, automated firmware baker for the Huawei E5785 router.

This repository contains the automated GitHub Actions build system that takes the original Huawei firmware, injects custom partitions (System, APP, and WebUI), and generates a fully modified, flash-ready firmware image.

## ⚠️ Important compatibility warning

This firmware is **ONLY** for the **E5785Lh-92a (Zain Unlocked)** variant.
Do NOT flash this on any other hardware revision or locked model. Flashing the wrong firmware will permanently brick your device.

## ✨ Custom modifications included

- 🚀 **AmneziaWG 3.1 (kernel module)** – WireGuard with traffic obfuscation, so the VPN is harder for DPI to detect and block. Use the **VPN** item in the device's script menu.
- 🛡️ **ByeDPI** – DPI bypass for HTTP/HTTPS traffic from LAN clients. Turn it on from the **Byedpi** item in the script menu, with an optional **Start on boot** toggle. While it runs, QUIC (UDP 443) is blocked so browsers fall back to TCP and go through ByeDPI.
- 🎨 **Modified WebUI** – A custom user interface for better control, monitoring, and management.
- ❌ **Standard WireGuard removed** to make way for AmneziaWG.

### Setting up the AmneziaWG VPN

1. SSH into the router and run `/etc/vpn_gen_configs.sh <your_server_ip>`.
2. The router config is written to `/online/vpn.conf`. The script also prints the matching server config and the commands to set it up on an Ubuntu 22.04/24.04 server.
3. On the device, open **VPN → Enable** (and optionally **Start on boot → Yes**).

The obfuscation values (`S1`, `S2`, `H1`–`H4`) must be identical on the router and the server. The generator handles that for you.

## 📥 How to build and download the firmware (no coding required)

GitHub Actions builds the firmware for you.

1. Open the **Actions** tab at the top of this repository.
2. In the left sidebar, click **Bake E5785 Firmware**.
3. Click **Run workflow**, choose the base firmware from the dropdown, and click the green **Run workflow** button.
4. Wait for the workflow to finish (a few minutes).

Each run produces two variants:

- `_zlib.bin` – compressed partitions (smaller file, recommended)
- `_nozlib.bin` – uncompressed partitions (larger file)

Download them from either:

- **Releases** – the release named after the base firmware version, on the right side of the main page.
- **Artifacts** – open the completed workflow run and scroll to the bottom.
