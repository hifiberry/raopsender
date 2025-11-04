# raopsender

## Use case

This project turns a Raspberry Pi with a HiFiBerry ADC board into a live audio sender that captures analog audio from the HiFiBerry ADC and forwards it to AirPlay-compatible speakers.

Typical scenario:
- Hardware: Raspberry Pi (any supported model) with a HiFiBerry ADC (model-specific overlay may be required) attached to the Pi's header.
- OS: Debian Trixie (the included setup script targets this release).
- Goal: Continuously capture from the HiFiBerry ADC and stream the audio in real-time to one or more AirPlay speakers on the local network.

What the repository provides
- A helper script `scripts/setup-trixie-pipewire-autologin.sh` that:
	- updates and upgrades the system,
	- installs PipeWire and WirePlumber,
	- enables user `systemd` linger so user services can run without an active login,
	- configures autologin (tty1 and common display managers) for the user who runs the script (useful for kiosk or dedicated-device setups).

Notes and next steps
- The script focuses on installing PipeWire/WirePlumber and enabling autologin; it does not (by default) create the capture-to-AirPlay pipeline or a systemd service to start it. After running the script you will typically:
	1. Enable the correct HiFiBerry device-tree overlay in `/boot/config.txt` for your specific HiFiBerry ADC model.
	2. Create a small user or system service that captures audio from the HiFiBerry ADC (ALSA) and routes it to an AirPlay sink. Options include:
		 - Using a PipeWire-native RAOP solution if available on your system.
		 - Using PulseAudio's RAOP module (if you prefer PulseAudio compatibility layers).
		 - Running an external sender program or an ffmpeg/arecord pipeline that pushes audio to an RAOP client.
- Security: automatic login removes the password prompt for local console access — only enable on trusted or dedicated devices.

Want help wiring the capture pipeline or adding a systemd service to start the forwarder at boot? Tell me your HiFiBerry model and preferred sender method (PipeWire RAOP, PulseAudio RAOP, or an external sender) and I can add an example service and configuration.

## Recording your analog audio

The raopsender setup also enables high-quality recording from your HiFiBerry ADC. Here's how to record analog sources like vinyl records, cassettes, or any line-level audio.

### Basic Recording Command

```bash
pw-record --format s16 --channels 2 --rate 48000 --target alsa_input.platform-soc_sound.stereo-fallback output.wav
```

### Recording a 25-Minute Vinyl Record Side

For a typical LP side (around 25 minutes), use the `timeout` command to automatically stop recording:

```bash
# Record for exactly 25 minutes (1500 seconds)
timeout 1500s pw-record \
    --format s16 \
    --channels 2 \
    --rate 48000 \
    --target alsa_input.platform-soc_sound.stereo-fallback \
    vinyl_side_$(date +%Y%m%d-%H%M%S).wav
```

### Recording Parameters Explained

- `--format s16`: 16-bit signed integer (CD quality, good balance of quality/file size)
- `--channels 2`: Stereo recording (left and right channels)  
- `--rate 48000`: 48kHz sample rate (matches HiFiBerry DAC+ADC Pro native rate)
- `--target alsa_input.platform-soc_sound.stereo-fallback`: HiFiBerry ADC input device
- `timeout 1500s`: Stop recording after 1500 seconds (25 minutes)

### File Size Estimation

A 25-minute recording at 48kHz/16-bit stereo will be approximately:

- **File size**: ~288 MB (48000 × 2 bytes × 2 channels × 1500 seconds)
- **Duration**: Exactly 25:00 minutes

### Recording Tips

1. **Test audio levels first** with a short recording:

   ```bash
   timeout 10s pw-record --format s16 --channels 2 --rate 48000 \
       --target alsa_input.platform-soc_sound.stereo-fallback test.wav
   ```

2. **Monitor audio levels** during recording (install VU meter first):

   ```bash
   # Install the vumz VU meter (one time setup)
   sudo ./scripts/install-vu-meter
   
   # Monitor HiFiBerry levels in real-time
   hifiberry-vu
   ```

3. **Split long recordings** by track later using audio editing software like Audacity or command-line tools.

### Checking Your Recording

After recording, verify the file:

```bash
# Check file info
file vinyl_side_*.wav

# Play back to test
pw-play vinyl_side_*.wav

# Check duration and technical details
ffprobe vinyl_side_*.wav
```
