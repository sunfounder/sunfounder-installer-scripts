#!/bin/bash
set -e

# Load I2C kernel module (needed for OLED)
modprobe i2c-dev 2>/dev/null || true

# Wrap shutdown commands to reach the host via nsenter
# (without this, shutdown only stops the container, not the Pi)
for cmd in shutdown reboot poweroff halt systemctl; do
    printf '#!/bin/bash\nexec nsenter -t 1 -a -- /usr/bin/%s "$@"\n' "$cmd" > "/usr/local/bin/$cmd"
    chmod +x "/usr/local/bin/$cmd"
done

# sudo wrapper: pass shutdown-related commands to host via nsenter,
# other commands run normally in the container
cat > /usr/local/bin/sudo << 'SUDO'
#!/bin/bash
case "$*" in
    *poweroff*|*reboot*|*shutdown*|*halt*)
        exec nsenter -t 1 -a -- /usr/bin/sudo "$@" ;;
    *)
        exec /usr/bin/sudo "$@" ;;
esac
SUDO
chmod +x /usr/local/bin/sudo

CONFIG_PATH="${CONFIG_PATH:-/data/config.json}"
mkdir -p "$(dirname "$CONFIG_PATH")"

exec /opt/pironman5/venv/bin/pironman5 --config-path "$CONFIG_PATH" start
