#!/bin/bash
set -e

# Load I2C kernel module (needed for OLED)
modprobe i2c-dev 2>/dev/null || true

# Shutdown wrappers: reach the host via nsenter
# systemctl detects chroot and refuses poweroff, so we translate to low-level commands
for cmd in shutdown reboot poweroff halt; do
    printf '#!/bin/bash\nexec nsenter -t 1 -a -- /usr/sbin/%s "$@"\n' "$cmd" > "/usr/local/bin/$cmd"
    chmod +x "/usr/local/bin/$cmd"
done

# systemctl wrapper: translate shutdown commands to avoid host's chroot guard
cat > /usr/local/bin/systemctl << 'SYSCTL'
#!/bin/bash
case "$*" in
    *poweroff*) exec nsenter -t 1 -a -- /usr/sbin/shutdown -h now ;;
    *reboot*)   exec nsenter -t 1 -a -- /usr/sbin/reboot ;;
    *halt*)     exec nsenter -t 1 -a -- /usr/sbin/halt ;;
    *)          exec /usr/bin/systemctl "$@" ;;
esac
SYSCTL
chmod +x /usr/local/bin/systemctl

# sudo wrapper: intercept shutdown calls, pass through everything else
cat > /usr/local/bin/sudo << 'SUDO'
#!/bin/bash
case "$*" in
    *systemctl*poweroff*|*poweroff*|*shutdown*|*reboot*|*halt*)
        exec nsenter -t 1 -a -- /usr/sbin/shutdown -h now ;;
    *)
        exec /usr/bin/sudo "$@" ;;
esac
SUDO
chmod +x /usr/local/bin/sudo

CONFIG_PATH="${CONFIG_PATH:-/data/config.json}"
mkdir -p "$(dirname "$CONFIG_PATH")"

exec /opt/pironman5/venv/bin/pironman5 --config-path "$CONFIG_PATH" start
