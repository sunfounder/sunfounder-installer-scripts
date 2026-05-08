#!/bin/bash
set -e

# Load I2C kernel module (needed for OLED, not loaded by default on Umbrel OS)
modprobe i2c-dev 2>/dev/null || true

# Write variant at runtime (image is unified, variant selected via env var)
VARIANT="${VARIANT:-base}"
echo -n "$VARIANT" > /opt/pironman5/.variant
if [ "${PIPOWER5:-false}" = "true" ]; then
    echo -n "pipower5" > /opt/pironman5/.custom_module
fi

CONFIG_PATH="${CONFIG_PATH:-/data/config.json}"
mkdir -p "$(dirname "$CONFIG_PATH")"

exec /opt/pironman5/venv/bin/pironman5 --config-path "$CONFIG_PATH" start
