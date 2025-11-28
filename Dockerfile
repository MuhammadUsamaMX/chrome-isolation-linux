FROM ubuntu:22.04

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies and tools
RUN apt-get update && apt-get install -y \
    wget \
    gnupg \
    ca-certificates \
    pulseaudio \
    libasound2 \
    fonts-liberation \
    libgbm1 \
    libnspr4 \
    libnss3 \
    xdg-utils \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Install AMD drivers and audio utils (Separate layer for caching)
RUN apt-get update && apt-get install -y \
    libgl1-mesa-dri \
    libgl1-mesa-glx \
    alsa-utils \
    pulseaudio-utils \
    libasound2-plugins \
    xclip \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Install Google Chrome
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && apt-get install -y google-chrome-stable \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user
# We use ID 1000 to match the typical host user, but this can be overridden
ARG USER_ID=1000
ARG GROUP_ID=1000

RUN groupadd -g ${GROUP_ID} chrome \
    && useradd -u ${USER_ID} -g chrome -G audio,video -m chrome \
    && mkdir -p /home/chrome/.config/google-chrome \
    && mkdir -p /home/chrome/Downloads \
    && chown -R chrome:chrome /home/chrome

# Switch to non-root user
USER chrome
WORKDIR /home/chrome

# Entrypoint
ENTRYPOINT ["google-chrome-stable"]
CMD ["--no-sandbox", "--no-first-run"]
