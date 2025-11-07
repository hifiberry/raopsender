# Analog transmitter with a 4" circular VU meter

This project shows how to create a device that can transmit analog audio (e.g. output of a record player a a tape deck) to an Airplay speaker. Is basically consists of 2 parts:

- The Raspberry Pi Airplay sender (this project)
- An 3D printed enclosure with an VU meter

## What you need
- Raspberry Pi. As this project doesn't require a lot of compute power, even a Pi3A will work.
- HiFiBerry ADC. Choose between the DAC+ ADC and the DAC2 ADC Pro. The DAC2 ADC Pro will allow you to adjust the input gain to your source. Therefore, we recommend this one.
- Circular Waveshare 4" DSI display
- 3D printer

# Base setup

- Install Raspberry PI OS Lite (64bit) to an SD card
- Add the HiFiBerry repository:
```
curl -Ls https://tinyurl.com/hbosrepo | bash
```
- Install a minimal HiFiBerryOS
```
sudo apt install -y hbos-minimal
```
- Basic configuration
```
sudo hifiberry-baseconfig
```
- Reboot
- Check that the sound card is detected
```
arecord -l
```
This should show your HiFiBerry sound card:
```
$ arecord -l
**** List of CAPTURE Hardware Devices ****
card 0: sndrpihifiberry [snd_rpi_hifiberry_dacplusadcpro], device 0: HiFiBerry DAC+ADC Pro HiFi multicodec-0 [HiFiBerry DAC+ADC Pro HiFi multicodec-0]
  Subdevices: 1/1
  Subdevice #0: subdevice #0
```

# Install Airplay sender

- Clone this repository
```
sudo apt install -y git
git clone https://github.com/hifiberry/raopsender
```

- Setup the software
```
cd raopsender/scripts
./setup.sh
```

# Sphere enclosure

TODO

# VU meter

After connecting the 4" DSI display, configure it in /boot/firmware/config.txt

```
echo "dtoverlay=vc4-kms-dsi-waveshare-panel,4_0_inchC" | sudo tee -a /boot/firmware/config.txt
```

Check that the display is recognized correctly. You should see boot messages on the screen.

## Install the VU meter

Clone the HiFiBerry VU meter repository:

```bash
git clone https://github.com/hifiberry/hifiberry-vu
cd hifiberry-vu
```

### Install dependencies

The VU meter requires SDL2 libraries and Python dependencies. Install them using the included script:

```bash
# Install SDL2 and system dependencies
cd sdl2
sudo ./install-sdl2
cd ..
```

This will install:
- SDL2 core libraries and extensions (image, mixer, ttf, gfx)
- PySDL2 Python bindings
- Development tools and headers

### Install Python package

Install the VU meter package:

```bash
# Install the package with dependencies
pip3 install --break-system-packages -e .
```

Or install dependencies manually:

```bash
pip3 install --break-system-packages pysdl2 pyaudio numpy
```

### Test the installation

Verify that SDL2 is working:

```bash
python3 sdl2/test-sdl2.py
```

## Run the VU meter

The VU meter can be run in different modes:

### Demo mode (animated needle):
```bash
python3 -m hifiberry_vu.vu_meter --mode=demo --rotate=180
```

### Real-time audio monitoring:
```bash
python3 -m hifiberry_vu.vu_meter --mode=alsa --channel=stereo --rotate=180
```

### Available options:
- `--mode`: `demo` or `alsa` (real audio)
- `--channel`: `left`, `right`, `stereo`, or `max` (for ALSA mode)
- `--rotate`: `0`, `90`, `180`, or `270` degrees
- `--config`: VU meter configuration (`simple` is default)
- `--update-rate`: VU level updates per second (5-60 Hz)
- `--no-fps`: Disable FPS display

### Quick launcher:
```bash
./run.sh
```

This provides an interactive menu to test different modes and configurations.

## Auto-start on login

To automatically start the VU meter when logging in locally (not via SSH):

```bash
./activate-on-local-login
```

This configures the VU meter to start automatically on local console login with optimal settings for the display.

## Environment configuration

For framebuffer rendering, set these environment variables:

```bash
export SDL_VIDEODRIVER=KMSDRM
export SDL_FBDEV=/dev/fb0
export SDL_NOMOUSE=1
```

## Troubleshooting

### Permission issues:
```bash
sudo usermod -a -G video $USER
newgrp video
```

### SDL2 import errors:
```bash
pip3 install --break-system-packages PySDL2
```

### Check available audio devices:
```bash
python3 -c "from hifiberry_vu.python_vu import VUMonitor; VUMonitor().list_audio_devices()"
```




