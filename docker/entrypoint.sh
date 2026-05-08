#!/bin/bash
set -e

# Load I2C kernel module (needed for OLED, not loaded by default on Umbrel OS)
modprobe i2c-dev 2>/dev/null || true

CONFIG_PATH="${CONFIG_PATH:-/data/config.json}"
mkdir -p "$(dirname "$CONFIG_PATH")"

exec /opt/pironman5/venv/bin/pironman5 --config-path "$CONFIG_PATH" start
