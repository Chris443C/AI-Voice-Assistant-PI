#!/bin/bash

# =============================================================================
# Voice Assistant Management Script
# =============================================================================
# Easy management interface for the local AI voice assistant
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
CONFIG_DIR="$HOME/.ai_assistant"
LOG_DIR="$CONFIG_DIR/logs"
SCRIPT_DIR="$CONFIG_DIR/scripts"

# Services
SERVICES=("wyoming-whisper" "wyoming-piper" "wyoming-openwakeword" "ollama" "home-assistant@homeassistant")

# Utility functions
log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

highlight() {
    echo -e "${CYAN}$1${NC}"
}

# Create header
show_header() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                        Local AI Voice Assistant Manager                      ║"
    echo "║                                                                              ║"
    echo "║  Manage your privacy-focused voice assistant built with:                    ║"
    echo "║  • Home Assistant  • Whisper STT  • Piper TTS  • Ollama LLM                ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Service management functions
check_service() {
    local service=$1
    if systemctl is-active --quiet "$service"; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
    fi
}

check_http_service() {
    local port=$1
    local timeout=3
    if timeout $timeout bash -c "echo >/dev/tcp/localhost/$port" 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
    fi
}

show_service_status() {
    show_header
    echo -e "${CYAN}Service Status Overview${NC}"
    echo "────────────────────────────────────────────────────────────────────────────"
    printf "%-25s %-10s %-10s %-15s\n" "Service" "SystemD" "HTTP" "Port"
    echo "────────────────────────────────────────────────────────────────────────────"
    
    printf "%-25s %-10s %-10s %-15s\n" "Wyoming Whisper" "$(check_service wyoming-whisper.service)" "$(check_http_service 10300)" "10300"
    printf "%-25s %-10s %-10s %-15s\n" "Wyoming Piper" "$(check_service wyoming-piper.service)" "$(check_http_service 10200)" "10200"
    printf "%-25s %-10s %-10s %-15s\n" "Wyoming OpenWakeWord" "$(check_service wyoming-openwakeword.service)" "$(check_http_service 10400)" "10400"
    printf "%-25s %-10s %-10s %-15s\n" "Ollama" "$(check_service ollama.service)" "$(check_http_service 11434)" "11434"
    printf "%-25s %-10s %-10s %-15s\n" "Home Assistant" "$(check_service home-assistant@homeassistant.service)" "$(check_http_service 8123)" "8123"
    
    echo ""
    if python3 "$SCRIPT_DIR/check_services.py" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ All services are operational${NC}"
    else
        echo -e "${YELLOW}⚠ Some services may have issues${NC}"
    fi
}

# Service control functions
start_all_services() {
    log "Starting all voice assistant services..."
    for service in "${SERVICES[@]}"; do
        echo -n "Starting $service... "
        if sudo systemctl start "$service" 2>/dev/null; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC}"
        fi
    done
    echo ""
    info "Waiting for services to initialize..."
    sleep 5
    show_service_status
}

stop_all_services() {
    log "Stopping all voice assistant services..."
    for service in "${SERVICES[@]}"; do
        echo -n "Stopping $service... "
        if sudo systemctl stop "$service" 2>/dev/null; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC}"
        fi
    done
    echo ""
    info "All services stopped"
}

restart_all_services() {
    log "Restarting all voice assistant services..."
    stop_all_services
    sleep 3
    start_all_services
}

restart_single_service() {
    echo "Select service to restart:"
    echo "1) Wyoming Whisper"
    echo "2) Wyoming Piper" 
    echo "3) Wyoming OpenWakeWord"
    echo "4) Ollama"
    echo "5) Home Assistant"
    echo ""
    read -p "Enter choice (1-5): " choice
    
    case $choice in
        1) service="wyoming-whisper.service" ;;
        2) service="wyoming-piper.service" ;;
        3) service="wyoming-openwakeword.service" ;;
        4) service="ollama.service" ;;
        5) service="home-assistant@homeassistant.service" ;;
        *) error "Invalid choice"; return ;;
    esac
    
    log "Restarting $service..."
    sudo systemctl restart "$service"
    sleep 3
    info "Service restarted"
}

# Testing functions
test_audio() {
    show_header
    echo -e "${CYAN}Audio System Test${NC}"
    echo "────────────────────────────────────────────────────────────────────────────"
    
    echo "Testing audio devices..."
    echo ""
    echo "Available playback devices:"
    aplay -l 2>/dev/null || echo "No playback devices found"
    echo ""
    echo "Available recording devices:"
    arecord -l 2>/dev/null || echo "No recording devices found"
    echo ""
    
    read -p "Test microphone recording? (y/n): " test_mic
    if [[ "$test_mic" =~ ^[Yy] ]]; then
        echo "Recording 3 seconds of audio..."
        arecord -D plughw:seeedvoicecard,0 -f cd -t wav -d 3 /tmp/voice_test.wav 2>/dev/null || {
            echo "Recording failed, trying default device..."
            arecord -f cd -t wav -d 3 /tmp/voice_test.wav 2>/dev/null
        }
        
        echo "Playing back recording..."
        aplay /tmp/voice_test.wav 2>/dev/null || echo "Playback failed"
        rm -f /tmp/voice_test.wav
    fi
    
    read -p "Press Enter to continue..."
}

