#!/bin/bash
set -e

# Load I2C kernel module (needed for OLED)
modprobe i2c-dev 2>/dev/null || true

# Shutdown wrappers: use nsenter + force flags to bypass systemd chroot guard
# systemctl and shutdown are symlinks to systemctl which refuses to run in
# a container context. -f flag forces the raw kernel syscall.
cat > /usr/local/bin/shutdown << 'WRAP'
#!/bin/bash
case "$*" in
    *-r*|*reboot*) exec nsenter -t 1 -a -- /sbin/reboot -f ;;
    *)             exec nsenter -t 1 -a -- /sbin/poweroff -f ;;
esac
WRAP
chmod +x /usr/local/bin/shutdown

for cmd in reboot poweroff halt; do
    case $cmd in
        reboot)   target="/sbin/reboot" ;;
        poweroff) target="/sbin/poweroff" ;;
        halt)     target="/sbin/halt" ;;
    esac
    printf '#!/bin/bash\nexec nsenter -t 1 -a -- %s -f "$@"\n' "$target" > "/usr/local/bin/$cmd"
    chmod +x "/usr/local/bin/$cmd"
done

# systemctl wrapper: translate shutdown commands, bypass chroot guard
cat > /usr/local/bin/systemctl << 'SYSCTL'
#!/bin/bash
case "$*" in
    *poweroff*) exec nsenter -t 1 -a -- /sbin/poweroff -f ;;
    *reboot*)   exec nsenter -t 1 -a -- /sbin/reboot -f ;;
    *halt*)     exec nsenter -t 1 -a -- /sbin/halt -f ;;
    *)          exec /usr/bin/systemctl "$@" ;;
esac
SYSCTL
chmod +x /usr/local/bin/systemctl

# sudo wrapper: intercept shutdown calls
cat > /usr/local/bin/sudo << 'SUDO'
#!/bin/bash
case "$*" in
    *systemctl*poweroff*|*poweroff*|*shutdown*|*reboot*|*halt*)
        exec nsenter -t 1 -a -- /sbin/poweroff -f ;;
    *)
        exec /usr/bin/sudo "$@" ;;
esac
SUDO
chmod +x /usr/local/bin/sudo

CONFIG_PATH="${CONFIG_PATH:-/data/config.json}"
mkdir -p "$(dirname "$CONFIG_PATH")"

exec /opt/pironman5/venv/bin/pironman5 --config-path "$CONFIG_PATH" start
