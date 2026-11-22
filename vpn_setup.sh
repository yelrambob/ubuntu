#!/bin/bash
# sudo bash vpn_setup.sh ~/Downloads/my-provider.conf      (WireGuard)
# sudo bash vpn_setup.sh ~/Downloads/my-provider.ovpn      (OpenVPN)
#
############################################
# Whole-server VPN (WireGuard or OpenVPN)
############################################
# Routes ALL of this server's outgoing internet traffic through your VPN
# provider (Proton, Mullvad, Surfshark, PIA, Windscribe, ... — download a
# Linux WireGuard .conf or OpenVPN .ovpn file from their website), starts it
# at boot, and keeps these working while the VPN is up:
#   * your LAN — SSH/web/etc. to the server's local IP (192.168.x.x) still works
#   * Tailscale — the 100.x address and MagicDNS name still work
#   * Docker containers' local networks
# Optional --killswitch blocks internet traffic if the VPN drops (LAN and
# Tailscale stay reachable even then).
#
# What does NOT work with a whole-server VPN: reaching the server from the
# internet via your home public IP + router port-forwarding (replies leave
# via the VPN). Use Tailscale for remote access instead.

set -e

NAME=vpn
KILLSWITCH=0
CONF=""

usage() {
  cat <<EOF
Usage: sudo vpn_setup.sh <provider-file.conf|.ovpn> [--killswitch]
       sudo vpn_setup.sh --status | --off | --on | --remove

  <file>.conf   WireGuard config from your VPN provider (recommended: faster)
  <file>.ovpn   OpenVPN config; you'll be asked for the VPN username/password
                (these are the provider's "OpenVPN/manual" credentials, often
                different from your account login)
  --killswitch  Block internet traffic outside the VPN (WireGuard only).
                LAN and Tailscale keep working.
  --status      Show VPN status and your current public IP
  --off / --on  Stop / start the VPN (stays enabled at boot unless --remove)
  --remove      Stop the VPN and disable it at boot (config files are kept)
EOF
}

svc_name() {
  if [[ -f /etc/wireguard/$NAME.conf ]]; then echo "wg-quick@$NAME"
  elif [[ -f /etc/openvpn/client/$NAME.conf ]]; then echo "openvpn-client@$NAME"
  fi
}

case $1 in
  ""|-h|--help) usage; exit 0 ;;
esac

if [[ $EUID -ne 0 ]]; then
  echo "Run this as root: sudo $0 $*" >&2
  exit 1
fi

case $1 in
  --status)
    s=$(svc_name); [[ -z $s ]] && { echo "No VPN configured."; exit 0; }
    systemctl --no-pager status "$s" | head -5
    command -v wg >/dev/null && wg show 2>/dev/null | head -12
    echo "Public IP: $(curl -s -m 5 ifconfig.me || echo unknown)"
    exit 0 ;;
  --off)    s=$(svc_name); systemctl stop "$s"; echo "VPN stopped ($s)."; exit 0 ;;
  --on)     s=$(svc_name); systemctl start "$s"; echo "VPN started ($s)."; exit 0 ;;
  --remove) s=$(svc_name); systemctl disable --now "$s"; echo "VPN stopped and disabled at boot."; exit 0 ;;
esac

for arg in "$@"; do
  case $arg in
    --killswitch) KILLSWITCH=1 ;;
    -*) echo "Unknown option: $arg" >&2; usage; exit 1 ;;
    *) CONF=$arg ;;
  esac
done
[[ -f $CONF ]] || { echo "Config file not found: $CONF" >&2; exit 1; }

