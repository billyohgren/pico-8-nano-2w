# Product Requirements Document

**Project:** PICO-8 Buildroot Image for Raspberry Pi Zero 2 W
**Version:** 2.0
**Date:** August 2026
**Status:** Draft — pending Spike 0 (see §17)

> **Changes from v1.0:** v1.0 was written without knowledge of three constraints that made it
> unbuildable as specified: PICO-8 is closed-source and cannot be built from source; Buildroot
> does not support macOS as a build host; and the referenced base project predates the target
> hardware. v2.0 corrects these, decides the architecture/libc/display questions v1.0 left open,
> and adds a risk register, a test plan, and a legal section. The original is preserved at
> `prd-v1-original.md`.

---

## 1. Overview

A Buildroot-based Linux image for the Raspberry Pi Zero 2 W that boots directly into PICO-8,
never exposing the underlying operating system. The device should behave like a dedicated retro
console: power on, PICO-8 appears, play. Developers can push cartridges over Wi-Fi via SCP
without removing the SD card.

The project is a **BR2_EXTERNAL tree** layered on top of a pinned upstream Buildroot checkout.
It is not a fork of Buildroot.

---

## 2. Goals

| # | Goal | Priority |
|---|------|----------|
| G1 | Boots directly into PICO-8 on Raspberry Pi Zero 2 W | Must |
| G2 | No shell, login prompt, or Linux UI ever visible to the user | Must |
| G3 | HDMI video output, fullscreen | Must |
| G4 | USB keyboard and USB gamepad support, hot-pluggable | Must |
| G5 | Onboard Wi-Fi, configured without a shell | Must |
| G6 | SSH + SCP access for cartridge transfer | Must |
| G7 | Survives power loss without filesystem corruption | Must |
| G8 | Reproducible builds from a pinned tree | Must |
| G9 | Boot time ≤ 12 s power-on to first PICO-8 frame | Must |
| G10 | Boot time ≤ 8 s | Should |
| G11 | HDMI audio | Should |
| G12 | Auto-run a specific cartridge on boot | Should |
| G13 | Image ≤ 256 MB | Should |

## 3. Non-goals

Desktop environment · X11 · Wayland · package manager on target · Python · PulseAudio ·
PipeWire · compilers or development tools on target · GUI configuration utilities ·
Bluetooth controllers (v1) · OTA updates (v1).

---

## 4. Target hardware

| Item | Spec |
|------|------|
| Board | Raspberry Pi Zero 2 W |
| SoC | BCM2710A1, quad-core Cortex-A53 |
| RAM | 512 MB |
| Storage | microSD, 4 GB minimum, 8 GB+ recommended |
| Video | mini-HDMI |
| Networking | onboard Wi-Fi (brcmfmac, BCM43436) |
| USB | one micro-USB data port (OTG), one power-only port |

**Required accessories (document in README):** mini-HDMI→HDMI cable or adapter,
micro-USB OTG adapter, and a **powered** USB hub if more than one input device is used. The
Zero 2 W has a single data port, and an unpowered hub with a keyboard plus gamepad can brown
out the board.

---

## 5. Key technical decisions

These were unresolved in v1.0. Each is decided here with rationale, and each is validated by
Spike 0 before the rest of the work proceeds.

### 5.1 PICO-8 is proprietary — supplied, not built

PICO-8 is closed-source commercial software from Lexaloffle (~$15). There is no source code.
Consequences that shape the entire project:

- The build **cannot** be "completely from source".
- The PICO-8 binary **must not** be committed to this repository or included in any image
  distributed to third parties. Doing so violates the Lexaloffle EULA.

**Decision (revised): PICO-8 is dropped in by the end user, not built into the image.**

v2.0 of this document had the builder supply `pico-8_<version>_raspi.zip` into `vendor/pico-8/`,
with the version pinned in the defconfig and the archive checksummed. That is no longer the
design. Instead:

- The build requires **nothing** from Lexaloffle. `vendor/pico-8/` is not consulted.
- The resulting image contains no proprietary code and is therefore **freely
  redistributable** — the same property that let the picopi project publish its image on
  GitHub.
- After flashing, the user copies the `pico-8` folder from their own raspi zip onto the FAT
  boot partition, which is the one volume visible on a Mac or Windows machine.
