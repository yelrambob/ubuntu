#!/bin/bash
set -e
#curl -fsSL https://raw.githubusercontent.com/yelrambob/ubuntu/main/mm_kiosk_install.sh | bash

############################################
# MagicMirror Kiosk Installer (Pi OS Lite)
############################################

MM_URL="http://34.26.147.91:8080"
USER_NAME="$(logname)"
HOME_DIR="/home/$USER_NAME"

echo "🔧 Installing MagicMirror kiosk for user: $USER_NAME"
sleep 2

############################################
# System update
############################################
sudo apt update
sudo apt upgrade -y

############################################
# Install kiosk dependencies
############################################
sudo apt install -y \
  xserver-xorg \
  xinit \
  openbox \
  chromium-browser \
  unclutter \
  watchdog

############################################
# Enable console auto-login
############################################
sudo raspi-config nonint do_boot_behaviour B2

############################################
# Create kiosk launcher
############################################
mkdir -p "$HOME_DIR/.local/bin"

cat <<EOF > "$HOME_DIR/.local/bin/kiosk.sh"
#!/bin/bash
sleep 10
xset -dpms
xset s off
xset s noblank
unclutter &
exec chromium-browser \
  --kiosk \
  --noerrdialogs \
  --disable-infobars \
  --disable-session-crashed-bubble \
  --disable-translate \
  --disable-features=TranslateUI \
  $MM_URL
EOF

chmod +x "$HOME_DIR/.local/bin/kiosk.sh"

############################################
# Auto-start X on login
############################################
cat <<EOF > "$HOME_DIR/.bash_profile"
if [[ -z "\$DISPLAY" ]] && [[ "\$(tty)" == "/dev/tty1" ]]; then
  startx
fi
EOF

############################################
# X init config
############################################
cat <<EOF > "$HOME_DIR/.xinitrc"
#!/bin/sh
exec openbox-session &
exec $HOME_DIR/.local/bin/kiosk.sh
EOF

chmod +x "$HOME_DIR/.xinitrc"

############################################
# Disable screen blanking (Openbox)
############################################
mkdir -p /etc/xdg/openbox
sudo tee /etc/xdg/openbox/autostart >/dev/null <<EOF
xset -dpms
xset s off
xset s noblank
EOF

############################################
# GPU memory
############################################
if ! grep -q "gpu_mem=" /boot/config.txt; then
  echo "gpu_mem=128" | sudo tee -a /boot/config.txt
else
  sudo sed -i 's/gpu_mem=.*/gpu_mem=128/' /boot/config.txt
fi

############################################
# Enable watchdog
############################################
sudo systemctl enable watchdog

############################################
# Ownership fixes
############################################
sudo chown -R "$USER_NAME:$USER_NAME" "$HOME_DIR"

############################################
# Done
############################################
echo ""
echo "✅ INSTALL COMPLETE"
echo "➡ Rebooting in 5 seconds..."
sleep 5
sudo reboot
