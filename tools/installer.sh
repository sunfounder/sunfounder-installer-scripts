PROGRESS_BAR_URL="https://raw.githubusercontent.com/sunfounder/sunfounder-installer-scripts/refs/heads/main/tools/progress_bar.sh"
# Source progress bar
curl -fsSL $PROGRESS_BAR_URL -o progress_bar.sh
source progress_bar.sh
rm progress_bar.sh

CONFIG_TXT_MANAGER_URL="https://raw.githubusercontent.com/sunfounder/sunfounder-installer-scripts/refs/heads/main/tools/config_txt_manager.sh"
# Source config_txt_manager
curl -fsSL $CONFIG_TXT_MANAGER_URL -o config_txt_manager.sh
source config_txt_manager.sh
rm config_txt_manager.sh



# Get username of 1000
LOG_FILE="/tmp/install.log"
USERNAME=${SUDO_USER:-$USER}
HOME=$(getent passwd $USERNAME | cut -d: -f6)
SUCCESS="\033[32m[✓]\033[0m"
FAILED="\033[31m[✗]\033[0m"
SUCCESS_PLAIN_TEXT="[✓]"
FAILED_PLAIN_TEXT="[✗]"
PLAIN_TEXT=false
ERROR_HAPPENED=false
ERROR_LOGS=""
CONFIG_TXT_FILE=$(config_txt_find)

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
        if [ "$PLAIN_TEXT" != true ]; then
            # echo -e "\033[36m[$char]\033[0m $info\r"
            printf "\033[36m[%s]\033[0m %s\r" "$char" "$info"
        fi
        i=$(( (i+1) % ${#spinstr} ))
        sleep $delay
    done
    
    # 等待命令完成并显示结果
    wait $pid
    local result=$?
    
    # 恢复光标
    tput cnorm
    
    if [ $result -eq 0 ]; then
        log_success "$info"
    else
        log_failed "$info"
        ERROR_HAPPENED=true
        ERROR_LOGS+="\n  `cat /tmp/cmd_output.log`\n"
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

init_log_file() {
    if [ "$PLAIN_TEXT" != true ]; then
        if [ -f "$LOG_FILE" ]; then
            rm $LOG_FILE
        fi
        touch $LOG_FILE
    fi
}

log_title() {
    if [ "$PLAIN_TEXT" == true ]; then
        echo -e $1
    else
        echo -e "\033[34m$1\033[0m"
        echo "[$1]" >> $LOG_FILE
    fi
}

log_success() {
    if [ "$PLAIN_TEXT" == true ]; then
        echo -e "$SUCCESS_PLAIN_TEXT $1"
    else
        echo -e "$SUCCESS $1"
        echo "$SUCCESS_PLAIN_TEXT $1" >> $LOG_FILE
    fi
}

log_failed() {
    if [ "$PLAIN_TEXT" == true ]; then
        echo -e "$FAILED_PLAIN_TEXT $1"
    else
        echo -e "$FAILED $1"
        echo "$FAILED_PLAIN_TEXT $1" >> $LOG_FILE
    fi
}

check_root_privileges
# Make sure that the progress bar is cleaned up when user presses ctrl+c
enable_trapping

for arg in "$@"; do
    case $arg in
    --plain-text)
        PLAIN_TEXT=true
        ;;
    esac
done


install() {
    init_log_file
    # Create progress bar
    setup_scroll_area
    COMMANDS=$1
    total=${#COMMANDS[@]}
    count=0
    for cmd in "${COMMANDS[@]}"; do
        eval $cmd
        count=$((count+1))
        draw_progress_bar $((count*100/total))
    done
    destroy_scroll_area
    
    if [ "$ERROR_HAPPENED" = false ]; then
        echo -e "Install finished."
    else
        echo -e "Error happened: $ERROR_LOGS"
        echo -e "Please check $LOG_FILE for more details."
        exit 1
    fi
}

prompt_reboot() {
    # prompt reboot - read from /dev/tty to avoid conflict with pipe input
    read -p "Do you want to reboot now? (y/n) " -n 1 -r < /dev/tty
    while true; do
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "Rebooting..."
            sleep 1
            reboot
        elif [[ $REPLY =~ ^[Nn]$ ]]; then
            echo -e "Skipping reboot."
            break
        else
            read -p "Invalid input. Please enter y or n. " -n 1 -r < /dev/tty
        fi
    done
}
