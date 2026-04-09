
#!/bin/bash

# Check root permission
if [ "$UID" -ne 0 ]; then
    echo "Please run this script as root"
    exit 1
fi

echo "Upgrade from 0.0.1 to 0.1.0"

echo "Pull latest code from GitHub"

HOME=/home/pi

cd $HOME/ai-lab-kit
git pull
cd $HOME

echo "Install dependencied for YOLO"
pip install mediapipe ultralytics pyyaml requests psutil polars tqdm matplotlib seaborn --break-system-packages

# Install CPU version of PyTorch (specify CPU source)
pip3 install torch torchvision --index-url https://download.pytorch.org/whl/cpu --break-system-packages

echo "Fix model privilege"
mkdir /opt/vosk_models
chown -R pi:pi /opt/vosk_models
mkdir /opt/piper_models
chown -R pi:pi /opt/piper_models

echo "Upgrade completed"
