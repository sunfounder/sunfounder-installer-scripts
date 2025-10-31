#!/bin/bash

INSTALLER_URL="https://raw.githubusercontent.com/sunfounder/sunfounder-installer-scripts/refs/heads/main/tools/installer.sh"

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

cleanup() {
    log_title "Cleanup"
}

COMMANDS=(
    # Install dependencies
    "log_title \"Install Fusion Hat Python Library\n\""
    "log_title \"Install dependencies\""
    "run \"apt-get update\" \"Update apt\""
    "run \"apt-get install -y ${APT_INSTALL_LIST[*]}\" \"Install apt dependencies\""
    "run \"pip3 uninstall -y RPi.GPIO --break-system-packages\" \"Uninstall RPi.GPIO\""

    # Install fusion-hat library
    "log_title \"Install fusion-hat library\""
    "cd $HOME/"
    "run \"rm -rf $HOME/fusion-hat\" \"Remove existing fusion-hat library\""
    "run \"git clone --depth=1 --branch main https://github.com/sunfounder/fusion-hat.git\" \"Clone fusion-hat library\""
    "run \"chown -R $USERNAME:$USERNAME $HOME/fusion-hat\" \"Change ownership of fusion-hat library to $USERNAME\""

    # Install fusion-hat driver
    "log_title \"Install fusion-hat driver\""
    "cd $HOME/fusion-hat/driver"
    "run \"make all\" \"Compile driver\""
    "run \"make install\" \"Install driver\""
    "run \"make clean\" \"Clean driver\""

    # Install fusion-hat library
    "log_title \"Install fusion-hat library\""
    "cd $HOME/fusion-hat"
    "run \"pip3 install . --break-system-packages\" \"Install fusion-hat library\""

    # Setup audio script
    "log_title \"Setup audio script\""
    "run \"rm -f /opt/setup_fusion_hat_audio.sh\" \"Remove existing audio script\""
    "run \"wget -O /opt/setup_fusion_hat_audio.sh https://raw.githubusercontent.com/sunfounder/sunfounder-installer-scripts/main/setup_fusion_hat_audio.sh\" \"Download audio script\""
    "run \"chown $USERNAME:$USERNAME /opt/setup_fusion_hat_audio.sh\" \"Change ownership of audio script to $USERNAME\""
    "run \"chmod 755 /opt/setup_fusion_hat_audio.sh\" \"Change permissions of audio script to 755\""
    "run \"/opt/setup_fusion_hat_audio.sh --skip-test\" \"Setup audio\""
)

install $COMMANDS

prompt_reboot "Remember to run sudo /opt/setup_fusion_hat_audio.sh to enable speaker after reboot."
