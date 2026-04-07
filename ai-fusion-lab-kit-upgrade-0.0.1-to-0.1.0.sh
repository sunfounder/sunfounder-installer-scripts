
echo "Upgrade from 0.0.1 to 0.1.0"

echo "Pull latest code from GitHub"

cd $HOME/ai-lab-kit
git pull
cd $HOME

echo "Install dependencied for YOLO"
sudo pip install mediapipe ultralytics pyyaml requests psutil polars tqdm matplotlib seaborn --break-system-packages

# Install CPU version of PyTorch (specify CPU source)
pip3 install torch torchvision --index-url https://download.pytorch.org/whl/cpu --break-system-packages

echo "Fix model privilege"
sudo mkdir /opt/vosk_models
sudo chown -R pi:pi /opt/vosk_models
sudo mkdir /opt/piper_models
sudo chown -R pi:pi /opt/piper_models

echo "Upgrade completed"
