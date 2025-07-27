#!/bin/bash

# =============================================================================
# Security Configuration for AI Voice Assistant
# =============================================================================
# This script implements security hardening for the voice assistant setup
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
CONFIG_DIR="$HOME/.ai_assistant"
LOG_FILE="$CONFIG_DIR/security_config.log"

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

# =============================================================================
# Firewall Configuration
# =============================================================================

configure_firewall() {
    log "Configuring firewall rules..."
    
    # Install ufw if not present
    if ! command -v ufw &> /dev/null; then
        sudo apt update
        sudo apt install -y ufw
    fi
    
    # Reset firewall rules
    sudo ufw --force reset
    
    # Default policies
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    
    # Allow SSH (adjust port if needed)
    sudo ufw allow ssh
    
    # Allow Home Assistant web interface
    sudo ufw allow 8123/tcp comment "Home Assistant"
    
    # Allow Wyoming services (restrict to localhost)
    sudo ufw allow from 127.0.0.1 to any port 10200 comment "Piper TTS"
    sudo ufw allow from 127.0.0.1 to any port 10300 comment "Whisper STT"
    sudo ufw allow from 127.0.0.1 to any port 10400 comment "OpenWakeWord"
    
    # Allow Ollama API (restrict to localhost)
    sudo ufw allow from 127.0.0.1 to any port 11434 comment "Ollama API"
    
    # Enable firewall
    sudo ufw --force enable
    
    log "Firewall configured successfully"
}

# =============================================================================
# SSL/TLS Certificate Setup
# =============================================================================

setup_ssl_certificates() {
    log "Setting up SSL certificates..."
    
    # Install certbot
    sudo apt update
    sudo apt install -y certbot python3-certbot-nginx
    
    # Create self-signed certificate for local development
    sudo mkdir -p /etc/ssl/private
    sudo mkdir -p /etc/ssl/certs
    
    # Generate self-signed certificate
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/private/homeassistant.key \
        -out /etc/ssl/certs/homeassistant.crt \
        -subj "/C=US/ST=State/L=City/O=HomeAssistant/CN=localhost"
    
    # Set proper permissions
    sudo chmod 600 /etc/ssl/private/homeassistant.key
    sudo chmod 644 /etc/ssl/certs/homeassistant.crt
    
    log "SSL certificates configured"
}

# =============================================================================
# Service Security Hardening
# =============================================================================

harden_services() {
    log "Hardening service configurations..."
    
    # Create dedicated user for voice assistant services
    sudo useradd -r -s /bin/false voiceassistant || true
    
    # Update Wyoming service configurations with security
    sudo tee /etc/systemd/system/wyoming-whisper.service > /dev/null <<EOF
[Unit]
Description=Wyoming Whisper
Wants=network-online.target
After=network-online.target

[Service]
Type=exec
ExecStart=$PYTHON_VENV/bin/python -m wyoming_faster_whisper --model $WHISPER_MODEL --language en --uri tcp://127.0.0.1:10300
Restart=always
RestartSec=1
User=voiceassistant
Group=voiceassistant
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/tmp /var/tmp
LimitNOFILE=65536

[Install]
WantedBy=default.target
EOF

    sudo tee /etc/systemd/system/wyoming-piper.service > /dev/null <<EOF
[Unit]
Description=Wyoming Piper
Wants=network-online.target
After=network-online.target

[Service]
Type=exec
ExecStart=$PYTHON_VENV/bin/python -m wyoming_piper --piper '$CONFIG_DIR/models/piper/${PIPER_VOICE}.onnx' --uri tcp://127.0.0.1:10200
Restart=always
RestartSec=1
User=voiceassistant
Group=voiceassistant
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/tmp /var/tmp
LimitNOFILE=65536

[Install]
WantedBy=default.target
EOF

    sudo tee /etc/systemd/system/wyoming-openwakeword.service > /dev/null <<EOF
[Unit]
Description=Wyoming OpenWakeWord
Wants=network-online.target
After=network-online.target

[Service]
Type=exec
ExecStart=$PYTHON_VENV/bin/python -m wyoming_openwakeword --uri tcp://127.0.0.1:10400
Restart=always
RestartSec=1
User=voiceassistant
Group=voiceassistant
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/tmp /var/tmp
LimitNOFILE=65536

[Install]
WantedBy=default.target
EOF

    # Reload systemd
    sudo systemctl daemon-reload
    
    log "Services hardened successfully"
}

