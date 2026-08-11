alias mmmodule='cd ~magicmirror/modules'
alias mm='cd ~/MagicMirror'
alias mmconfig='sudo nano ~/MagicMirror/config/config.js' #alter mm config
alias plex_stop='cd ~/plex && docker compose down' #Stop Plex
alias plex_start='cd ~/plex && docker compose up -d' #Start Plex
alias pihole_stop='cd ~/pihole && docker compose down' #Stop pihole
alias pihole_start='cd ~/pihole && docker compose up -d' #Start pihole
alias makealias='sudo nano ~/.bash_aliases' #Makes aliases
alias battery='upower -i $(upower -e | grep BAT) | grep -E "state|percentage"' #Check the battery health
alias updatelog='sudo tail -n 30 /var/log/auto-updates.log' #Shows what recently updated
alias seemonitor='for f in /sys/class/drm/*/status; do echo "$f: $(cat $f)"; done' #Lists the monitors
alias checkmonitor='sudo -u sean DISPLAY=:0 XAUTHORITY=/home/sean/.Xauthority xrandr' #Checks the dummy monitors
alias entervenv='source /srv/schedule/venv/bin/activate' #Enter the virtual environment
alias checkvpn='docker exec -it qbittorrent-vpn wget -qO- ifconfig.me/ip' #Check to see if Bitorrent is still on VPN
alias updatealias='source ~/.bash_aliases' #Update any aliases just made
alias checkdisplay='export DISPLAY=:0.0 && xrandr' # looks at the displays becuase xrandr doesnt work over SSH
alias dockerports='docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"'
alias backupnow='sudo timeshift --create --comments "Manual Snapshot $(date +%Y-%m-%d_%H-%M-%S)"'
alias restorenow='sudo timeshift --restore'
alias media-stack='sudo nano ~/docker/media-stack/docker-compose.yml'
alias tbdrive='cd /mnt/10_tb_drive'
alias tbplex='cd /mnt/10_tbdrive'
alias dc='dockercomp'
alias dockerlist='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}"'
alias mntfile='sudo nano /etc/fstab'
alias mnt='sudo mount -a'
#v this one cleans the install buffer if getting an error for not enough space to install something looks like this 
#E: You don't have enough free space in /var/cache/apt/archives/.
alias cleanup='sudo apt-get clean && sudo apt-get autoremove --purge -y && sudo journalctl --vacuum-size=100M' 
# ===== MagicMirror =====
alias checkconfig='node ~/MagicMirror/config/config.js --check'
alias mmmodule='cd ~/MagicMirror/modules'
alias mm='cd ~/MagicMirror'
alias mmconfig='sudo nano -l ~/MagicMirror/config/config.js'

# ===== Docker stacks =====
alias plex_stop='cd ~/plex && docker compose down'
alias plex_start='cd ~/plex && docker compose up -d'
alias pihole_stop='cd ~/pihole && docker compose down'
alias pihole_start='cd ~/pihole && docker compose up -d'

# ===== Editing helpers =====
alias aptup='sudo apt update && sudo apt upgrade -y'
alias makealias='sudo nano ~/.bash_aliases'
alias updatealias='source ~/.bash_aliases'

# ===== Power / hardware =====
alias battery='upower -i $(upower -e | grep BAT) | grep -E "state|percentage"'
alias seemonitor='for f in /sys/class/drm/*/status; do echo "$f: $(cat $f)"; done'
alias checkmonitor='sudo -u sean DISPLAY=:0 XAUTHORITY=/home/sean/.Xauthority xrandr'
alias checkdisplay='export DISPLAY=:0.0 && xrandr'

# ===== Python =====
alias entervenv='source /srv/schedule/venv/bin/activate'

# ===== VPN check =====
alias checkvpn='docker exec -it qbittorrent-vpn wget -qO- ifconfig.me/ip'

# ===== Docker inspection =====
alias dockerports='docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"'
alias dockerlist='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}"'

# ===== Filesystems =====
alias mntfile='sudo nano /etc/fstab'
alias mnt='sudo mount -a'
alias tbdrive='cd /mnt/10_tb_drive'
alias tbplex='cd /mnt/10_tbdrive'

# ===== Git helper =====
gitone () {
  if [[ $1 == -h || $1 == --help ]]; then
    echo "Usage: gitone <path>..."
    echo "  git add the given path(s), commit with an auto-generated message, and push."
    return 0
  fi
  git add "$@"
  git commit -m "update $*"
  git push
}

# ===== Package cleanup (openSUSE) =====
alias cleanup='sudo zypper clean --all && sudo journalctl --vacuum-size=100M'

# ===== Updates / logs =====
alias updatelog='sudo journalctl -u packagekit -n 30 --no-pager'

# ===== Snapper (openSUSE native snapshots) =====
alias backupnow='sudo snapper create --description "Manual Snapshot $(date +%Y-%m-%d_%H-%M-%S)"'
alias restorenow='sudo snapper list'

# ===== Docker Compose shortcuts =====
DOCKER_BASE=~/docker

dockerup() {
  if [[ $1 == -h || $1 == --help ]]; then
    echo "Usage: dockerup <stack>"
    echo "  cd into \$DOCKER_BASE/<stack> and run 'docker compose up -d'."
    return 0
  fi
  if [ -d "$DOCKER_BASE/$1" ]; then
    cd "$DOCKER_BASE/$1" && docker compose up -d
  else
    echo "❌ No such directory: $DOCKER_BASE/$1"
  fi
}

