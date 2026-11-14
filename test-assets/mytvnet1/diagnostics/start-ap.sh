#!/usr/bin/env bash
set -u

IFACE=wlan0
if ! command -v iw >/dev/null 2>&1 || ! command -v hostapd >/dev/null 2>&1; then
  logger -t mytvnet1-diag "Wi-Fi AP unavailable: iw/hostapd missing"
  exit 0
fi

rfkill unblock wifi 2>/dev/null || true
if ! iw dev "$IFACE" info >/dev/null 2>&1; then
  logger -t mytvnet1-diag "Wi-Fi AP unavailable: $IFACE not present"
  exit 0
fi
if ! iw list 2>/dev/null | grep -Eq '^[[:space:]]*\* AP([[:space:]]|$)'; then
  logger -t mytvnet1-diag "Wi-Fi AP unavailable: driver does not advertise AP mode"
  exit 0
fi

if command -v nmcli >/dev/null 2>&1; then
  nmcli device set "$IFACE" managed no 2>/dev/null || true
fi
ip link set "$IFACE" down 2>/dev/null || true
ip address flush dev "$IFACE" 2>/dev/null || true
ip address add 192.168.77.1/24 dev "$IFACE" || exit 1
ip link set "$IFACE" up || exit 1
logger -t mytvnet1-diag "Starting diagnostic Wi-Fi AP on $IFACE (192.168.77.1)"
exec /usr/sbin/hostapd /etc/hostapd/mytvnet1-diag.conf
