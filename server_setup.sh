#!/bin/bash
# curl -fsSL https://raw.githubusercontent.com/yelrambob/ubuntu/main/server_setup.sh | sudo bash
#   (pass options with:  ... | sudo bash -s -- --subnet --exit-node)
#
############################################
# Home server setup (Ubuntu / Ubuntu MATE)
############################################
# Sets up a home box to run as an always-on server:
#   * everyday CLI tools (curl, git, htop, tmux, ncdu, jq, ...)
#   * OpenSSH server
#   * Tailscale (reach the box from anywhere, no port forwarding)
#   * UFW firewall: SSH + everything from your LAN + everything over Tailscale
#   * fail2ban (bans IPs that brute-force SSH)
#   * automatic security updates (unattended-upgrades)
#   * Docker + compose plugin (from Ubuntu's own repos)
#   * never sleep/suspend, and keep running with a laptop lid closed
# Safe to re-run: every step checks before changing things.

set -e

SUBNET=0; EXIT_NODE=0; DOCKER=1; COCKPIT=0; TS_SSH=0
TARGET_USER="${SUDO_USER:-$USER}"

usage() {
  cat <<EOF
Usage: sudo server_setup.sh [options]
  --subnet      Let Tailscale devices reach your whole LAN through this box
                (advertises the LAN as a subnet route; approve it in the
                Tailscale admin console afterwards)
  --exit-node   Offer this box as a Tailscale exit node (route your phone's
                internet through home); approve it in the admin console
  --tailscale-ssh  Enable Tailscale SSH (log in with your Tailscale identity)
  --cockpit     Install Cockpit, a web admin panel on port 9090
  --no-docker   Skip installing Docker
  -h, --help    Show this help

Tailscale login: the script prints a URL to open, or set TS_AUTHKEY=tskey-...
in the environment (sudo TS_AUTHKEY=... bash server_setup.sh) to log in
unattended. Run as root (sudo).
EOF
}

for arg in "$@"; do
  case $arg in
    --subnet) SUBNET=1 ;;
    --exit-node) EXIT_NODE=1 ;;
    --tailscale-ssh) TS_SSH=1 ;;
    --cockpit) COCKPIT=1 ;;
    --no-docker) DOCKER=0 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; usage; exit 1 ;;
  esac
done

if [[ $EUID -ne 0 ]]; then
  echo "Run this as root: sudo $0 $*" >&2
  exit 1
fi

step() { echo; echo "==> $*"; }

