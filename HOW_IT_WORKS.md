# Chrome Isolation: How It Works Deeply

This document provides a deep technical analysis of the Chrome Isolation Manager, explaining its architecture, isolation mechanisms, fingerprinting protection, and system integration.

## 🏗️ System Architecture

The system operates on a client-server model running entirely on your local machine. It uses Docker to create isolated environments (containers) for each Chrome profile, managed by a Python Flask service.

```mermaid
graph TD
    User[User / Destkop Environment] -->|Interacts via| WebUI[Web Interface (Flask)]
    User -->|Launches via| Desktop[Desktop Shortcuts]
    
    subgraph "Host System"
        WebUI -->|Controls| DockerMgr[Docker Manager (Python)]
        Desktop -->|Executes| Launcher[Launcher Script]
        Launcher -->|Calls| DockerMgr
        
        DockerMgr -->|Spawns| Container[Docker Container]
        
        subgraph "Integration Points"
            X11[X Server / Wayland] <-->|Display Forwarding| Container
            Pulse[PulseAudio] <-->|Audio Forwarding| Container
            GPU[GPU / Kernel] <-->|Direct Rendering| Container
        end
    end
    
    subgraph "Isolated Environment (Inside Container)"
        Spoof[Stealth Scripts] -->|Configures| Chrome[Chromium Browser]
        Chrome -->|Writes to| VolConf[Config Volume]
        Chrome -->|Writes to| VolDown[Downloads Volume]
    end
```

## 🧩 Core Components

### 1. The Manager Service (`app/`)
*   **Role**: The central brain of the application.
*   **Technology**: Python 3, Flask, Docker SDK for Python.
*   **Function**: 
    *   Exposes a REST API to list, create, start, stop, and delete profiles.
    *   Generates `.desktop` files in `~/.local/share/applications` so isolated browsers feel like native apps.
    *   Calculates dynamic permissions (e.g., getting correct Group IDs for GPU access) before launching containers.

### 2. The Docker Container (`Dockerfile`)
*   **Base Image**: `alpine:3.19` (Lightweight, secure by default).
*   **Software**: Chromium, PulseAudio client, Mesa drivers (Intel/AMD/Nvidia support), and core utilities.
*   **Stealth Layer**: Custom scripts injected during build time to randomize the environment (see "Stealth Mechanics" below).

### 3. File System Isolation (**Persistance**)
Each profile gets its own persistent storage, isolated from the host and other profiles.
*   **Profile Config**: `~/Chrome/<ProfileName>` maps to `/home/chrome/.config/chromium`.
*   **Downloads**: `~/Chrome/<ProfileName>/Downloads` maps to `/home/chrome/Downloads`.
*   **Benefit**: Cookies, Local Storage, History, and Extensions are distinct per profile. A malicious site in "Profile A" cannot read the cookies of "Profile B".

## 🛡️ Stealth & Anti-Fingerprinting

The system uses a 3-layer spoofing mechanism executed every time a container starts. This prevents tracking via browser fingerprinting.

### Layer 1: Hardware Spoofing (`hardware-spoof.sh`)
Before Chrome starts, this script generates a random hardware profile:
*   **CPU Cores**: Randomly reports between 2 and 16 cores.
*   **RAM**: Randomly reports 4GB, 8GB, 16GB, or 32GB memory.
*   **GPU Renderer**: Spoofs strings like "NVIDIA GeForce GTX 1060" or "AMD Radeon RX 580" to web GL APIs.
*   **Screen Resolution**: Sets the internal window geometry to common resolutions (e.g., 1920x1080) regardless of the actual window size.

### Layer 2: Network & Identity Spoofing (`container-hide.sh` & `user-agent-spoof.sh`)
*   **Hostname**: randomizes the hostname to look like a generic desktop (e.g., `DESKTOP-AB12CD`).
*   **User Agent**: Rotates between Windows, macOS, and Linux User Agents to blend in with the most common traffic.
*   **Timezone**: Randomly selects a timezone (e.g., `America/New_York`, `Asia/Tokyo`) to decouple your physical location from your browser time.

