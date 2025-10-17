#!/bin/bash

LOG_FILE="./install.log"
if [ -f "$LOG_FILE" ]; then
    rm $LOG_FILE
fi
touch $LOG_FILE

# Get username of 1000
USERNAME=$(getent passwd 1000 | cut -d: -f1)
HOME=$(getent passwd 1000 | cut -d: -f6)
FORCE_REINSTALL=false
SUCCESS="\033[32m[✓]\033[0m"
FAILED="\033[31m[✗]\033[0m"

ERROR_HAPPENED=false
ERROR_LOGS=""

VERSION=`cat fusion_hat/version.py | grep __version__ | cut -d'"' -f2`

DTOVERLAY_FILE="sunfounder-fusionhat.dtbo"
DTOVERLAY_PATH="/boot/firmware/overlays/$DTOVERLAY_FILE"
SERVICE_FILE="fusion-hat-safe-shutdown.service"
SERVICE_PATH="/etc/systemd/system/$SERVICE_FILE"

APT_INSTALL_LIST=(
    "git"
    "python3"
    "raspi-config"
    "python3-pip"
    "i2c-tools"
    "espeak"
    "libsdl2-dev"
    "libsdl2-mixer-dev"
    "portaudio19-dev"
    "sox"
    "libttspico-utils"
)

PIP_INSTALL_LIST=(
    'smbus2'
    'gpiozero'
    'pyaudio'
    'spidev'
    'pyserial'
    'pillow'
    'pygame>=2.1.2'
    'luma.led_matrix'
    'luma.core'
)

log() {
    echo -e "$1"
    echo "$1" >> $LOG_FILE
}

log_title() {
    echo -e "\033[34m$1\033[0m"
    echo "[$1]" >> $LOG_FILE
}

cleanup() {
    log_title "Cleanup"
}

# Ctrl+C信号处理函数
handle_interrupt() {
    # 恢复光标（如果之前隐藏了）
    tput cnorm
    
    if [ "$ERROR_HAPPENED" = true ]; then
        echo -e "\n\033[31mUser interrupted. Error logs:\033[0m"
        echo "$ERROR_LOGS"
        echo "Please check $LOG_FILE for more details."
    else
        echo -e "\n\033[33mUser canceled.\033[0m"
    fi
    cleanup
    exit 1
}

# 注册信号处理函数
trap handle_interrupt SIGINT

# Check root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

run() {
    local cmd="$1"
    local info="$2"
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'  # 更精细的旋转字符
    local i=0
    
    # 隐藏光标
    tput civis
    
    # 在后台执行命令
    eval $cmd > /tmp/cmd_output.log 2>&1 &
    local pid=$!
    
    # 显示旋转光标和详细信息
    while [ -d /proc/$pid ]; do
        local char=${spinstr:$i:1}
        printf "\r\033[36m[%s]\033[0m %s" "$char" "$info"
        i=$(( (i+1) % ${#spinstr} ))
        sleep $delay
    done
    
    # 等待命令完成并显示结果
    wait $pid
    local result=$?
    
    # 恢复光标
    tput cnorm
    
    if [ $result -eq 0 ]; then
        printf "\r$SUCCESS %s\n" "$info"
        echo "[✓] $info" >> $LOG_FILE
    else
        printf "\r$FAILED %s\n" "$info"
        ERROR_HAPPENED=true
        ERROR_LOGS+=`cat /tmp/cmd_output.log`
        echo "[✗] $info" >> $LOG_FILE
    fi
    
    # 清理临时文件
    cat /tmp/cmd_output.log >> $LOG_FILE
    rm -f /tmp/cmd_output.log
    
    return $result
}

# Check how many arguments
if [ "$#" -gt 0  ]; then
    # 循环所有参数
    for arg in "$@"; do
        if [ "$arg" == "--force-reinstall" ]; then
            FORCE_REINSTALL=true
        fi
        if [ "$arg" == "--no-dep" ]; then
            NO_DEP=true
        fi
    done
fi

log_title "Install Fusion Hat Python Library v$VERSION\n"

if [ "$NO_DEP" != true ]; then
    # Install dependencies
    log_title "Install dependencies"
    run "apt-get update" "Update apt"
    run "apt-get install -y ${APT_INSTALL_LIST[*]}" "Install apt dependencies"

    # Install pip dependencies
    log_title "Install pip dependencies"
    run "pip3 install ${PIP_INSTALL_LIST[*]} --break-system-packages" "Install pip dependencies"
fi

# Download fusion-hat library
log_title "Download fusion-hat library"
if [ -d $HOME/fusion-hat ]; then
    if [ "$FORCE_REINSTALL" == true ]; then
        run "rm -rf $HOME/fusion-hat" "Remove existing fusion-hat library"
        run "git clone --depth=1 https://github.com/sunfounder/fusion-hat.git" "Clone fusion-hat library"
    fi
else
    run "git clone --depth=1 https://github.com/sunfounder/fusion-hat.git" "Clone fusion-hat library"
fi

# Change to fusion-hat directory
cd $HOME/fusion-hat

# Install fusion-hat library
log_title "Install fusion-hat library"
if [ `pip3 show fusion-hat` ]; then
    if [ "$FORCE_REINSTALL" == true ]; then
        run "pip3 uninstall -y fusion-hat --break-system-packages" "Uninstall existing fusion-hat library"
        run "pip3 install . --break-system-packages" "Install fusion-hat library"
    fi
fi
run "pip3 install . --break-system-packages" "Install fusion-hat library"
fi

# Copy dt-overlay
log_title "Copy dt-overlay"
if [ -f $DTOVERLAY_PATH ]; then
    if [ "$FORCE_REINSTALL" == true ]; then
        run "rm $DTOVERLAY_PATH" "Remove existing dt-overlay"
        run "cp $DTOVERLAY_FILE $DTOVERLAY_PATH" "Copy dt-overlay"
    fi
else
    run "cp $DTOVERLAY_FILE $DTOVERLAY_PATH" "Copy dt-overlay"
fi

# Enable safe shutdown
log_title "Enable safe shutdown"
run "cp $SERVICE_FILE $SERVICE_PATH" "Copy safe shutdown service"
run "systemctl enable $SERVICE_FILE" "Enable safe shutdown service" 
run "systemctl daemon-reload" "Reload systemd daemon"
run "systemctl start $SERVICE_FILE" "Start safe shutdown service"

# Setup audio script
log_title "Setup audio script"
run "wget -O /opt/setup_fusion_hat_audio.sh https://raw.githubusercontent.com/sunfounder/sunfounder-installer-scripts/main/setup_fusion_hat_audio.sh" "Download audio script"
run "chmod 755 /opt/setup_fusion_hat_audio.sh" "Change permissions of audio script to 755"
run "/opt/setup_fusion_hat_audio.sh --skip-test" "Setup audio script"

if [ "$ERROR_HAPPENED" = false ]; then
    log "$SUCCESS Install finished. Remember to run sudo /opt/setup_fusion_hat_audio.sh to enable speaker after reboot."
    # prompt reboot
    read -p "Do you want to reboot now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "$SUCCESS Rebooting..."
        sleep 1
        reboot
    fi
else
    echo -e "$FAILED Error happened: $ERROR_LOGS"
    echo -e "$FAILED Please check $LOG_FILE for more details."
    exit 1
fi