# =============================================================================
# Input Validation & Sanitization
# =============================================================================

create_validation_scripts() {
    log "Creating input validation scripts..."
    
    mkdir -p "$CONFIG_DIR/scripts"
    
    # Input validation script
    cat > "$CONFIG_DIR/scripts/validate_input.py" <<'EOF'
#!/usr/bin/env python3
"""
Input Validation for Voice Assistant
"""
import re
import sys
import json
from pathlib import Path

def validate_wake_word(wake_word):
    """Validate wake word input"""
    if not wake_word or len(wake_word.strip()) == 0:
        return False, "Wake word cannot be empty"
    
    if len(wake_word) > 50:
        return False, "Wake word too long (max 50 characters)"
    
    # Only allow alphanumeric and basic punctuation
    if not re.match(r'^[a-zA-Z0-9\s\-_\.]+$', wake_word):
        return False, "Wake word contains invalid characters"
    
    return True, "Valid"

def validate_voice_command(command):
    """Validate voice command input"""
    if not command or len(command.strip()) == 0:
        return False, "Command cannot be empty"
    
    if len(command) > 500:
        return False, "Command too long (max 500 characters)"
    
    # Check for potential injection patterns
    dangerous_patterns = [
        r'[<>"\']',  # HTML/XML injection
        r'javascript:',  # JavaScript injection
        r'data:',  # Data URI injection
        r'vbscript:',  # VBScript injection
    ]
    
    for pattern in dangerous_patterns:
        if re.search(pattern, command, re.IGNORECASE):
            return False, f"Command contains potentially dangerous content: {pattern}"
    
    return True, "Valid"

def validate_config_file(config_path):
    """Validate configuration file"""
    try:
        with open(config_path, 'r') as f:
            config = yaml.safe_load(f)
        
        # Validate required fields
        required_fields = ['homeassistant', 'frontend']
        for field in required_fields:
            if field not in config:
                return False, f"Missing required field: {field}"
        
        return True, "Valid"
    except Exception as e:
        return False, f"Configuration error: {str(e)}"

def main():
    """Main validation function"""
    if len(sys.argv) < 3:
        print("Usage: validate_input.py <type> <input>")
        sys.exit(1)
    
    validation_type = sys.argv[1]
    input_data = sys.argv[2]
    
    if validation_type == "wake_word":
        is_valid, message = validate_wake_word(input_data)
    elif validation_type == "command":
        is_valid, message = validate_voice_command(input_data)
    elif validation_type == "config":
        is_valid, message = validate_config_file(input_data)
    else:
        print("Unknown validation type")
        sys.exit(1)
    
    if is_valid:
        print("VALID")
        sys.exit(0)
    else:
        print(f"INVALID: {message}")
        sys.exit(1)

if __name__ == "__main__":
    main()
EOF

    chmod +x "$CONFIG_DIR/scripts/validate_input.py"
    
    log "Input validation scripts created"
}

# =============================================================================
# Backup & Recovery
# =============================================================================

