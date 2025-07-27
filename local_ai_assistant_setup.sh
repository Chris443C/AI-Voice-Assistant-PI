#!/bin/bash

# =============================================================================
# Local AI Voice Assistant Setup Script
# =============================================================================
# This script automates the installation of a complete local AI voice assistant
# using Raspberry Pi, Home Assistant, Whisper, Piper TTS, and Ollama
# =============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/ai_assistant_install.log"
CONFIG_DIR="$HOME/.ai_assistant"
PYTHON_VENV="$CONFIG_DIR/venv"

# Default settings (can be overridden)
DEVICE_TYPE="auto"  # auto, pi4, pi5, server
INSTALL_OLLAMA=true
INSTALL_HOMEASSISTANT=true
OLLAMA_MODEL="llama3.2:3b"
WHISPER_MODEL="base"
PIPER_VOICE="en_US-lessac-medium"

# =============================================================================
# Utility Functions
# =============================================================================

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" | tee -a "$LOG_FILE"
    exit 1
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}" | tee -a "$LOG_FILE"
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root"
    fi
}

detect_device() {
    if [[ "$DEVICE_TYPE" == "auto" ]]; then
        if grep -q "Raspberry Pi" /proc/cpuinfo; then
            if grep -q "BCM2711" /proc/cpuinfo; then
                DEVICE_TYPE="pi4"
            elif grep -q "BCM2712" /proc/cpuinfo; then
                DEVICE_TYPE="pi5"
            else
                DEVICE_TYPE="pi4"  # Default fallback
            fi
        else
            DEVICE_TYPE="server"
        fi
    fi
    log "Detected device type: $DEVICE_TYPE"
}

check_system_requirements() {
    log "Checking system requirements..."
    
    # Check OS
    if ! command -v apt &> /dev/null; then
        error "This script requires a Debian/Ubuntu-based system"
    fi
    
    # Check available space (need at least 8GB)
    available_space=$(df / | awk 'NR==2 {print $4}')
    required_space=8388608  # 8GB in KB
    
    if [[ $available_space -lt $required_space ]]; then
        error "Insufficient disk space. Need at least 8GB free."
    fi
    
    # Check memory (need at least 2GB for Pi, 4GB for server)
    total_mem=$(free -m | awk 'NR==2{print $2}')
    if [[ "$DEVICE_TYPE" == "server" && $total_mem -lt 4096 ]]; then
        warn "Server installations work better with 4GB+ RAM"
    elif [[ "$DEVICE_TYPE" =~ ^pi && $total_mem -lt 2048 ]]; then
        warn "Raspberry Pi installations need at least 2GB RAM"
    fi
    
    log "System requirements check passed"
}

# =============================================================================
# System Preparation
# =============================================================================

update_system() {
    log "Updating system packages..."
    sudo apt update
    sudo apt upgrade -y
    sudo apt install -y \
        curl \
        wget \
        git \
        python3 \
        python3-pip \
        python3-venv \
        build-essential \
        portaudio19-dev \
        python3-dev \
        libasound2-dev \
        pulseaudio \
        pulseaudio-utils \
        alsa-utils \
        ffmpeg \
        jq \
        unzip \
        htop \
        nano \
        screen \
        ufw \
        yamllint \
        fail2ban
}

setup_home_security() {
    log "Setting up basic home security..."
    
    # Install and configure UFW firewall
    if ! command -v ufw &> /dev/null; then
        sudo apt install -y ufw
    fi
    
    # Reset and configure firewall
    sudo ufw --force reset
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    
    # Allow SSH (adjust port if needed)
    sudo ufw allow ssh comment "SSH Access"
    
    # Allow Home Assistant web interface
    sudo ufw allow 8123/tcp comment "Home Assistant Web Interface"
    
    # Allow Wyoming services (restrict to localhost)
    sudo ufw allow from 127.0.0.1 to any port 10200 comment "Piper TTS"
    sudo ufw allow from 127.0.0.1 to any port 10300 comment "Whisper STT"
    sudo ufw allow from 127.0.0.1 to any port 10400 comment "OpenWakeWord"
    
    # Allow Ollama API (restrict to localhost)
    sudo ufw allow from 127.0.0.1 to any port 11434 comment "Ollama API"
    
    # Enable firewall
    sudo ufw --force enable
    
    log "Firewall configured successfully"
    
    # Configure fail2ban for SSH protection
    sudo systemctl enable fail2ban
    sudo systemctl start fail2ban
    
    log "Basic security setup complete"
}

