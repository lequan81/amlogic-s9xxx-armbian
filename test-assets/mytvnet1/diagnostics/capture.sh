#!/usr/bin/env bash
set -u

BASE=/var/lib/mytvnet1-diag
USB=/mnt/mytv-diag
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_DIR="$BASE/$STAMP"
mkdir -p "$RUN_DIR" "$USB"
chmod 0755 "$BASE" "$RUN_DIR" "$USB"

for _ in $(seq 1 30); do
  if [ -b /dev/disk/by-label/MYTV_DIAG ]; then
    if ! mountpoint -q "$USB"; then
      mount -o rw,nosuid,nodev,noexec /dev/disk/by-label/MYTV_DIAG "$USB" || true
    fi
    break
  fi
  sleep 1
done

if mountpoint -q "$USB"; then
  mkdir -p "$USB/boots/$STAMP"
  OUT="$USB/boots/$STAMP/report.txt"
else
  OUT="$RUN_DIR/report.txt"
fi

{
  echo "MyTV Net 1 boot diagnostic"
  echo "UTC: $STAMP"
  echo
  echo "=== OS ==="
  cat /etc/os-release 2>&1 || true
  echo
  echo "=== Kernel / bootargs ==="
  uname -a 2>&1 || true
  cat /proc/cmdline 2>&1 || true
  printf "DT model: "
  tr '\000' ' ' </proc/device-tree/model 2>/dev/null || true
  echo
  printf "DT compatible: "
  tr '\000' ' ' </proc/device-tree/compatible 2>/dev/null || true
  echo
  echo "=== Block devices / mounts ==="
  lsblk -o NAME,TYPE,FSTYPE,LABEL,SIZE,MOUNTPOINTS 2>&1 || true
  findmnt 2>&1 || true
  echo
  echo "=== Network links / addresses / routes ==="
  ip -details -brief link 2>&1 || true
  ip -brief address 2>&1 || true
  ip route 2>&1 || true
  ip -6 route 2>&1 || true
  echo
  echo "=== Wi-Fi ==="
  rfkill list 2>&1 || true
  iw dev 2>&1 || true
  iw list 2>&1 || true
  echo
  echo "=== USB ==="
  lsusb 2>&1 || true
  lsusb -t 2>&1 || true
  echo
  echo "=== Modules ==="
  lsmod 2>&1 || true
  find "/lib/modules/$(uname -r)" -maxdepth 3 -type f 2>&1 | sort | head -n 400 || true
  echo
  echo "=== Kernel log ==="
  dmesg --color=never 2>&1 || true
  echo
  echo "=== Boot journal ==="
  journalctl -b --no-pager -o short-monotonic 2>&1 || true
  echo
  echo "=== Services ==="
  systemctl --failed --no-pager 2>&1 || true
  systemctl status mytvnet1-diag-ap mytvnet1-diag-ap-dhcp mytvnet1-diag-eth-dhcp mytvnet1-diag-web --no-pager 2>&1 || true
} >"$OUT" 2>&1

cp "$OUT" "$BASE/latest-report.txt"
if mountpoint -q "$USB"; then
  cp "$OUT" "$USB/latest-report.txt"
  sync
fi
logger -t mytvnet1-diag "Boot report written to $OUT"
