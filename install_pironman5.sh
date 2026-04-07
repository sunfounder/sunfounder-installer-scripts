#!/bin/bash

# Note: For interactive prompts to work properly, please download and run:
# curl -sSL https://raw.githubusercontent.com/sunfounder/sunfounder-installer-scripts/main/install_pironman5.sh -o install_pironman5.sh
# sudo bash install_pironman5.sh
# (Do NOT use: curl ... | sudo bash)

declare -A products=(
    ["base"]="Pironman 5"
    ["mini"]="Pironman 5 Mini"
    ["max"]="Pironman 5 Max"
    ["pro-max"]="Pironman 5 Pro Max"
)

INSTALLER_URL="https://raw.githubusercontent.com/sunfounder/sunfounder-installer-scripts/refs/heads/main/tools/installer_1.1.0.sh"

# Source Installer (add timestamp to bypass cache)
curl -fsSL "$INSTALLER_URL?$(date +%s)" -o installer.sh
if [ $? -ne 0 ]; then
    log_failed "Network error, please check your internet connection."
    exit 1
fi
source installer.sh
rm installer.sh

installer_check_root_privileges

# Product selection
product_names=("${products[@]}")
product_keys=("${!products[@]}")

echo "Pironman 5 Series:"
PS3="Please select your product: "
select choice in "${product_names[@]}"; do
    for i in "${!product_names[@]}"; do
        if [[ "${product_names[$i]}" = "$choice" ]]; then
            branch_name="${product_keys[$i]}"
            product_name="$choice"
            break 2
        fi
    done
done
PS3=""

installer_log_title "\nPreparing installation for ${product_name}"

installer_update_git_urls

installer_run "apt-get install git python3 python3-pip python3-setuptools -y" "Installing dependencies..."

cd ~
rm -rf ~/pironman5
# git clone -b $branch_name https://github.com/sunfounder/pironman5.git --depth 1
installer_git_clone pironman5 $branch_name
cd ~/pironman5
python3 install.py