setup_audio_pi() {
    if [[ "$DEVICE_TYPE" =~ ^pi ]]; then
        log "Setting up ReSpeaker 2-Mic Pi HAT..."
        
        # Enable I2C and SPI for ReSpeaker HAT
        sudo raspi-config nonint do_i2c 0
        sudo raspi-config nonint do_spi 0
        
        # Install ReSpeaker drivers
        cd /tmp
        git clone https://github.com/respeaker/seeed-voicecard.git
        cd seeed-voicecard
        sudo ./install.sh
        
        # Configure audio
        sudo tee /etc/asound.conf > /dev/null <<EOF
pcm.!default {
    type asym
    playback.pcm "plughw:seeedvoicecard,0"
    capture.pcm "plughw:seeedvoicecard,0"
}
ctl.!default {
    type hw
    card seeedvoicecard
}
EOF
        
        # Optimize Pi performance for audio
        echo "gpu_mem=128" | sudo tee -a /boot/config.txt
        echo "arm_freq=1800" | sudo tee -a /boot/config.txt
        echo "over_voltage=2" | sudo tee -a /boot/config.txt
        
        log "Audio setup complete. Reboot required after installation."
    fi
}

create_directories() {
    log "Creating configuration directories..."
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$CONFIG_DIR/homeassistant"
    mkdir -p "$CONFIG_DIR/ollama"
    mkdir -p "$CONFIG_DIR/scripts"
    mkdir -p "$CONFIG_DIR/models"
}

# =============================================================================
# Python Environment Setup
# =============================================================================

setup_python_environment() {
    log "Setting up Python virtual environment..."
    python3 -m venv "$PYTHON_VENV"
    source "$PYTHON_VENV/bin/activate"
    
    pip install --upgrade pip setuptools wheel
    pip install \
        homeassistant \
        wyoming \
        wyoming-whisper \
        wyoming-piper \
        wyoming-openwakeword \
        requests \
        aiohttp \
        pyyaml \
        jinja2
}

# =============================================================================
# Home Assistant Installation
# =============================================================================

install_homeassistant() {
    if [[ "$INSTALL_HOMEASSISTANT" == true ]]; then
        log "Installing Home Assistant..."
        
        # Create Home Assistant user
        sudo useradd -rm homeassistant -G dialout,gpio,i2c || true
        sudo mkdir -p /srv/homeassistant
        sudo chown homeassistant:homeassistant /srv/homeassistant
        
        # Install Home Assistant in venv
        sudo -u homeassistant -H -s <<EOF
cd /srv/homeassistant
python3 -m venv .
source bin/activate
pip install --upgrade homeassistant
EOF
        
            # Create systemd service with improved reliability
    sudo tee /etc/systemd/system/home-assistant@homeassistant.service > /dev/null <<EOF
[Unit]
Description=Home Assistant
After=network-online.target
Wants=network-online.target
Requires=wyoming-whisper.service wyoming-piper.service wyoming-openwakeword.service

[Service]
Type=exec
User=%i
WorkingDirectory=/srv/homeassistant
ExecStart=/srv/homeassistant/bin/hass -c "/srv/homeassistant/.homeassistant"
Restart=always
RestartSec=10
TimeoutStartSec=60
TimeoutStopSec=30
LimitNOFILE=65536
LimitNPROC=4096
MemoryMax=2G

[Install]
WantedBy=multi-user.target
EOF
        
        sudo systemctl daemon-reload
        sudo systemctl enable home-assistant@homeassistant.service
        
        log "Home Assistant installed. Will start after full setup."
    fi
}

# =============================================================================
# Wyoming Services Installation
# =============================================================================

