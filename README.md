# Chrome Isolation Manager

A powerful, secure system for running Google Chrome profiles in isolated Docker containers with advanced anti-fingerprinting and native Linux integration.

## 🚀 Features

*   **Total Isolation**: Each Chrome profile runs in its own Docker container with separate file systems.
*   **Anti-Fingerprinting**:
    *   **Hardware Spoofing**: Randomizes CPU cores, RAM, and GPU model on every launch.
    *   **Identity Protection**: Spoofs Hostnames, User Agents, and Timezones.
    *   **Tracking Prevention**: Disables specific Chrome features to reduce unique footprint.
*   **Native Experience**:
    *   **GPU Acceleration**: Full hardware acceleration (Vulkan/OpenGL) for smooth video and WebGL.
    *   **Audio Support**: Seamless PulseAudio integration.
    *   **Desktop Integration**: Creates standard application menu shortcuts.
*   **Management Interface**:
    *   Web-based dashboard to create, manage, and delete profiles.
    *   Import/Export profiles with full data retention (passwords, cookies, etc.).

## 📖 Deep Dive

Curious about how the magic happens? We have documented the architecture, security model, and stealth mechanisms in detail.

👉 **[Read the Deep Dive: HOW_IT_WORKS.md](HOW_IT_WORKS.md)**

## 🛠️ Installation

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/MuhammadUsamaMX/chrome-isolation-linux.git
    cd chrome-isolation-linux
    ```

2.  **Run the installer**:
    ```bash
    ./install.sh
    ```
    *   This will check dependencies (Docker, Python), build the image, and set up the systemd service.

3.  **Access the Dashboard**:
    *   Open `http://localhost:5000` in your browser.
    *   Access the Web UI to create your first isolated profile.

## ⚡ Usage

*   **Create Profile**: Use the Web UI to name a new profile (e.g., "Banking", "Social").
*   **Launch**: Click "Start" in the Web UI or launch from your desktop application menu (e.g., search for "Chrome (Banking)").
*   **Data**: Your data is persistent and stored in `~/Chrome/<ProfileName>`.

## ⚠️ Requirements

*   Linux OS (Ubuntu/Debian recommended)
*   Docker installed and running (`sudo apt install docker.io`)
*   Python 3

## 🗑️ Uninstall

To remove the application, service, and all desktop entries:

```bash
./uninstall.sh
```
*(Note: Your profile data in `~/Chrome` is preserved by default)*
