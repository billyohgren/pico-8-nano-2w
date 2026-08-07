#!/bin/bash
#
# Assemble the three-partition SD card image (PRD 7).
#
# Derived from Buildroot's board/raspberrypi/post-image.sh (GPL-2.0-or-later):
# the genimage invocation and the generated boot-file list come from there. The
# list is built from whatever the firmware package actually installed rather
# than hard-coded, so a firmware bump cannot silently drop a file.

set -e

BOARD_DIR="$(dirname "$0")"
GENIMAGE_CFG="${BINARIES_DIR}/genimage.cfg"
GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"

# cmdline.txt is ours, not the firmware package's.
cp "${BOARD_DIR}/cmdline.txt" "${BINARIES_DIR}/rpi-firmware/cmdline.txt"

# The FAT partition is the one volume a non-technical user can mount on a Mac
# or Windows machine, so the user-serviceable files live there (PRD 7, 7.1).
if [ ! -f "${BINARIES_DIR}/rpi-firmware/wifi.txt" ]; then
	cp "${BOARD_DIR}/wifi.txt" "${BINARIES_DIR}/rpi-firmware/wifi.txt"
fi
mkdir -p "${BINARIES_DIR}/rpi-firmware/carts"

FILES=()
for i in "${BINARIES_DIR}"/*.dtb "${BINARIES_DIR}"/rpi-firmware/*; do
	FILES+=( "${i#"${BINARIES_DIR}"/}" )
done

KERNEL=$(sed -n 's/^kernel=//p' "${BINARIES_DIR}/rpi-firmware/config.txt")
FILES+=( "${KERNEL}" )

BOOT_FILES=$(printf '\\t\\t\\t"%s",\\n' "${FILES[@]}")
sed "s|#BOOT_FILES#|${BOOT_FILES}|" "${BOARD_DIR}/genimage.cfg.in" > "${GENIMAGE_CFG}"

# Pass an empty rootpath: genimage copies the whole rootpath to its tmpdir,
# and we only need it to place already-built filesystem images.
trap 'rm -rf "${ROOTPATH_TMP}"' EXIT
ROOTPATH_TMP="$(mktemp -d)"

rm -rf "${GENIMAGE_TMP}"

genimage \
	--rootpath "${ROOTPATH_TMP}"   \
	--tmppath "${GENIMAGE_TMP}"    \
	--inputpath "${BINARIES_DIR}"  \
	--outputpath "${BINARIES_DIR}" \
	--config "${GENIMAGE_CFG}"

exit $?
