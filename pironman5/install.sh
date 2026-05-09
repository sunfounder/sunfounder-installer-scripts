#!/bin/bash
# ============================================================
# Pironman 5 Installer
# Supports: Pironman 5, Pironman 5 Mini, Pironman 5 Max, Pironman 5 Pro Max, Pironman 5 UPS
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/sunfounder/sunfounder-installer-scripts/main/pironman5/install.sh | sudo bash
#   curl -sSL https://raw.githubusercontent.com/sunfounder/sunfounder-installer-scripts/main/pironman5/install.sh | sudo bash -s -- --pipower5
#   curl -sSL https://raw.githubusercontent.com/sunfounder/sunfounder-installer-scripts/main/pironman5/install.sh | sudo bash -s -- --variant base --pipower5 --container
# (Safe to pipe — all interactive prompts use /dev/tty)
# ============================================================

# Source Installer framework — use local path when available (e.g. Docker build),
# otherwise curl from GitHub.
FRAMEWORK_DIR="/tmp/installer-tools"
if [ -d "$FRAMEWORK_DIR" ]; then
    source "$FRAMEWORK_DIR/installer_1.1.0.sh"
else
    INSTALLER_URL="https://raw.githubusercontent.com/sunfounder/sunfounder-installer-scripts/refs/heads/main/tools/installer_1.1.0.sh"
    curl -fsSL "$INSTALLER_URL?$(date +%s)" -o installer.sh
    if [ $? -ne 0 ]; then
        echo "Network error, please check your internet connection."
        exit 1
    fi
    source installer.sh
    rm installer.sh
fi

installer_check_root_privileges

# ============================================================
# Parse CLI Arguments
# ============================================================
INSTALL_PIPOWER5=false
IS_CONTAINER=false
IS_PLAIN_TEXT=false
ARG_VARIANT=""
while [ $# -gt 0 ]; do
    case "$1" in
        --pipower5) INSTALL_PIPOWER5=true ;;
        --container) IS_CONTAINER=true; IS_PLAIN_TEXT=true ;;
        --plain-text) IS_PLAIN_TEXT=true ;;
        --variant=*) ARG_VARIANT="${1#*=}" ;;
        --variant) shift; ARG_VARIANT="$1" ;;
    esac
    shift
done

# Validate --variant
if [ -n "$ARG_VARIANT" ]; then
    case "$ARG_VARIANT" in
        base|mini|max|pro-max|ups) ;;
        *) echo "Invalid variant: $ARG_VARIANT. Valid: base, mini, max, pro-max, ups"; exit 1 ;;
    esac
fi

# ============================================================
# Banner
# ============================================================
echo -e "\033[34m"
cat <<'BANNER'

██████╗ ██╗██████╗  ██████╗ ███╗   ██╗███╗   ███╗ █████╗ ███╗   ██╗    ███████╗
██╔══██╗██║██╔══██╗██╔═══██╗████╗  ██║████╗ ████║██╔══██╗████╗  ██║    ██╔════╝
██████╔╝██║██████╔╝██║   ██║██╔██╗ ██║██╔████╔██║███████║██╔██╗ ██║    ███████╗
██╔═══╝ ██║██╔══██╗██║   ██║██║╚██╗██║██║╚██╔╝██║██╔══██║██║╚██╗██║    ╚════██║
██║     ██║██║  ██║╚██████╔╝██║ ╚████║██║ ╚═╝ ██║██║  ██║██║ ╚████║    ███████║
╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝    ╚══════╝

               Pironman 5 Installer
        Supports: 5 | 5 Mini | 5 Max | 5 Pro Max | 5 UPS

BANNER
echo -e "\033[0m"

# ============================================================
# Product Configuration
# ============================================================

# --- Product list (shown in menu) ---
# Format: "Display Name|variant|branch|part_number"
PRODUCTS=(
    "Pironman 5|base|1.3.x|0306V10"
    "Pironman 5 Mini|mini|1.3.x|0308V10"
    "Pironman 5 Max|max|1.3.x|0306V11"
    "Pironman 5 Pro Max|pro-max|1.3.x|0316V10"
    "Pironman 5 UPS|ups|1.3.x|2602V10"
)

