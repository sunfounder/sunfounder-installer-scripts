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
    "raspberrypi-kernel-headers"
)

cleanup() {
}

COMMANDS=(
    # Install dependencies
    "log_title \"Install SunFounder TFT 3.5 Inch Display Driver\n\""
    "log_title \"Install dependencies\""
    "run \"apt-get update\" \"Update apt\""
    "run \"apt-get install -y ${APT_INSTALL_LIST[*]}\" \"Install apt dependencies\""

    "log_title \"Download driver\""
    "cd $HOME/"
    "run \"rm -rf $HOME/sunfounder-tft35ips\" \"Remove existing folder\""
    "run \"git clone --depth=1 --branch main https://github.com/sunfounder/sunfounder-tft35ips.git\" \"Clone driver\""
    "run \"chown -R $USERNAME:$USERNAME $HOME/sunfounder-tft35ips\" \"Change ownership of driver to $USERNAME\""

    "log_title \"Build and install driver\""
    "cd $HOME/sunfounder-tft35ips/driver"
    "run \"make all\" \"Compile driver\""
    "run \"make install\" \"Install driver\""
    "run \"make clean\" \"Clean driver\""

    "log_title \"Setup driver\""
    "cd $HOME/sunfounder-tft35ips"
    "run \"cp 99-calibration.conf /etc/X11/xorg.conf.d/\" \"Copy calibration config\""
    "run \"config_txt_set $CONFIG_TXT_FILE dtoverlay=sunfounder-tft35ips\" \"Add dtoverlay\""
)

install $COMMANDS

prompt_reboot ""