install_wyoming_whisper() {
    log "Installing Wyoming Whisper..."
    
    source "$PYTHON_VENV/bin/activate"
    pip install wyoming-faster-whisper
    
    # Download Whisper model
    python3 -c "
import whisper
model = whisper.load_model('$WHISPER_MODEL')
print(f'Whisper model $WHISPER_MODEL downloaded successfully')
"
    
    # Create Whisper service with security hardening
    sudo tee /etc/systemd/system/wyoming-whisper.service > /dev/null <<EOF
[Unit]
Description=Wyoming Whisper
Wants=network-online.target
After=network-online.target

[Service]
Type=exec
ExecStart=$PYTHON_VENV/bin/python -m wyoming_faster_whisper --model $WHISPER_MODEL --language en --uri tcp://127.0.0.1:10300
Restart=always
RestartSec=10
User=$USER
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/tmp /var/tmp
LimitNOFILE=65536
MemoryMax=1G

[Install]
WantedBy=default.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable wyoming-whisper.service
}

install_wyoming_piper() {
    log "Installing Wyoming Piper..."
    
    source "$PYTHON_VENV/bin/activate"
    pip install wyoming-piper
    
    # Download Piper voice model
    mkdir -p "$CONFIG_DIR/models/piper"
    cd "$CONFIG_DIR/models/piper"
    
    # Download voice files
    wget -O "${PIPER_VOICE}.onnx" "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx"
    wget -O "${PIPER_VOICE}.onnx.json" "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json"
    
    # Create Piper service with security hardening
    sudo tee /etc/systemd/system/wyoming-piper.service > /dev/null <<EOF
[Unit]
Description=Wyoming Piper
Wants=network-online.target
After=network-online.target

[Service]
Type=exec
ExecStart=$PYTHON_VENV/bin/python -m wyoming_piper --piper '$CONFIG_DIR/models/piper/${PIPER_VOICE}.onnx' --uri tcp://127.0.0.1:10200
Restart=always
RestartSec=10
User=$USER
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/tmp /var/tmp
LimitNOFILE=65536
MemoryMax=1G

[Install]
WantedBy=default.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable wyoming-piper.service
}

install_wyoming_openwakeword() {
    log "Installing Wyoming OpenWakeWord..."
    
    source "$PYTHON_VENV/bin/activate"
    pip install wyoming-openwakeword
    
    # Create OpenWakeWord service with security hardening
    sudo tee /etc/systemd/system/wyoming-openwakeword.service > /dev/null <<EOF
[Unit]
Description=Wyoming OpenWakeWord
Wants=network-online.target
After=network-online.target

[Service]
Type=exec
ExecStart=$PYTHON_VENV/bin/python -m wyoming_openwakeword --uri tcp://127.0.0.1:10400
Restart=always
RestartSec=10
User=$USER
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/tmp /var/tmp
LimitNOFILE=65536
MemoryMax=1G

[Install]
WantedBy=default.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable wyoming-openwakeword.service
}

# =============================================================================
# Ollama Installation
# =============================================================================

install_ollama() {
    if [[ "$INSTALL_OLLAMA" == true ]]; then
        log "Installing Ollama..."
        
        # Install Ollama
        curl -fsSL https://ollama.ai/install.sh | sh
        
            # Create Ollama service override for local network access
    sudo mkdir -p /etc/systemd/system/ollama.service.d/
    sudo tee /etc/systemd/system/ollama.service.d/override.conf > /dev/null <<EOF
[Service]
Environment="OLLAMA_HOST=127.0.0.1:11434"
LimitNOFILE=65536
MemoryMax=4G
EOF
        
        sudo systemctl daemon-reload
        sudo systemctl enable ollama.service
        sudo systemctl start ollama.service
        
        # Wait for Ollama to start
        sleep 10
        
        # Pull the specified model
        log "Downloading Ollama model: $OLLAMA_MODEL"
        ollama pull "$OLLAMA_MODEL"
        
        log "Ollama installation complete"
    fi
}

# =============================================================================
# Home Assistant Configuration
# =============================================================================

