#!/bin/bash

INSTALLER_URL="https://raw.githubusercontent.com/sunfounder/sunfounder-installer-scripts/refs/heads/main/tools/installer_1.1.0.sh"

# Source Installer
curl -fsSL $INSTALLER_URL -o installer.sh
if [ $? -ne 0 ]; then
    installer_log_failed "Network error, please check your internet connection."
    exit 1
fi
source installer.sh
rm installer.sh
# source tools/installer_1.1.0.sh

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

# Install robot-hat
TITLE "Install robot-hat"
CD $HOME
RUN "rm -rf $HOME/robot-hat" "Remove robot-hat if exists"
CLONE "robot-hat" "2.6.x"
if [ $? -ne 0 ]; then
    installer_log_failed "Failed to clone robot-hat."
    exit 1
fi
CD $HOME/robot-hat
RUN "python3 install.py" "Install robot-hat"

# Install vilib
TITLE "Install vilib"
CD $HOME
RUN "rm -rf $HOME/vilib" "Remove vilib if exists"
CLONE "vilib" "main"
if [ $? -ne 0 ]; then
    installer_log_failed "Failed to clone vilib."
    exit 1
fi
CD $HOME/vilib
RUN "python3 install.py" "Install vilib"

# Install picar-x
TITLE "Install picar-x"
CD $HOME
RUN "rm -rf $HOME/picar-x" "Remove $HOME/picar-x if exist"
CLONE "picar-x" "3.0.x"
if [ $? -ne 0 ]; then
    installer_log_failed "Failed to clone picar-x."
    exit 1
fi
RUN "chown -R $USERNAME:$USERNAME $HOME/picar-x" "Change ownership of picar-x to $USERNAME"
CD $HOME/picar-x
RUN "pip3 install ./ --break-system-packages --force-reinstall --ignore-installed" "Install picar-x"

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
TITLE "Install picar-x-app"
RUN "echo '[Unit]' > /etc/systemd/system/picar-x-app.service && echo 'Description=picarx service' >> /etc/systemd/system/picar-x-app.service && echo 'After=multi-user.target' >> /etc/systemd/system/picar-x-app.service && echo '' >> /etc/systemd/system/picar-x-app.service && echo '[Service]' >> /etc/systemd/system/picar-x-app.service && echo 'Type=simple' >> /etc/systemd/system/picar-x-app.service && echo 'WorkingDirectory=/home/$USERNAME/picar-x/app' >> /etc/systemd/system/picar-x-app.service && echo 'ExecStart=python3 app.py' >> /etc/systemd/system/picar-x-app.service && echo '' >> /etc/systemd/system/picar-x-app.service && echo '[Install]' >> /etc/systemd/system/picar-x-app.service && echo 'WantedBy=multi-user.target' >> /etc/systemd/system/picar-x-app.service" "Create picar-x-app service"
RUN "systemctl enable picar-x-app.service" "Enable picar-x-app service"
RUN "systemctl daemon-reload" "Reload systemd daemon"
TITLE "picar-x-app installed"

installer_install

installer_prompt_reboot "Remember to run sudo /opt/setup_robot_hat_audio.sh to enable speaker after reboot."
