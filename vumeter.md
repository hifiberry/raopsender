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

# VU meter

After connecting the 4" DSI display, configure it in /boot/firmware/config.txt

```
dtoverlay=vc4-kms-dsi-waveshare-panel,4_0_inchC
```






