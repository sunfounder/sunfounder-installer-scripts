#!/bin/bash

LOG_FILE="./install.log"
if [ -f "$LOG_FILE" ]; then
    rm $LOG_FILE
fi
touch $LOG_FILE

log() {
    echo -e "$1"
    echo "$1" >> $LOG_FILE
}

log_title() {
    echo -e "\033[33m[ $1 ]\033[0m"
    echo "[$1]" >> $LOG_FILE
}

ERROR_HAPPENED=false
ERROR_LOGS=""

cleanup() {
    log_title "Cleanup"
    run "rm -rf $HOME/fusion-hat" "Remove fusion-hat if exists"
    run "rm -rf $HOME/vilib" "Remove vilib if exists"
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

# Get username of 1000
USERNAME=$(getent passwd 1000 | cut -d: -f1)
HOME=$(getent passwd 1000 | cut -d: -f6)
FORCE_REINSTALL=false
SUCCESS="\033[32m[✓]\033[0m"
FAILED="\033[31m[✗]\033[0m"

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
if [ "$#" -eq 1  ]; then
    if [ "$1" == "--force-reinstall" ]; then
        FORCE_REINSTALL=true
    fi
fi

# Install dependencies
log_title "Install dependencies"
run "sudo apt-get update" "Update apt"
run "sudo apt-get install -y git python3 python3-pip python3-dev python3-venv python3-pyaudio sox" "Install python3-pip python3-dev python3-venv python3-pyaudio sox"
# sudo apt install -y libatlas-base-dev libjasper-dev libqtgui4 libqt4-test

# Install fusion-hat
log_title "Install fusion-hat"
cd $HOME
run "git clone -b 1.1.x --depth=1 https://github.com/sunfounder/fusion-hat.git" "Clone fusion-hat"
if [ $? -eq 0 ]; then
    cd $HOME/fusion-hat
    run "python3 install.py" "Install fusion-hat"
fi

# Install vilib
log_title "Install vilib"
cd $HOME
run "rm -rf $HOME/vilib" "Remove vilib if exists"
run "git clone --depth=1 https://github.com/sunfounder/vilib.git" "Clone vilib"
if [ $? -eq 0 ]; then
    cd $HOME/vilib
    run "python3 install.py" "Install vilib"
fi

# Install picar-x
log_title "Install picar-x"
cd $HOME
run "git clone -b 3.0.x --depth=1 https://github.com/sunfounder/picar-x.git" "Clone picar-x"
if [ $? -eq 0 ]; then
    cd $HOME/picar-x
    run "pip3 install ./ --break-system-packages" "Install picar-x"
fi

# Create dir for config
run "mkdir -p /opt/picar-x" "Create dir for config"
run "chown -R $USERNAME:$USERNAME /opt/picar-x" "Change ownership of /opt/picar-x to $USERNAME:$USERNAME"
run "chmod -R 755 /opt/picar-x" "Change permissions of /opt/picar-x to 755"

# Setup speaker script
log_title "Setup speaker script"
run "wget -O /opt/picar-x/setup_fusion_hat_speaker.sh https://raw.githubusercontent.com/sunfounder/sunfounder-installer-scripts/main/setup_fusion_hat_speaker.sh" "Download speaker script"
run "chmod 755 /opt/picar-x/setup_fusion_hat_speaker.sh" "Change permissions of speaker script to 755"
run "/opt/picar-x/setup_fusion_hat_speaker.sh --skip-test" "Setup speaker script"

# Install picar-x-app
log_title "Install picar-x-app"
echo "[Unit]
Description=picarx service
After=multi-user.target

[Service]
Type=simple
WorkingDirectory=/home/$USERNAME/picar-x/app
ExecStart=python3 app.py

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/picar-x-app.service
run "systemctl enable picar-x-app.service" "Enable picar-x-app service"
run "systemctl daemon-reload" "Reload systemd daemon"
run "systemctl start picar-x-app.service" "Start picar-x-app service"
log "picar-x-app installed"

cleanup

if [ "$ERROR_HAPPENED" = false ]; then
    log "$SUCCESS Install finished. Remember to run sudo /opt/picar-x/setup_fusion_hat_speaker.sh to enable speaker after reboot."
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
