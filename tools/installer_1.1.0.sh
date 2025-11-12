
INSTALLER_PROGRESS_BAR_URL="https://raw.githubusercontent.com/sunfounder/sunfounder-installer-scripts/refs/heads/main/tools/progress_bar_1.1.0.sh"

INSTALLER_CONFIG_TXT_MANAGER_URL="https://raw.githubusercontent.com/sunfounder/sunfounder-installer-scripts/refs/heads/main/tools/config_txt_manager.sh"

# Get username of 1000
USERNAME=${SUDO_USER:-$USER}
HOME=$(getent passwd $USERNAME | cut -d: -f6)

INSTALLER_LOG_FILE="/tmp/install.log"
INSTALLER_SUCCESS="\033[32m[✓]\033[0m"
INSTALLER_FAILED="\033[31m[✗]\033[0m"
INSTALLER_SUCCESS_PLAIN_TEXT="[✓]"
INSTALLER_FAILED_PLAIN_TEXT="[✗]"
INSTALLER_PLAIN_TEXT=false
INSTALLER_ERROR_HAPPENED=false
INSTALLER_ERROR_LOGS=""
INSTALLER_CONFIG_TXT_FILE=""
INSTALLER_COMMANDS=()
INSTALLER_COMMANDS_COUNT=0
INSTALLER_COMMAND_SPACE="&#&"

installer_import() {
    local url="$1"
    local filename=$(basename $url)
    curl -fsSL $url -o $filename
    source $filename
    rm $filename
}

installer_run() {
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
        if [ "$INSTALLER_PLAIN_TEXT" != true ]; then
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
        installer_log_success "$info"
    else
        installer_log_failed "$info"
        INSTALLER_ERROR_HAPPENED=true
        INSTALLER_ERROR_LOGS+="\n  `cat /tmp/cmd_output.log`\n"
    fi
    
    # 清理临时文件
    cat /tmp/cmd_output.log >> $INSTALLER_LOG_FILE
    rm -f /tmp/cmd_output.log
    
    return $result
}

installer_check_root_privileges() {
    # Check root privileges
    if [ "$EUID" -ne 0 ]; then
      echo "Please run as root"
      exit 1
    fi
}

# Ctrl+C信号处理函数
installer_handle_interrupt() {
    # 恢复光标（如果之前隐藏了）
    tput cnorm
    progress_bar_trap_on_interrupt
    
    if [ "$INSTALLER_ERROR_HAPPENED" = true ]; then
        echo -e "\n\033[31mUser interrupted. Error logs:\033[0m"
        echo "$INSTALLER_ERROR_LOGS"
        echo "Please check $INSTALLER_LOG_FILE for more details."
    else
        echo -e "\n\033[33mUser canceled.\033[0m"
    fi
    installer_cleanup
    exit 1
}

installer_init_log_file() {
    if [ "$INSTALLER_PLAIN_TEXT" != true ]; then
        if [ -f "$INSTALLER_LOG_FILE" ]; then
            rm $INSTALLER_LOG_FILE
        fi
        touch $INSTALLER_LOG_FILE
    fi
}

installer_log_title() {
    if [ "$INSTALLER_PLAIN_TEXT" == true ]; then
        echo -e $1
    else
        echo -e "\033[34m$1\033[0m"
        echo "[$1]" >> $INSTALLER_LOG_FILE
    fi
}

installer_log_success() {
    if [ "$INSTALLER_PLAIN_TEXT" == true ]; then
        echo -e "$INSTALLER_SUCCESS_PLAIN_TEXT $1"
    else
        echo -e "$INSTALLER_SUCCESS $1"
        echo "$INSTALLER_SUCCESS_PLAIN_TEXT $1" >> $INSTALLER_LOG_FILE
    fi
}

installer_log_failed() {
    if [ "$INSTALLER_PLAIN_TEXT" == true ]; then
        echo -e "$INSTALLER_FAILED_PLAIN_TEXT $1"
    else
        echo -e "$INSTALLER_FAILED $1"
        echo "$INSTALLER_FAILED_PLAIN_TEXT $1" >> $INSTALLER_LOG_FILE
    fi
}

installer_add_command() {
    local command=""
    # Add command space to each argument
    for arg in "$@"; do
        command+="$arg$INSTALLER_COMMAND_SPACE"
    done
    # Remove last command space
    command=${command%$INSTALLER_COMMAND_SPACE}
    INSTALLER_COMMANDS+=("$command")
}

installer_cleanup() {
    installer_log_title "Cleanup"
}

TITLE() {
    installer_add_command TITLE "$@"
}

RUN() {
    commands=()
    for arg in "$@"; do
        commands+=("$arg")
    done
    installer_add_command RUN "${commands[0]}" "${commands[1]}"
    INSTALLER_COMMANDS_COUNT=$((INSTALLER_COMMANDS_COUNT+1))
}

CD() {
    installer_add_command CD "$@"
}

installer_init() {
    # Check root privileges
    installer_check_root_privileges
    # Import progress bar
    installer_import $INSTALLER_PROGRESS_BAR_URL
    # Import config_txt_manager
    installer_import $INSTALLER_CONFIG_TXT_MANAGER_URL
    
    # Find config.txt file
    INSTALLER_CONFIG_TXT_FILE=$(config_txt_find)
    if [ -z "$INSTALLER_CONFIG_TXT_FILE" ]; then
        echo "Warning: config.txt file not found."
        exit 1
    fi

    # 注册信号处理函数
    trap installer_handle_interrupt SIGINT
    
    installer_init_log_file
    
    # Create progress bar
    progress_bar_setup_scroll_area

    for arg in "$@"; do
        case $arg in
        --plain-text)
            INSTALLER_PLAIN_TEXT=true
            ;;
        esac
    done
}

installer_install() {
    installer_init

    local command_count=0

    for (( i=0; i<${#INSTALLER_COMMANDS[@]}; i++ )); do
        command=${INSTALLER_COMMANDS[$i]}
        # Replace &$& with newline
        command="${command//$INSTALLER_COMMAND_SPACE/$'\n'}"
        # break string into array by newline
        mapfile -t command <<< "$command"

        if [ "${command[0]}" == "TITLE" ]; then
            installer_log_title "${command[1]}"
        elif [ "${command[0]}" == "RUN" ]; then
            installer_run "${command[1]}" "${command[2]}"
            command_count=$((command_count+1))
        elif [ "${command[0]}" == "CD" ]; then
            cd "${command[1]}"
        fi
        progress_bar_draw $(((command_count+1)*100/INSTALLER_COMMANDS_COUNT))
    done
    progress_bar_destroy_scroll_area
    
    if [ "$INSTALLER_ERROR_HAPPENED" = false ]; then
        echo -e "Install finished."
    else
        echo -e "Error happened: $INSTALLER_ERROR_LOGS"
        echo -e "Please check $INSTALLER_LOG_FILE for more details."
        exit 1
    fi
}

installer_prompt_reboot() {
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
