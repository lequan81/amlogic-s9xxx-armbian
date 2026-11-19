#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
cp -a /tmp/overlay/. /
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