test_voice_pipeline() {
    show_header
    echo -e "${CYAN}Voice Pipeline Test${NC}"
    echo "────────────────────────────────────────────────────────────────────────────"
    
    echo "Testing individual components..."
    echo ""
    
    # Test Whisper
    echo -n "Whisper STT: "
    if curl -s http://localhost:10300/info >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Ready${NC}"
    else
        echo -e "${RED}✗ Not responding${NC}"
    fi
    
    # Test Piper
    echo -n "Piper TTS: "
    if curl -s http://localhost:10200/info >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Ready${NC}"
    else
        echo -e "${RED}✗ Not responding${NC}"
    fi
    
    # Test OpenWakeWord
    echo -n "OpenWakeWord: "
    if curl -s http://localhost:10400/info >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Ready${NC}"
    else
        echo -e "${RED}✗ Not responding${NC}"
    fi
    
    # Test Ollama
    echo -n "Ollama LLM: "
    if curl -s http://localhost:11434/api/version >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Ready${NC}"
        ollama_version=$(curl -s http://localhost:11434/api/version | jq -r '.version // "unknown"')
        echo "  Version: $ollama_version"
    else
        echo -e "${RED}✗ Not responding${NC}"
    fi
    
    echo ""
    read -p "Run detailed pipeline test? (y/n): " run_test
    if [[ "$run_test" =~ ^[Yy] ]]; then
        python3 "$SCRIPT_DIR/check_services.py"
    fi
    
    read -p "Press Enter to continue..."
}

test_tts() {
    show_header
    echo -e "${CYAN}Text-to-Speech Test${NC}"
    echo "────────────────────────────────────────────────────────────────────────────"
    
    if ! curl -s http://localhost:10200/info >/dev/null 2>&1; then
        error "Piper TTS service is not running"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo "Testing Piper TTS..."
    echo ""
    
    read -p "Enter text to speak (or press Enter for default): " text
    if [[ -z "$text" ]]; then
        text="Hello! This is a test of the local text to speech system. Voice assistant is working correctly."
    fi
    
    echo "Generating speech..."
    echo "$text" | curl -s -X POST http://localhost:10200/tts \
        -H "Content-Type: text/plain" \
        --data-binary @- \
        -o /tmp/tts_test.wav
    
    if [[ -f /tmp/tts_test.wav ]]; then
        echo "Playing generated speech..."
        aplay /tmp/tts_test.wav 2>/dev/null || echo "Playback failed"
        rm -f /tmp/tts_test.wav
    else
        error "Failed to generate speech"
    fi
    
    read -p "Press Enter to continue..."
}

# Configuration functions
show_config() {
    show_header
    echo -e "${CYAN}Configuration Overview${NC}"
    echo "────────────────────────────────────────────────────────────────────────────"
    
    echo "Installation Directory: $CONFIG_DIR"
    echo "Log Directory: $LOG_DIR"
    echo "Scripts Directory: $SCRIPT_DIR"
    echo ""
    
    echo "Home Assistant Config: /srv/homeassistant/.homeassistant"
    echo "Models Directory: $CONFIG_DIR/models"
    echo ""
    
    # Show Ollama models
    echo "Installed Ollama Models:"
    if command -v ollama >/dev/null 2>&1; then
        ollama list | tail -n +2 | while read -r line; do
            echo "  • $line"
        done
    else
        echo "  Ollama not found"
    fi
    echo ""
    
    # Show Whisper models
    echo "Whisper Models:"
    python3 -c "
import whisper
try:
    models = whisper.available_models()
    for model in models:
        print(f'  • {model}')
except:
    print('  Unable to list models')
" 2>/dev/null || echo "  Unable to check Whisper models"
    
    echo ""
    read -p "Press Enter to continue..."
}

manage_models() {
    show_header
    echo -e "${CYAN}Model Management${NC}"
    echo "────────────────────────────────────────────────────────────────────────────"
    echo ""
    echo "1) Update Piper TTS voices"
    echo "2) Update Whisper models"
    echo "3) Manage Ollama models"
    echo "4) Train custom wake word"
    echo "5) Back to main menu"
    echo ""
    read -p "Enter choice: " choice
    
    case $choice in
        1)
            python3 "$SCRIPT_DIR/update_models.py"
            read -p "Press Enter to continue..."
            ;;
        2)
            python3 "$SCRIPT_DIR/update_models.py"
            read -p "Press Enter to continue..."
            ;;
        3)
            manage_ollama_models
            ;;
        4)
            python3 "$SCRIPT_DIR/train_wake_word.py"
            read -p "Press Enter to continue..."
            ;;
        5)
            return
            ;;
        *)
            error "Invalid choice"
            read -p "Press Enter to continue..."
            ;;
    esac
}

