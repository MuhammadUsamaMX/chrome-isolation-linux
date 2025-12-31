#!/bin/bash

# Chrome Isolation Manager - Uninstaller
# Removes all installed components

set -e

echo "🗑️  Chrome Isolation Manager - Uninstaller"
echo "=========================================="
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Installation directory
INSTALL_DIR="$HOME/.local/share/chrome-isolation-manager"

# Confirm uninstallation
echo -e "${YELLOW}⚠️  This will remove:${NC}"
echo "  • Chrome Isolation Manager application"
echo "  • Systemd service"
echo "  • Desktop entries for all profiles"
echo "  • Docker containers (running profiles will be stopped)"
echo ""
echo -e "${YELLOW}⚠️  Your profile data in ~/Chrome will NOT be deleted${NC}"
echo ""
read -p "Are you sure you want to uninstall? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi

echo ""
echo "🛑 Stopping and disabling service..."
if systemctl is-active --quiet chrome-manager.service; then
    sudo systemctl stop chrome-manager.service
    echo -e "${GREEN}✅ Service stopped${NC}"
fi

if systemctl is-enabled --quiet chrome-manager.service 2>/dev/null; then
    sudo systemctl disable chrome-manager.service
    echo -e "${GREEN}✅ Service disabled${NC}"
fi

echo ""
echo "🗑️  Removing systemd service..."
if [ -f "/etc/systemd/system/chrome-manager.service" ]; then
    sudo rm /etc/systemd/system/chrome-manager.service
    sudo systemctl daemon-reload
    echo -e "${GREEN}✅ Service file removed${NC}"
fi

echo ""
echo "🐳 Stopping and removing Docker containers..."
CONTAINERS=$(docker ps -a --filter "name=chrome-" --format "{{.Names}}" 2>/dev/null || true)
if [ -n "$CONTAINERS" ]; then
    echo "$CONTAINERS" | while read container; do
        echo "  Removing $container..."
        docker rm -f "$container" > /dev/null 2>&1 || true
    done
    echo -e "${GREEN}✅ Containers removed${NC}"
else
    echo "  No containers found"
fi

echo ""
echo "🖼️  Removing Docker image..."
if docker images | grep -q "isolated-chrome"; then
    docker rmi isolated-chrome > /dev/null 2>&1 || true
    echo -e "${GREEN}✅ Docker image removed${NC}"
else
    echo "  Image not found"
fi

echo ""
echo "📁 Removing desktop entries..."
DESKTOP_ENTRIES=$(find ~/.local/share/applications -name "chrome-*.desktop" 2>/dev/null || true)
if [ -n "$DESKTOP_ENTRIES" ]; then
    echo "$DESKTOP_ENTRIES" | while read entry; do
        echo "  Removing $(basename "$entry")..."
        rm "$entry"
    done
    update-desktop-database ~/.local/share/applications > /dev/null 2>&1 || true
    echo -e "${GREEN}✅ Desktop entries removed${NC}"
else
    echo "  No desktop entries found"
fi

echo ""
echo "🚀 Removing autostart entry..."
AUTOSTART_FILE="$HOME/.config/autostart/chrome-isolation-startup.desktop"
if [ -f "$AUTOSTART_FILE" ]; then
    rm "$AUTOSTART_FILE"
    echo -e "${GREEN}✅ Autostart entry removed${NC}"
else
    echo "  Autostart entry not found"
fi

echo ""
echo "📂 Removing installation directory..."
if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    echo -e "${GREEN}✅ Installation directory removed${NC}"
else
    echo "  Installation directory not found"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}✅ Uninstallation Complete!${NC}"
echo "=========================================="
echo ""
echo "Your profile data is still available at: ~/Chrome"
echo ""
echo "To completely remove all data, run:"
echo "  rm -rf ~/Chrome"
echo ""
echo "To reinstall, run ./install.sh"
