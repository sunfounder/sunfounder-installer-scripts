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
    "dkms"
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
RUN "fusion_hat setup_speaker --skip-test" "Setup audio"

installer_install

installer_prompt_reboot "Remember to run fusion_hat setup_speaker to enable speaker after reboot."