setup_backup_system() {
    log "Setting up backup system..."
    
    # Create backup script
    cat > "$CONFIG_DIR/scripts/backup.sh" <<'EOF'
#!/bin/bash

# Backup script for voice assistant
BACKUP_DIR="$HOME/.ai_assistant/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="voice_assistant_backup_$DATE.tar.gz"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Create backup
tar -czf "$BACKUP_DIR/$BACKUP_NAME" \
    -C /srv/homeassistant .homeassistant \
    -C "$HOME" .ai_assistant \
    --exclude='*.log' \
    --exclude='*.tmp' \
    --exclude='__pycache__'

# Keep only last 5 backups
cd "$BACKUP_DIR"
ls -t *.tar.gz | tail -n +6 | xargs -r rm

echo "Backup created: $BACKUP_NAME"
EOF

    chmod +x "$CONFIG_DIR/scripts/backup.sh"
    
    # Create restore script
    cat > "$CONFIG_DIR/scripts/restore.sh" <<'EOF'
#!/bin/bash

# Restore script for voice assistant
BACKUP_DIR="$HOME/.ai_assistant/backups"

if [ $# -eq 0 ]; then
    echo "Usage: $0 <backup_file>"
    echo "Available backups:"
    ls -la "$BACKUP_DIR"/*.tar.gz 2>/dev/null || echo "No backups found"
    exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "Backup file not found: $BACKUP_FILE"
    exit 1
fi

echo "Restoring from backup: $BACKUP_FILE"
echo "This will overwrite current configuration. Continue? (y/N)"
read -r response

if [[ "$response" =~ ^[Yy]$ ]]; then
    # Stop services
    sudo systemctl stop home-assistant@homeassistant.service
    sudo systemctl stop wyoming-whisper.service
    sudo systemctl stop wyoming-piper.service
    sudo systemctl stop wyoming-openwakeword.service
    
    # Restore backup
    tar -xzf "$BACKUP_FILE" -C /
    
    # Restart services
    sudo systemctl start wyoming-whisper.service
    sudo systemctl start wyoming-piper.service
    sudo systemctl start wyoming-openwakeword.service
    sudo systemctl start home-assistant@homeassistant.service
    
    echo "Restore completed successfully"
else
    echo "Restore cancelled"
fi
EOF

    chmod +x "$CONFIG_DIR/scripts/restore.sh"
    
    # Set up automatic backups
    (crontab -l 2>/dev/null; echo "0 2 * * * $CONFIG_DIR/scripts/backup.sh") | crontab -
    
    log "Backup system configured"
}

# =============================================================================
# Monitoring & Alerting
# =============================================================================

setup_monitoring() {
    log "Setting up monitoring and alerting..."
    
    # Create monitoring script
    cat > "$CONFIG_DIR/scripts/monitor_security.sh" <<'EOF'
#!/bin/bash

# Security monitoring script
LOG_FILE="$HOME/.ai_assistant/security_monitor.log"
ALERT_FILE="$HOME/.ai_assistant/security_alerts.log"

log_alert() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] SECURITY ALERT: $1" >> "$ALERT_FILE"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] SECURITY ALERT: $1" >> "$LOG_FILE"
}

# Check for failed login attempts
failed_logins=$(grep "Failed password" /var/log/auth.log | wc -l)
if [ "$failed_logins" -gt 10 ]; then
    log_alert "High number of failed login attempts: $failed_logins"
fi

# Check for unauthorized access attempts
unauthorized_access=$(grep "Invalid user" /var/log/auth.log | wc -l)
if [ "$unauthorized_access" -gt 5 ]; then
    log_alert "Unauthorized access attempts detected: $unauthorized_access"
fi

# Check service status
services=("wyoming-whisper" "wyoming-piper" "wyoming-openwakeword" "home-assistant@homeassistant")
for service in "${services[@]}"; do
    if ! systemctl is-active --quiet "$service"; then
        log_alert "Service $service is not running"
    fi
done

# Check disk space
disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$disk_usage" -gt 90 ]; then
    log_alert "Disk usage critical: ${disk_usage}%"
fi

# Check memory usage
memory_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
if [ "$memory_usage" -gt 90 ]; then
    log_alert "Memory usage critical: ${memory_usage}%"
fi
EOF

    chmod +x "$CONFIG_DIR/scripts/monitor_security.sh"
    
    # Set up monitoring cron job
    (crontab -l 2>/dev/null; echo "*/5 * * * * $CONFIG_DIR/scripts/monitor_security.sh") | crontab -
    
    log "Security monitoring configured"
}

# =============================================================================
# Main Function
# =============================================================================

main() {
    log "Starting security configuration..."
    
    configure_firewall
    setup_ssl_certificates
    harden_services
    create_validation_scripts
    setup_backup_system
    setup_monitoring
    
    log "Security configuration completed successfully!"
    info ""
    info "Security features enabled:"
    info "- Firewall rules configured"
    info "- SSL certificates installed"
    info "- Service hardening applied"
    info "- Input validation scripts created"
    info "- Backup system configured"
    info "- Security monitoring active"
    info ""
    info "Next steps:"
    info "1. Review firewall rules: sudo ufw status"
    info "2. Test SSL certificates"
    info "3. Verify service permissions"
    info "4. Set up regular security audits"
}

# Run security configuration
main 