# --- Peripherals per variant ---
declare -A PM5_PERIPHERALS
PM5_PERIPHERALS[base]="storage cpu network memory history log cpu_temperature gpu_temperature temperature_unit oled oled_sleep ws2812 pwm_fan_speed gpio_fan_state gpio_fan_mode pi5_power_button"
PM5_PERIPHERALS[mini]="storage cpu network memory history log cpu_temperature gpu_temperature temperature_unit ws2812 pwm_fan_speed gpio_fan_state gpio_fan_mode gpio_fan_led"
PM5_PERIPHERALS[max]="storage cpu network memory history log cpu_temperature gpu_temperature temperature_unit oled ws2812 pwm_fan_speed gpio_fan_state gpio_fan_mode gpio_fan_led pi5_power_button oled_sleep"
PM5_PERIPHERALS[pro-max]="storage cpu network memory history log cpu_temperature gpu_temperature temperature_unit oled oled_sleep ws2812 pwm_fan_speed pi5_power_button"
PM5_PERIPHERALS[ups]="storage cpu network memory history log cpu_temperature gpu_temperature temperature_unit oled oled_sleep sf_rgb_led pwm_fan_speed"

# --- DT overlays per variant ---
declare -A PM5_OVERLAYS
PM5_OVERLAYS[base]="sunfounder-pironman5.dtbo"
PM5_OVERLAYS[mini]="sunfounder-pironman5mini.dtbo"
PM5_OVERLAYS[max]="sunfounder-pironman5.dtbo"
PM5_OVERLAYS[pro-max]="sunfounder-pironman5promax.dtbo"
PM5_OVERLAYS[ups]=""

# ============================================================
if [ -n "$ARG_VARIANT" ]; then
    # --variant mode: skip interactive menu
    for prod in "${PRODUCTS[@]}"; do
        IFS='|' read -r p_name p_variant p_branch p_part <<< "$prod"
        if [ "$p_variant" = "$ARG_VARIANT" ]; then
            product_name="$p_name"
            variant="$p_variant"
            branch="$p_branch"
            part_number="$p_part"
            break
        fi
    done
    if [ -z "$variant" ]; then
        echo "Variant not found: $ARG_VARIANT"
        exit 1
    fi
else
    # Interactive menu mode
    echo "Please select your product model:"
    selected=0
    n=${#PRODUCTS[@]}

    _draw_menu() {
        for i in $(seq 0 $((n - 1))); do
            printf "\033[K"
            local name="${PRODUCTS[$i]%%|*}"
            if [ $i -eq $selected ]; then
                printf "  \033[34m> %s\033[0m\n" "$name"
            else
                printf "    %s\n" "$name"
            fi
        done
    }

    printf "\033[?25l"
    _draw_menu

    while true; do
        read -rsn1 key < /dev/tty
        if [ "$key" = $'\033' ]; then
            read -rsn1 -t 0.1 k1 < /dev/tty || true
            read -rsn1 -t 0.1 k2 < /dev/tty || true
            case "$k1$k2" in
                '[A') selected=$(( (selected - 1 + n) % n )) ;;
                '[B') selected=$(( (selected + 1) % n )) ;;
            esac
            printf "\033[%dA" $n
            printf "\033[J"
            _draw_menu
        elif [ -z "$key" ]; then
            printf "\n"
            break
        fi
    done

    printf "\033[?25h"

    IFS='|' read -r product_name variant branch part_number <<< "${PRODUCTS[$selected]}"
fi

PERIPHERALS="${PM5_PERIPHERALS[$variant]}"
DT_OVERLAYS="${PM5_OVERLAYS[$variant]}"

# UPS variant has pipower5 as a built-in module
if [ "$variant" = "ups" ]; then
    INSTALL_PIPOWER5=true
fi

installer_log_title "\nPreparing installation for ${product_name} (branch: ${branch})"
if [ "$INSTALL_PIPOWER5" = true ]; then
    installer_log_title "PiPower5 UPS module: enabled"
fi

# Helper: check if a peripheral is present
has() { [[ " $PERIPHERALS " == *" $1 "* ]]; }

# ============================================================
# Package Versions
# ============================================================
PM_AUTO_VERSION="1.4.8"
DASHBOARD_VERSION="1.4.0"
SF_RPI_STATUS_VERSION="1.1.8"

GIT_REPO="https://github.com/sunfounder/"

