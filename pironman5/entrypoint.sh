#!/bin/bash
set -e

# Load I2C kernel module (needed for OLED)
modprobe i2c-dev 2>/dev/null || true

# Create shutdown wrappers that reach the host via nsenter
# (container shutdown only stops the container; nsenter runs it on the host)
for cmd in shutdown reboot poweroff halt; do
    printf '#!/bin/bash\nexec nsenter -t 1 -a -- /usr/sbin/%s "$@"\n' "$cmd" > "/usr/local/bin/$cmd"
    chmod +x "/usr/local/bin/$cmd"
done

CONFIG_PATH="${CONFIG_PATH:-/data/config.json}"
mkdir -p "$(dirname "$CONFIG_PATH")"

exec /opt/pironman5/venv/bin/pironman5 --config-path "$CONFIG_PATH" start
