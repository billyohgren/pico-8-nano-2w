#!/bin/sh
#
# Runs against TARGET_DIR after all packages are installed, before the rootfs
# image is generated.
#
# Upstream's raspberrypi post-build.sh adds a getty on tty1. We deliberately do
# the opposite: the user must never land on a console (PRD 5.5).

set -u
set -e

# Mount point for the single FAT volume.
mkdir -p "${TARGET_DIR}/boot"

# Overlay ships the inittab. Strip anything a package appended (getty,
# ctrlaltdel) so the user never lands on a console (PRD 5.5).
if [ -e "${TARGET_DIR}/etc/inittab" ]; then
	sed -i '/^tty[0-9]*::/d' "${TARGET_DIR}/etc/inittab"
	sed -i '/getty/d' "${TARGET_DIR}/etc/inittab"
	sed -i '/ctrlaltdel/d' "${TARGET_DIR}/etc/inittab"
	sed -i '/rcS/d' "${TARGET_DIR}/etc/inittab"

	grep -q 'pico8-launch' "${TARGET_DIR}/etc/inittab" || \
		printf '\n::respawn:/usr/sbin/pico8-launch\n' \
			>> "${TARGET_DIR}/etc/inittab"
fi

chmod 0755 "${TARGET_DIR}/usr/sbin/pico8-launch"
chmod 0755 "${TARGET_DIR}/etc/init.d/S10mdev" \
	"${TARGET_DIR}/etc/init.d/S20storage" \
	"${TARGET_DIR}/etc/init.d/S25modules" \
	"${TARGET_DIR}/etc/init.d/S41wifi" "${TARGET_DIR}/etc/init.d/S50sshd"

# udhcpc writes resolv.conf on every lease. Point it at tmpfs so a full
# disk on / (ramfs) cannot leave a stale resolver file behind either.
ln -sf /tmp/resolv.conf "${TARGET_DIR}/etc/resolv.conf"
