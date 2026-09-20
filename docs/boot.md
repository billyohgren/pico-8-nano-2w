# Boot time and the ramdisk OS

## What we are aiming at

The current image takes on the order of **20 s** from power-on to PICO-8.
Projects in the same shape (Buildroot on a Pi, one application, no
desktop) publish **3–5 s**. PICOPi was the famous “boots straight into
PICO-8” image; Instant-pi and Furkan Tokac’s Pi 3 write-up are the
measured ones.

This branch does two things: put the OS in a ramdisk, and take the
waits off the path to the first frame. It does **not** claim sub-3 s
until someone times it on a Zero 2 W. The closed GPU firmware alone
is most of a 3 s budget.

## Where 20 s goes

Rough, from the old path and from other people’s traces — not from a
scope on this board:

| Stage | Old path | Why it was slow |
|---|---|---|
| GPU firmware (`start.elf`) | 4–8 s | Closed blob, camera/codec machinery, rainbow splash |
| `rootwait` + squashfs mount | 1–3 s | Kernel sits until `mmcblk0p2` exists, then reads the root off SD |
| BusyBox `rcS` | 2–8 s | **Waits** for every `S*` script. `S10mdev` coldplugs every modalias in sysfs. `S50sshd` runs `ssh-keygen` three times on first boot |
| `sleep 1` in `pico8-launch` | 1 s | Waiting for USB, unconditionally |
| Mesa / KMS / PICO-8 | 1–2 s | Real work, hard to cut |

The firmware number is the one we cannot code around. Instant-pi
measured **4.1 s of cut-down firmware** on a Pi Zero W before Linux
runs at all. A Zero 2 W is a faster ARM complex; the VideoCore loader
is the same class of blob. Sub-3 s *total* therefore means the
firmware has to come in under ~2 s on this chip, which we will only
know by measuring.

## What this branch changes

### 1. OS in RAM

- Root filesystem is `rootfs.cpio.gz`, loaded by the firmware:
  `initramfs rootfs.cpio.gz followkernel` (no `=` on that line).
- No `root=` / `rootwait` on the kernel command line.
- The card is **one** FAT32 volume (PICO8BOOT): firmware, kernel,
  initramfs, pico-8 binary, carts, saves. Copy `pico8-fat-files.zip`
  onto a FAT32 card of any size, or flash `sdcard.img`.
- The OS is never written. PICO-8 saves on the same FAT the firmware
  boots from (PicoPi tradeoff).

gzip cpio, not a cpio baked into the kernel. Overlay changes must not
force a kernel rebuild. The kernel has `CONFIG_BLK_DEV_INITRD` and
`CONFIG_RD_GZIP` built in.

**Memory.** A 512 MB Zero 2 W with `cma-128` and `gpu_mem=16` leaves
roughly 360 MB for kernel + unpacked rootfs + PICO-8. The old squashfs
was ~70 MB compressed; unpacked it is larger. If the first hardware
boot OOMs, the next step is a nested squashfs inside the initramfs
(compressed in RAM, pages decompressed on demand) rather than giving
up on the ramdisk.

### 2. Firmware

- Boot `start.elf` / `fixup.dat` with `gpu_mem=64`.
- `dtoverlay=vc4-kms-v3d,cma-128,noaudio`. Hardware beta: vc4 bound
  HVS then `deferred probe pending`, `/dev/dri` empty, PICO-8 never
  started. HDMI audio in the overlay is what was stalling KMS.
- `disable-bt` instead of `miniuart-bt`. Bluetooth is out of scope;
  this still puts the PL011 on GPIO 14/15 for serial.
- `boot_delay=0`, `disable_splash=1`, `hdmi_force_hotplug=1`,
  `initial_turbo=30`.

### 3. Init is no longer a queue

BusyBox `rcS` ran every script as `sysinit` and **waited**. The new
`inittab` does:

```
sysinit:  mount, mdev, SD, modules     # waited, keep this short
respawn:  pico8-launch                 # first frame
once:     wifi, sshd                   # must not block PICO-8
```

`S10mdev` only starts the hotplug daemon. It does **not** walk `/sys`
and `modprobe` every alias — that coldplug was seconds. `S25modules`
still loads `vc4`, `brcmfmac` and `snd_bcm2835` explicitly.

`pico8-launch` waits for `/dev/dri/card0` (up to 2 s) instead of
`sleep 1`.

## What is still on the table after a rebuild

In likely order of remaining seconds:

1. **Measure.** Serial + a camera on the HDMI input. Until we have
   numbers, the 20 s / 3 s discussion is folklore.
2. **Firmware floor.** If `start_cd.elf` is still ~4 s, sub-3 s total
   is not happening on this SoC without a different bootloader, and
   there isn’t a viable open one for the Zero 2 W.
3. **Build `vc4` into the kernel** so `/dev/dri` exists before
   userspace. Module load from a ramdisk is already cheap; this is
   polish.
4. **Nested squashfs** if RAM is tight (see above).
5. **Kernel LZ4** instead of gzip zImage — faster decompress, larger
   file. Worth a timed A/B, not a guess.
6. **Drop unused DTB overlays from the FAT image** so the firmware
   directory listing is smaller. Only `vc4-kms-v3d` and `disable-bt`
   are referenced.

## How to time it

Serial at 115200 on GPIO 14/15. The first kernel line is roughly
“firmware done”; `pico8-launch: starting` is userspace; the HDMI
frame is later and needs a camera or a `drm` debug print. Three runs,
worst case, same as PRD A6.
