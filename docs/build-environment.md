# Build environment

You build this project **on your Mac**, using Docker. You do not need a VM you manage
yourself, and you do not need a separate Linux machine.

## Quick start

```sh
./scripts/br setup       # one-time: fetch Buildroot, build the container image
./scripts/br defconfig
./scripts/br build       # first run takes a few hours
./scripts/br image       # → output/sdcard.img
```

Before `build`, download `pico-8_<version>_raspi.zip` from your Lexaloffle account and put it
in `vendor/pico-8/`. It cannot be fetched automatically — see [licensing.md](licensing.md).

## Why not just build on macOS?

Buildroot supports Linux hosts only. This is not a matter of installing the right Homebrew
packages; two macOS problems cannot be fixed at the package level.

**1. APFS is case-insensitive by default.** The Linux kernel source contains files whose names
differ only in case — `xt_CONNMARK.h` and `xt_connmark.h` are the classic pair. On APFS the
second one overwrites the first, silently. You can reproduce this in ten seconds:

```sh
$ cd ~/Desktop
$ echo upper > xt_CONNMARK.h && echo lower > xt_connmark.h
$ ls xt_[Cc]*        # one file, not two
$ cat xt_CONNMARK.h  # "lower" — the other file is simply gone
```

There is no error. The kernel tarball just extracts wrong, and you find out hours later as an
incomprehensible compile failure.

**2. Host tools misdetect the platform.** `uname` reports Darwin, so configure scripts take BSD
code paths while building for a Linux target.

The `ncurses` error hit during early development was a symptom of the second problem. Fixing it
only moves you to the next failure.

## Why Docker is genuinely enough

Docker Desktop on macOS already runs a Linux VM — the container gets a real Linux kernel and a
real ext4 filesystem. The only thing you have to get right is **keeping the build off the macOS
filesystem**, which `compose.yaml` does:

| Path in container | Backed by | Holds |
|---|---|---|
| `/src` | bind mount from this repo (APFS) | your editable files: defconfig, overlay, package, docs |
| `/build` | named volume `br-output` (ext4) | **everything Buildroot extracts** — kernel, toolchain, packages |
| `/dl` | named volume `br-dl` (ext4) | download cache, persists across cleans |
| `/ccache` | named volume `br-ccache` (ext4) | compiler cache |

Buildroot is invoked with `O=/build`, so it never extracts a single tarball onto APFS. Your own
files stay on the Mac where you can edit them in your normal editor; nothing in `/src` has case
collisions because you wrote all of it.

You can verify the split is working at any time:

```sh
docker compose run --rm buildroot sh -c \
  'cd /build && echo a > A.h && echo b > a.h && ls [Aa].h'
```

Two files means ext4, and you are fine. One file means you are writing to the bind mount by
mistake.

## Architecture: stay on arm64

The container is `linux/arm64` and runs natively on Apple Silicon. Buildroot compiles its own
cross-toolchain from source, so an ARM host costs nothing — the target is ARM either way.

**Do not add `--platform linux/amd64`.** x86 emulation on Apple Silicon can make a
several-hour build take most of a day.

The one exception: if some Buildroot *host* package turns out to be broken on aarch64 hosts,
the escape hatch is to set `platform: linux/amd64` in `compose.yaml` and accept the slowdown.
Try it only against a specific failure, never pre-emptively.

## Getting the image out

The built image lives in the Docker volume, not on your Mac. `./scripts/br image` copies it to
`output/sdcard.img`, which is a normal macOS file you can hand to Raspberry Pi Imager.

## Disk usage

A full Buildroot tree is roughly 15–25 GB, all inside the Docker volumes. Docker Desktop's
virtual disk must have room for it — check Settings → Resources if the build fails with ENOSPC.

- `./scripts/br clean` — wipes the build output, keeps downloads (fast rebuild)
- `./scripts/br nuke` — removes the volumes entirely, including the download cache

## Editing config interactively

```sh
./scripts/br menuconfig      # curses UI works fine through docker compose run -t
./scripts/br savedefconfig   # write your changes back to configs/
```

Always run `savedefconfig` after `menuconfig`, otherwise your change lives only in the Docker
volume and is lost on the next `clean`.
