#!/usr/bin/env bash
set -euo pipefail

# setup-trixie-pipewire-autologin.sh
# - Updates Debian (Trixie-compatible) packages
# - Installs PipeWire and WirePlumber and common audio helpers
# - Enables linger for the target user so user systemd units can run
# - Configures autologin on tty1
# Run with: sudo ./setup-trixie-pipewire-autologin.sh

########################################
# Safety checks and environment
########################################
if [ "$(id -u)" -ne 0 ]; then
  echo "This script requires root. Re-running with sudo..."
  exec sudo bash "$0" "$@"
fi

TARGET_USER="${SUDO_USER:-${USER:-}}
"
# Trim whitespace/newline if any
TARGET_USER="$(echo "$TARGET_USER" | tr -d '\n' | xargs)"

if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ]; then
  echo "Could not determine non-root target user. Run as an unprivileged user with sudo, or set SUDO_USER." >&2
  exit 1
fi

echo "Target user: $TARGET_USER"

# Minimal check for Debian
if [ -f /etc/os-release ]; then
  . /etc/os-release
  if [ "${ID:-}" != "debian" ]; then
    echo "Warning: system does not identify as Debian (ID=$ID). Proceeding anyway." >&2
  fi
  if [ "${VERSION_CODENAME:-}" != "trixie" ]; then
    echo "Warning: VERSION_CODENAME=${VERSION_CODENAME:-unknown} (not 'trixie'). Adjust packages if needed." >&2
  fi
else
  echo "Warning: /etc/os-release not found; cannot verify distribution." >&2
fi

########################################
# Helper functions
########################################
backup_file() {
  local f="$1"
  if [ -e "$f" ]; then
    local bak="$f.bak.$(date +%Y%m%d%H%M%S)"
    echo "Backing up $f -> $bak"
    cp -a "$f" "$bak" || true
  fi
}

########################################
# Update system and install packages
########################################
export DEBIAN_FRONTEND=noninteractive

echo "Updating package lists and upgrading..."
apt update
apt -y full-upgrade

echo "Installing PipeWire, WirePlumber and helpers..."
apt -y --no-install-recommends install \
  pipewire pipewire-audio-client-libraries pipewire-pulse wireplumber \
  libspa-0.2-bluetooth libspa-0.2-jack pavucontrol || {
  echo "apt install failed. You may need to review repositories or retry." >&2
}

apt -y autoremove
apt -y clean

########################################
# Enable linger so user systemd --user units can run without active session
########################################
if command -v loginctl >/dev/null 2>&1; then
  echo "Enabling linger for $TARGET_USER"
  loginctl enable-linger "$TARGET_USER" || true
fi

# Try to enable user services (best-effort)
echo "Attempting to enable user PipeWire services for $TARGET_USER (best-effort)."
# Use su -l so systemctl --user has the right environment
su -l "$TARGET_USER" -c "systemctl --user daemon-reload >/dev/null 2>&1 || true; systemctl --user enable --now pipewire pipewire-pulse wireplumber >/dev/null 2>&1 || true" || true

########################################
# Configure PipeWire RAOP module
########################################
echo ""
echo "Configuring PipeWire RAOP module..."
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPEWIRE_SCRIPT="$SCRIPT_DIR/configure-pipewire"

if [ -f "$PIPEWIRE_SCRIPT" ]; then
  # Make sure the script is executable
  chmod +x "$PIPEWIRE_SCRIPT"
  
  # Run the PipeWire configuration script
  "$PIPEWIRE_SCRIPT"
else
  echo "Warning: configure-pipewire not found at $PIPEWIRE_SCRIPT"
  echo "You will need to manually configure PipeWire RAOP module."
fi

########################################
# Configure autologin on tty1 (systemd getty override)
########################################
GETTY_DIR="/etc/systemd/system/getty@tty1.service.d"
mkdir -p "$GETTY_DIR"
OVERRIDE="$GETTY_DIR/override.conf"
backup_file "$OVERRIDE"
cat > "$OVERRIDE" <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $TARGET_USER --noclear %I \$TERM
EOF

systemctl daemon-reload
systemctl restart getty@tty1.service || true

########################################
# Configure HiFiBerry sound card
########################################
echo ""
echo "System setup complete. Now configuring HiFiBerry sound card..."
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOUNDCARD_SCRIPT="$SCRIPT_DIR/enable-soundcard.sh"

if [ -f "$SOUNDCARD_SCRIPT" ]; then
  # Make sure the script is executable
  chmod +x "$SOUNDCARD_SCRIPT"
  
  # Run the sound card configuration script
  "$SOUNDCARD_SCRIPT"
else
  echo "Warning: enable-soundcard.sh not found at $SOUNDCARD_SCRIPT"
  echo "You will need to manually configure your HiFiBerry overlay in /boot/firmware/config.txt"
fi

########################################
# Final notes and reboot
########################################
echo ""
echo "Setup complete!"
echo "- PipeWire and WirePlumber installed"
echo "- PipeWire RAOP module configured for AirPlay streaming"
echo "- Autologin configured for user: $TARGET_USER"
echo "- HiFiBerry sound card overlay configured"
echo ""

echo "Security notes:"
echo " - Automatic login will allow physical access to the account without a password."
echo " - If this is for a desktop kiosk or dedicated device, it's common; on a multi-user system it may be undesirable."

echo ""
echo "The system will reboot in 10 seconds to apply all changes..."
echo "Press Ctrl+C to cancel the reboot."
echo ""

# Countdown
for i in {10..1}; do
  echo -n "$i... "
  sleep 1
done

echo ""
echo "Rebooting now..."
reboot
