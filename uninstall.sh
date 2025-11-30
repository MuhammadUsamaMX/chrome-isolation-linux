#!/bin/bash

# Chrome Isolation Manager - Uninstaller
# Safely removes all components installed by install.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🧹 Chrome Isolation Manager - Uninstall Script"
echo "=============================================="
echo ""

# Check if root – SHOULD be root for uninstall
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}⚠️  Please run this script as root (sudo)${NC}"
    exit 1
fi

# Detect install path (script location)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SERVICE_NAME="chrome-manager.service"
APP_DIR="$SCRIPT_DIR/app"
PROFILE_DIR="/home/$SUDO_USER/Chrome"
DESKTOP_DIR="/home/$SUDO_USER/.local/share/applications"
DOCKER_IMAGE="isolated-chrome"

echo -e "${YELLOW}⚠️  This will REMOVE Chrome Isolation Manager completely.${NC}"
echo -e "Including:"
echo "  • Systemd service"
echo "  • Docker image ($DOCKER_IMAGE)"
echo "  • ~/Chrome profiles"
echo "  • Desktop launcher entries"
echo "  • App folder (optional)"
echo ""

read -rp "Are you sure? (y/N): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "❌ Uninstall cancelled."
    exit 0
fi

echo ""
echo "🛑 Stopping systemd service..."
systemctl stop $SERVICE_NAME 2>/dev/null || true

echo "❌ Disabling systemd service..."
systemctl disable $SERVICE_NAME 2>/dev/null || true

echo "🗑 Removing systemd file..."
rm -f /etc/systemd/system/$SERVICE_NAME
systemctl daemon-reload

echo ""
echo "🐳 Removing Docker containers & image..."
docker stop isolated-chrome-container 2>/dev/null || true
docker rm isolated-chrome-container 2>/dev/null || true
docker rmi $DOCKER_IMAGE 2>/dev/null || true

echo ""
echo "🗑 Removing user Chrome profiles..."
rm -rf "$PROFILE_DIR"

echo "🗑 Removing desktop entries (*.desktop)..."
find "$DESKTOP_DIR" -maxdepth 1 -name "chrome-isolated-*.desktop" -exec rm -f {} \;

echo ""
read -rp "Remove application folder as well? ($SCRIPT_DIR) (y/N): " REMOVE_APP
if [[ "$REMOVE_APP" == "y" || "$REMOVE_APP" == "Y" ]]; then
    rm -rf "$APP_DIR"
    echo -e "${GREEN}✔ App folder removed.${NC}"
else
    echo -e "${YELLOW}Skipping app folder removal.${NC}"
fi

echo ""
read -rp "Remove python dependencies installed via apt? (python3-flask python3-docker) (y/N): " REMOVE_PY
if [[ "$REMOVE_PY" == "y" || "$REMOVE_PY" == "Y" ]]; then
    apt remove -y python3-flask python3-docker
    echo -e "${GREEN}✔ Python packages removed.${NC}"
else
    echo -e "${YELLOW}Skipping Python package removal.${NC}"
fi

echo ""
echo "🧼 Cleaning leftover files..."
rm -rf /tmp/chrome-manager-* 2>/dev/null || true

echo ""
echo "=============================================="
echo -e "${GREEN}✔ Uninstall Complete!${NC}"
echo "=============================================="
echo ""
echo "If you want to reinstall later, just run:"
echo "  ./install.sh"
echo ""

exit 0
