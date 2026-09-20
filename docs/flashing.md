# Putting the image on a card

## What you need

- A microSD card (any size — the image is under 100 MB)
- Your own `pico-8_<version>_raspi.zip` from your Lexaloffle account
- A Raspberry Pi Zero 2 W, HDMI cable and a USB keyboard
- **Strongly recommended for the first boot:** a USB-to-serial adapter on
  GPIO 14/15. See "If nothing appears" below — there is no console on this
  image, so serial is the only way to see what went wrong.

## 1. Build and export the image

```sh
./scripts/br build
./scripts/br image        # -> output/sdcard.img
```

The build needs nothing from Lexaloffle. PICO-8 is not in the image.

## 2. Write it to the card

Easiest is Raspberry Pi Imager: choose "Use custom", pick
`output/sdcard.img`, select your card, write.

From the terminal on macOS:

```sh
diskutil list                                    # find your card, e.g. /dev/disk4
diskutil unmountDisk /dev/disk4
sudo dd if=output/sdcard.img of=/dev/rdisk4 bs=4m
diskutil eject /dev/disk4
```

Two macOS details: use `/dev/rdisk4` rather than `/dev/disk4` — the raw device
is far faster — and press **Ctrl-T** for progress, because BSD `dd` has no
`status=progress`. Check the disk number carefully; `dd` to the wrong one
destroys it.

## 3. Add PICO-8

Take the card out and plug it back in. A volume called **PICO8BOOT** appears —
this is the FAT boot partition, and it is the only one macOS and Windows can
read.

Open your `pico-8_<version>_raspi.zip` and copy the whole **`pico-8` folder**
onto PICO8BOOT, so you end up with:

```
PICO8BOOT/
├── pico-8/           <- the folder you just copied
│   ├── pico8_dyn
│   ├── pico8.dat
│   └── ...
├── config.txt
├── pico8.txt
├── rootfs.cpio.gz    <- the OS (ramdisk)
├── wifi.txt
├── zImage
└── ...
```

Any PICO-8 version works. Nothing is pinned: the launcher looks for
`pico8_dyn` by name, so upgrading later means replacing this folder.

It must be `pico8_dyn`, the dynamically linked build — it uses the SDL2 in the
image, which is built with the KMSDRM backend. `pico8_64` is 64-bit and will
not run here; the launcher will tell you so if that is all it finds.

## 4. Wi-Fi

Edit `wifi.txt` on the same PICO8BOOT volume:

```
ssid=MyNetwork
psk=mypassword
country=SE
```

`country=` is required — the radio will not transmit without knowing which
channels are legal where you are.

`country=` is required. Without a regulatory domain the radio does not know
which channels are legal where you are, and will not transmit.

This is read on every boot, so you can change networks later by editing the
file on any computer. Wi-Fi is brought up in the background — PICO-8 starts
whether or not the network comes up.

If you need something `wifi.txt` cannot express — EAP, a hidden SSID, several
networks — put a complete `wpa_supplicant.conf` on the same partition and it
takes priority.

## 4a. Launch mode (optional)

PICO-8 can start two ways. Edit `pico8.txt` on the same PICO8BOOT volume:

```
mode=prompt
```

or

```
mode=splore
```

`prompt` is the command prompt / editor, and is the default if the file is
missing or both lines stay commented. `splore` is the cartridge browser:
local carts with a gamepad, or the Lexaloffle BBS if Wi-Fi is up.

Online Splore needs a working clock for TLS. This image has CA certificates
but no NTP client yet, so BBS downloads may fail until the clock is set.
Local carts in Splore do not need the network.

## 4b. SSH (optional)

Copy your public key to the boot partition as `authorized_keys`:

```sh
cp ~/.ssh/id_ed25519.pub /Volumes/PICO8BOOT/authorized_keys
```

On first boot the device generates its own host keys onto `/data` and keeps
them, so the fingerprint stays stable. Root login is by key only — there is no
password.

```sh
ssh root@<address>
```

You need the IP address for now: there is no mDNS yet, so `pico8.local` will
not resolve. Check your router's client list, or read it from the serial
console.

## 5. Boot

Eject the card, put it in the Pi, connect HDMI and a USB keyboard, power on.

PICO-8 should come up fullscreen after a few seconds. It runs under BusyBox
init's `respawn`, so if it exits it is restarted immediately — you should
never land on a shell.

The OS is a ramdisk (`rootfs.cpio.gz` on PICO8BOOT). Carts and saves live
on the second volume, **PICO8DATA**. Drop `.p8` / `.p8.png` files into
`pico-8/carts` on that volume. PICO-8 writes saves there too. A power cut
mid-write can corrupt PICO8DATA (FAT has no journal); it cannot brick
PICO8BOOT, which is mounted read-only.

Launch mode (`pico8.txt`) and boot-time choices are in
[docs/boot.md](boot.md).

## If nothing appears

There is no getty on this image (PRD 5.5), so a black screen tells you
nothing. Attach a serial adapter to GPIO 14 (TX), 15 (RX) and ground, and
open it at **115200 baud**:

```sh
screen /dev/tty.usbserial-XXXX 115200
```

Kernel messages and the launcher's own errors go there. The launcher reports
exactly what it looked for and where, which is usually enough:

```
pico8-launch: no PICO-8 found on the boot partition.
pico8-launch: found only pico8_64, which is 64-bit ...
```

## Known gaps

- **No mDNS.** `pico8.local` does not resolve; you need the IP address (PRD
  8.3). This is the main thing standing between you and `scp game.p8 pico8:`.
- **PICO8DATA does not auto-resize.** It is a fixed 128 MB and does not grow
  to fill the card. Fine for a large cart library, but the rest of the card
  is unused.
- **Carts go on PICO8DATA.** Copy `.p8` files into `pico-8/carts` on that
  volume. The `carts/` folder on PICO8BOOT is not imported.
- **Never booted on hardware.** Everything here is verified by inspecting the
  built image, not by running it. Treat the first boot as a test, and bring a
  serial adapter.
