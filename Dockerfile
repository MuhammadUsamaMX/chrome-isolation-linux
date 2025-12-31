FROM alpine:3.19

# Build arguments for user creation and stealth
ARG USER_ID=1000
ARG GROUP_ID=1000

# Install only essential runtime dependencies with aggressive cleanup
RUN apk add --no-cache \
    chromium \
    alsa-lib \
    mesa-gbm \
    mesa-gl \
    mesa-vulkan-intel \
    mesa-vulkan-ati \
    vulkan-loader \
    libxcb \
    gtk+3.0 \
    libcanberra-gtk3 \
    font-noto \
    pulseaudio-alsa \
    bash \
    python3 \
    coreutils \
    && addgroup -g ${GROUP_ID} chrome \
    && adduser -u ${USER_ID} -G chrome -D -s /bin/bash chrome \
    && adduser chrome audio \
    && adduser chrome video \
    && mkdir -p /home/chrome/.config/chromium /home/chrome/Downloads /home/chrome/scripts \
    && chown -R chrome:chrome /home/chrome \
    && find /usr -name "*.pyc" -delete 2>/dev/null || true \
    && find /usr -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true \
    && rm -rf /var/cache/apk/* /tmp/* /var/tmp/* \
    && rm -rf /usr/share/man /usr/share/doc /usr/share/info /usr/share/locale \
    && rm -rf /usr/share/gtk-doc /usr/share/terminfo /usr/share/zoneinfo/right \
    && find /usr/lib -name "*.a" -delete 2>/dev/null || true \
    && find /usr/lib -name "*.la" -delete 2>/dev/null || true \
    && mkdir -p /home/chrome/scripts \
    && printf '#!/bin/bash\nPROFILE_NAME="${1:-default}"\nCONFIG_DIR="/home/chrome/.config/chromium"\nHARDWARE_FILE="$CONFIG_DIR/hardware-signature.json"\nmkdir -p "$CONFIG_DIR"\nif [[ ! -f "$HARDWARE_FILE" ]]; then\n    CPU_CORES=$((RANDOM %% 15 + 2))\n    RAM_SIZES=(4 8 16 32)\n    RAM_GB=${RAM_SIZES[$RANDOM %% ${#RAM_SIZES[@]}]}\n    GPU_MODELS=("NVIDIA GeForce GTX 1050" "NVIDIA GeForce GTX 1060" "AMD Radeon RX 580" "Intel UHD Graphics 630")\n    GPU_MODEL=${GPU_MODELS[$RANDOM %% ${#GPU_MODELS[@]}]}\n    RESOLUTIONS=("1920x1080" "2560x1440" "1366x768" "1440x900")\n    RESOLUTION=${RESOLUTIONS[$RANDOM %% ${#RESOLUTIONS[@]}]}\n    MAC_ADDRESS=$(printf '\''02:%%02x:%%02x:%%02x:%%02x:%%02x'\'' $((RANDOM%%256)) $((RANDOM%%256)) $((RANDOM%%256)) $((RANDOM%%256)) $((RANDOM%%256)))\n    TIMEZONES=("America/New_York" "America/Los_Angeles" "Europe/London" "Asia/Tokyo")\n    TIMEZONE=${TIMEZONES[$RANDOM %% ${#TIMEZONES[@]}]}\n    cat > "$HARDWARE_FILE" << EOF2\n{\n    "profile": "$PROFILE_NAME",\n    "hardware": {\n        "cpu_cores": $CPU_CORES,\n        "ram_gb": $RAM_GB,\n        "gpu_model": "$GPU_MODEL",\n        "screen_resolution": "$RESOLUTION",\n        "mac_address": "$MAC_ADDRESS"\n    },\n    "system": {\n        "timezone": "$TIMEZONE"\n    }\n}\nEOF2\nfi\nCPU_CORES=$(python3 -c "import json; print(json.load(open('\''$HARDWARE_FILE'\'')).get('\''hardware'\'',{}).get('\''cpu_cores'\'',4))")\nRAM_GB=$(python3 -c "import json; print(json.load(open('\''$HARDWARE_FILE'\'')).get('\''hardware'\'',{}).get('\''ram_gb'\'',8))")\nRESOLUTION=$(python3 -c "import json; print(json.load(open('\''$HARDWARE_FILE'\'')).get('\''hardware'\'',{}).get('\''screen_resolution'\'','\''1920x1080'\''))")\nexport CHROME_CPU_CORES="$CPU_CORES"\nexport CHROME_RAM_GB="$RAM_GB"\nexport CHROME_RESOLUTION="$RESOLUTION"\n' > /home/chrome/scripts/hardware-spoof.sh \
    && printf '#!/bin/bash\nunset DOCKER_CONTAINER\nexport HOSTNAME="DESKTOP-$(tr -dc '\''A-Z0-9'\'' < /dev/urandom | head -c 7)"\nunset container\necho "Container detection evasion configured"\n' > /home/chrome/scripts/container-hide.sh \
    && printf '#!/bin/bash\nPROFILE_NAME="${1:-default}"\nCONFIG_DIR="/home/chrome/.config/chromium"\nUA_FILE="$CONFIG_DIR/user-agent.txt"\nmkdir -p "$CONFIG_DIR"\nif [[ ! -f "$UA_FILE" ]]; then\n    # UPDATED: Use newer Chrome versions and strictly Linux UAs to avoid fingerprint mismatches\n    CHROME_VERSIONS=("120.0.6099.129" "121.0.6167.85" "122.0.6261.94" "119.0.6045.199")\n    CHROME_VERSION=${CHROME_VERSIONS[$RANDOM %% ${#CHROME_VERSIONS[@]}]}\n    # STRICTLY LINUX: Spoofing Windows on a Linux container leaks via fonts/canvas. \n    # Being a "normal Linux user" is safer than being a "fake Windows user".\n    USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$CHROME_VERSION Safari/537.36"\n    echo "$USER_AGENT" > "$UA_FILE"\nfi\nexport CHROME_USER_AGENT="$(cat "$UA_FILE")"\n' > /home/chrome/scripts/user-agent-spoof.sh \
    && printf '#!/bin/bash\nPROFILE_NAME="${CHROME_PROFILE:-default}"\nSCRIPT_DIR="/home/chrome/scripts"\necho "Launching stealth Chrome for profile: $PROFILE_NAME"\nsource "$SCRIPT_DIR/hardware-spoof.sh" "$PROFILE_NAME"\nsource "$SCRIPT_DIR/container-hide.sh"\nsource "$SCRIPT_DIR/user-agent-spoof.sh" "$PROFILE_NAME"\nSTEALTH_FLAGS=(\n    "--no-first-run"\n    "--no-default-browser-check"\n    "--disable-features=VizDisplayCompositor"\n    "--disable-webgl-image-chromium"\n    "--disable-webgl2"\n    "--disable-accelerated-2d-canvas"\n    "--disable-background-networking"\n    "--disable-background-timer-throttling"\n    "--disable-backgrounding-occluded-windows"\n    "--disable-renderer-backgrounding"\n    "--memory-pressure-off"\n    "--user-agent=$CHROME_USER_AGENT"\n    "--window-size=${CHROME_RESOLUTION/x/,}"\n    "--disable-sync"\n    "--disable-translate"\n    "--disable-dev-shm-usage"\n    "--disable-logging"\n    "--log-level=3"\n    "--disable-blink-features=AutomationControlled"\n    "--disable-infobars"\n    "--start-maximized"\n    "--test-type"\n)\nexport TZ="$(python3 -c "import json; print(json.load(open('\''/home/chrome/.config/chromium/hardware-signature.json'\'')).get('\''system'\'',{}).get('\''timezone'\'','\''UTC'\''))" 2>/dev/null || echo UTC)"\nexport LANG="en_US.UTF-8"\necho "Starting Chrome with stealth configuration..."\necho "Profile: $PROFILE_NAME"\necho "Hardware: ${CHROME_CPU_CORES} cores, ${CHROME_RAM_GB}GB RAM, ${CHROME_RESOLUTION}"\necho "User Agent: $CHROME_USER_AGENT"\necho "Timezone: $TZ"\necho "Display: ${DISPLAY:-not set}"\nif [[ ! -S /tmp/.X11-unix/X${DISPLAY##*:} ]] && [[ "$DISPLAY" != "" ]]; then\n    echo "⚠️  Warning: X11 socket not found for display $DISPLAY"\nfi\nif ! chromium-browser "${STEALTH_FLAGS[@]}" "$@" 2>&1; then\n    EXIT_CODE=$?\n    echo "❌ Chromium exited with code: $EXIT_CODE" >&2\n    echo "Check X11 connection and display permissions" >&2\n    exit $EXIT_CODE\nfi\n' > /home/chrome/scripts/stealth-launch.sh \
    && chmod +x /home/chrome/scripts/*.sh \
    && chown -R chrome:chrome /home/chrome/scripts \
    && rm -rf /tmp/* /var/tmp/*

# Environment setup for stealth mode
ENV CHROME_PROFILE=default
ENV DISPLAY=:0

# Switch to non-root user
USER chrome
WORKDIR /home/chrome

# Use stealth launcher as entrypoint for maximum fingerprint evasion
ENTRYPOINT ["/home/chrome/scripts/stealth-launch.sh"]
CMD []
