#!/bin/bash

# INSTALLER_URL="https://raw.githubusercontent.com/sunfounder/sunfounder-installer-scripts/refs/heads/main/tools/installer_1.1.0.sh"

# # Source Installer
# curl -fsSL $INSTALLER_URL -o installer.sh
# if [ $? -ne 0 ]; then
#     log_failed "Network error, please check your internet connection."
#     exit 1
# fi
# source installer.sh
# rm installer.sh
source tools/installer_1.1.0.sh

APT_INSTALL_LIST=(
    "git"
    "python3"
    "python3-pip"
    "python3-dev"
    "python3-venv"
    "python3-pyaudio"
    "sox"
)

TITLE "Install PiCar-X V4\n"

# Install dependencies
TITLE "Install dependencies"
RUN "apt-get update" "Update apt"
RUN "apt-get install -y ${APT_INSTALL_LIST[*]}" "Install apt dependencies"
# sudo apt install -y libatlas-base-dev libjasper-dev libqtgui4 libqt4-test

# Install robot-hat
TITLE "Install robot-hat"
CD $HOME
RUN "rm -rf $HOME/robot-hat" "Remove robot-hat if exists"
RUN "git clone -b 2.5.x --depth=1 https://github.com/sunfounder/robot-hat.git" "Clone robot-hat"
if [ $? -ne 0 ]; then
    log_failed "Failed to clone robot-hat."
    exit 1
fi
CD $HOME/robot-hat
RUN "python3 install.py" "Install robot-hat"

# Install vilib
TITLE "Install vilib"
CD $HOME
RUN "rm -rf $HOME/vilib" "Remove vilib if exists"
RUN "git clone --depth=1 https://github.com/sunfounder/vilib.git" "Clone vilib"
if [ $? -ne 0 ]; then
    log_failed "Failed to clone vilib."
    exit 1
fi
CD $HOME/vilib
RUN "python3 install.py" "Install vilib"

# Install picar-x
TITLE "Install picar-x"
CD $HOME
RUN "rm -rf $HOME/picar-x" "Remove $HOME/picar-x if exist"
RUN "git clone -b 3.0.x --depth=1 https://github.com/sunfounder/picar-x.git" "Clone picar-x"
if [ $? -ne 0 ]; then
    log_failed "Failed to clone picar-x."
    exit 1
fi
RUN "chown -R $USERNAME:$USERNAME $HOME/picar-x" "Change ownership of picar-x to $USERNAME"
CD $HOME/picar-x
RUN "pip3 install ./ --break-system-packages" "Install picar-x"

# Create dir for config
RUN "mkdir -p /opt/picar-x" "Create dir for config"
RUN "chown -R $USERNAME:$USERNAME /opt/picar-x" "Change ownership of /opt/picar-x to $USERNAME:$USERNAME"
RUN "chmod -R 755 /opt/picar-x" "Change permissions of /opt/picar-x to 755"

# Setup audio script
TITLE "Setup audio script"
RUN "wget -O /opt/setup_robot_hat_audio.sh https://raw.githubusercontent.com/sunfounder/sunfounder-installer-scripts/main/setup_robot_hat_audio.sh" "Download audio script"
RUN "chmod 755 /opt/setup_robot_hat_audio.sh" "Change permissions of audio script to 755"
RUN "/opt/setup_robot_hat_audio.sh --skip-test" "Setup audio script"

# Install picar-x-app
# TITLE "Install picar-x-app"
# RUN "echo \"[Unit]
# Description=picarx service
# After=multi-user.target

# [Service]
# Type=simple
# WorkingDirectory=/home/$USERNAME/picar-x/app
# ExecStart=python3 app.py

# [Install]
# WantedBy=multi-user.target\" > /etc/systemd/system/picar-x-app.service" "Create picar-x-app service"
# RUN "systemctl enable picar-x-app.service" "Enable picar-x-app service"
# RUN "systemctl daemon-reload" "Reload systemd daemon"
# RUN "systemctl start picar-x-app.service" "Start picar-x-app service"
# TITLE "picar-x-app installed"

installer_install

installer_prompt_reboot "Remember to run sudo /opt/setup_robot_hat_audio.sh to enable speaker after reboot."
