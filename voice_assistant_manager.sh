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
