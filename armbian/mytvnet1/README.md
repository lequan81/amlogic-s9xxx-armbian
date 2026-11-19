# MyTV Net 1 Armbian source build

Run the `Build MyTV Net 1 from Armbian source` workflow from the `main` branch.
The default inputs select `dev-mytv-net1` from the RK3528 kernel fork and a
Debian Trixie root filesystem. One workflow run builds the kernel, DTB, rootfs,
diagnostic services, and complete SD card image.

The workflow takes the board DTS and `rockchip_linux_defconfig` from the
selected kernel ref. It applies the FD655 GPIO patch in
`userpatches/kernel/mytvnet1-vendor-6.1/`; that patch aligns the DT node with
the tested C driver's GPIO4_A3/A2 lines. It uses the Armbian `rock-2f` RK3528
build recipe, then writes the verified MyTV Net 1 `idbloader.img` and
`u-boot.itb` into the raw image at LBA 64 and LBA 16384 before compression.

Download `Armbian-MyTV-Net1-source-build` from the workflow run. It contains
the compressed image, checksums, build information, diagnostic Wi-Fi
credentials, and the diagnostic USB instructions. Format the spare USB as
FAT32 with volume label `MYTV_DIAG`, flash the image to the SD card, then boot
the box with both USB devices connected. The optional direct-Ethernet DHCP
mode is enabled by placing an empty `ENABLE_ETH_DHCP` file on that USB.

This builds the OS image and kernel from source through Armbian's build
framework. The final boot chain still uses the verified prebuilt Rockchip
loader pair because those files contain the MyTV DDR V1.05 training code.
