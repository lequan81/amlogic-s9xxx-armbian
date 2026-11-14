#!/usr/bin/env bash
set -euo pipefail

RUNDIR=/run/mytvnet1-diag
MARKER="$RUNDIR/ENABLE_ETH_DHCP"
if [ ! -f "$MARKER" ]; then
  logger -t mytvnet1-diag "Ethernet DHCP disabled; create ENABLE_ETH_DHCP on MYTV_DIAG USB to enable direct-cable mode"
  exit 0
fi

IFACE=eth0
if grep -q '^IFACE=' "$MARKER"; then
  IFACE="$(sed -n 's/^IFACE=//p' "$MARKER" | tail -n 1)"
elif [ -s "$MARKER" ]; then
  IFACE="$(head -n 1 "$MARKER" | tr -d '\r\n')"
fi
[[ "$IFACE" =~ ^[A-Za-z0-9_.:-]+$ ]] || { echo "Invalid Ethernet interface name" >&2; exit 1; }
[ -e "/sys/class/net/$IFACE" ] || { echo "Interface $IFACE not found" >&2; exit 1; }

ip address flush dev "$IFACE"
ip address add 192.168.88.1/24 dev "$IFACE"
ip link set "$IFACE" up
logger -t mytvnet1-diag "Ethernet direct-cable DHCP enabled on $IFACE (192.168.88.1)"
mkdir -p "$RUNDIR"
trap 'rm -f "$RUNDIR/eth-dhcp-ready"' EXIT
/usr/sbin/dnsmasq --keep-in-foreground --conf-file=/etc/mytvnet1-diag/dnsmasq-eth.conf --interface="$IFACE" &
dnsmasq_pid=$!
sleep 2
if ! kill -0 "$dnsmasq_pid" 2>/dev/null; then
  wait "$dnsmasq_pid"
  exit 1
fi
touch "$RUNDIR/eth-dhcp-ready"
wait "$dnsmasq_pid"
