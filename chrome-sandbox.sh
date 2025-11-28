#!/bin/bash

# Configuration
IMAGE_NAME="isolated-chrome"
BASE_STORAGE_DIR="$HOME/Chrome"

# Check if profile name is provided
if [ -z "$1" ]; then
    echo "Usage: $0 [ProfileName]"
    echo "Example: $0 Work"
    exit 1
fi

PROFILE_NAME="$1"
PROFILE_DIR="$BASE_STORAGE_DIR/$PROFILE_NAME"
DOWNLOADS_DIR="$BASE_STORAGE_DIR/$PROFILE_NAME/Downloads"

# Create directories if they don't exist
if [ ! -d "$PROFILE_DIR" ]; then
    echo "Creating profile directory: $PROFILE_DIR"
    mkdir -p "$PROFILE_DIR"
    mkdir -p "$DOWNLOADS_DIR"
fi

# Check if Docker image exists, build if not
if [[ "$(docker images -q $IMAGE_NAME 2> /dev/null)" == "" ]]; then
    echo "Image $IMAGE_NAME not found. Building..."
    DOCKER_BUILDKIT=1 docker build -t $IMAGE_NAME "$(dirname "$0")"
fi

# Allow X11 access
xhost +local:docker > /dev/null 2>&1

# --- Audio Setup (PulseAudio) ---
# Ensure the cookie exists and is readable
if [ -f "$HOME/.config/pulse/cookie" ]; then
    PULSE_COOKIE="$HOME/.config/pulse/cookie"
elif [ -f "$HOME/.pulse-cookie" ]; then
    PULSE_COOKIE="$HOME/.pulse-cookie"
else
    # Try to generate one if missing (rare)
    PULSE_COOKIE="/tmp/pulse-cookie-generated"
    touch "$PULSE_COOKIE"
fi

# --- Desktop Entry Integration ---
ICON_PATH="$PROFILE_DIR/chrome-icon.png"
DESKTOP_FILE="$HOME/.local/share/applications/chrome-$PROFILE_NAME.desktop"

# Extract icon if missing (using a generic one or downloading)
if [ ! -f "$ICON_PATH" ]; then
    # Download a standard Chrome icon
    wget -q -O "$ICON_PATH" "https://upload.wikimedia.org/wikipedia/commons/e/e1/Google_Chrome_icon_%28February_2022%29.svg" || true
fi

# Create .desktop file
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Chrome ($PROFILE_NAME)
Comment=Isolated Chrome Profile: $PROFILE_NAME
Exec=$(realpath "$0") "$PROFILE_NAME"
Icon=google-chrome
Terminal=false
Categories=Network;WebBrowser;
StartupWMClass=chrome-$PROFILE_NAME
EOF

# Update desktop database
update-desktop-database "$HOME/.local/share/applications" > /dev/null 2>&1 || true

echo "Launching Isolated Chrome (Profile: $PROFILE_NAME)..."

# Run Docker Container
# Changes:
# - Removed --no-sandbox (Fixed warning)
# - Added --cap-add=SYS_ADMIN (Required for sandbox)
# - Improved PulseAudio mounting (Socket + Cookie)
# - Added --name with timestamp to allow multiple instances if needed (or handle cleanup)
# - Added --ipc=host (Helps with performance/shared memory)

# Clean up previous container if it exists (optional, or we can just restart it)
docker rm -f "chrome-$PROFILE_NAME" > /dev/null 2>&1 || true

docker run -d \
    --name "chrome-$PROFILE_NAME" \
    --ipc=host \
    --cap-add=SYS_ADMIN \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e DISPLAY="$DISPLAY" \
    -v /run/user/$(id -u)/pulse:/run/user/1000/pulse \
    -v "$PULSE_COOKIE":/home/chrome/.config/pulse/cookie \
    -e PULSE_SERVER=unix:/run/user/1000/pulse/native \
    -e PULSE_COOKIE=/home/chrome/.config/pulse/cookie \
    --device /dev/dri \
    --group-add audio \
    --group-add video \
    -v "$PROFILE_DIR":/home/chrome/.config/google-chrome \
    -v "$DOWNLOADS_DIR":/home/chrome/Downloads \
    --security-opt seccomp=unconfined \
    $IMAGE_NAME \
    --window-position=0,0 \
    --window-size=1280,800 \
    --class="chrome-$PROFILE_NAME"

echo "Container chrome-$PROFILE_NAME started."
echo "Desktop entry created at: $DESKTOP_FILE"
