
LOG_FILE="./install.log"
if [ -f "$LOG_FILE" ]; then
    rm $LOG_FILE
fi
touch $LOG_FILE

# Get username of 1000
USERNAME=${SUDO_USER:-$USER}
HOME=$(getent passwd $USERNAME | cut -d: -f6)
SUCCESS="\033[32m[✓]\033[0m"
FAILED="\033[31m[✗]\033[0m"

ERROR_HAPPENED=false
ERROR_LOGS=""

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
        ERROR_LOGS+="\n  `cat /tmp/cmd_output.log`\n"
        echo "[✗] $info" >> $LOG_FILE
    fi
    
    # 清理临时文件
    cat /tmp/cmd_output.log >> $LOG_FILE
    rm -f /tmp/cmd_output.log
    
    return $result
}

check_root_privileges() {
    # Check root privileges
    if [ "$EUID" -ne 0 ]; then
      echo "Please run as root"
      exit 1
    fi
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


log() {
    echo -e "$1"
    echo "$1" >> $LOG_FILE
}

log_title() {
    echo -e "\033[34m$1\033[0m"
    echo "[$1]" >> $LOG_FILE
}

prompt_reboot() {
    if [ "$ERROR_HAPPENED" = false ]; then
        log "$SUCCESS Install finished. $1"
        # prompt reboot
        read -p "Do you want to reboot now? (y/n) " -n 1 -r
        while true; do
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                log "$SUCCESS Rebooting..."
                sleep 1
                reboot
            elif [[ $REPLY =~ ^[Nn]$ ]]; then
                log "$SUCCESS Skipping reboot."
                break
            else
                read -p "$FAILED Invalid input. Please enter y or n. " -n 1 -r
            fi
        done
    else
        echo -e "$FAILED Error happened: $ERROR_LOGS"
        echo -e "$FAILED Please check $LOG_FILE for more details."
        exit 1
    fi
}