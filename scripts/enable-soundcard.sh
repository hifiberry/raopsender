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