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
