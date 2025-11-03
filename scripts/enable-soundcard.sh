#!/usr/bin/env bash
set -euo pipefail

# enable-soundcard.sh
# Configures the correct HiFiBerry overlay in /boot/firmware/config.txt
# Removes any existing HiFiBerry overlays and adds the correct one based on user selection
# Run with: sudo ./scripts/enable-soundcard.sh

########################################
# Safety checks and environment
########################################
if [ "$(id -u)" -ne 0 ]; then
  echo "This script requires root. Re-running with sudo..."
  exec sudo bash "$0" "$@"
fi

CONFIG_FILE="/boot/firmware/config.txt"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: $CONFIG_FILE not found. This script is designed for Raspberry Pi OS." >&2
  exit 1
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
# Check if HiFiBerry is already configured
########################################
echo "Checking for existing HiFiBerry sound card..."

if command -v aplay >/dev/null 2>&1; then
  # Check if aplay -l shows any HiFiBerry devices
  if aplay -l 2>/dev/null | grep -qi hifiberry; then
    echo ""
    echo "HiFiBerry sound card already detected:"
    echo "======================================"
    aplay -l | grep -i hifiberry || true
    echo ""
    echo "HiFiBerry overlay appears to be already configured."
    echo "Skipping sound card configuration."
    echo ""
    echo "To verify recording capability:"
    echo "  arecord -l"
    echo ""
    exit 0
  else
    echo "No HiFiBerry sound card detected in aplay output."
    echo "Proceeding with configuration..."
    echo ""
  fi
else
  echo "Warning: aplay command not found. Proceeding with configuration..."
  echo ""
fi

########################################
# User selection
########################################
echo "HiFiBerry Sound Card Configuration"
echo "=================================="
echo ""
echo "Please select your HiFiBerry sound card model:"
echo "1) DAC+ADC Standard"
echo "2) DAC+ADC Pro / DAC2 ADC Pro"
echo ""
read -p "Enter your choice (1 or 2): " choice

case "$choice" in
  1)
    OVERLAY="hifiberry-dacplusadc"
    CARD_NAME="DAC+ADC"
    ;;
  2)
    OVERLAY="hifiberry-dacplusadcpro"
    CARD_NAME="DAC+ADC Pro / DAC2 ADC Pro"
    ;;
  *)
    echo "Invalid choice. Exiting."
    exit 1
    ;;
esac

echo ""
echo "Selected: $CARD_NAME"
echo "Overlay: dtoverlay=$OVERLAY"
echo ""

########################################
# Configure overlay in config.txt
########################################
backup_file "$CONFIG_FILE"

echo "Removing any existing HiFiBerry overlays from $CONFIG_FILE..."

# Remove existing HiFiBerry overlay lines (commented or uncommented)
sed -i '/^#*dtoverlay=hifiberry-/d' "$CONFIG_FILE" || true

# Remove any existing onboard/HDMI audio settings so we can set them explicitly
sed -i '/^#*dtparam=audio=/d' "$CONFIG_FILE" || true
sed -i '/^#*hdmi_ignore_audio=/d' "$CONFIG_FILE" || true

echo "Adding dtoverlay=$OVERLAY to $CONFIG_FILE..."

# Check if there's already a [all] section, if not add one
if ! grep -q '^\[all\]' "$CONFIG_FILE"; then
  echo "" >> "$CONFIG_FILE"
  echo "[all]" >> "$CONFIG_FILE"
fi

# Add the overlay after the [all] section
sed -i "/^\[all\]/a dtoverlay=$OVERLAY" "$CONFIG_FILE" || {
  # Fallback: just append to the end of the file
  echo "dtoverlay=$OVERLAY" >> "$CONFIG_FILE"
}

# Ensure onboard analog/HDMI audio are disabled for exclusive HiFiBerry use
# Add dtparam=audio=off and hdmi_ignore_audio=1 under [all] as well
if ! grep -q '^dtparam=audio=off' "$CONFIG_FILE"; then
  sed -i "/^\[all\]/a dtparam=audio=off" "$CONFIG_FILE" || true
fi
if ! grep -q '^hdmi_ignore_audio=1' "$CONFIG_FILE"; then
  sed -i "/^\[all\]/a hdmi_ignore_audio=1" "$CONFIG_FILE" || true
fi

########################################
# Verification and final notes
########################################
echo ""
echo "Configuration complete!"
echo ""
echo "Added overlay: dtoverlay=$OVERLAY"
echo ""
echo "To verify the configuration, check $CONFIG_FILE:"
echo "  grep 'dtoverlay=hifiberry' $CONFIG_FILE"
echo ""
echo "IMPORTANT: Reboot required for changes to take effect:"
echo "  sudo reboot"
echo ""
echo "After reboot, verify the sound card is detected:"
echo "  aplay -l"
echo "  arecord -l"
echo ""
echo "If you need to revert changes, restore the backup:"
echo "  sudo cp $CONFIG_FILE.bak.* $CONFIG_FILE"

exit 0