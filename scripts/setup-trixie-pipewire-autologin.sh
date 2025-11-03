#!/usr/bin/env bash
set -euo pipefail

# setup-trixie-pipewire-autologin.sh
# - Updates Debian (Trixie-compatible) packages
# - Installs PipeWire and WirePlumber and common audio helpers
# - Enables linger for the target user so user systemd units can run
# - Configures autologin on tty1 and common display managers (GDM, LightDM, SDDM) if present
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
# Configure common display managers (best-effort)
########################################
# GDM (gdm3)
if [ -f /etc/gdm3/daemon.conf ]; then
  echo "Configuring GDM autologin"
  backup_file /etc/gdm3/daemon.conf
  # Ensure [daemon] section contains the keys we need
  if ! grep -q "^\[daemon\]" /etc/gdm3/daemon.conf; then
    printf "\n[daemon]\nAutomaticLoginEnable=true\nAutomaticLogin=%s\n" "$TARGET_USER" >> /etc/gdm3/daemon.conf
  else
    # set or replace keys in-place
    sed -i -E "s/^#?[[:space:]]*AutomaticLoginEnable=.*/AutomaticLoginEnable=true/" /etc/gdm3/daemon.conf || true
    sed -i -E "s/^#?[[:space:]]*AutomaticLogin=.*/AutomaticLogin=$TARGET_USER/" /etc/gdm3/daemon.conf || true
    if ! grep -q "^AutomaticLoginEnable=" /etc/gdm3/daemon.conf; then
      sed -i "/^\[daemon\]/a AutomaticLoginEnable=true" /etc/gdm3/daemon.conf || true
    fi
    if ! grep -q "^AutomaticLogin=" /etc/gdm3/daemon.conf; then
      sed -i "/^\[daemon\]/a AutomaticLogin=$TARGET_USER" /etc/gdm3/daemon.conf || true
    fi
  fi
  systemctl restart gdm3.service >/dev/null 2>&1 || true
fi

# LightDM
if [ -d /etc/lightdm ] || [ -f /etc/lightdm/lightdm.conf ]; then
  echo "Configuring LightDM autologin"
  LIGHT_CONF="/etc/lightdm/lightdm.conf.d/50-autologin.conf"
  mkdir -p "$(dirname "$LIGHT_CONF")"
  backup_file "$LIGHT_CONF"
  cat > "$LIGHT_CONF" <<EOF
[Seat:*]
autologin-user=$TARGET_USER
autologin-user-timeout=0
EOF
  systemctl restart lightdm.service >/dev/null 2>&1 || true
fi

# SDDM
if [ -f /etc/sddm.conf ] || [ -d /etc/sddm.conf.d ]; then
  echo "Configuring SDDM autologin"
  SDDM_DIR="/etc/sddm.conf.d"
  mkdir -p "$SDDM_DIR"
  SDDM_CONF="$SDDM_DIR/autologin.conf"
  backup_file "$SDDM_CONF"
  cat > "$SDDM_CONF" <<EOF
[Autologin]
User=$TARGET_USER
Session=
EOF
  systemctl restart sddm.service >/dev/null 2>&1 || true
fi

########################################
# Final notes and warnings
########################################
echo "\nDone. Installed PipeWire and WirePlumber (best-effort)."
echo "Autologin configured for user: $TARGET_USER"

echo "Security notes:"
echo " - Automatic login will allow physical access to the account without a password."
echo " - If this is for a desktop kiosk or dedicated device, it's common; on a multi-user system it may be undesirable."

echo "If you need to revert autologin changes, restore backups created with the .bak.TIMESTAMP suffix in any modified file locations (e.g. /etc/gdm3/daemon.conf.bak.* or files under /etc/lightdm or /etc/sddm.conf.d)."

echo "To make the script executable locally run:"
echo "  chmod +x ./scripts/setup-trixie-pipewire-autologin.sh"

echo "Run it with:"
echo "  sudo ./scripts/setup-trixie-pipewire-autologin.sh"

exit 0
