#!/bin/bash

# Chrome Isolation Manager - Automated Installer
# For Ubuntu/Debian-based Linux systems

set -e

echo "🚀 Chrome Isolation Manager - Installation Script"
echo "=================================================="
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR/app"
SYSTEMD_DIR="$SCRIPT_DIR/systemd"

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}❌ Please do not run this script as root${NC}"
    echo "Run it as your regular user. It will ask for sudo when needed."
    exit 1
fi

echo "📋 Checking system requirements..."
echo ""

# Check for Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed${NC}"
    echo "Please install Docker first:"
    echo "  sudo apt update"
    echo "  sudo apt install docker.io"
    echo "  sudo usermod -aG docker $USER"
    echo "  newgrp docker"
    exit 1
else
    echo -e "${GREEN}✅ Docker found: $(docker --version)${NC}"
fi

# Check if user is in docker group
if ! groups | grep -q docker; then
    echo -e "${YELLOW}⚠️  Your user is not in the docker group${NC}"
    echo "Adding you to the docker group..."
    sudo usermod -aG docker $USER
    echo -e "${YELLOW}⚠️  You need to log out and log back in for this to take effect${NC}"
    echo "After logging back in, run this installer again."
    exit 1
fi

# Check for Python 3
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python 3 is not installed${NC}"
    echo "Installing Python 3..."
    sudo apt update
    sudo apt install -y python3 python3-pip
else
    echo -e "${GREEN}✅ Python 3 found: $(python3 --version)${NC}"
fi

# Check for pip
if ! command -v pip3 &> /dev/null; then
    echo -e "${YELLOW}⚠️  pip3 not found, installing...${NC}"
    sudo apt install -y python3-pip
fi

echo -e "${GREEN}✅ pip3 found${NC}"

# Check for curl
if ! command -v curl &> /dev/null; then
    echo -e "${YELLOW}⚠️  curl not found, installing...${NC}"
    sudo apt install -y curl
fi

echo -e "${GREEN}✅ curl found${NC}"

echo ""
echo "📦 Installing Python dependencies..."

# Check if packages are already installed via apt
if ! python3 -c "import flask" 2>/dev/null; then
    echo "Installing python3-flask..."
    sudo apt update
    sudo apt install -y python3-flask python3-docker
else
    echo -e "${GREEN}✅ Python packages already installed${NC}"
fi

echo ""
echo "🐳 Building Docker image..."
cd "$SCRIPT_DIR"
DOCKER_BUILDKIT=1 docker build -t isolated-chrome .

echo ""
echo "📁 Setting up directories..."
mkdir -p ~/Chrome
mkdir -p ~/.local/share/applications

echo ""
echo "🔧 Installing systemd service..."

# Create a temporary service file with the correct user
SERVICE_FILE="/tmp/chrome-manager-$USER.service"
sed "s/%u/$USER/g" "$SYSTEMD_DIR/chrome-manager.service" > "$SERVICE_FILE"

# Install the service
sudo cp "$SERVICE_FILE" /etc/systemd/system/chrome-manager.service
rm "$SERVICE_FILE"

# Reload systemd and enable the service
sudo systemctl daemon-reload
sudo systemctl enable chrome-manager.service
sudo systemctl start chrome-manager.service

echo ""
echo "⏳ Waiting for service to start..."
sleep 3

# Check if service is running
if systemctl is-active --quiet chrome-manager.service; then
    echo -e "${GREEN}✅ Service is running!${NC}"
else
    echo -e "${RED}❌ Service failed to start${NC}"
    echo "Check logs with: sudo journalctl -u chrome-manager.service -n 50"
    exit 1
fi

echo ""
echo "=================================================="
echo -e "${GREEN}✅ Installation Complete!${NC}"
echo "=================================================="
echo ""
echo "🌐 Web Interface: http://localhost:5000"
echo "📁 Profiles Directory: ~/Chrome"
echo ""
echo "Quick Start:"
echo "  1. Open http://localhost:5000 in your browser"
echo "  2. Create a new profile"
echo "  3. Launch it from your application menu!"
echo ""
echo "Useful Commands:"
echo "  • View logs: sudo journalctl -u chrome-manager.service -f"
echo "  • Restart service: sudo systemctl restart chrome-manager.service"
echo "  • Stop service: sudo systemctl stop chrome-manager.service"
echo ""
echo "Opening web interface in 3 seconds..."
sleep 3

# Try to open the browser
if command -v xdg-open &> /dev/null; then
    xdg-open http://localhost:5000 &
elif command -v gnome-open &> /dev/null; then
    gnome-open http://localhost:5000 &
fi

echo ""
echo "🎉 Enjoy your isolated Chrome profiles!"
