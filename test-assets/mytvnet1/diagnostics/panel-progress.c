#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define CLK_PIN 131 /* Known-working MyTV panel GPIO4_A3 */
#define DAT_PIN 130 /* Known-working MyTV panel GPIO4_A2 */
#define MODE_ADDR 0x48
#define ICON_ADDR 0x66
static const uint8_t DIGIT_ADDRS[4] = {0x68, 0x6A, 0x6C, 0x6E};
static const uint8_t DIGIT_MAP[10] =
    {0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F};
#define ICON_COLON 0x10
#define ICON_LAN   0x20
#define ICON_WIFI  0x40
#define ICON_USB   0x02

static int fd_clk = -1, fd_dat = -1;
static volatile sig_atomic_t running = 1;

static void stop_handler(int sig) { (void)sig; running = 0; }

static void write_text(const char *path, const char *value)
{
    int fd = open(path, O_WRONLY | O_CLOEXEC);
    if (fd >= 0) {
        (void)write(fd, value, strlen(value));
        close(fd);
    }
}

static int gpio_open(int pin)
{
    char path[96], value[16];
    snprintf(path, sizeof(path), "/sys/class/gpio/gpio%d", pin);
    if (access(path, F_OK) != 0) {
        snprintf(value, sizeof(value), "%d", pin);
        write_text("/sys/class/gpio/export", value);
        for (int i = 0; i < 100 && access(path, F_OK) != 0; ++i)
            usleep(1000);
    }
    snprintf(path, sizeof(path), "/sys/class/gpio/gpio%d/direction", pin);
    write_text(path, "out");
    snprintf(path, sizeof(path), "/sys/class/gpio/gpio%d/value", pin);
    int fd = open(path, O_WRONLY | O_CLOEXEC);
    if (fd < 0)
        fprintf(stderr, "GPIO %d unavailable: %s\n", pin, strerror(errno));
    return fd;
}

static inline void half_delay(void)
{
    for (volatile int i = 0; i < 40; ++i)
        __asm__ volatile("nop");
}

static inline void gpio_set(int fd, int value)
{
    if (fd >= 0)
        (void)pwrite(fd, value ? "1" : "0", 1, 0);
}
static inline void clk(int v) { gpio_set(fd_clk, v); }
static inline void dat(int v) { gpio_set(fd_dat, v); }

static void bus_start(void)
{
    dat(1); clk(1); half_delay();
    dat(0); half_delay();
    clk(0); half_delay();
}

static void bus_stop(void)
{
    dat(0); clk(0); half_delay();
    clk(1); half_delay();
    dat(1); half_delay();
}

static void write_byte(uint8_t value)
{
    for (int bit = 7; bit >= 0; --bit) {
        dat((value >> bit) & 1);
        half_delay(); clk(1); half_delay(); clk(0); half_delay();
    }
    dat(1); half_delay(); clk(1); half_delay(); clk(0); half_delay();
}

static void write_reg(uint8_t reg, uint8_t value)
{
    bus_start(); write_byte(reg); write_byte(value); bus_stop();
}

static void show_stage(int stage, uint8_t icons)
{
    uint8_t digits[4] = {DIGIT_MAP[0], DIGIT_MAP[0], DIGIT_MAP[0],
                         DIGIT_MAP[stage % 10]};
    for (int i = 0; i < 4; ++i)
        write_reg(DIGIT_ADDRS[i], digits[i]);
    write_reg(ICON_ADDR, icons);
}

static bool file_exists(const char *path) { return access(path, F_OK) == 0; }

static bool carrier_up(const char *iface)
{
    char path[128], value = '0';
    snprintf(path, sizeof(path), "/sys/class/net/%s/carrier", iface);
    int fd = open(path, O_RDONLY | O_CLOEXEC);
    if (fd < 0) return false;
    (void)read(fd, &value, 1);
    close(fd);
    return value == '1';
}

static bool has_external_usb(void)
{
    return file_exists("/sys/bus/usb/devices/3-1/idVendor") ||
           file_exists("/sys/bus/usb/devices/1-1/idVendor") ||
           file_exists("/sys/bus/usb/devices/2-1/idVendor");
}

static int current_stage(uint8_t *icons)
{
    int stage = 1; /* panel service has started */
    bool wifi = file_exists("/run/mytvnet1-diag/wifi-ap-ready");
    bool eth = file_exists("/run/mytvnet1-diag/eth-dhcp-ready");
    bool lan_link = carrier_up("end0") || carrier_up("eth0");
    bool wifi_link = carrier_up("wlan0");

    if (file_exists("/run/mytvnet1-diag/report-ready"))
        stage = 2; /* diagnostic capture completed */
    if (wifi || eth || lan_link || wifi_link)
        stage = 3; /* network/AP or physical link is present */
    if (stage >= 3 && file_exists("/run/sshd.pid"))
        stage = 4; /* SSH daemon is running on a networked system */

    *icons = 0;
    if (wifi || wifi_link) *icons |= ICON_WIFI;
    if (eth || lan_link) *icons |= ICON_LAN;
    if (has_external_usb()) *icons |= ICON_USB;
    return stage;
}

int main(void)
{
    if (geteuid() != 0) return 1;
    struct sigaction sa = {0};
    sa.sa_handler = stop_handler;
    sigaction(SIGTERM, &sa, NULL);
    sigaction(SIGINT, &sa, NULL);

    fd_clk = gpio_open(CLK_PIN);
    fd_dat = gpio_open(DAT_PIN);
    if (fd_clk < 0 || fd_dat < 0) {
        if (fd_clk >= 0) close(fd_clk);
        if (fd_dat >= 0) close(fd_dat);
        return 2;
    }

    clk(0); dat(1);
    write_reg(MODE_ADDR, 0x01);
    write_reg(MODE_ADDR, 0x03);
    usleep(20000);

    int previous_stage = -1;
    uint8_t previous_icons = 0xff;
    while (running) {
        uint8_t icons = 0;
        int stage = current_stage(&icons);
        if (stage != previous_stage || icons != previous_icons) {
            show_stage(stage, icons);
            previous_stage = stage;
            previous_icons = icons;
        } else {
            /* Blink colon as a heartbeat, proving the panel service is alive. */
            static bool colon = false;
            colon = !colon;
            write_reg(ICON_ADDR, icons | (colon ? ICON_COLON : 0));
        }
        sleep(1);
    }

    for (int i = 0; i < 4; ++i) write_reg(DIGIT_ADDRS[i], 0);
    write_reg(ICON_ADDR, 0);
    close(fd_clk); close(fd_dat);
    return 0;
}
