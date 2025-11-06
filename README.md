# SunFounder Installer Scripts

This repository contains the installer scripts for SunFounder products.

To install anything, use a command like this:

```bash
curl -sSL https://raw.githubusercontent.com/sunfounder/sunfounder-installer-scripts/main/<SCRIPT> | sudo bash
```

Replace `<SCRIPT>` with the name of the script you want to run. Like this:

```bash
curl -sSL https://raw.githubusercontent.com/sunfounder/sunfounder-installer-scripts/main/install-picar-x.sh | sudo bash
```

## Install commands

Here are all install commands for easy access:

```bash
# Install Fusion Hat
curl -sSL https://raw.githubusercontent.com/sunfounder/sunfounder-installer-scripts/main/install-fusion-hat.sh | sudo bash

# Install Picar-X
curl -sSL https://raw.githubusercontent.com/sunfounder/sunfounder-installer-scripts/main/install-picar-x.sh | sudo bash

# Install TFT 3.5 inch IPS TFT display
curl -sSL https://raw.githubusercontent.com/sunfounder/sunfounder-installer-scripts/main/install-tft35ips.sh | sudo bash

# Setup Fusion Hat Audio - this need to run again after reboot
wget https://raw.githubusercontent.com/sunfounder/sunfounder-installer-scripts/main/setup_fusion_hat_audio.sh
sudo bash setup_fusion_hat_audio.sh

```
## Scripts

- `install-picar-x.sh` - Installs the Picar-X robot

## License

This repository is licensed under the GPL-3.0 License. See the [LICENSE](LICENSE) file for more details.

## Contact

- Email: [service@sunfounder.com](mailto:service@sunfounder.com)
- Website: [https://www.sunfounder.com/](https://www.sunfounder.com/)