manage_ollama_models() {
    show_header
    echo -e "${CYAN}Ollama Model Management${NC}"
    echo "────────────────────────────────────────────────────────────────────────────"
    
    echo "Currently installed models:"
    ollama list
    echo ""
    
    echo "1) Install new model"
    echo "2) Remove model"
    echo "3) Update model"
    echo "4) Test model"
    echo "5) Back"
    echo ""
    read -p "Enter choice: " choice
    
    case $choice in
        1)
            echo ""
            echo "Popular models:"
            echo "  • llama3.2:1b (fastest, least memory)"
            echo "  • llama3.2:3b (balanced)"
            echo "  • llama3.2:7b (better quality, more memory)"
            echo "  • codellama:7b (code-focused)"
            echo ""
            read -p "Enter model name to install: " model
            if [[ -n "$model" ]]; then
                ollama pull "$model"
            fi
            ;;
        2)
            read -p "Enter model name to remove: " model
            if [[ -n "$model" ]]; then
                ollama rm "$model"
            fi
            ;;
        3)
            read -p "Enter model name to update: " model
            if [[ -n "$model" ]]; then
                ollama pull "$model"
            fi
            ;;
        4)
            read -p "Enter model name to test: " model
            if [[ -n "$model" ]]; then
                echo "Testing model $model..."
                echo "Hello, how are you today?" | ollama run "$model"
            fi
            ;;
        5)
            return
            ;;
    esac
    
    read -p "Press Enter to continue..."
}

# Log management
show_logs() {
    show_header
    echo -e "${CYAN}System Logs${NC}"
    echo "────────────────────────────────────────────────────────────────────────────"
    echo ""
    echo "1) Home Assistant logs"
    echo "2) Wyoming Whisper logs"
    echo "3) Wyoming Piper logs"
    echo "4) OpenWakeWord logs"
    echo "5) Ollama logs"
    echo "6) Installation logs"
    echo "7) Service monitor logs"
    echo "8) Back to main menu"
    echo ""
    read -p "Enter choice: " choice
    
    case $choice in
        1) sudo journalctl -u home-assistant@homeassistant.service -f ;;
        2) sudo journalctl -u wyoming-whisper.service -f ;;
        3) sudo journalctl -u wyoming-piper.service -f ;;
        4) sudo journalctl -u wyoming-openwakeword.service -f ;;
        5) sudo journalctl -u ollama.service -f ;;
        6) 
            if [[ -f "$CONFIG_DIR/ai_assistant_install.log" ]]; then
                tail -f "$CONFIG_DIR/ai_assistant_install.log"
            else
                error "Installation log not found"
            fi
            ;;
        7)
            if [[ -f "$CONFIG_DIR/service_monitor.log" ]]; then
                tail -f "$CONFIG_DIR/service_monitor.log"
            else
                error "Service monitor log not found"
            fi
            ;;
        8) return ;;
        *) error "Invalid choice" ;;
    esac
}

# Troubleshooting
troubleshoot() {
    show_header
    echo -e "${CYAN}Troubleshooting Assistant${NC}"
    echo "────────────────────────────────────────────────────────────────────────────"
    echo ""
    echo "1) Fix common service issues"
    echo "2) Reset audio configuration"
    echo "3) Reinstall Wyoming services"
    echo "4) Check system resources"
    echo "5) Backup/Restore configuration"
    echo "6) Back to main menu"
    echo ""
    read -p "Enter choice: " choice
    
    case $choice in
        1) fix_common_issues ;;
        2) reset_audio_config ;;
        3) reinstall_wyoming ;;
        4) check_system_resources ;;
        5) backup_restore_menu ;;
        6) return ;;
        *) error "Invalid choice"; read -p "Press Enter to continue..." ;;
    esac
}

fix_common_issues() {
    echo "Running common issue fixes..."
    echo ""
    
    # Fix permissions
    echo "Fixing permissions..."
    sudo chown -R homeassistant:homeassistant /srv/homeassistant/.homeassistant/ 2>/dev/null || true
    sudo chown -R $USER:$USER "$CONFIG_DIR" 2>/dev/null || true
    
    # Restart services in order
    echo "Restarting services in dependency order..."
    sudo systemctl restart ollama.service
    sleep 5
    sudo systemctl restart wyoming-whisper.service
    sudo systemctl restart wyoming-piper.service
    sudo systemctl restart wyoming-openwakeword.service
    sleep 5
    sudo systemctl restart home-assistant@homeassistant.service
    
    # Check if audio devices are available
    echo "Checking audio devices..."
    if ! aplay -l >/dev/null 2>&1; then
        warn "No audio playback devices found"
    fi
    if ! arecord -l >/dev/null 2>&1; then
        warn "No audio recording devices found"
    fi
    
    echo "Common fixes applied."
    read -p "Press Enter to continue..."
}