# ---- Detect the LAN (interface, subnet, IP) ------------------------------
LAN_IF=$(ip -4 route show default | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
LAN_NET=$(ip -4 route show dev "$LAN_IF" proto kernel scope link 2>/dev/null | awk 'NR==1{print $1}')
LAN_IP=$(ip -4 -o addr show dev "$LAN_IF" 2>/dev/null | awk 'NR==1{split($4,a,"/"); print a[1]}')
echo "LAN interface: ${LAN_IF:-?}   subnet: ${LAN_NET:-?}   this box: ${LAN_IP:-?}"

export DEBIAN_FRONTEND=noninteractive

# ---- Packages ------------------------------------------------------------
step "Updating packages and installing tools"
apt-get update
apt-get upgrade -y
apt-get install -y \
  curl wget git ca-certificates gnupg \
  htop btop ncdu tree jq unzip zip rsync tmux nano vim \
  net-tools dnsutils iperf3 nmap traceroute \
  lm-sensors smartmontools \
  mpack mutt \
  openssh-server ufw fail2ban unattended-upgrades

# ---- SSH -----------------------------------------------------------------
step "Enabling SSH"
systemctl enable --now ssh

# ---- Automatic security updates ------------------------------------------
step "Turning on automatic security updates"
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
systemctl enable --now unattended-upgrades

# ---- fail2ban ------------------------------------------------------------
step "Configuring fail2ban for SSH"
cat > /etc/fail2ban/jail.d/sshd.local <<EOF
[sshd]
enabled  = true
backend  = systemd
maxretry = 5
findtime = 10m
bantime  = 1h
# never ban your own LAN or Tailscale devices
ignoreip = 127.0.0.1/8 ::1 ${LAN_NET} 100.64.0.0/10
EOF
systemctl enable fail2ban
systemctl restart fail2ban

# ---- Never sleep; ignore laptop lid --------------------------------------
step "Disabling sleep/suspend (and lid-close suspend)"
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target >/dev/null
mkdir -p /etc/systemd/logind.conf.d
cat > /etc/systemd/logind.conf.d/10-server-lid.conf <<'EOF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
EOF
# Applies at next boot (restarting logind now would end the desktop session).

# ---- Tailscale -----------------------------------------------------------
step "Installing Tailscale"
if ! command -v tailscale >/dev/null; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi
systemctl enable --now tailscaled

if (( SUBNET || EXIT_NODE )); then
  # Needed for subnet routes / exit node to forward traffic.
  cat > /etc/sysctl.d/99-tailscale.conf <<'EOF'
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF
  sysctl -p /etc/sysctl.d/99-tailscale.conf >/dev/null
fi

TS_ARGS=()
(( SUBNET )) && [[ -n $LAN_NET ]] && TS_ARGS+=(--advertise-routes="$LAN_NET")
(( EXIT_NODE )) && TS_ARGS+=(--advertise-exit-node)
(( TS_SSH )) && TS_ARGS+=(--ssh)
[[ -n $TS_AUTHKEY ]] && TS_ARGS+=(--authkey="$TS_AUTHKEY")

echo "Starting Tailscale — if a login URL appears, open it on any device."
tailscale up --reset "${TS_ARGS[@]}"

# ---- Firewall ------------------------------------------------------------
step "Configuring UFW firewall"
ufw allow OpenSSH >/dev/null
[[ -n $LAN_NET ]] && ufw allow from "$LAN_NET" comment 'LAN' >/dev/null
ufw allow in on tailscale0 comment 'Tailscale' >/dev/null
ufw allow 41641/udp comment 'Tailscale direct connections' >/dev/null
if (( SUBNET || EXIT_NODE )); then
  sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
fi
ufw default deny incoming >/dev/null
ufw default allow outgoing >/dev/null
ufw --force enable
ufw status verbose

# ---- Docker --------------------------------------------------------------
if (( DOCKER )); then
  step "Installing Docker"
  if ! command -v docker >/dev/null; then
    apt-get install -y docker.io docker-compose-v2 || apt-get install -y docker.io docker-compose-plugin
  fi
  systemctl enable --now docker
  if [[ -n $TARGET_USER && $TARGET_USER != root ]]; then
    usermod -aG docker "$TARGET_USER"
    echo "Added $TARGET_USER to the docker group (log out and back in to use docker without sudo)."
  fi
  echo "NOTE: Docker-published ports bypass UFW. Bind private services to the"
  echo "      LAN/Tailscale IP (e.g. \"${LAN_IP:-192.168.1.x}:8080:8080\") if they shouldn't be public."
fi

# ---- Cockpit -------------------------------------------------------------
if (( COCKPIT )); then
  step "Installing Cockpit (web admin on :9090)"
  apt-get install -y cockpit
  systemctl enable --now cockpit.socket
fi

# ---- Summary -------------------------------------------------------------
TS_IP=$(tailscale ip -4 2>/dev/null | head -1)
TS_NAME=$(tailscale status --json 2>/dev/null | jq -r '.Self.DNSName // empty' | sed 's/\.$//')
echo
echo "================ Done ================"
echo " SSH on your LAN:      ssh $TARGET_USER@${LAN_IP:-<lan-ip>}"
echo " SSH over Tailscale:   ssh $TARGET_USER@${TS_IP:-<tailscale-ip>}   ${TS_NAME:+(or $TS_NAME)}"
(( COCKPIT )) && echo " Cockpit:              https://${LAN_IP:-<lan-ip>}:9090"
(( SUBNET || EXIT_NODE )) && echo " Approve the subnet route / exit node at https://login.tailscale.com/admin/machines"
echo " Tip: in the admin console, 'Disable key expiry' for this machine so it never logs out."
echo " Tip: give this box a DHCP reservation in your router so its LAN IP never changes."
echo " Reboot once to apply the lid-close setting: sudo reboot"