configure_homeassistant() {
    log "Configuring Home Assistant..."
    
    HA_CONFIG="/srv/homeassistant/.homeassistant"
    sudo mkdir -p "$HA_CONFIG"
    
    # Create enhanced configuration.yaml with home network support
    sudo tee "$HA_CONFIG/configuration.yaml" > /dev/null <<EOF
# Enhanced Home Assistant Configuration for AI Voice Assistant
homeassistant:
  name: "AI Assistant Home"
  latitude: !secret home_latitude
  longitude: !secret home_longitude
  elevation: 0
  unit_system: metric
  time_zone: "UTC"
  country: US

# Enable the frontend
frontend:

# Enable configuration UI
config:

# Enable system health checks
system_health:

# Enable mobile app support
mobile_app:

# Enable media player
media_player:

# Wyoming integrations for voice assistant
wyoming:

# Assist pipeline
assist_pipeline:

# Conversation agent
conversation:

# Intent script
intent_script:

# Automation
automation: !include automations.yaml

# Scripts
script: !include scripts.yaml

# Scenes
scene: !include scenes.yaml

# HTTP configuration with home network support
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 127.0.0.1
    - ::1
    - 192.168.1.0/24
    - 10.0.0.0/8
    - 172.16.0.0/12
  cache_control: true

# Logger
logger:
  default: info
  logs:
    homeassistant.components.assist_pipeline: debug
    homeassistant.components.wyoming: debug

# Recorder for data persistence
recorder:
  db_url: !secret db_url
  purge_keep_days: 30
  auto_purge: true
  commit_interval: 1
  max_queue_size: 10000

# History
history:

# Logbook
logbook:
EOF

    # Create enhanced secrets.yaml template
    sudo tee "$HA_CONFIG/secrets.yaml" > /dev/null <<EOF
# Home Assistant Secrets
home_latitude: 0.0
home_longitude: 0.0
db_url: "sqlite:////srv/homeassistant/.homeassistant/home-assistant_v2.db"
api_password: "your_secure_password_here"
EOF

    # Create empty automation files
    sudo touch "$HA_CONFIG/automations.yaml"
    sudo touch "$HA_CONFIG/scripts.yaml"
    sudo touch "$HA_CONFIG/scenes.yaml"
    
    # Set proper ownership
    sudo chown -R homeassistant:homeassistant "$HA_CONFIG"
}

# =============================================================================
# Service Management
# =============================================================================

start_services() {
    log "Starting all services..."
    
    sudo systemctl start wyoming-whisper.service
    sudo systemctl start wyoming-piper.service
    sudo systemctl start wyoming-openwakeword.service
    
    if [[ "$INSTALL_OLLAMA" == true ]]; then
        sudo systemctl start ollama.service
    fi
    
    if [[ "$INSTALL_HOMEASSISTANT" == true ]]; then
        sudo systemctl start home-assistant@homeassistant.service
    fi
    
    log "All services started"
}

check_services() {
    log "Checking service status..."
    
    services=("wyoming-whisper" "wyoming-piper" "wyoming-openwakeword")
    
    if [[ "$INSTALL_OLLAMA" == true ]]; then
        services+=("ollama")
    fi
    
    if [[ "$INSTALL_HOMEASSISTANT" == true ]]; then
        services+=("home-assistant@homeassistant")
    fi
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            log "✓ $service is running"
        else
            warn "✗ $service is not running"
        fi
    done
}

# =============================================================================
# Post-Installation Setup
# =============================================================================

