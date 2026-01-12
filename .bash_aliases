#Aliases I've made

alias checkconfig='node ~/MagicMirror/config/config.js --check'
alias mmmodule='cd ~/MagicMirror/modules'
alias mm='cd ~/MagicMirror'
alias mmconfig='sudo nano -l ~/MagicMirror/config/config.js' #alter mm config
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
gitone () {
  git add "$@"
  git commit -m "update $*"
  git push
}

#v this one cleans the install buffer if getting an error for not enough space to install something looks like this 
#E: You don't have enough free space in /var/cache/apt/archives/.
alias cleanup='sudo apt-get clean && sudo apt-get autoremove --purge -y && sudo journalctl --vacuum-size=100M' 

# ===== Docker Shortcuts for Individual App Folders =====
# Usage examples:
#   dockerup homeassistant
#   dockerdown plex
#   dockerlogs pihole
#   dockerupdate portainer

# Base Docker directory
DOCKER_BASE=~/docker/

dockerup() {
  if [ -d "$DOCKER_BASE/$1" ]; then
    cd "$DOCKER_BASE/$1" && docker compose up -d
  else
    echo "❌ No such directory: $DOCKER_BASE/$1"
  fi
}

dockerdown() {
  if [ -d "$DOCKER_BASE/$1" ]; then
    cd "$DOCKER_BASE/$1" && docker compose down
  else
    echo "❌ No such directory: $DOCKER_BASE/$1"
  fi
}

dockerlogs() {
  if [ -d "$DOCKER_BASE/$1" ]; then
    cd "$DOCKER_BASE/$1" && docker compose logs -f
  else
    echo "❌ No such directory: $DOCKER_BASE/$1"
  fi
}

dockerupdate() {
  if [ -d "$DOCKER_BASE/$1" ]; then
    cd "$DOCKER_BASE/$1" && docker compose pull && docker compose up -d
  else
    echo "❌ No such directory: $DOCKER_BASE/$1"
  fi
}

dockershell() {
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


dockercomp      () {
  if [ -d "$DOCKER_BASE/$1" ]; then
    cd "$DOCKER_BASE/$1" && sudo nano docker-compose.yml
  else
    echo "❌ No such directory: $DOCKER_BASE/$1"
  fi
}
email() {
  local file="$1"
  local subject="${2:-File Report}"
  local recipient="${3:-$EMAIL_TO}"  # Optional 3rd arg to override recipient
  
  if [ -z "$file" ]; then
    echo "Usage: email <file> [subject] [recipient]"
    return 1
  fi
  
  if [ ! -f "$file" ]; then
    echo "❌ File not found: $file"
    return 1
  fi
 
  curl --silent --url "smtps://smtp.gmail.com:465" \
    --ssl-reqd \
    --mail-from "$EMAIL_FROM" \
    --mail-rcpt "$recipient" \
    --user "sean.chinery@gmail.com:bjnf bhlh tjxd loip" \
    -T <(echo -e "Subject: $subject\n\n$(cat "$file")")
  
  echo "✅ Sent '$file' to $recipient"
}

 
# Usage:
# sendemail modified_configs.txt "Config Report"
# cat /var/log/syslog | sendemail - "Syslog"


# Load custom functions
if [ -f ~/.bash_functions ]; then
    source ~/.bash_functions
fi
