# Copilot Instructions for raopsender

## Project Overview
This is a HiFiBerry ADC to AirPlay audio streaming solution for Raspberry Pi running Debian Trixie. The project provides system setup infrastructure for a headless audio streaming appliance.

## Architecture & Key Concepts

### Hardware-Software Stack
- **Target Platform**: Raspberry Pi with HiFiBerry ADC boards
- **OS**: Debian Trixie specifically (package names and systemd services are version-specific)
- **Audio Framework**: PipeWire/WirePlumber (modern replacement for PulseAudio/JACK)
- **Deployment Model**: Headless kiosk/appliance with auto-login

### Core Components
- `scripts/setup-trixie-pipewire-autologin.sh`: System initialization script that handles OS configuration, package installation, and service setup
- Missing components (mentioned in README): Audio capture pipeline, systemd services, device-tree overlay configuration

## Development Patterns

### Script Architecture (`scripts/setup-trixie-pipewire-autologin.sh`)
- **Safety-first pattern**: Root privilege checking with automatic sudo elevation
- **Target user detection**: Uses `SUDO_USER` environment variable to identify the actual user
- **Backup strategy**: All config file modifications create timestamped backups (`file.bak.YYYYMMDDHHMMSS`)
- **Best-effort execution**: Critical operations use `|| true` to prevent script failure on edge cases
- **OS validation**: Explicit Debian Trixie detection with warnings for other distributions

### Systemd Integration Patterns
- **User service management**: Enables `loginctl enable-linger` for user services to run without active sessions
- **Getty override technique**: Uses systemd service drops (`/etc/systemd/system/getty@tty1.service.d/override.conf`) for console auto-login
- **Service activation**: User services enabled via `su -l` to ensure proper environment

### Error Handling & Robustness
- Use `set -euo pipefail` for strict bash error handling
- Implement backup functions before modifying system files
- Use `DEBIAN_FRONTEND=noninteractive` for unattended package installation
- Graceful degradation with warning messages rather than hard failures

## Key Commands & Workflows

### Script Execution
```bash
# Make executable and run (script handles sudo internally)
chmod +x ./scripts/setup-trixie-pipewire-autologin.sh
sudo ./scripts/setup-trixie-pipewire-autologin.sh
```

### Typical Next Steps (Post-Setup)
1. Configure HiFiBerry device-tree overlay in `/boot/config.txt`
2. Create audio capture pipeline (PipeWire RAOP, PulseAudio RAOP, or external tools)
3. Implement systemd service for automatic startup

## Project-Specific Conventions

### Character Conventions
- do not use emojis in code or comments
- use clear, descriptive variable and function names

### File Organization
- System setup scripts in `scripts/` directory
- Target Debian Trixie specifically (not generic Linux)
- Focus on headless/kiosk deployment scenarios

### Naming Patterns
- Scripts include target OS version (`trixie`) and main functionality (`pipewire-autologin`)
- Backup files use timestamp suffix pattern: `original.bak.YYYYMMDDHHMMSS`

### Dependencies & Integration Points
- **PipeWire ecosystem**: `pipewire`, `pipewire-pulse`, `wireplumber`, `libspa-0.2-*`
- **Audio tools**: `pavucontrol` for debugging/configuration
- **System integration**: systemd user services, getty autologin, loginctl linger

## Current State & Extension Points
- **Complete**: OS setup, PipeWire installation, auto-login configuration
- **Missing**: Audio capture pipeline implementation, AirPlay streaming service, HiFiBerry device-tree configuration
- **Extension areas**: systemd service creation, audio routing configuration, multi-speaker support