reset_audio_config() {
    echo "Resetting audio configuration..."
    
    # Backup current config
    sudo cp /etc/asound.conf /etc/asound.conf.backup 2>/dev/null || true
    
    # Create new ALSA config
    sudo tee /etc/asound.conf > /dev/null <<'EOF'
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
    
    # Restart audio services
    sudo systemctl restart alsa-state
    pulseaudio -k || true
    sleep 2
    pulseaudio --start || true
    
    echo "Audio configuration reset."
    read -p "Press Enter to continue..."
}

reinstall_wyoming() {
    echo "Reinstalling Wyoming services..."
    read -p "This will stop services and reinstall. Continue? (y/n): " confirm
    
    if [[ "$confirm" =~ ^[Yy] ]]; then
        # Stop services
        sudo systemctl stop wyoming-whisper.service
        sudo systemctl stop wyoming-piper.service  
        sudo systemctl stop wyoming-openwakeword.service
        
        # Reinstall Python packages
        source "$CONFIG_DIR/venv/bin/activate"
        pip install --upgrade --force-reinstall wyoming-whisper wyoming-piper wyoming-openwakeword
        
        # Restart services
        sudo systemctl start wyoming-whisper.service
        sudo systemctl start wyoming-piper.service
        sudo systemctl start wyoming-openwakeword.service
        
        echo "Wyoming services reinstalled."
    fi
    
    read -p "Press Enter to continue..."
}

check_system_resources() {
    echo -e "${CYAN}System Resource Usage${NC}"
    echo "────────────────────────────────────────────────────────────────────────────"
    echo ""
    
    echo "CPU Usage:"
    top -bn1 | grep "Cpu(s)" | awk '{print $2 $3}' | awk -F'%' '{print $1}'
    echo ""
    
    echo "Memory Usage:"
    free -h
    echo ""
    
    echo "Disk Usage:"
    df -h /
    echo ""
    
    echo "Temperature (if available):"
    if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
        temp=$(cat /sys/class/thermal/thermal_zone0/temp)
        temp_c=$((temp / 1000))
        echo "CPU: ${temp_c}°C"
    else
        echo "Temperature monitoring not available"
    fi
    echo ""
    
    echo "Top processes by CPU:"
    ps aux --sort=-%cpu | head -6
    echo ""
    
    read -p "Press Enter to continue..."
}

backup_restore_menu() {
    echo -e "${CYAN}Backup & Restore${NC}"
    echo "────────────────────────────────────────────────────────────────────────────"
    echo ""
    echo "1) Create backup"
    echo "2) Restore from backup"
    echo "3) List backups"
    echo "4) Back to troubleshooting"
    echo ""
    read -p "Enter choice: " choice
    
    case $choice in
        1) create_backup ;;
        2) restore_backup ;;
        3) list_backups ;;
        4) return ;;
        *) error "Invalid choice" ;;
    esac
}

create_backup() {
    echo "Creating backup..."
    backup_dir="$CONFIG_DIR/backups"
    mkdir -p "$backup_dir"
    
    timestamp=$(date +%Y%m%d_%H%M%S)
    backup_file="$backup_dir/voice_assistant_backup_$timestamp.tar.gz"
    
    tar -czf "$backup_file" \
        -C /srv/homeassistant .homeassistant \
        -C "$CONFIG_DIR" . \
        --exclude="*.log" \
        --exclude="backups" \
        --exclude="venv" 2>/dev/null
    
    info "Backup created: $backup_file"
    read -p "Press Enter to continue..."
}

restore_backup() {
    backup_dir="$CONFIG_DIR/backups"
    if [[ ! -d "$backup_dir" ]] || [[ -z "$(ls -A "$backup_dir")" ]]; then
        error "No backups found"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo "Available backups:"
    ls -la "$backup_dir"/*.tar.gz 2>/dev/null | awk '{print $9}' | xargs -n1 basename
    echo ""
    
    read -p "Enter backup filename to restore: " backup_name
    backup_file="$backup_dir/$backup_name"
    
    if [[ -f "$backup_file" ]]; then
        read -p "This will overwrite current configuration. Continue? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy] ]]; then
            echo "Stopping services..."
            stop_all_services
            
            echo "Restoring backup..."
            tar -xzf "$backup_file" -C /
            
            echo "Starting services..."
            start_all_services
            
            info "Restore completed"
        fi
    else
        error "Backup file not found"
    fi