- **No version is pinned anywhere.** `/usr/sbin/pico8-launch` searches for the binary by
  name (`pico8_dyn`, then `pico8`), so any release works and upgrading means dragging in a
  newer folder.

The tradeoff accepted here: the image no longer determines which PICO-8 you get, so an image
alone is not a reproducible description of the running system. Given PICO-8 ships no source
and no published checksums, that determinism was always partial.

### 5.2 Architecture: 32-bit armhf

**Decision: 32-bit ARM (armhf) kernel and userland**, based on upstream
`raspberrypizero2w_defconfig`, running Lexaloffle's `pico8` / `pico8_dyn` armhf binary.

Rationale: on a 512 MB device a 32-bit userland has a meaningfully smaller memory footprint;
the armhf PICO-8 build is the most widely exercised on Raspberry Pi hardware; and it keeps the
legacy firmware graphics path available as a fallback if §5.4 does not pan out.

A 64-bit variant (`raspberrypizero2w_64_defconfig` + Lexaloffle's `pico8_64`) is a documented
alternate configuration, not the default. Both must not be mixed in one image.

### 5.3 C library: glibc — mandatory

Buildroot defaults to uClibc-ng. A prebuilt Lexaloffle binary linked against Raspberry Pi OS
**will not run** on uClibc-ng or musl. The defconfig must select glibc, and the Buildroot glibc
version must be at least the version PICO-8 was linked against. The same applies to
`libstdc++` and SDL2 ABI compatibility.

This is the single most likely cause of a "builds fine, boots fine, PICO-8 segfaults" failure,
and is the primary thing Spike 0 exists to disprove.

### 5.4 Display: SDL2 on KMS/DRM

**Decision: `vc4-kms-v3d` + SDL2 built with the KMSDRM backend**, no X11, no Wayland,
no DirectFB.

"Framebuffer" in v1.0 was ambiguous. Current Raspberry Pi kernels use DRM/KMS; the legacy
fbdev/dispmanx path is deprecated and exists only on the 32-bit firmware stack. PICO-8 is an
SDL2 application, so the requirement is precisely: SDL2 with `KMSDRM` video driver enabled and
`SDL_VIDEODRIVER=kmsdrm` in PICO-8's environment.

Fallback if KMSDRM performance or compatibility fails: legacy `vc4-fkms-v3d` or dispmanx
(available only because of the 32-bit decision in §5.2). Chosen path is confirmed by Spike 0.

### 5.5 Init and supervision

BusyBox init. PICO-8 runs under a **respawning supervisor**. If PICO-8 exits or crashes for any
reason, it is restarted; the user never lands on a console. Additionally:

- No `getty` on any tty.
- `Ctrl+Alt+Del` disabled.
- Magic SysRq disabled.
- Kernel console output redirected away from tty1 (see §11).

### 5.6 SSH: OpenSSH, not Dropbear

**Decision: OpenSSH** (`sshd` + `sftp-server`).

Modern OpenSSH clients (including the one shipped with current macOS) use the **SFTP protocol**
for `scp` by default. Dropbear provides no SFTP subsystem, so `scp game.p8 pico8:` would fail
against it unless the developer remembers `scp -O`. The ~1–2 MB size cost is irrelevant next to
the goal of frictionless cartridge transfer (G6).

### 5.7 Base project

**Decision: BR2_EXTERNAL tree over pinned upstream Buildroot.**

v1.0 referenced `gamaral/rpi-buildroot`. That project predates the Pi Zero 2 W and is not a
viable base. Upstream Buildroot already provides `configs/raspberrypizero2w_defconfig` and
`board/raspberrypi/`; this project adds only what is specific to PICO-8.

---

## 6. Boot flow

```
Power on
  → Pi bootloader (bootcode.bin / start.elf, from FAT boot partition)
  → Linux kernel + bcm2710-rpi-zero-2-w.dtb
  → BusyBox init
      ├─ mount /data (rw), overlay writable paths
      ├─ start PICO-8 supervisor          ← foreground, blocks nothing
      └─ start network + sshd             ← background, never blocks boot
  → DRM/KMS mode set
  → PICO-8 fullscreen
```

**Networking must never block the boot path.** Wi-Fi association and DHCP run asynchronously;
PICO-8 appears whether or not the network comes up.

No shell appears at any point in this sequence, including on failure.

---

## 7. Filesystem and power-loss safety

The device has no shutdown button and users will pull the power. v1.0 specified a read-write
root filesystem, which corrupts SD cards under those conditions. Corrected layout:

| Partition | Format | Mount | Mode | Contents |
|-----------|--------|-------|------|----------|
| p1 | FAT32 | `/boot` | **read-only** | firmware, kernel, dtb, `config.txt`, `cmdline.txt`, `wifi.txt`, `pico8.txt`, `authorized_keys`, `carts/` (drop-box, see §7.1) |
| p2 | ext4 or squashfs | `/` | **read-only** | base system, PICO-8 binary |
| p3 | ext4 | `/data` | read-write | `/home/pi`, carts, saves, PICO-8 config |

- Writable paths on the root (`/etc`, `/var`) are provided by tmpfs or an overlay backed by p3.
- p3 is auto-resized to fill the SD card on first boot.
- p3 is mounted with journaling enabled and `commit` tuned for durability over throughput.

**p1 is deliberately FAT32 so a non-technical user can edit `wifi.txt` and drop in
`authorized_keys` by mounting the SD card on a Mac or Windows machine.**

### 7.1 Cartridge drop-box (how carts get onto the card)

There are two ways to get a cartridge onto the device, and they are deliberately different
mechanisms:

1. **Over the network (primary):** `scp game.p8 pico8:carts/` writes straight to `/data`. No
   card removal, works while the device is running. This is the developer path (G6).
2. **By SD card (convenience):** drop `.p8` / `.p8.png` files into the `carts/` folder on the
   FAT partition — the one volume that appears when you plug the card into a Mac. **On boot,
   init copies them into `/data` and PICO-8 reads them from there.**

The copy is deliberately **one-way and boot-time only**. PICO-8 never reads or writes the FAT
partition at runtime, because:

- p1 is the partition the Pi firmware boots from. Corrupting it on a power cut bricks the
  device, not just the save data.
- FAT has no permissions or journaling, and PICO-8 writes save data (`cstore`, `cdata`) during
  play.

So the answer to "can I just put a folder of carts on the SD card?" is yes — but it is an
import folder, not the live cart directory. Saves and any cart PICO-8 writes itself land on
`/data` and will not appear back on the FAT partition.

---

## 8. Networking

### 8.1 Wi-Fi

- `brcmfmac` driver + Raspberry Pi Wi-Fi firmware blobs.
- `wpa_supplicant` + `udhcpc`.
- **WPA2-PSK is required.** WPA3/SAE is best-effort only — support on `brcmfmac` is
  inconsistent, and it is explicitly **not** an acceptance criterion.

### 8.2 Provisioning (new requirement — v1.0 had a chicken-and-egg gap)

The user must be able to configure Wi-Fi **without** a shell or network. At boot, an init script
reads `/boot/wifi.txt`:

```
ssid=MyNetwork
psk=mypassword
country=SE
```

and generates `wpa_supplicant.conf` from it. A raw `wpa_supplicant.conf` on `/boot` overrides
`wifi.txt` for advanced users. The plaintext PSK on a FAT partition is an accepted tradeoff,
documented in the README.

### 8.3 Discovery

`scp game.p8 pico8:` requires name resolution. **An mDNS responder is required** — `mdnsd`
preferred for footprint, `avahi-daemon` acceptable — advertising `pico8.local`. The README
documents a DHCP-reservation fallback for networks where mDNS is blocked.

---

## 9. SSH and file transfer

- OpenSSH `sshd` started in the background at boot (§5.6).
- **Key-based authentication only.** Password authentication disabled. Root login disabled.
- Public keys are read from `/boot/authorized_keys`, copied to `pi`'s account on boot.
- **No default password ships in the image.** An image with a known default password reachable
  over Wi-Fi is not acceptable.
- Target: `scp game.p8 pico8:/data/home/pi/carts/` works from a stock macOS terminal with no
  extra flags.

---

## 10. PICO-8 integration

- Launched fullscreen by the supervisor (§5.5), with `SDL_VIDEODRIVER=kmsdrm`.

**Where PICO-8 lives on the target (revised — see 5.1).** PICO-8 is **not** in the image. The
user copies the `pico-8` folder from their raspi zip onto the **FAT boot partition** (p1) after
flashing, and `/usr/sbin/pico8-launch` finds it at boot.

- p1 is mounted `ro,exec,umask=0022`. FAT carries no permission bits, so the umask is what
  makes the dropped binary executable; `ro` keeps the boot partition itself immutable at
  runtime.
- The launcher prefers `pico8_dyn`, the dynamically linked build, so PICO-8 uses the SDL2 we
  build with the KMSDRM backend (5.4) rather than a bundled one. `pico8` is the fallback.
  `pico8_64` is aarch64 and cannot run on this 32-bit userland; the launcher says so
  explicitly rather than failing obscurely.
- The root partition stays read-only and free of proprietary code.

Note this differs from picopi, which ran `pico8_dyn -home /mnt/pico-8` — putting PICO-8's save
data on the FAT partition. We read the binary from p1 but keep `-home` on `/data` (p3), for
the reasons in 7.1: PICO-8 writes `cstore`/`cdata` during play, and a power cut mid-write to
the boot partition is what bricks the device rather than merely losing a save.

**Where PICO-8's data lives.** PICO-8 insists on `~/.lexaloffle/pico-8/` for its config,
cartridge directory and save data. That path must resolve onto writable `/data`:

| PICO-8 path | Backed by |
|---|---|
| `~/.lexaloffle/pico-8/config.txt` | `/data` — templated by the build on first boot, then user-owned |
| `~/.lexaloffle/pico-8/carts/` | `/data` — the live cart directory (§7.1) |
| `~/.lexaloffle/pico-8/cdata/` | `/data` — cartridge save data |

v1.0's invented `/roms` path does not work as written; PICO-8 will not look there. The build
reconciles this with a symlink plus `root_path` in PICO-8's own `config.txt`, and exposes a
friendly `~/carts` for the SCP target in §9.
- Launch mode is selected from `/boot/pico8.txt` (`mode=prompt` or `mode=splore`),
  the same FAT-partition pattern as `wifi.txt`. Missing or empty file boots to
  the PICO-8 prompt. `mode=splore` passes `-splore` so Splore comes up instead
  of the editor — usable with a gamepad, and with the BBS if Wi-Fi is up.
- **Auto-run cartridge (G12):** if a designated cart is present, boot straight into it;
  otherwise boot to the PICO-8 prompt.
- `splore` (online cart browser) requires `ca-certificates` and a correct clock — see §12.

---

## 11. Audio, display and boot cosmetics

- **ALSA only.** No PulseAudio, no PipeWire.
- HDMI audio requires selecting the correct ALSA card explicitly via `asound.conf`. "Use ALSA"
  is not sufficient configuration.
- `hdmi_force_hotplug=1` so the image works when the TV is powered on after the Pi.
- `gpu_mem` / CMA sizing tuned during Spike 0 — the correct value differs between the KMS and
  legacy paths.
- Silent boot: `quiet loglevel=0 vt.global_cursor_default=0` on the kernel command line,
  `disable_splash=1` in `config.txt`, console redirected off tty1.
- Optional boot splash image, replaceable by the user.

---

## 12. Time

The Pi has no RTC. Without a time source, file timestamps are wrong and TLS (splore, any HTTPS)
fails. A lightweight NTP client (BusyBox `ntpd` or `chrony`) is required, started in the
background, non-blocking.

---

## 13. Reproducibility

"Reproducible" in v1.0 had no mechanism behind it. Required:

- Upstream Buildroot pinned to a specific tag as a git submodule.
- Raspberry Pi firmware and kernel pinned to specific commits.
- PICO-8 version pinned, with checksum verification.
- A vendored or mirrored `BR2_DOWNLOAD_DIR` so upstream URL rot does not break the build.
- `make legal-info` output committed as part of the release artifacts (§16).

---

## 14. Build host

**Buildroot does not support macOS.** This is not a matter of installing the right Homebrew
packages — the `ncurses` failure encountered during v1.0 development was a symptom, not the
cause. Two macOS-specific problems are unfixable at the package level:

1. **APFS is case-insensitive by default.** The Linux kernel source contains files whose names
   differ only in case; extracting the kernel tarball silently clobbers them.
2. **Host tool platform misdetection.** `uname` reports Darwin, and configure scripts take BSD
   code paths while targeting Linux.

### Supported build environment: Docker on macOS

**Decision: a `linux/arm64` Debian container via Docker Desktop.** No self-managed VM and no
separate Linux machine. Docker Desktop already provides a Linux VM with a real ext4 filesystem;
the container is where the build runs.

The design that makes this work is the **volume split** — your files stay on the Mac, and
everything Buildroot extracts goes to a Docker named volume:

| Container path | Backed by | Contents |
|---|---|---|
| `/src` | bind mount from the repo (APFS) | defconfig, overlay, package, docs — files you edit |
| `/build` | named volume (ext4) | **all extracted sources**: kernel, toolchain, packages |
| `/dl` | named volume (ext4) | download cache |
| `/ccache` | named volume (ext4) | compiler cache |

Buildroot is invoked with `O=/build`, so no tarball is ever extracted onto APFS. This is what
neutralises the case-insensitivity problem while still letting you edit in your normal editor.

Two hard rules, both documented in `docs/build-environment.md`:

- **Never move the Buildroot output onto the bind mount.** Verified by the check in
  `docs/build-environment.md`; a regression here corrupts the kernel source silently.
- **Never set `platform: linux/amd64`.** The container is native arm64 on Apple Silicon;
  x86 emulation can turn a multi-hour build into most of a day. Reserved as an escape hatch
  only if a specific Buildroot host package proves broken on aarch64 hosts.

Editing source on the Mac is fine; the build itself runs in Linux. The v1.0 Homebrew / ncurses /
gnu-sed prerequisite list is obsolete and removed — there are no macOS-side dependencies beyond
Docker Desktop and git.

---

## 15. Repository layout

```
pico-rpi/
├── buildroot/                  # pinned upstream, git submodule — not modified
├── external.desc               # BR2_EXTERNAL descriptor
├── external.mk
├── Config.in
├── configs/
│   └── pico8_rpi_zero2w_defconfig
├── board/pico8/rpi-zero2w/
│   ├── config.txt
│   ├── cmdline.txt
│   ├── genimage.cfg            # 3-partition layout (§7)
│   ├── post-build.sh
│   └── post-image.sh
├── package/pico8/              # consumes vendor/pico-8/*.zip (§5.1)
│   ├── Config.in
│   └── pico8.mk
├── overlay/                    # rootfs overlay: init scripts, sshd, wifi, mDNS
├── vendor/pico-8/              # user drops their PICO-8 zip here — .gitignored
├── docker/Dockerfile           # linux/arm64 Debian build environment (§14)
├── compose.yaml                # volume split: /src bind, /build + /dl volumes
├── scripts/br                  # build driver — run from macOS
├── output/                     # sdcard.img copied out of the volume — .gitignored
├── docs/
│   ├── flashing.md
│   ├── wifi.md
│   ├── ssh.md
│   ├── build-environment.md    # Docker setup and the case-sensitivity rationale (§14)
│   └── licensing.md
└── README.md
```

`vendor/pico-8/` **must** be in `.gitignore` (§5.1, §16).

Build interface, run from macOS:

```sh
./scripts/br setup       # fetch pinned Buildroot, build the container image
./scripts/br defconfig
./scripts/br build
./scripts/br image       # → output/sdcard.img
```

---

## 16. Legal

- **PICO-8**: proprietary, per-user licensed. The binary must never be committed here or
  distributed in any image shared with another person. Each builder supplies their own copy.
- **GPL compliance**: if an image is distributed to anyone, the corresponding source for GPL
  components must be offered. `make legal-info` produces the manifest and license texts; this
  output is a release artifact.
- **Raspberry Pi firmware / Wi-Fi blobs**: redistributable under their own terms; include the
  license files.
- `docs/licensing.md` states all of the above in plain language.

---

## 17. Risks and spikes

### Spike 0 — do this before anything else (est. 1–2 days)

**Question:** does a Lexaloffle PICO-8 binary run correctly on a Buildroot glibc rootfs with
SDL2/KMSDRM on a Pi Zero 2 W?

Fastest path: build the stock upstream `raspberrypizero2w_defconfig` with glibc + SDL2/KMSDRM +
OpenSSH, copy PICO-8 onto it by hand, and run it. This validates §5.2, §5.3 and §5.4
simultaneously. **Do not build the full project structure before this succeeds.** If it fails,
the fallback ladder is: `pico8_dyn` with our own SDL2 → legacy fkms/dispmanx → 64-bit +
`pico8_64`.

| Risk | Impact | Mitigation |
|------|--------|------------|
| glibc/libstdc++ ABI mismatch with PICO-8 binary | Blocker | Spike 0; raise Buildroot glibc version |
| KMSDRM performance inadequate on Zero 2 W | High | Spike 0; legacy dispmanx fallback (enabled by 32-bit choice) |
| PICO-8 needs a library not obvious from `ldd` | Medium | Spike 0 on real hardware, not qemu |
| 8 s boot target unreachable | Low | G9 (12 s) is the Must; G10 (8 s) is a Should |
| WPA3 unsupported by brcmfmac | Low | Explicitly out of acceptance criteria (§8.1) |
| Single USB port limits input options | Low | Documented in §4 accessories |

---

## 18. Deliverables

- BR2_EXTERNAL project tree (§15) with `pico8_rpi_zero2w_defconfig`
- Custom `pico8` Buildroot package that consumes a user-supplied archive
- Board support files, 3-partition `genimage.cfg`, rootfs overlay, init scripts
- `docker/Dockerfile` + `compose.yaml` + `scripts/br` — Docker build environment and driver
- `sdcard.img`, flashable with Raspberry Pi Imager or Balena Etcher
- Documentation: README, build environment (Docker) guide, flashing, Wi-Fi, SSH, licensing
- `make legal-info` output

---

## 19. Acceptance criteria

Each criterion states how it is verified.

| # | Criterion | Verification |
|---|-----------|--------------|
| A1 | Builds from clean checkout on stock macOS + Docker Desktop, no manual fixes | Fresh clone, `./scripts/br setup && ./scripts/br defconfig && ./scripts/br build`, exit 0 |
| A2 | Build fails with a clear, actionable message when the PICO-8 archive is absent | Build with empty `vendor/pico-8/` |
| A3 | Produces a bootable `sdcard.img` | Flash with Raspberry Pi Imager |
| A4 | Boots on Pi Zero 2 W and displays PICO-8 fullscreen over HDMI | Visual |
| A5 | No shell, login prompt, or kernel log is ever visible — including when PICO-8 is killed | Visual; `kill` PICO-8 over SSH and observe HDMI |
| A6 | Power-on to first PICO-8 frame ≤ 12 s | Video capture at 30 fps, 3 runs, worst case |
| A7 | USB keyboard works, hot-plug included | Manual, via powered hub |
| A8 | USB gamepad works, hot-plug included | Manual, generic HID + one Xbox-type pad |
| A9 | Connects to WPA2 Wi-Fi configured only by editing `/boot/wifi.txt` on a Mac | Manual, from freshly flashed card |
| A10 | `ssh pico8.local` succeeds with a key from `/boot/authorized_keys`; password auth rejected | Manual, from macOS |
| A11 | `scp game.p8 pico8:...` succeeds from stock macOS `scp`, no extra flags | Manual |
| A12 | Cart transferred by SCP is visible and loadable in PICO-8 without reboot | Manual |
| A12b | Cart dropped into `carts/` on the FAT partition from a Mac appears in PICO-8 after one boot | Manual, freshly flashed card |
| A13 | HDMI audio plays | Manual |
| A14 | 20 consecutive hard power-cuts during play leave the filesystem intact and the device bootable | Scripted power cycling |
| A15 | No package manager, compiler, or dev tooling on target | `find` on rootfs |
| A16 | Two builds from the same pinned tree produce functionally identical images | Build twice, compare manifests |
| A17 | Image ≤ 256 MB | `ls -l sdcard.img` |

---

## 20. Out of scope / future work

Bluetooth controller pairing · OTA updates · web configuration UI · automatic cart sync over
Wi-Fi · USB mass-storage gadget mode (mutually exclusive with USB host mode on the single data
port) · multi-cart launcher menu · additional Pi models · RetroArch integration.

---

## 21. Open questions

1. Which PICO-8 version is pinned for v1? (Depends on what the builder owns.)
2. Squashfs or read-only ext4 for the root partition — decide after measuring image size.
3. `mdnsd` or `avahi-daemon` — decide after measuring footprint and reliability on-device.
4. Is a custom boot splash in scope for v1, or deferred?
5. Should the boot-time cart import (§7.1) move or copy? Moving keeps the FAT drop-box tidy but
   writes to p1; copying is safer but leaves duplicates the user must clean up manually.

*Resolved since v2.0:* build host (§14, Docker on macOS — implemented), cart location
(§7.1/§10), PICO-8 install path (§10).
