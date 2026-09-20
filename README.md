# pico-8-nano-2w

A PICO-8 console image for the Raspberry Pi Zero 2 W. Power on, PICO-8 comes
up fullscreen. No desktop, no login prompt, no shell.

> **Status: never booted on real hardware.** Everything here is verified by
> inspecting the built image. Treat the first boot as a test and bring a USB
> serial adapter — there is no console on the device, so a black screen tells
> you nothing on its own.

## PICO-8 is not included

PICO-8 is commercial software from Lexaloffle. It cannot be redistributed, so
it is not in this repository and not in the image. Buy it at
[lexaloffle.com/pico-8.php](https://www.lexaloffle.com/pico-8.php) and drop
your own copy onto the SD card.

That constraint is also the design: because the build needs nothing
proprietary, the image itself is freely redistributable.

## Quick start

Grab `sdcard.img` from the [latest release](../../releases), or build it
yourself (see below), then:

1. Write it to a card — Raspberry Pi Imager, "Use custom".
2. Re-insert the card. A **PICO8BOOT** volume appears.
3. Copy the `pico-8` folder out of your `pico-8_<version>_raspi.zip` onto it.
   Any version works; nothing is pinned. It must contain `pico8_dyn` — the
   64-bit `pico8_64` will not run on this 32-bit userland.
4. Edit `wifi.txt` on the same volume:

   ```
   ssid=MyNetwork
   psk=mypassword
   country=SE
   ```

   `country=` is required. Without a regulatory domain the radio does not know
   which channels are legal where you are and will not transmit.
5. Optionally edit `pico8.txt` on the same volume and set `mode=splore` to
   boot into Splore (the cartridge browser) instead of the command prompt.
6. Optionally copy your SSH public key there as `authorized_keys`.
7. Boot with HDMI and a USB keyboard.

Full detail, including serial console setup, is in [docs/flashing.md](docs/flashing.md).

## Building

Buildroot does not run on macOS, so the build happens in a Linux container.
Everything it extracts lives in a Docker volume, never on the macOS
filesystem — see [docs/build-environment.md](docs/build-environment.md) for
why that matters.

```sh
git clone --recursive git@github.com:billyohgren/pico-8-nano-2w.git
cd pico-8-nano-2w
./scripts/br setup
./scripts/br defconfig
./scripts/br build        # first run takes a while
./scripts/br image        # -> output/sdcard.img
```

The build needs nothing from Lexaloffle.

## What it is

- Buildroot 2026.02.3, pinned as an unmodified submodule
- Linux 6.12, 32-bit armhf, glibc — the ABI Lexaloffle's binary expects
- SDL2 on KMSDRM with Mesa vc4. No X11, no Wayland, no framebuffer
- Two partitions: FAT boot (firmware, kernel, **initramfs**), writable `/data`.
  The OS runs from RAM; there is no root partition on the card
- PICO-8 under a respawning supervisor; no getty on any tty
- Wi-Fi provisioned from a text file on the FAT partition, brought up in the
  background so it can never delay PICO-8 starting

The OS lives in a ramdisk, so a power cut cannot corrupt it. Only `/data` is
ever written. PICO-8's saves and carts live there rather than on the boot
partition — a power cut mid-write to `/boot` would stop the device booting
at all, not merely lose a save.

Boot time is discussed in [docs/boot.md](docs/boot.md): the ramdisk removes
`rootwait`, and init no longer waits for Wi-Fi or `ssh-keygen` before
PICO-8. The closed GPU firmware is still most of a 3 s budget.

## Known gaps

- No mDNS, so `pico8.local` does not resolve. Find the IP on your router.
- `/data` is a fixed 128 MB and does not grow to fill the card.
- Dropping carts into a folder on the FAT partition does not import them yet.
  Use `scp` to `/data/pico-8/carts/`.

## Credits

This is **not** written from scratch.

- **[Buildroot](https://buildroot.org)** does the actual work. It is vendored
  as an unmodified submodule, and parts of this tree are derived from it —
  `configs/pico8_rpi_zero2w_defconfig` began as upstream's
  `raspberrypizero2w_defconfig`, and `board/pico8/rpi-zero2w/post-image.sh`
  is modelled on upstream's `board/raspberrypi/post-image.sh`, sharing its
  genimage invocation and boot-file-list generation.

- **[gamaral/rpi-buildroot](https://github.com/gamaral/rpi-buildroot)** and
  the PICOPi work built on it by
  [itsonlym3](https://github.com/itsonlym3/rpi-buildroot/tree/picopi) showed
  that this was worth doing at all, and the idea of shipping an image with no
  PICO-8 in it and letting the user drop their own onto the boot partition is
  theirs. No code was taken from either — PICOPi targets the original Pi Zero
  on a 2017-era Buildroot and a 4.9 kernel, neither of which supports the
  Zero 2 W — but the shape of the thing is inherited.

## Licence

GPL-2.0-or-later, following Buildroot, from which several files here are
derived.

This covers the build system in this repository. It does not cover the images
it produces, and it emphatically does not cover PICO-8, which is Lexaloffle's
and is never distributed here.
