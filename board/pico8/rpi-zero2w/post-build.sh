#!/bin/sh
#
# Runs against TARGET_DIR after all packages are installed, before the rootfs
# image is generated.
#
# Upstream's raspberrypi post-build.sh adds a getty on tty1. We deliberately do
# the opposite: the user must never land on a console (PRD 5.5).

set -u
set -e

# Mount points for the read-only root and the writable data partition (PRD 7).
mkdir -p "${TARGET_DIR}/boot"
mkdir -p "${TARGET_DIR}/data"

# No getty on any tty. BR2_TARGET_GENERIC_GETTY_PORT="" already suppresses the
# serial one; this catches anything a package added.
if [ -e "${TARGET_DIR}/etc/inittab" ]; then
	sed -i '/^tty[0-9]*::/d' "${TARGET_DIR}/etc/inittab"
	sed -i '/getty/d' "${TARGET_DIR}/etc/inittab"

	# Ctrl+Alt+Del must not reboot the console mid-game (PRD 5.5).
	sed -i '/ctrlaltdel/d' "${TARGET_DIR}/etc/inittab"

	# Respawning supervisor (PRD 5.5): if PICO-8 exits or crashes, restart it.
	# The user never lands on a console. 'respawn' is BusyBox init's own
	# supervision, so no extra process manager is needed.
	grep -q 'pico8-launch' "${TARGET_DIR}/etc/inittab" || \
		printf '\n# PICO-8, restarted forever (PRD 5.5)\n::respawn:/usr/sbin/pico8-launch\n' \
			>> "${TARGET_DIR}/etc/inittab"
fi

chmod 0755 "${TARGET_DIR}/usr/sbin/pico8-launch"
chmod 0755 "${TARGET_DIR}/etc/init.d/S25modules" \
	"${TARGET_DIR}/etc/init.d/S41wifi" "${TARGET_DIR}/etc/init.d/S50sshd"

# The root filesystem is read-only squashfs, but udhcpc writes resolv.conf on
# every lease. Point it at tmpfs. Without this, DNS silently never works.
ln -sf /tmp/resolv.conf "${TARGET_DIR}/etc/resolv.conf"