# ============================================================
# Build Dependency Sets (deduplicated)
# ============================================================

# -- Pre-install scripts --
if [ "$IS_CONTAINER" = true ]; then
    PRE_SCRIPTS="install_influxdb.sh"
else
    PRE_SCRIPTS="umbrel_patch.sh"
    if has "ws2812" || has "gpio_fan_state" || has "vibration_switch"; then
        PRE_SCRIPTS="$PRE_SCRIPTS install_lgpio.sh fix_kali_gpio_spi.sh"
    fi
    PRE_SCRIPTS="$PRE_SCRIPTS install_influxdb.sh"
    if [ "$INSTALL_PIPOWER5" = true ]; then
        PRE_SCRIPTS="$PRE_SCRIPTS setup_pipower5.sh"
    fi
fi
# Deduplicate
PRE_SCRIPTS=$(echo "$PRE_SCRIPTS" | tr ' ' '\n' | awk 'NF' | sort -u | tr '\n' ' ')

# -- APT dependencies --
APT_DEPS="python3-dev influxdb"
if has "oled"; then
    APT_DEPS="$APT_DEPS libjpeg-dev libfreetype6-dev libopenjp2-7 kmod i2c-tools"
fi
if has "pi5_power_button"; then
    APT_DEPS="$APT_DEPS build-essential gcc g++"
fi
if has "gpio_fan_state" || has "vibration_switch"; then
    APT_DEPS="$APT_DEPS python3-gpiozero"
fi
APT_DEPS=$(echo "$APT_DEPS" | tr ' ' '\n' | awk 'NF' | sort -u | tr '\n' ' ')

# -- Pip dependencies (installed into venv) --
PIP_DEPS="pip setuptools build requests psutil"
if has "ws2812"; then
    PIP_DEPS="$PIP_DEPS adafruit-circuitpython-neopixel-spi adafruit_platformdetect Adafruit-Blinka==8.59.0 rpi.lgpio adafruit-circuitpython-typing 'Adafruit-PureIO>=1.1.7' 'pyftdi>=0.40.0'"
fi
if has "oled"; then
    PIP_DEPS="$PIP_DEPS Pillow smbus2"
fi
if has "gpio_fan_state" || has "vibration_switch"; then
    PIP_DEPS="$PIP_DEPS rpi.lgpio"
fi
if has "pi5_power_button"; then
    PIP_DEPS="$PIP_DEPS evdev"
fi
PIP_DEPS=$(echo "$PIP_DEPS" | tr ' ' '\n' | awk 'NF' | sort -u | tr '\n' ' ')

# -- Groups --
GROUP_LIST="video influxdb"
if has "ws2812"; then
    GROUP_LIST="$GROUP_LIST spi gpio"
fi
if has "oled"; then
    GROUP_LIST="$GROUP_LIST i2c"
fi
if has "gpio_fan_state" || has "vibration_switch"; then
    GROUP_LIST="$GROUP_LIST gpio"
fi
if has "pi5_power_button"; then
    GROUP_LIST="$GROUP_LIST input"
fi
if [ "$INSTALL_PIPOWER5" = true ]; then
    GROUP_LIST="$GROUP_LIST i2c pipower5"
fi
GROUP_LIST=$(echo "$GROUP_LIST" | tr ' ' '\n' | awk 'NF' | sort -u | tr '\n' ' ')

# -- Kernel modules --
MODULES=""
if has "oled"; then
    MODULES="i2c-dev"
fi

# ============================================================
# Build Declarative Install Commands (DSL)
# ============================================================

# --- Clone repository ---
TITLE "Installing ${product_name}"
TITLE "Install build dependencies"
RUN "DEBIAN_FRONTEND=noninteractive apt-get update" "Update package list"
RUN "DEBIAN_FRONTEND=noninteractive apt-get install -y python3-pip python3-venv git curl" "Install build dependencies"

TITLE "Clone pironman5 repository"
RUN "rm -rf ${HOME}/pironman5" "Remove existing pironman5 directory"
RUN "git clone -b ${branch} --depth=1 ${GIT_REPO}pironman5 ${HOME}/pironman5" "Clone pironman5"
if [ "$IS_CONTAINER" = false ]; then
    RUN "chown -R ${USERNAME}:${USERNAME} ${HOME}/pironman5" "Set repo ownership"
