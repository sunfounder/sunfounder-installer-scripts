# SunFounder Installer Scripts

This repository contains the installer scripts for SunFounder products.

## Repository policy

- Shared tooling used by the product installers lives in `tools/`.
- A product's installer lives in that product's repository. Product installers
  that used to live here are deprecated: the file is kept as a forwarding stub
  so existing `pironman5 update` commands keep working, see
  [`pironman5/README.md`](pironman5/README.md).
- Scripts for products that have no repository of their own stay here.

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

# Install PiCar-X V4
curl -sSL https://raw.githubusercontent.com/sunfounder/sunfounder-installer-scripts/main/install-picar-x-v4.sh | sudo bash

# Install TFT 3.5 inch IPS TFT display
curl -sSL https://raw.githubusercontent.com/sunfounder/sunfounder-installer-scripts/main/install-tft35ips.sh | sudo bash

# Upgrade AI Fusion Lab Kit from 0.0.1 to 0.1.0
curl -sSL https://raw.githubusercontent.com/sunfounder/sunfounder-installer-scripts/main/ai-fusion-lab-kit-upgrade-0.0.1-to-0.1.0.sh | sudo bash

# Install Pironman 5 - the installer now lives in the product repository
curl -sSL "https://raw.githubusercontent.com/sunfounder/pironman5/v1/install.sh" | sudo bash
# Pironman 5 with PiPower5 option
curl -sSL "https://raw.githubusercontent.com/sunfounder/pironman5/v1/install.sh" | sudo bash -s -- --pipower5
# China mirror
curl -sSL "https://gitee.com/sunfounder/pironman5/raw/v1/install.sh" | sudo bash -s -- --cn

# Setup Fusion Hat Audio - this need to run again after reboot
wget https://raw.githubusercontent.com/sunfounder/sunfounder-installer-scripts/main/setup_fusion_hat_audio.sh
sudo bash setup_fusion_hat_audio.sh

# Setup Robot Hat Audio - this need to run again after reboot
curl -sSL https://raw.githubusercontent.com/sunfounder/sunfounder-installer-scripts/main/setup_robot_hat_audio.sh | sudo bash
```
## Scripts

- `install-picar-x.sh` - Installs the Picar-X robot

## License

This repository is licensed under the GPL-3.0 License. See the [LICENSE](LICENSE) file for more details.

## Contact

- Email: [service@sunfounder.com](mailto:service@sunfounder.com)
- Website: [https://www.sunfounder.com/](https://www.sunfounder.com/)