# ---- Detect the LAN ------------------------------------------------------
LAN_IF=$(ip -4 route show default | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
LAN_NET=$(ip -4 route show dev "$LAN_IF" proto kernel scope link 2>/dev/null | awk 'NR==1{print $1}')
LAN_IP=$(ip -4 -o addr show dev "$LAN_IF" 2>/dev/null | awk 'NR==1{split($4,a,"/"); print a[1]}')
[[ -n $LAN_NET ]] || { echo "Couldn't detect your LAN subnet — is the network up?" >&2; exit 1; }
echo "LAN: $LAN_NET on $LAN_IF (this server: $LAN_IP) — will stay reachable."
BEFORE_IP=$(curl -s -m 5 ifconfig.me || true)

# Stop any VPN this script set up before, so we start clean.
old=$(svc_name); [[ -n $old ]] && systemctl disable --now "$old" 2>/dev/null || true

export DEBIAN_FRONTEND=noninteractive

if [[ $CONF == *.conf ]]; then
  # ======================= WireGuard =======================
  apt-get update
  apt-get install -y wireguard-tools iptables curl
  install -d -m 700 /etc/wireguard
  dest=/etc/wireguard/$NAME.conf

  # Strip lines we manage ourselves: DNS (handled via systemd-resolved below,
  # avoiding the resolvconf dependency) and any provider Post/Pre hooks.
  DNS_SERVERS=$(awk -F= 'tolower($1) ~ /^[ \t]*dns[ \t]*$/ {gsub(/[ \t]/,"",$2); print $2}' "$CONF" | tr ',' ' ' | xargs -n1 | grep -E '^[0-9a-fA-F.:]+$' | xargs)
  grep -viE '^[[:space:]]*(DNS|PostUp|PostDown|PreUp|PreDown)[[:space:]]*=' "$CONF" > "$dest.tmp"

  # Build our hooks and insert them right after the [Interface] header.
  hooks=$(mktemp)
  {
    # LAN traffic always uses the normal routing table, never the tunnel.
    echo "PostUp = ip rule add to $LAN_NET lookup main priority 100"
    echo "PreDown = ip rule del to $LAN_NET lookup main priority 100 || true"
    if [[ -n $DNS_SERVERS ]]; then
      echo "PostUp = resolvectl dns %i $DNS_SERVERS && resolvectl domain %i '~.' && resolvectl default-route %i yes"
    fi
    if (( KILLSWITCH )); then
      # Dedicated chain: allow loopback, the tunnel itself, the tunnel's own
      # encrypted packets (wg fwmark), LAN, Tailscale (interface + tailscaled's
      # own packets, mark 0x80000), and Docker bridges; reject everything else.
      ks="iptables -N VPN_KS 2>/dev/null || true; iptables -F VPN_KS"
      ks+="; iptables -A VPN_KS -o lo -j ACCEPT"
      ks+="; iptables -A VPN_KS -o %i -j ACCEPT"
      ks+="; iptables -A VPN_KS -m mark --mark \$(wg show %i fwmark) -j ACCEPT"
      ks+="; iptables -A VPN_KS -d $LAN_NET -j ACCEPT"
      ks+="; iptables -A VPN_KS -o tailscale0 -j ACCEPT"
      ks+="; iptables -A VPN_KS -m mark --mark 0x80000/0xff0000 -j ACCEPT"
      ks+="; iptables -A VPN_KS -o docker+ -j ACCEPT; iptables -A VPN_KS -o br-+ -j ACCEPT"
      ks+="; iptables -A VPN_KS -m addrtype --dst-type LOCAL -j ACCEPT"
      ks+="; iptables -A VPN_KS -j REJECT"
      ks+="; iptables -C OUTPUT -j VPN_KS 2>/dev/null || iptables -I OUTPUT -j VPN_KS"
      echo "PostUp = $ks"
      echo "PreDown = iptables -D OUTPUT -j VPN_KS 2>/dev/null; iptables -F VPN_KS 2>/dev/null; iptables -X VPN_KS 2>/dev/null; true"
      # Same idea for IPv6, so nothing leaks over v6 when the tunnel drops.
      ks6="ip6tables -N VPN_KS 2>/dev/null || true; ip6tables -F VPN_KS"
      ks6+="; ip6tables -A VPN_KS -o lo -j ACCEPT"
      ks6+="; ip6tables -A VPN_KS -o %i -j ACCEPT"
      ks6+="; ip6tables -A VPN_KS -m mark --mark \$(wg show %i fwmark) -j ACCEPT"
      ks6+="; ip6tables -A VPN_KS -o tailscale0 -j ACCEPT"
      ks6+="; ip6tables -A VPN_KS -m mark --mark 0x80000/0xff0000 -j ACCEPT"
      ks6+="; ip6tables -A VPN_KS -d fe80::/10 -j ACCEPT"
      ks6+="; ip6tables -A VPN_KS -m addrtype --dst-type LOCAL -j ACCEPT"
      ks6+="; ip6tables -A VPN_KS -j REJECT"
      ks6+="; ip6tables -C OUTPUT -j VPN_KS 2>/dev/null || ip6tables -I OUTPUT -j VPN_KS"
      echo "PostUp = $ks6 || true"
      echo "PreDown = ip6tables -D OUTPUT -j VPN_KS 2>/dev/null; ip6tables -F VPN_KS 2>/dev/null; ip6tables -X VPN_KS 2>/dev/null; true"
    fi
  } > "$hooks"
  awk -v hf="$hooks" '{print} /^[ \t]*\[Interface\][ \t]*$/ {while ((getline l < hf) > 0) print l}' "$dest.tmp" > "$dest"
  rm -f "$dest.tmp" "$hooks"
  chmod 600 "$dest"

  SVC="wg-quick@$NAME"

elif [[ $CONF == *.ovpn ]]; then
  # ======================= OpenVPN =======================
  (( KILLSWITCH )) && echo "NOTE: --killswitch is only implemented for WireGuard; continuing without it."
  apt-get update
  apt-get install -y openvpn curl
  # Lets the provider's pushed DNS servers take effect (prevents DNS leaks).
  apt-get install -y openvpn-systemd-resolved || true
  install -d -m 700 /etc/openvpn/client
  dest=/etc/openvpn/client/$NAME.conf
  grep -viE '^[[:space:]]*auth-user-pass' "$CONF" > "$dest"

  if [[ ! -f /etc/openvpn/client/$NAME.auth ]]; then
    read -rp "VPN username: " VU </dev/tty
    read -rsp "VPN password: " VP </dev/tty; echo
    printf '%s\n%s\n' "$VU" "$VP" > /etc/openvpn/client/$NAME.auth
  fi
  chmod 600 /etc/openvpn/client/$NAME.auth "$dest"
  {
    echo
    echo "# --- added by vpn_setup.sh ---"
    echo "auth-user-pass /etc/openvpn/client/$NAME.auth"
    # Keep the LAN on the normal gateway, even if the provider pushes routes.
    echo "route ${LAN_NET%/*} $(python3 -c "import ipaddress,sys;print(ipaddress.ip_network(sys.argv[1]).netmask)" "$LAN_NET") net_gateway"
    if [[ -x /etc/openvpn/update-systemd-resolved ]]; then
      echo "script-security 2"
      echo "up /etc/openvpn/update-systemd-resolved"
      echo "down /etc/openvpn/update-systemd-resolved"
      echo "down-pre"
    fi
    echo "persist-tun"
    echo "persist-key"
  } >> "$dest"
  SVC="openvpn-client@$NAME"
else
  echo "File must end in .conf (WireGuard) or .ovpn (OpenVPN)." >&2
  exit 1
fi

systemctl enable --now "$SVC"
sleep 5

AFTER_IP=$(curl -s -m 8 ifconfig.me || true)
echo
echo "================ VPN status ================"
systemctl --no-pager is-active "$SVC" >/dev/null && echo " Service:        $SVC (running, starts at boot)" \
                                               || { echo " Service $SVC FAILED — see: journalctl -u $SVC -n 50"; exit 1; }
echo " Public IP before: ${BEFORE_IP:-unknown}"
echo " Public IP now:    ${AFTER_IP:-unknown (no internet? check: journalctl -u $SVC)}"
[[ -n $AFTER_IP && $AFTER_IP == "$BEFORE_IP" ]] && echo " WARNING: public IP didn't change — traffic may not be going through the VPN."
echo " LAN access:       still works at $LAN_IP (e.g. ssh $(logname 2>/dev/null || echo user)@$LAN_IP)"
command -v tailscale >/dev/null && echo " Tailscale:        $(tailscale ip -4 2>/dev/null | head -1) (unaffected)"
echo
echo " Manage it:  sudo bash vpn_setup.sh --status | --off | --on | --remove"
