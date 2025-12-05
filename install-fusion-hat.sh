#!/bin/bash

INSTALLER_URL="https://raw.githubusercontent.com/sunfounder/sunfounder-installer-scripts/refs/heads/main/tools/installer_1.1.0.sh"

# Source Installer
curl -fsSL $INSTALLER_URL -o installer.sh
if [ $? -ne 0 ]; then
    log_failed "Network error, please check your internet connection."
    exit 1
fi
source installer.sh
rm installer.sh

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

TITLE "Install Fusion Hat Python Library\n"
TITLE "Install dependencies"
RUN "apt-get update" "Update apt"
RUN "apt-get install -y ${APT_INSTALL_LIST[*]}" "Install apt dependencies"

TITLE "Install fusion-hat library"
CD "$HOME/" "Change to home directory"
RUN "rm -rf $HOME/fusion-hat" "Remove existing fusion-hat library"
RUN "git clone --depth=1 --branch main https://github.com/sunfounder/fusion-hat.git" "Clone fusion-hat library"
RUN "chown -R $USERNAME:$USERNAME $HOME/fusion-hat" "Change ownership of fusion-hat library to $USERNAME"

TITLE "Install fusion-hat driver"
CD "$HOME/fusion-hat/driver" "Change to driver directory"
RUN "make all" "Compile driver"
RUN "make install" "Install driver"
RUN "make clean" "Clean driver"

TITLE "Install fusion-hat python library"
CD "$HOME/fusion-hat" "Change to fusion-hat directory"
RUN "pip3 install . --break-system-packages" "Install fusion-hat library"
RUN "pip3 uninstall -y RPi.GPIO --break-system-packages" "Uninstall RPi.GPIO"

TITLE "Setup audio"
RUN "rm -f /opt/setup_fusion_hat_audio.sh" "Remove existing audio script"
RUN "wget -O /opt/setup_fusion_hat_audio.sh https://raw.githubusercontent.com/sunfounder/sunfounder-installer-scripts/main/setup_fusion_hat_audio.sh" "Download audio script"
RUN "chown $USERNAME:$USERNAME /opt/setup_fusion_hat_audio.sh" "Change ownership of audio script to $USERNAME"
RUN "chmod 755 /opt/setup_fusion_hat_audio.sh" "Change permissions of audio script to 755"
RUN "/opt/setup_fusion_hat_audio.sh --skip-test" "Setup audio"

installer_install

installer_prompt_reboot "Remember to run sudo /opt/setup_fusion_hat_audio.sh to enable speaker after reboot."