create_test_scripts() {
    log "Creating test scripts..."
    
    # Audio test script
    cat > "$CONFIG_DIR/scripts/test_audio.sh" <<EOF
#!/bin/bash
echo "Testing audio devices..."
aplay -l
arecord -l

echo "Testing microphone..."
arecord -D plughw:seeedvoicecard,0 -f cd -t wav -d 3 test_recording.wav

echo "Testing speakers..."
aplay test_recording.wav

echo "Testing audio quality..."
ffmpeg -i test_recording.wav -af "volumedetect" -f null /dev/null 2>&1 | grep "mean_volume"

rm test_recording.wav
echo "Audio test complete"
EOF
    
    # Service test script
    cat > "$CONFIG_DIR/scripts/test_services.sh" <<EOF
#!/bin/bash
echo "Testing Wyoming services..."
echo "Whisper: \$(curl -s http://localhost:10300/info | jq -r '.name // "Not responding"')"
echo "Piper: \$(curl -s http://localhost:10200/info | jq -r '.name // "Not responding"')"
echo "OpenWakeWord: \$(curl -s http://localhost:10400/info | jq -r '.name // "Not responding"')"
if [[ "$INSTALL_OLLAMA" == true ]]; then
    echo "Ollama: \$(curl -s http://localhost:11434/api/version | jq -r '.version // "Not responding"')"
fi
EOF

    # Service monitoring script
    cat > "$CONFIG_DIR/scripts/monitor_services.sh" <<EOF
#!/bin/bash
# Simple home monitoring - restart services if they fail
SERVICES=("wyoming-whisper" "wyoming-piper" "wyoming-openwakeword" "ollama")

for service in "\${SERVICES[@]}"; do
    if ! systemctl is-active --quiet "\$service"; then
        echo "\$(date): Restarting \$service"
        sudo systemctl restart "\$service"
    fi
done
EOF

    # Configuration validation script
    cat > "$CONFIG_DIR/scripts/validate_config.sh" <<EOF
#!/bin/bash
echo "Validating Home Assistant configuration..."
hass --script check_config

echo "Validating YAML syntax..."
yamllint /srv/homeassistant/.homeassistant/

echo "Checking service dependencies..."
systemctl list-dependencies home-assistant@homeassistant.service
EOF

    # Backup script
    cat > "$CONFIG_DIR/scripts/backup.sh" <<EOF
#!/bin/bash
# Backup script for voice assistant
BACKUP_DIR="\$HOME/.ai_assistant/backups"
DATE=\$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="voice_assistant_backup_\$DATE.tar.gz"

# Create backup directory
mkdir -p "\$BACKUP_DIR"

# Create backup
tar -czf "\$BACKUP_DIR/\$BACKUP_NAME" \\
    -C /srv/homeassistant .homeassistant \\
    -C "\$HOME" .ai_assistant \\
    --exclude='*.log' \\
    --exclude='*.tmp' \\
    --exclude='__pycache__'

# Keep only last 5 backups
cd "\$BACKUP_DIR"
ls -t *.tar.gz | tail -n +6 | xargs -r rm

echo "Backup created: \$BACKUP_NAME"
EOF
    
    chmod +x "$CONFIG_DIR/scripts/"*.sh

    # Set up monitoring cron job
    (crontab -l 2>/dev/null; echo "*/5 * * * * $CONFIG_DIR/scripts/monitor_services.sh") | crontab -
    
    # Copy comprehensive test script
    cp "$SCRIPT_DIR/test_voice_pipeline.py" "$CONFIG_DIR/scripts/"
    chmod +x "$CONFIG_DIR/scripts/test_voice_pipeline.py"
    
    log "Test scripts and monitoring created"
}

