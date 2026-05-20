# Pironman 5 Installer

One-command installer for SunFounder Pironman 5 series HATs on Raspberry Pi.

## Quick Install

```bash
curl -sSL "https://raw.githubusercontent.com/sunfounder/sunfounder-installer-scripts/main/pironman5/install.sh" | sudo bash
```

With options:

```bash
# With PiPower5 UPS module
curl -sSL "https://raw.githubusercontent.com/sunfounder/sunfounder-installer-scripts/main/pironman5/install.sh" | sudo bash -s -- --pipower5

# Skip menu, select variant directly
curl -sSL "https://raw.githubusercontent.com/sunfounder/sunfounder-installer-scripts/main/pironman5/install.sh" | sudo bash -s -- --variant ups
```

## Ubuntu Users

Ubuntu's `sudo` uses `use_pty` by default, which breaks interactive input when piping.  
If you see **`Input/output error`** or the menu doesn't respond, download the script first:

```bash
curl -sSL "https://raw.githubusercontent.com/sunfounder/sunfounder-installer-scripts/main/pironman5/install.sh" -o install.sh
sudo bash install.sh
rm install.sh
```

## Supported Variants

| Variant | `--variant` | Description |
|---|---|---|
| Pironman 5 | `base` | OLED, RGB LED, PWM Fan |
| Pironman 5 Mini | `mini` | No OLED, RGB LED, PWM Fan |
| Pironman 5 Max | `max` | OLED, RGB LED, PWM+GPIO Fan |
| Pironman 5 Pro Max | `pro-max` | OLED, M.2 NVMe slot |
| Pironman 5 UPS | `ups` | OLED, UPS battery |
| Pironman 5 NAS | `nas` | OLED, 2.5G Ethernet, MCU button |

## CLI Flags

| Flag | Description |
|---|---|
| `--variant <key>` | Skip menu, select variant directly |
| `--pipower5` | Enable PiPower5 UPS module |
| `--container` | Container/Docker mode |
| `--plain-text` | Disable color output |

## Service Management

```bash
sudo systemctl restart pironman5.service   # apply config changes
sudo systemctl stop pironman5.service
journalctl -xefu pironman5.service          # live logs
```

Config: `/opt/pironman5/config.json`
