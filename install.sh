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

# Installation directory
INSTALL_DIR="$HOME/.local/share/chrome-isolation-manager"

# Get the directory where the script is located (source directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
echo "📁 Creating installation directory..."

# Remove old installation if exists
if [ -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}⚠️  Existing installation found at $INSTALL_DIR${NC}"
    echo "Removing old installation..."
    rm -rf "$INSTALL_DIR"
fi

# Create installation directory
mkdir -p "$INSTALL_DIR"

# Copy application files
echo "📋 Copying application files..."
cp -r "$SCRIPT_DIR/app" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/Dockerfile" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/requirements.txt" "$INSTALL_DIR/"
mkdir -p "$INSTALL_DIR/scripts"
cp "$SCRIPT_DIR/scripts/chrome-launcher.sh" "$INSTALL_DIR/scripts/"
chmod +x "$INSTALL_DIR/scripts/chrome-launcher.sh"

echo -e "${GREEN}✅ Files copied to $INSTALL_DIR${NC}"

echo ""
echo "🐳 Building Docker image..."
cd "$INSTALL_DIR"
DOCKER_BUILDKIT=1 docker build -t isolated-chrome .

echo ""
echo "📁 Setting up directories..."
mkdir -p ~/Chrome
mkdir -p ~/.local/share/applications

echo ""
echo "🔧 Configuring X11 access..."
if command -v xhost &> /dev/null; then
    xhost +local:docker
    echo -e "${GREEN}✅ X11 access configured${NC}"
else
    echo -e "${YELLOW}⚠️  xhost not found - X11 access may not work${NC}"
fi

echo ""
echo "🚀 Setting up autostart..."
AUTOSTART_DIR="$HOME/.config/autostart"
mkdir -p "$AUTOSTART_DIR"

cat > "$AUTOSTART_DIR/chrome-isolation-startup.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Chrome Isolation Startup
Comment=Configure X11 access for Chrome Isolation
Exec=$INSTALL_DIR/scripts/startup.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

echo -e "${GREEN}✅ Autostart entry created${NC}"

echo ""
echo "🔧 Installing systemd service..."

# Create systemd service file with correct paths
SERVICE_FILE="/tmp/chrome-manager-$USER.service"
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Chrome Isolation Manager Web Interface
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
User=$USER
WorkingDirectory=$INSTALL_DIR/app
Environment="PATH=/usr/local/bin:/usr/bin:/bin"
ExecStart=/usr/bin/python3 $INSTALL_DIR/app/app.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

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
echo "📍 Installation Directory: $INSTALL_DIR"
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
echo "  • Uninstall: Run ./uninstall.sh from the source directory"
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