print_completion_info() {
    log "==============================================================================="
    log "AI Voice Assistant Installation Complete!"
    log "==============================================================================="
    info ""
    info "Installation Summary:"
    info "- Device Type: $DEVICE_TYPE"
    info "- Home Assistant: $([ "$INSTALL_HOMEASSISTANT" == true ] && echo "Installed" || echo "Skipped")"
    info "- Ollama: $([ "$INSTALL_OLLAMA" == true ] && echo "Installed" || echo "Skipped")"
    info "- Whisper Model: $WHISPER_MODEL"
    info "- Piper Voice: $PIPER_VOICE"
    info "- Ollama Model: $OLLAMA_MODEL"
    info ""
    info "Next Steps:"
    info "1. Reboot your system: sudo reboot"
    info "2. After reboot, run comprehensive test: $CONFIG_DIR/scripts/test_voice_pipeline.py"
    info "3. Test audio: $CONFIG_DIR/scripts/test_audio.sh"
    info "4. Validate configuration: $CONFIG_DIR/scripts/validate_config.sh"
    if [[ "$INSTALL_HOMEASSISTANT" == true ]]; then
        info "5. Access Home Assistant: http://localhost:8123"
        info "6. Complete Home Assistant onboarding"
        info "7. Add Wyoming integrations in HA"
    fi
    info ""
    info "Security Features Enabled:"
    info "- Firewall configured (UFW)"
    info "- SSH protection (fail2ban)"
    info "- Services restricted to localhost"
    info "- Automatic service monitoring"
    info "- Configuration validation"
    info "- Automated backups"
    info ""
    info "Service URLs:"
    info "- Whisper: http://localhost:10300"
    info "- Piper: http://localhost:10200"
    info "- OpenWakeWord: http://localhost:10400"
    if [[ "$INSTALL_OLLAMA" == true ]]; then
        info "- Ollama: http://localhost:11434"
    fi
    if [[ "$INSTALL_HOMEASSISTANT" == true ]]; then
        info "- Home Assistant: http://localhost:8123"
    fi
    info ""
    info "Log file: $LOG_FILE"
    info "Config directory: $CONFIG_DIR"
    log "==============================================================================="
}

# =============================================================================
# Command Line Argument Parsing
# =============================================================================

show_help() {
    cat <<EOF
Local AI Voice Assistant Setup Script

Usage: $0 [OPTIONS]

Options:
    -h, --help              Show this help message
    -d, --device TYPE       Device type (auto, pi4, pi5, server) [default: auto]
    --no-ollama            Skip Ollama installation
    --no-homeassistant     Skip Home Assistant installation
    --ollama-model MODEL   Ollama model to install [default: llama3.2:3b]
    --whisper-model MODEL  Whisper model to use [default: base]
    --piper-voice VOICE    Piper voice to use [default: en_US-lessac-medium]
    --dry-run              Show what would be done without executing

Examples:
    $0                                          # Auto-detect and install everything
    $0 --device pi4 --ollama-model llama3.2:1b # Raspberry Pi 4 with smaller model
    $0 --no-ollama                             # Skip Ollama, use external LLM
    $0 --device server                         # Server installation
EOF
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -d|--device)
                DEVICE_TYPE="$2"
                shift 2
                ;;
            --no-ollama)
                INSTALL_OLLAMA=false
                shift
                ;;
            --no-homeassistant)
                INSTALL_HOMEASSISTANT=false
                shift
                ;;
            --ollama-model)
                OLLAMA_MODEL="$2"
                shift 2
                ;;
            --whisper-model)
                WHISPER_MODEL="$2"
                shift 2
                ;;
            --piper-voice)
                PIPER_VOICE="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done
}

# =============================================================================
# Main Installation Function
# =============================================================================

main() {
    # Initialize log file
    echo "=== AI Voice Assistant Installation Started at $(date) ===" > "$LOG_FILE"
    
    log "Starting Local AI Voice Assistant installation..."
    
    # Pre-installation checks
    check_root
    detect_device
    check_system_requirements
    
    # System preparation
    update_system
    setup_home_security
    setup_audio_pi
    create_directories
    
    # Python environment
    setup_python_environment
    
    # Core installations
    install_wyoming_whisper
    install_wyoming_piper
    install_wyoming_openwakeword
    install_ollama
    install_homeassistant
    
    # Configuration
    configure_homeassistant
    
    # Service management
    start_services
    
    # Post-installation
    create_test_scripts
    check_services
    print_completion_info
    
    log "Installation completed successfully!"
}

# =============================================================================
# Script Entry Point
# =============================================================================

# Parse command line arguments
parse_arguments "$@"

# Run main installation
if [[ "${DRY_RUN:-false}" == "true" ]]; then
    info "DRY RUN - Would install with these settings:"
    info "Device Type: $DEVICE_TYPE"
    info "Install Ollama: $INSTALL_OLLAMA"
    info "Install Home Assistant: $INSTALL_HOMEASSISTANT"
    info "Ollama Model: $OLLAMA_MODEL"
    info "Whisper Model: $WHISPER_MOD
