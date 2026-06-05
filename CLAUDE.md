# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repo hosts installer shell scripts for SunFounder Raspberry Pi HAT products. Scripts are fetched at runtime by end users via `curl | sudo bash` from the `main` branch. There is no build step, test suite, or linting — changes go live immediately upon merge to `main`.

## Architecture

**Two installer framework generations live side by side in `tools/`:**

- **v1.0** (`installer.sh` + `progress_bar.sh`) — Older style. Product scripts build a `COMMANDS` bash array of eval-able strings, then call `install $COMMANDS`. Used by `install-tft35ips.sh` and `install_portainer.sh`.
- **v1.1.0** (`installer_1.1.0.sh` + `progress_bar_1.1.0.sh`) — Current standard. Uses a declarative DSL: product scripts call `TITLE`, `RUN`, `CD`, `CLONE`, `DTOVERLAY_ADD` to queue operations, then `installer_install` executes them with a progress bar. Supports Gitee fallback for mainland China users. Used by all recent product installers.

**DSL commands (v1.1.0):**
| Command | Usage | Description |
|---------|-------|-------------|
| `TITLE` | `TITLE "Section name"` | Section header, no progress count |
| `RUN` | `RUN "command" "description"` | Shell command with progress step |
| `CD` | `CD "/path"` | Change working directory |
| `CLONE` | `CLONE "url" "branch"` | Git clone with progress step |
| `DTOVERLAY_ADD` | `DTOVERLAY_ADD "overlay.dtbo"` | Add dtoverlay to config.txt; auto-skips if already present |

**Product installer scripts** (root level) each follow this pattern:
1. Set `INSTALLER_URL` pointing to the framework on `refs/heads/main`
2. `curl` + `source` the framework, then `rm` it
3. Define operations using the framework's DSL or COMMANDS array
4. Call the framework's install function
5. Optionally prompt for reboot

**Audio setup scripts** (`setup_*_hat_audio.sh`) are standalone — they don't use the installer framework. They configure ALSA, PulseAudio, and `/boot/config.txt` for HAT soundcards. They are meant to be re-run after reboot.

**`tools/config_txt_manager.sh`** is a utility for reading/writing Raspberry Pi `/boot/config.txt` (handles both legacy `/boot/config.txt` and newer `/boot/firmware/config.txt` paths).

## Key conventions

- All scripts require root (`sudo`). The framework checks `EUID` on init.
- Scripts target the user with UID 1000 (`$SUDO_USER`), which is the default `pi` user on Raspberry Pi OS.
- Home directory is derived via `getent passwd $USERNAME | cut -d: -f6`.
- GitHub URLs use `refs/heads/main` (not `main` alone) to avoid redirects.
- The v1.1.0 installer checks GitHub accessibility and auto-switches to Gitee if GitHub is unreachable.
- `--plain-text` flag disables ANSI color output (for non-TTY environments).
- Logs are written to `/tmp/install.log`.

## Branch strategy

- **`main`** — Production. All user-facing install commands in README point here. Merge to main = go live.
- **`dev`** — General development. Pre-release fixes and improvements land here first.
- **Feature branches** — Named after the product variant or feature (e.g. `ups`). Created from `main`, merged back when the feature is released. Do NOT mix variant-specific work into `dev`.
- Upstream convention: tag pushes trigger CI builds; PRs are not used — commits go directly to the branch.

## Pironman 5 installer (`pironman5/install.sh`)

The most complex installer in the repo. Supports 6 product variants via a bash selection menu or `--variant` CLI flag.

**Variant system:**
- Defined as `PRODUCTS` array entries: `"Display Name|variant_key|git_branch|part_number"`
- Each variant has entries in `PM5_PERIPHERALS` and `PM5_OVERLAYS` associative arrays
- Peripherals drive conditional apt/pip dependencies, kernel modules, and GPIO groups
- The variant key is written to `/opt/pironman5/.variant` at install time
- All variants follow the `1.3.x` branch; `pm_auto` pinned to `2.0.1`

**Supported variants:** base, mini, max, pro-max, ups, nas

**CLI flags:** `--variant <key>`, `--pipower5`, `--container`, `--plain-text`

**Peripheral-driven dependencies:**
- `oled` → apt: libjpeg-dev libfreetype6-dev libopenjp2-7 kmod i2c-tools; pip: Pillow smbus2; group: i2c; module: i2c-dev
- `ws2812` → pip: adafruit-circuitpython-neopixel-spi Adafruit-Blinka; group: spi gpio
- `sf_rgb_led` → pip: numpy; group: i2c
- `rtl8125` → pre-install: setup_rtl8125.sh; apt: build-essential gcc g++
- `gpio_fan_state` / `vibration_switch` → apt: python3-gpiozero; pip: rpi.lgpio; group: gpio
- `pi5_power_button` → apt: build-essential gcc g++; pip: evdev; group: input

**Other files in `pironman5/`:**
- `entrypoint.sh` — Docker container entrypoint; handles shutdown proxying to host
- `Dockerfile` — Multi-stage build for Umbrel/container deployments

## Interactive prompts and pipe safety

End users install via `curl ... | sudo bash`, which pipes the script to bash's **stdin**. On Ubuntu (which defaults to `sudo use_pty`), `/dev/tty` is also broken inside the sudo PTY. The only reliable input source is **stderr (fd 2)**, which stays connected to the real terminal.

**Rule: all `read` in interactive prompts MUST use `<&2`, not `< /dev/tty`.**

```bash
# Correct
read -r answer <&2

# Wrong — fails under curl | sudo bash on Ubuntu
read -r answer < /dev/tty
```

This is critical for the arrow-key menu in `pironman5/install.sh`.
