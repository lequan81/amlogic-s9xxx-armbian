# MyTV Net 1 diagnostic image

## Prepare the diagnostic USB

Use the spare USB stick, format it as FAT32, and set its volume label to exactly:

`MYTV_DIAG`

Do not put passwords or other private files on this stick. The diagnostic service writes one report per boot under `boots/` and also refreshes `latest-report.txt`. The full report contains kernel logs, device addresses, interface names, and hardware identifiers.

Connect this USB together with the Armbian test image. Keep the box powered for about two minutes.

## Connect over Wi-Fi

The image starts a WPA2 diagnostic access point when the Wi-Fi driver supports AP mode:

- SSID: `MyTVNet1-Diag`
- Password: see `DIAGNOSTIC-ACCESS.txt` in the same Actions artifact as the image
- Status page: `http://192.168.77.1:8080`
- Full report: `http://192.168.77.1:8080/report.txt`

The access point is a local diagnostic network and does not provide Internet access. If the Wi-Fi driver or firmware fails, the report on the USB should show that.

## Optional direct Ethernet connection

This mode runs a DHCP server on the box Ethernet port. It is disabled unless you enable it on the diagnostic USB.

1. On the USB labeled `MYTV_DIAG`, create an empty file named `ENABLE_ETH_DHCP`.
2. Disconnect the box Ethernet cable from the home router.
3. Connect the box Ethernet port directly to the laptop and reboot the box.
4. Let the laptop obtain an address automatically, then open `http://192.168.88.1:8080`.

If the Linux interface is not named `eth0`, put `IFACE=interface-name` in the marker file instead of leaving it empty. Do not enable this mode while the box is connected to a router or shared LAN, because it intentionally serves DHCP on the selected Ethernet interface.

## What gets logged

The report captures the boot arguments, kernel and device-tree identity, USB tree, loaded modules, Wi-Fi capabilities, IP links and routes, dmesg, boot journal, and diagnostic service status. It is copied to the USB when that device is mounted; otherwise it remains under `/var/lib/mytvnet1-diag/` and is available from the web page if a diagnostic interface starts.