dockerdown() {
  if [[ $1 == -h || $1 == --help ]]; then
    echo "Usage: dockerdown <stack>"
    echo "  cd into \$DOCKER_BASE/<stack> and run 'docker compose down'."
    return 0
  fi
  if [ -d "$DOCKER_BASE/$1" ]; then
    cd "$DOCKER_BASE/$1" && docker compose down
  else
    echo "❌ No such directory: $DOCKER_BASE/$1"
  fi
}

dockerlogs() {
  if [[ $1 == -h || $1 == --help ]]; then
    echo "Usage: dockerlogs <stack>"
    echo "  cd into \$DOCKER_BASE/<stack> and run 'docker compose logs -f'."
    return 0
  fi
  if [ -d "$DOCKER_BASE/$1" ]; then
    cd "$DOCKER_BASE/$1" && docker compose logs -f
  else
    echo "❌ No such directory: $DOCKER_BASE/$1"
  fi
}

dockerupdate() {
  if [[ $1 == -h || $1 == --help ]]; then
    echo "Usage: dockerupdate <stack>"
    echo "  cd into \$DOCKER_BASE/<stack> and run 'docker compose pull && docker compose up -d'."
    return 0
  fi
  if [ -d "$DOCKER_BASE/$1" ]; then
    cd "$DOCKER_BASE/$1" && docker compose pull && docker compose up -d
  else
    echo "❌ No such directory: $DOCKER_BASE/$1"
  fi
}

dockershell() {
  if [[ $1 == -h || $1 == --help ]]; then
    echo "Usage: dockershell <container_name>"
    echo "  Exec into the first running container whose name matches <container_name> (bash, falling back to sh)."
    return 0
  fi
  if [ -z "$1" ]; then
    echo "Usage: dockershell <container_name>"
    return 1
  fi

  container_id=$(docker ps --format '{{.Names}}' | grep -m1 "$1")

  if [ -z "$container_id" ]; then
    echo "❌ No running container matching '$1'"
    return 1
  fi

  echo "🔹 Connecting to $container_id..."
  docker exec -it "$container_id" bash 2>/dev/null || docker exec -it "$container_id" sh
}

dockercomp() {
  if [[ $1 == -h || $1 == --help ]]; then
    echo "Usage: dockercomp <stack>"
    echo "  cd into \$DOCKER_BASE/<stack> and open its docker-compose.yml in nano (sudo)."
    return 0
  fi
  if [ -d "$DOCKER_BASE/$1" ]; then
    cd "$DOCKER_BASE/$1" && sudo nano docker-compose.yml
  else
    echo "❌ No such directory: $DOCKER_BASE/$1"
  fi
}

# ===== Email helper =====
email() {
  if [[ $1 == -h || $1 == --help ]]; then
    echo "Usage: email <file> [subject] [recipient]"
    echo "  Email <file> as a real MIME attachment via Gmail SMTP (curl + base64)."
    echo "  subject   defaults to 'File Report'"
    echo "  recipient defaults to \$EMAIL_TO"
    return 0
  fi
  local file="$1"
  local subject="${2:-File Report}"
  local recipient="${3:-$EMAIL_TO}"

  if [ -z "$file" ]; then
    echo "Usage: email <file> [subject] [recipient]"
    return 1
  fi

  if [ ! -f "$file" ]; then
    echo "❌ File not found: $file"
    return 1
  fi

  if [ -z "$recipient" ]; then
    echo "❌ No recipient given and \$EMAIL_TO is not set" >&2
    return 1
  fi

  local basefile boundary
  basefile=$(basename -- "$file")
  boundary="EMAIL_BOUNDARY_$$_$RANDOM"

  curl --silent --url "smtps://smtp.gmail.com:465" \
    --ssl-reqd \
    --mail-from "$EMAIL_FROM" \
    --mail-rcpt "$recipient" \
    --user "sean.chinery@gmail.com:bjnf bhlh tjxd loip" \
    -T <(
      printf 'Subject: %s\nTo: %s\nMIME-Version: 1.0\nContent-Type: multipart/mixed; boundary="%s"\n\n' "$subject" "$recipient" "$boundary"
      printf -- '--%s\nContent-Type: text/plain; charset="UTF-8"\n\nAttached: %s\n\n' "$boundary" "$basefile"
      printf -- '--%s\nContent-Type: application/octet-stream; name="%s"\nContent-Transfer-Encoding: base64\nContent-Disposition: attachment; filename="%s"\n\n' "$boundary" "$basefile" "$basefile"
      base64 -- "$file"
      printf '\n--%s--\n' "$boundary"
    )

  echo "✅ Sent '$file' to $recipient"
}

emn() {
  if [[ $1 == -h || $1 == --help ]]; then
    echo "Usage: emn <number> [subject] [recipient]"
    echo "  Email item <number> from the last lsn listing as an attachment (see: email -h)."
    return 0
  fi
  (( $# )) || { echo "emn: usage: emn <number> [subject] [recipient]" >&2; return 2; }
  (( ${#LSN_ITEMS[@]} )) || { echo "emn: no list yet — run lsn first" >&2; return 1; }
  local n=$1; shift
  [[ $n =~ ^[0-9]+$ ]] || { echo "emn: '$n' is not a number" >&2; return 2; }
  local idx=$((10#$n))
  local target=${LSN_ITEMS[idx]}
  [[ -n $target ]] || { echo "emn: no item numbered $n" >&2; return 1; }
  email "$target" "$@"
}