fi
CD "${HOME}/pironman5"

# --- Pre-install scripts ---
if [ -n "$PRE_SCRIPTS" ]; then
    TITLE "Run pre-install scripts"
    for script in $PRE_SCRIPTS; do
        RUN "bash scripts/${script}" "Run ${script}"
    done
fi

# --- APT dependencies ---
TITLE "Install APT dependencies"
RUN "DEBIAN_FRONTEND=noninteractive apt-get install -y ${APT_DEPS}" "Install APT dependencies"

# --- User and group setup ---
if [ "$IS_CONTAINER" = false ]; then
    TITLE "Setup system user"
    RUN "getent group pironman5 > /dev/null || groupadd -r pironman5" "Create pironman5 group"
    RUN "getent passwd pironman5 > /dev/null || useradd -r -g pironman5 -s /sbin/nologin -d /opt/pironman5 -m pironman5" "Create pironman5 user"
    RUN "usermod -aG pironman5 ${USERNAME}" "Add ${USERNAME} to pironman5 group"

    TITLE "Setup sudo permissions"
    RUN "echo 'pironman5 ALL=(ALL) NOPASSWD: /usr/sbin/shutdown, /usr/sbin/reboot, /usr/sbin/poweroff, /usr/sbin/halt, /usr/bin/systemctl, /usr/bin/lsblk' | tee /etc/sudoers.d/pironman5 > /dev/null" "Create sudoers file"
    RUN "chmod 0440 /etc/sudoers.d/pironman5" "Set sudoers permissions"

    if [ -n "$GROUP_LIST" ]; then
        TITLE "Add user to groups"
        for group in $GROUP_LIST; do
            RUN "getent group ${group} > /dev/null 2>&1 || groupadd -r ${group}; usermod -aG ${group} pironman5" "Setup ${group} group"
        done
    fi
fi

# --- Working directory and venv ---
TITLE "Create working directory"
RUN "mkdir -p /opt/pironman5 /var/log/pironman5" "Create directories"
RUN "touch /var/log/pironman5/pironman5.log" "Create log file"
if [ "$IS_CONTAINER" = false ]; then
    RUN "chmod 775 /opt/pironman5" "Set work directory permissions"
    RUN "chown -R pironman5:pironman5 /opt/pironman5" "Set work directory owner"
    RUN "chmod 775 /var/log/pironman5" "Set log directory permissions"
    RUN "chown -R pironman5:pironman5 /var/log/pironman5" "Set log directory owner"
    RUN "chmod 664 /var/log/pironman5/pironman5.log" "Set log file permissions"
    RUN "chown pironman5:pironman5 /var/log/pironman5/pironman5.log" "Set log file owner"
fi
RUN "rm -rf /opt/pironman5/venv" "Remove old virtual environment"
RUN "python3 -m venv /opt/pironman5/venv --system-site-packages" "Create virtual environment"

VENV_PIP="/opt/pironman5/venv/bin/pip3"

# --- Uninstall conflicting packages ---
if has "gpio_fan_state" || has "vibration_switch"; then
    TITLE "Remove conflicting packages"
    RUN "${VENV_PIP} uninstall -y RPi.GPIO 2>/dev/null; true" "Uninstall RPi.GPIO"
fi

# --- Install pip dependencies ---
TITLE "Install Python dependencies"
RUN "${VENV_PIP} install --upgrade ${PIP_DEPS}" "Install Python packages"

# --- Install Python source packages ---
TITLE "Install Python packages from source"
RUN "${VENV_PIP} install ./ " "Install pironman5"
RUN "${VENV_PIP} install git+${GIT_REPO}pm_auto.git@${PM_AUTO_VERSION}" "Install pm_auto"
RUN "${VENV_PIP} install git+${GIT_REPO}sf_rpi_status.git@${SF_RPI_STATUS_VERSION}" "Install sf_rpi_status"
RUN "${VENV_PIP} install git+${GIT_REPO}pm_dashboard.git@${DASHBOARD_VERSION}" "Install pm_dashboard"

# --- Install PiPower5 ---
if [ "$INSTALL_PIPOWER5" = true ]; then
    TITLE "Install PiPower5"
    RUN "${VENV_PIP} install git+${GIT_REPO}pipower5.git@main" "Install pipower5"
    RUN "${VENV_PIP} install git+${GIT_REPO}spc.git" "Install spc"
    RUN "ln -sf /opt/pironman5/venv/bin/pipower5 /usr/local/bin/pipower5" "Create pipower5 symlink"
