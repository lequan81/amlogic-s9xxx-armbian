#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
rsync -a --no-owner --no-group /tmp/overlay/ /
apt-get update
apt-get install -y --no-install-recommends \
        dnsmasq hostapd iproute2 iw python3 rfkill usbutils wireless-regdb
apt-get clean
rm -rf /var/lib/apt/lists/*

systemctl --root=/ --no-reload disable hostapd.service dnsmasq.service 2>/dev/null || true
systemctl --root=/ --no-reload enable \
        mytvnet1-diag-capture.service \
        mytvnet1-diag-ap.service \
        mytvnet1-diag-ap-dhcp.service \
        mytvnet1-diag-eth-dhcp.service \
        mytvnet1-diag-web.service \
        mytvnet1-diag-final.service \
        mytvnet1-panel-progress.service

install -d -m 0755 /var/lib/mytvnet1-diag /mnt/mytv-diag /run/mytvnet1-diag

# Shift DTB (131 MiB) and initrd (162 MiB) load addresses within the first 256 MiB
# Works on both 2 GiB and 4 GiB RAM boards and persists across apt upgrades.
if [ -f /boot/armbianEnv.txt ]; then
    sed -i '/^\(kernel_addr_r\|fdt_addr_r\|ramdisk_addr_r\|fdt_high\|initrd_high\)=/d' /boot/armbianEnv.txt
    cat <<'EOF' >> /boot/armbianEnv.txt
kernel_addr_r=0x00400000
fdt_addr_r=0x08300000
ramdisk_addr_r=0x0a200000
fdt_high=0xffffffffffffffff
initrd_high=0xffffffffffffffff
EOF
fi

# Hold custom kernel/DTB packages so apt upgrade keeps HS200 eMMC, AIC8800, and FD6551 support
for pkg in $(dpkg-query -W -f='${Package}\n' 'linux-image-*' 'linux-dtb-*' 'linux-headers-*' 2>/dev/null); do
  apt-mark hold "$pkg"
done
