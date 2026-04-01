#!/bin/bash
declare -A products=(
    ["base"]="Pironman 5"
    ["mini"]="Pironman 5 Mini"
    ["max"]="Pironman 5 Max"
    ["pro-max"]="Pironman 5 Pro Max"
)

INSTALLER_URL="https://raw.githubusercontent.com/sunfounder/sunfounder-installer-scripts/refs/heads/main/tools/installer_1.1.0.sh"

# Source Installer
curl -fsSL $INSTALLER_URL -o installer.sh
if [ $? -ne 0 ]; then
    log_failed "Network error, please check your internet connection."
    exit 1
fi
source installer.sh
rm installer.sh

installer_check_root_privileges
installer_update_git_urls

# Product selection
echo "Please select your product:"
PS3="#? "
select choice in "${products[@]}"; do
    case $REPLY in
        1) branch_name="base"; product_name="Pironman 5"; break ;;
        2) branch_name="mini"; product_name="Pironman 5 Mini"; break ;;
        3) branch_name="max"; product_name="Pironman 5 Max"; break ;;
        4) branch_name="pro-max"; product_name="Pironman 5 Pro Max"; break ;;
        *) echo "Invalid option, please try again." ;;
    esac
done
PS3=""

installer_log_title "\nPreparing installation for ${product_name}"

apt-get install git python3 python3-pip python3-setuptools -y

cd ~
rm -rf ~/pironman5
# git clone -b $branch_name https://github.com/sunfounder/pironman5.git --depth 1
CLONE pironman5 $branch_name
cd ~/pironman5

python3 install.py

