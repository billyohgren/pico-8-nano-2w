Product Requirements Document (PRD)
Pico-8 Buildroot Image for Raspberry Pi Zero 2 W
Version: 1.0
Date: August 2026
Author: ChatGPT (based on project discussions)
1. Overview
The goal is to create a Buildroot-based Linux image for the Raspberry Pi Zero 2 W that boots directly into Pico-8 without exposing the underlying Linux operating system.
The system should function like a dedicated retro gaming console:
Power on
Boot directly into Pico-8
Support USB keyboards/controllers
Support Wi-Fi
Allow SCP/SSH management
Boot quickly
Be lightweight
Be reproducible using Buildroot
The project is based on the existing Buildroot Pico-8 projects found on GitHub, but adapted specifically for the Raspberry Pi Zero 2 W.
2. Goals
Primary goals
Raspberry Pi Zero 2 W support
Fully reproducible Buildroot project
Boots directly into Pico-8
No desktop environment
No login prompt
HDMI output
USB OTG keyboard/controller support
Wi-Fi support
SSH support
Small image size
Fast boot time
3. Non-goals
The project should NOT include
Desktop environment
X11
Wayland
Package manager
Python
Audio server (unless required)
Development tools
GUI configuration utilities
4. Target Hardware
Target board
Raspberry Pi Zero 2 W
CPU
BCM2710A1
Quad-core ARM Cortex-A53
RAM
512 MB
Storage
microSD
Networking
onboard Wi-Fi
onboard Bluetooth (optional)
Video
HDMI
Input
USB OTG
5. Build System
Use
Buildroot
Latest stable Buildroot (or current Git version)
Project should build completely from source.
6. Existing Project
Original project based on
https://github.com/gamaral/rpi-buildroot
or equivalent Pico-8 Buildroot projects.
The project must be updated to support
Raspberry Pi Zero 2 W
newer Buildroot
newer Raspberry Pi firmware
7. Boot Flow
Desired boot sequence
Power On

↓

Bootloader

↓

Linux Kernel

↓

Init

↓

Framebuffer initialized

↓

Pico-8 starts automatically

↓

User sees Pico-8
No shell should ever appear.
8. Display
Use framebuffer.
No X server.
No Wayland.
Pico-8 should render directly to framebuffer.
Fullscreen.
9. Input Devices
Support
USB keyboard
USB gamepads
Xbox controllers (if possible)
Generic HID controllers
Automatically detected.
10. Audio
Support
HDMI audio
Optional
PWM audio
No PulseAudio.
No PipeWire.
Use ALSA.
11. Networking
The Pi Zero 2 W must support onboard Wi-Fi.
Required kernel drivers.
Required firmware.
Required userspace.
12. Wi-Fi Requirements
Must support
WPA2
WPA3 (if possible)
Use
wpa_supplicant
DHCP
udhcpc
Networking should start automatically.
13. SSH
Include
OpenSSH or Dropbear.
Requirements
SSH enabled at boot
SCP enabled
SFTP optional
Default login configurable.
14. File Transfer
Developers should be able to
scp game.p8 pi:/home/pi/
without removing the SD card.
15. Pico-8 Startup
Pico-8 should automatically launch during boot.
Example
pico8
or
pico8 -fullscreen
No manual intervention.
16. Auto-run Cartridge (Optional)
Support booting directly into a cartridge.
Example
pico8 mygame.p8
17. Filesystem
Read-write root filesystem.
Support
/home/pi

/config

/roms
or equivalent.
18. Build Output
Buildroot should produce
sdcard.img
or
image.img
that can be flashed using
Balena Etcher
or
Raspberry Pi Imager.
19. Build Host
Development performed on
macOS
Must compile correctly using
make
Requirements
Homebrew
ncurses
pkg-config
gnu-sed if required
The project should document all macOS prerequisites to avoid the missing ncurses issue encountered during development.
20. Repository Layout
Suggested
project/

buildroot/

board/

configs/

overlay/

package/

scripts/

README.md

build.sh
21. Overlay
Overlay should contain
etc/

init.d/

network/

wifi/

home/
22. Init Scripts
Responsibilities
initialize framebuffer
initialize networking
initialize USB
initialize audio
launch Pico-8
23. Build Configuration
Provide
rpi_zero2_defconfig
containing all required Buildroot settings.
24. Raspberry Pi Support
Enable
Raspberry Pi firmware
Device Tree
Pi Zero 2 W DTB
GPU firmware
25. Kernel
Use Buildroot-managed Linux kernel.
Enable
Framebuffer
USB HID
Networking
Wi-Fi
ALSA
Input
FAT
EXT4
OverlayFS (optional)
26. Firmware
Include firmware for
brcmfmac
Raspberry Pi GPU
Wi-Fi
27. Performance Goals
Boot time
Target
<10 seconds
Preferred
5–8 seconds
Memory usage
As low as possible.
28. Logging
Console logging minimized.
No verbose boot.
Optional splash screen.
29. Customization
Developers should easily modify
startup cartridge
Wi-Fi configuration
SSH keys
hostname
boot splash
30. Deliverables
The project should include:
Complete Buildroot project
rpi_zero2_defconfig
Board support package
Root filesystem overlay
Init scripts
Build script
Documentation
Flashing instructions
Wi-Fi configuration guide
SSH configuration guide
macOS build guide (including dependency installation)
License information
31. Acceptance Criteria
The project is complete when:
✅ Builds successfully on macOS without manual fixes beyond documented prerequisites.
✅ Produces a bootable SD card image.
✅ Boots on Raspberry Pi Zero 2 W.
✅ Automatically starts Pico-8.
✅ Displays Pico-8 over HDMI.
✅ Supports USB keyboard.
✅ Supports USB controllers.
✅ Connects to Wi-Fi automatically when configured.
✅ Allows SSH access over Wi-Fi.
✅ Supports SCP file transfers.
✅ Uses Buildroot exclusively (no manual package installation on target).
✅ Boots quickly with a minimal footprint.
✅ Is fully reproducible from source.
32. Future Enhancements (Out of Scope)
Potential future work includes:
Bluetooth controller pairing
OTA update mechanism
Web-based configuration UI
Automatic cartridge synchronization over Wi-Fi
USB mass-storage mode for easy file transfer
Read-only root filesystem with persistent overlay
Boot splash screen and custom branding
Multiple Pico-8 cartridge launcher/menu
Support for additional Raspberry Pi models (e.g., Pi 3, Pi 4, Pi 5)
Integration with RetroArch or other emulators as optional packages
