# MyTV Net 1 Armbian source build

For boot testing, run `Cook MyTV Net 1 image variants` from `main`. It produces
three artifacts: baseline, custom-kernel, and diagnostics. Set `base_image_url`
to a known-good full Armbian image with two partitions. The cooker now requires
the reference GPT layout: BOOT starts at LBA 32768 and ROOTFS at LBA 1081344,
with 512-byte sectors. A one-partition source-build image is rejected as a base.

The separate `Build MyTV Net 1 from Armbian source` workflow builds a full
Armbian image and is useful for source-build experiments. The source-build
artifact we inspected had one `rootfs` partition. Do not use that artifact as
the base for the three SD boot tests; use the cooker with a known-good
two-partition Armbian image instead.

The workflow takes the board DTS and `rockchip_linux_defconfig` from the
selected kernel ref. It applies the FD655 GPIO patch in
`userpatches/kernel/mytvnet1-vendor-6.1/`; that patch aligns the DT node with
the tested C driver's GPIO4_A3/A2 lines. It uses the Armbian `rock-2f` RK3528
build recipe, then writes the verified MyTV Net 1 `idbloader.img` and
`u-boot.itb` into the raw image at LBA 64 and LBA 16384 before compression.

Download the three `Armbian-MyTV-Net1-{baseline,custom-kernel,diagnostics}`
artifacts from the cooker run. Each artifact includes a compressed full-disk
image, checksums, partition/loader build information, and flash instructions.
The diagnostics artifact also contains Wi-Fi credentials and USB instructions.
Flash the selected image to a removable SD card. The diagnostic USB is separate:
format it FAT32 with volume label `MYTV_DIAG`; optional direct-Ethernet DHCP is
enabled by placing an empty `ENABLE_ETH_DHCP` file on it.

## Keep the eMMC boot environment intact

The SD cooker never writes to eMMC and does not copy eMMC bytes into the SD
image. Leave the box's eMMC unchanged while testing SD boot. Community reports
for some RK3528 TV boxes describe an early U-Boot environment stored in the
first 10 MiB of eMMC. A separate P52/MyTV Net 1 report describes factory
firmware replacing built-in U-Boot and affecting older Armbian loader images.
These reports make a read-only backup useful, but the X88 Pro 13 report does
not prove the identical boot path on every MyTV revision. See the
[X88 Pro 13 discussion](https://forum.armbian.com/topic/37232-rupa-x88-pro-13-rk3528-board-with-images/page/2/)
and [P52/MyTV Net 1 report](https://github.com/ophub/amlogic-s9xxx-armbian/issues/3782).
Do not flash an eMMC first-10-MiB dump over the SD image: it contains
eMMC-specific data and can replace the SD image's GPT.

From the running system, first confirm `/dev/mmcblk1` is the eMMC and mount the
diagnostic USB. Read-only capture commands for the eMMC first 10 MiB, IDB,
U-Boot FIT, and hardware boot partitions should write only to that USB.

The source workflow builds the OS image and kernel through Armbian's build
framework. The final boot chain uses the verified prebuilt Rockchip loader pair
because those files contain the MyTV DDR V1.05 training code.