### Layer 3: Browser Flags (`stealth-launch.sh`)
Chrome is launched with specific flags to reduce leak vectors:
*   `--disable-blink-features=AutomationControlled`: **Crucial for passing bot checks (Fiverr, etc.)**. It removes standard WebDriver traces.
*   `--disable-infobars`: Hides "Chrome is being controlled by automated software" notifications.
*   `--disable-features=VizDisplayCompositor`: Reduces some graphics overhead and fingerprinting surfaces.
*   `--no-default-browser-check`: Prevents "Set as default" nags.

### Layer 4: Consistency Enforcement (Anti-Fraud)
To pass sophisticated "Human Verification" checks:
*   **Strict Linux User-Agents**: We force the User-Agent to match the Linux container environment. Spoofing Windows on Linux creates detectable mismatches (e.g., System Fonts, Rendering Engine quirks) that trigger fraud alerts.
*   **Sandbox Enabled**: We run Chrome with its **native sandbox active** (removing `--no-sandbox`). This signals a legitimate, secure browser environment to remote servers, as most bots/scrapers disable the sandbox for easier deployment.

## 🔌 System Integration Deep-Dive

To make the isolated Chrome feel "native", the system punches specific holes in the isolation.

### 1. Graphics Acceleration (GPU Passthrough)
Instead of software rendering (which is slow), we allow the container direct access to the GPU.
*   **Device Mapping**: `--device /dev/dri` maps the Direct Rendering Interface.
*   **Group Permissions**: Use `docker_manager.py` to find the host's `video` and `render` Group IDs (GIDs) and dynamically adds the container user to these groups.
*   **Vulkan/OpenGL**: The container includes `mesa-vulkan-intel`, `mesa-vulkan-ati`, and `vulkan-loader`.
*   **Launch Flags**: Forces ANGLE/Vulkan backend via `--use-angle=vulkan`, ensuring smooth video playback (YouTube at 4k) and WebGL support.

### 2. Audio Forwarding (PulseAudio)
*   **Socket Sharing**: The host's PulseAudio socket (`/run/user/1000/pulse/native`) is mounted into the container.
*   **Authentication**: The PulseAudio "cookie" (`~/.config/pulse/cookie`) is shared. This acts as the authentication token, allowing the container to send audio data to the host's sound server without opening network ports.

### 3. Display Server (X11 / Wayland)
*   **X11 Socket**: `/tmp/.X11-unix` is mounted. This allows the GUI applications inside Docker to draw windows on your host screen.
*   **Authorization**: The script runs `xhost +local:docker` to permit local Docker containers to connect to the X server.
*   **Wayland Support**: Chrome runs via XWayland (X11 complexity layer) which is standard for extensive compatibility.

### 4. Networking (DNS)
*   **Bridge Gateway**: The container uses the Docker bridge gateway (`172.17.0.1`) as its primary DNS. This allows the container to resolve domains using whatever DNS configuration the host machine uses (e.g., VPN DNS, local caching), preventing DNS leaks that might occur if it forced Google DNS (8.8.8.8).

## 🔒 Security Model & Trade-offs

| Feature | Implementation | Trade-off |
| :--- | :--- | :--- |
| **Filesystem** | Strict Isolation. Root FS is read-only or ephemeral (reset on restart). | Data not saved to mapped volumes is lost. |
| **Network** | Separate Network Namespace. | Localhost in container != Localhost on host. |
| **Process** | Separate PID Namespace. Host processes are invisible. | `ipc=host` is used for performance, technically sharing shared memory segments. |
| **Sandbox** | `seccomp=unconfined` + `--cap-add=SYS_ADMIN`. | **Important**: We relax Docker's default seccomp profile to allow Chrome's *internal* sandbox to function. If we didn't, Chrome would have to run with `--no-sandbox` which is much less secure. We prioritize Chrome's internal security mechanism over Docker's default restrictions. |