fi

# --- Symlinks ---
TITLE "Create symlinks"
RUN "ln -sf /opt/pironman5/venv/bin/pironman5 /usr/local/bin/pironman5" "Create pironman5 symlink"

# --- Systemd auto-start ---
if [ "$IS_CONTAINER" = false ]; then
    TITLE "Setup auto-start"
    RUN "cp bin/pironman5.service /etc/systemd/system/" "Install service file"
    RUN "systemctl enable pironman5.service" "Enable pironman5 service"
    RUN "systemctl daemon-reload" "Reload systemd"
fi

# --- Kernel modules ---
if [ "$IS_CONTAINER" = false ] && [ -n "$MODULES" ]; then
    TITLE "Configure kernel modules"
    for module in $MODULES; do
        RUN "echo ${module} >> /etc/modules-load.d/modules.conf" "Add module ${module}"
    done
fi

# --- Device tree overlays ---
if [ "$IS_CONTAINER" = false ]; then
    TITLE "Copy device tree overlays"
    OVERLAY_SEARCH_PATHS="/boot/firmware/overlays /boot/overlays /boot/firmware/current/overlays"
    OVERLAY_PATH=""
    for p in $OVERLAY_SEARCH_PATHS; do
        if [ -d "$p" ]; then
            OVERLAY_PATH="$p"
            break
        fi
    done
    if [ -z "$OVERLAY_PATH" ]; then
        installer_log_failed "Device tree overlay directory not found. Checked: ${OVERLAY_SEARCH_PATHS}"
    else
        for overlay in $DT_OVERLAYS; do
            RUN "cp overlays/${overlay} ${OVERLAY_PATH}/" "Copy ${overlay}"
        done
        if [ "$INSTALL_PIPOWER5" = true ]; then
            RUN "curl -fsSL https://github.com/sunfounder/pipower5/raw/refs/heads/main/sunfounder-pipower5.dtbo -o ${OVERLAY_PATH}/sunfounder-pipower5.dtbo" "Copy PiPower5 device tree overlay"
        fi
    fi
fi

# --- Post-install scripts ---
if [ "$IS_CONTAINER" = false ]; then
    if has "gpio_fan_state" || has "vibration_switch"; then
        TITLE "Run post-install scripts"
        RUN "bash scripts/change_rpi.gpio_to_rpi.lgpio.sh" "Migrate RPi.GPIO to rpi.lgpio"
    fi
fi

# --- Fix permissions ---
if [ "$IS_CONTAINER" = false ]; then
    TITLE "Finalize permissions"
    RUN "chmod +x /opt/pironman5" "Set execution permission on work dir"
    RUN "chown -R pironman5:pironman5 /opt/pironman5" "Set final ownership"
fi

# --- Write variant file ---
TITLE "Write product variant"
RUN "mkdir -p /opt/pironman5" "Ensure work directory exists"
RUN "echo -n '${variant}' > /opt/pironman5/.variant" "Write variant identifier"
if [ "$INSTALL_PIPOWER5" = true ]; then
    RUN "echo -n 'pipower5' > /opt/pironman5/.custom_module" "Write custom module"
fi

# ============================================================
# Execute Installation
# ============================================================
if [ "$IS_PLAIN_TEXT" = true ]; then
    installer_install --plain-text
else
    installer_install
fi

# ============================================================
# Pro Max: Auto-launch browser
# ============================================================
if [ "$IS_CONTAINER" = false ] && [ "$variant" = "pro-max" ]; then
    echo ""
    echo "Do you want the browser to open automatically on desktop startup?"
    echo "This will install an autostart entry that launches the Pironman 5 dashboard in a browser."
    read -p "Install auto-launch browser? [Y/n]: " install_browser < /dev/tty
    if [[ "$install_browser" =~ ^[Yy]?$ ]]; then
        /opt/pironman5/venv/bin/python3 ~/pironman5/pironman5/_launch_browser.py
    fi
fi

# ============================================================
# Complete
# ============================================================
if [ "$IS_CONTAINER" = false ]; then
    installer_prompt_reboot
fi
