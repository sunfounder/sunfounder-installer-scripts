
#!/bin/bash

# Check root permission
if [ "$UID" -ne 0 ]; then
    echo "Please run this script as root"
    exit 1
fi

# Check if user 'pi' exists
if ! id "pi" &>/dev/null; then
    echo "Error: user 'pi' not found"
    exit 1
fi

HOME=/home/pi

# Check if target directory exists
if [ ! -d "$HOME/ai-lab-kit" ]; then
    echo "Error: $HOME/ai-lab-kit not found"
    exit 1
fi

echo "Upgrade from 0.0.1 to 0.1.0"

echo "Pull latest code from GitHub"

cd $HOME/ai-lab-kit
git pull
cd $HOME

echo "Install dependencied for YOLO"
pip install mediapipe ultralytics pyyaml requests psutil polars tqdm matplotlib seaborn --break-system-packages

# Install CPU version of PyTorch (specify CPU source)
pip3 install torch torchvision --index-url https://download.pytorch.org/whl/cpu --break-system-packages

echo "Fix model privilege"
mkdir -p /opt/vosk_models
mkdir -p /opt/piper_models
chown -R pi:pi /opt/vosk_models
chown -R pi:pi /opt/piper_models

echo "Upgrade completed"
