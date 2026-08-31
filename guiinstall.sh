#!/bin/bash
set -e
#curl -fsSL https://raw.githubusercontent.com/yelrambob/ubuntu/main/nice_dcv_ec2_install.sh | sudo bash

############################################
# NICE DCV Browser-Desktop Installer (Ubuntu EC2)
############################################
# Turns a headless Ubuntu EC2 instance into a full desktop you reach from
# a plain web browser at https://<instance-ip>:8443 — no VPN, no SSH client,
# no RDP/VNC client needed. Installs a minimal GNOME desktop + GDM3, then
# installs and configures the AWS NICE DCV server (free to use on EC2) with
# an automatic console session and its built-in HTML5 web client.
#
# Run this AS ROOT (sudo) on the instance itself. If your workplace blocks
# SSH, you can still get a shell on the instance with zero extra software
# via AWS Systems Manager Session Manager: EC2 console -> select instance
# -> Connect -> "Session Manager" tab -> Connect. That opens a browser-based
# shell with no inbound ports and no SSH keys involved — paste/run this
# script there.

TARGET_USER="${1:-${SUDO_USER:-ubuntu}}"

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  echo "Usage: sudo nice_dcv_ec2_install.sh [linux-username]"
  echo "  Installs a minimal desktop (GNOME + GDM3) and NICE DCV on an Ubuntu"
  echo "  EC2 instance, and configures DCV's HTML5 web client on port 8443 so"
  echo "  the desktop is reachable from any browser at https://<ip>:8443 —"
  echo "  no VPN, SSH, RDP, or VNC client required."
  echo ""
  echo "  [linux-username] defaults to the sudo-invoking user, or 'ubuntu'."
  echo "  This is the account you'll log into the desktop as; the script"
  echo "  sets its password interactively if it doesn't have one yet."
  echo ""
  echo "  Must be run as root (sudo). Reboots the instance when finished."
  echo "  Remember to open inbound TCP 8443 on the instance's security group"
  echo "  (scoped to your office/VPN IP range, not 0.0.0.0/0)."
  exit 0
fi

if [[ $EUID -ne 0 ]]; then
  echo "Run this with sudo: sudo $0 $*" >&2
  exit 1
fi

echo "🔧 Installing NICE DCV browser desktop for user: $TARGET_USER"
sleep 2

############################################
# Detect Ubuntu version / architecture
############################################
UBUNTU_VER="$(lsb_release -rs)"
UBUNTU_CODE="${UBUNTU_VER//./}"   # e.g. 22.04 -> 2204
case "$UBUNTU_VER" in
  20.04|22.04|24.04) ;;
  *)
    echo "❌ Unsupported Ubuntu version: $UBUNTU_VER (NICE DCV supports 20.04/22.04/24.04)" >&2
    exit 1
    ;;
esac

case "$(dpkg --print-architecture)" in
  amd64) DCV_ARCH="x86_64" ;;
  arm64) DCV_ARCH="aarch64" ;;
  *)
    echo "❌ Unsupported architecture: $(dpkg --print-architecture)" >&2
    exit 1
    ;;
esac

############################################
# System update + minimal desktop + GDM3
############################################
# NICE DCV only supports GDM as the display/login manager (any desktop on
# top of it is fine); it also does not support Wayland sessions.
apt update
apt upgrade -y
apt install -y ubuntu-desktop-minimal gdm3

sed -i '/^\[daemon\]/,/^\[/{s/^#\?WaylandEnable=.*/WaylandEnable=false/}' /etc/gdm3/custom.conf
grep -q '^WaylandEnable=false' /etc/gdm3/custom.conf || \
  sed -i '/^\[daemon\]/a WaylandEnable=false' /etc/gdm3/custom.conf

systemctl set-default graphical.target

############################################
# NICE DCV server + web viewer
############################################
WORKDIR="$(mktemp -d)"
cd "$WORKDIR"

wget -q https://d1uj6qtbmh3dt5.cloudfront.net/NICE-GPG-KEY
gpg --import NICE-GPG-KEY

# This "latest" filename always points at the current DCV release for this
# Ubuntu version/arch — no version number to keep updated.
DCV_TGZ="nice-dcv-ubuntu${UBUNTU_CODE}-${DCV_ARCH}.tgz"
wget -q "https://d1uj6qtbmh3dt5.cloudfront.net/${DCV_TGZ}"
tar -xzf "$DCV_TGZ"
cd nice-dcv-*"${DCV_ARCH}"

apt install -y ./nice-dcv-server_*.deb
apt install -y ./nice-dcv-web-viewer_*.deb

cd /
rm -rf "$WORKDIR"

usermod -aG video dcv || true

############################################
# DCV config: auto-start a console session, HTML5 web client on 8443
############################################
cp /etc/dcv/dcv.conf /etc/dcv/dcv.conf.orig 2>/dev/null || true

python3 - "$TARGET_USER" <<'PYEOF'
import configparser, sys
target_user = sys.argv[1]
path = "/etc/dcv/dcv.conf"
c = configparser.ConfigParser(strict=False)
c.read(path)

for section in ("connectivity", "session-management", "session-management/automatic-console-session"):
    if not c.has_section(section):
        c.add_section(section)

c.set("connectivity", "web-port", "8443")
c.set("session-management", "create-session", "true")
c.set("session-management/automatic-console-session", "owner", f'"{target_user}"')

with open(path, "w") as f:
    c.write(f)
PYEOF

systemctl enable dcvserver
systemctl restart dcvserver
systemctl restart gdm3 || true

############################################
# Make sure the login user actually has a usable password
############################################
# DCV authenticates against the normal Linux login (PAM). Cloud images
# ship with SSH-key-only accounts (no password), which can't log into DCV.
if ! id "$TARGET_USER" &>/dev/null; then
  echo "❌ User $TARGET_USER does not exist on this instance." >&2
  exit 1
fi

if [[ "$(passwd -S "$TARGET_USER" | awk '{print $2}')" != "P" ]]; then
  echo ""
  echo "➡ Set a login password for '$TARGET_USER' (used to sign into the DCV desktop):"
  passwd "$TARGET_USER"
fi

############################################
# Done
############################################
TOKEN="$(curl -sX PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null || true)"
PUBLIC_IP="$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "<instance-public-ip>")"

echo ""
echo "✅ INSTALL COMPLETE"
echo "➡ Open inbound TCP 8443 on this instance's security group (scope it to"
echo "  your office IP range, not 0.0.0.0/0), then browse to:"
echo "      https://${PUBLIC_IP}:8443"
echo "  Accept the self-signed certificate warning and log in as '$TARGET_USER'."
echo "➡ Rebooting in 5 seconds to fully apply the GDM/desktop changes..."
sleep 5
reboot
