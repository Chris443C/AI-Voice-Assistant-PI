#!/bin/bash

# =============================================================================
# Home Assistant Voice Assistant Configuration Script
# =============================================================================
# This script configures Home Assistant with Wyoming integrations and 
# sets up the voice assistant pipeline after initial installation
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
HA_CONFIG="/srv/homeassistant/.homeassistant"
CONFIG_DIR="$HOME/.ai_assistant"
LOG_FILE="$CONFIG_DIR/ha_config.log"

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

wait_for_homeassistant() {
    log "Waiting for Home Assistant to start..."
    local max_attempts=60
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if curl -s http://localhost:8123 > /dev/null 2>&1; then
            log "Home Assistant is responding"
            return 0
        fi
        sleep 5
        ((attempt++))
        echo -n "."
    done
    
    error "Home Assistant failed to start within 5 minutes"
}

create_advanced_configuration() {
    log "Creating advanced Home Assistant configuration..."
    
    # Enhanced configuration.yaml
    sudo tee "$HA_CONFIG/configuration.yaml" > /dev/null <<'EOF'
# Advanced Home Assistant Configuration for AI Voice Assistant
homeassistant:
  name: "AI Assistant Home"
  latitude: !secret home_latitude
  longitude: !secret home_longitude
  elevation: 0
  unit_system: metric
  time_zone: "America/New_York"
  country: US
  customize: !include customize.yaml

# Core components
frontend:
  themes: !include_dir_merge_named themes
config:
system_health:
mobile_app:
my:
sun:
person:
zone:

# Media and Audio
media_player:
tts:
  - platform: tts
    service_name: piper_tts

# Voice Assistant Components
wyoming:

assist_pipeline:

conversation:

intent_script:
  GetTime:
    speech:
      text: "The current time is {{ now().strftime('%I:%M %p') }}"
  
  GetWeather:
    speech:
      text: "I don't have weather information configured yet"
  
  LightControl:
    speech:
      text: "Light control would happen here"

# Automations and Scripts
automation: !include automations.yaml
script: !include scripts.yaml
scene: !include scenes.yaml

# Input components for voice training
input_boolean:
  voice_assistant_enabled:
    name: "Voice Assistant Enabled"
    initial: true
    icon: mdi:microphone

input_select:
  voice_response_style:
    name: "Voice Response Style"
    options:
      - "Professional"
      - "Casual"
      - "Humorous"
      - "Detailed"
    initial: "Professional"
    icon: mdi:voice

input_number:
  voice_confidence_threshold:
    name: "Voice Confidence Threshold"
    min: 0.1
    max: 1.0
    step: 0.1
    initial: 0.7
    icon: mdi:gauge

# Sensors for monitoring
sensor:
  - platform: systemmonitor
    resources:
      - type: disk_use_percent
        arg: /
      - type: memory_use_percent
      - type: processor_use
      - type: processor_temperature
  
  - platform: template
    sensors:
      voice_assistant_status:
        friendly_name: "Voice Assistant Status"
        value_template: >
          {% if is_state('input_boolean.voice_assistant_enabled', 'on') %}
            Active
          {% else %}
            Disabled
          {% endif %}
        icon_template: >
          {% if is_state('input_boolean.voice_assistant_enabled', 'on') %}
            mdi:microphone
          {% else %}
            mdi:microphone-off
          {% endif %}

# HTTP configuration
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 127.0.0.1
    - ::1

# Logging
logger:
  default: info
  logs:
    homeassistant.components.assist_pipeline: debug
    homeassistant.components.wyoming: debug
    homeassistant.components.conversation: debug
    homeassistant.components.intent: debug
    homeassistant.components.tts: debug

# Recorder
recorder:
  purge_keep_days: 30
  db_url: !secret db_url
  include:
    domains:
      - sensor
      - binary_sensor
      - input_boolean
      - input_select
      - input_number

# History
history:
  include:
    domains:
      - sensor
      - binary_sensor
      - input_boolean

# Logbook
logbook:
  include:
    domains:
      - input_boolean
      - sensor
EOF

    # Create customize.yaml
    sudo tee "$HA_CONFIG/customize.yaml" > /dev/null <<'EOF'
# Device customizations
sensor.voice_assistant_status:
  friendly_name: "Voice Assistant"
  icon: mdi:robot
EOF

    # Create enhanced automations
    sudo tee "$HA_CONFIG/automations.yaml" > /dev/null <<'EOF'
# Voice Assistant Automations

- id: voice_assistant_startup
  alias: "Voice Assistant - Startup Notification"
  trigger:
    - platform: homeassistant
      event: start
  action:
    - service: tts.speak
      target:
        entity_id: tts.piper
      data:
        message: "Voice assistant is now online and ready"

- id: voice_confidence_adjustment
  alias: "Voice Assistant - Adjust Confidence Based on Noise"
  trigger:
    - platform: time_pattern
      minutes: "/5"
  condition:
    - condition: state
      entity_id: input_boolean.voice_assistant_enabled
      state: "on"
  action:
    - service: input_number.set_value
      target:
        entity_id: input_number.voice_confidence_threshold
      data:
        value: >
          {% set noise_level = states('sensor.sound_level') | float(0) %}
          {% if noise_level > 50 %}
            0.9
          {% elif noise_level > 30 %}
            0.8
          {% else %}
            0.7
          {% endif %}

- id: wake_word_timeout_reset
  alias: "Voice Assistant - Reset Wake Word After Timeout"
  trigger:
    - platform: state
      entity_id: sensor.voice_assistant_status
      to: "Listening"
      for: "00:01:00"
  action:
    - service: assist_pipeline.reset
EOF

    # Create scripts
    sudo tee "$HA_CONFIG/scripts.yaml" > /dev/null <<'EOF'
# Voice Assistant Scripts

voice_assistant_test:
  alias: "Test Voice Assistant"
  sequence:
    - service: tts.speak
      target:
        entity_id: tts.piper
      data:
        message: "Voice assistant test successful. All systems operational."

voice_assistant_restart:
  alias: "Restart Voice Assistant Services"
  sequence:
    - service: shell_command.restart_wyoming_services
    - delay: "00:00:10"
    - service: tts.speak
      target:
        entity_id: tts.piper
      data:
        message: "Voice assistant services have been restarted"

voice_response_professional:
  alias: "Set Professional Voice Response"
  sequence:
    - service: input_select.select_option
      target:
        entity_id: input_select.voice_response_style
      data:
        option: "Professional"
    - service: conversation.process
      data:
        text: "Voice assistant is now in professional mode"

voice_response_casual:
  alias: "Set Casual Voice Response"
  sequence:
    - service: input_select.select_option
      target:
        entity_id: input_select.voice_response_style
      data:
        option: "Casual"
    - service: conversation.process
      data:
        text: "Hey there! I'm now in casual mode"

train_custom_wake_word:
  alias: "Train Custom Wake Word"
  sequence:
    - service: shell_command.train_wake_word
    - service: tts.speak
      target:
        entity_id: tts.piper
      data:
        message: "Custom wake word training initiated. Please follow the voice prompts."
EOF

    # Create scenes
    sudo tee "$HA_CONFIG/scenes.yaml" > /dev/null <<'EOF'
# Voice Assistant Scenes

- name: "Voice Assistant Active"
  entities:
    input_boolean.voice_assistant_enabled: true
    input_number.voice_confidence_threshold: 0.7

- name: "Voice Assistant Sleep"
  entities:
    input_boolean.voice_assistant_enabled: false

- name: "Voice Assistant High Sensitivity"
  entities:
    input_boolean.voice_assistant_enabled: true
    input_number.voice_confidence_threshold: 0.5

- name: "Voice Assistant Low Sensitivity"
  entities:
    input_boolean.voice_assistant_enabled: true
    input_number.voice_confidence_threshold: 0.9
EOF

    # Create shell commands configuration
    sudo tee "$HA_CONFIG/shell_commands.yaml" > /dev/null <<'EOF'
# Shell Commands for Voice Assistant

restart_wyoming_services: |
  sudo systemctl restart wyoming-whisper.service &&
  sudo systemctl restart wyoming-piper.service &&
  sudo systemctl restart wyoming-openwakeword.service

check_audio_devices: |
  aplay -l && arecord -l

test_microphone: |
  arecord -D plughw:seeedvoicecard,0 -f cd -t wav -d 3 /tmp/test.wav && 
  aplay /tmp/test.wav && 
  rm /tmp/test.wav

train_wake_word: |
  cd /home/$USER/.ai_assistant && 
  python3 scripts/train_wake_word.py

check_ollama_status: |
  curl -s http://localhost:11434/api/version | jq -r '.version // "Offline"'

update_voice_models: |
  cd /home/$USER/.ai_assistant && 
  python3 scripts/update_models.py
EOF

    # Update main configuration to include shell commands
    sudo sed -i '/^logbook:/i shell_command: !include shell_commands.yaml' "$HA_CONFIG/configuration.yaml"

    # Create themes directory and dark theme
    sudo mkdir -p "$HA_CONFIG/themes"
    sudo tee "$HA_CONFIG/themes/voice_assistant_dark.yaml" > /dev/null <<'EOF'
# Voice Assistant Dark Theme
voice_assistant_dark:
  # Main colors
  primary-color: "#3498db"
  accent-color: "#e74c3c"
  dark-primary-color: "#2980b9"
  light-primary-color: "#85c1e9"
  
  # Text colors
  primary-text-color: "#ffffff"
  text-primary-color: "#ffffff"
  secondary-text-color: "#b3b3b3"
  disabled-text-color: "#666666"
  
  # Sidebar
  sidebar-icon-color: "#b3b3b3"
  sidebar-text-color: "#ffffff"
  sidebar-selected-background-color: "#2980b9"
  sidebar-selected-icon-color: "#ffffff"
  sidebar-selected-text-color: "#ffffff"
  
  # Background colors
  primary-background-color: "#1e1e1e"
  secondary-background-color: "#2d2d2d"
  divider-color: "#404040"
  table-row-background-color: "#2d2d2d"
  table-row-alternative-background-color: "#353535"
  
  # Nav Menu
  paper-listbox-color: "#ffffff"
  paper-listbox-background-color: "#2d2d2d"
  paper-grey-50: "#1e1e1e"
  paper-grey-200: "#404040"
  
  # Paper card
  paper-card-header-color: "#ffffff"
  paper-card-background-color: "#2d2d2d"
  paper-dialog-background-color: "#2d2d2d"
  paper-item-icon-color: "#b3b3b3"
  paper-item-icon-active-color: "#ffffff"
  paper-item-icon_-_color: "#b3b3b3"
  paper-item-selected_-_background-color: "#2980b9"
  
  # Labels
  label-badge-border-color: "#404040"
  label-badge-background-color: "#2d2d2d"
  label-badge-text-color: "#ffffff"
  
  # Switches
  paper-toggle-button-checked-button-color: "#3498db"
  paper-toggle-button-checked-bar-color: "#2980b9"
  paper-toggle-button-unchecked-button-color: "#b3b3b3"
  paper-toggle-button-unchecked-bar-color: "#404040"
  
  # Sliders
  paper-slider-knob-color: "#3498db"
  paper-slider-knob-start-color: "#3498db"
  paper-slider-pin-color: "#3498db"
  paper-slider-active-color: "#3498db"
  paper-slider-container-color: "#404040"
EOF

    log "Advanced Home Assistant configuration created"
}

create_python_scripts() {
    log "Creating Python helper scripts..."
    
    mkdir -p "$CONFIG_DIR/scripts"
    
    # Wake word training script
    cat > "$CONFIG_DIR/scripts/train_wake_word.py" <<'EOF'
#!/usr/bin/env python3
"""
Custom Wake Word Training Script
"""
import os
import sys
import time
import wave
import pyaudio
import json
from pathlib import Path

def record_audio(filename, duration=3, sample_rate=16000):
    """Record audio sample for wake word training"""
    chunk = 1024
    format = pyaudio.paInt16
    channels = 1
    
    audio = pyaudio.PyAudio()
    
    stream = audio.open(format=format,
                       channels=channels,
                       rate=sample_rate,
                       input=True,
                       frames_per_buffer=chunk,
                       input_device_index=None)
    
    print(f"Recording {filename} for {duration} seconds...")
    frames = []
    
    for i in range(0, int(sample_rate / chunk * duration)):
        data = stream.read(chunk)
        frames.append(data)
    
    print("Recording finished")
    
    stream.stop_stream()
    stream.close()
    audio.terminate()
    
    # Save the recording
    wf = wave.open(filename, 'wb')
    wf.setnchannels(channels)
    wf.setsampwidth(audio.get_sample_size(format))
    wf.setframerate(sample_rate)
    wf.writeframes(b''.join(frames))
    wf.close()

def main():
    """Main training function"""
    wake_word = input("Enter your custom wake word: ").strip().lower()
    if not wake_word:
        print("Wake word cannot be empty")
        return
    
    samples_dir = Path(f"wake_word_samples/{wake_word}")
    samples_dir.mkdir(parents=True, exist_ok=True)
    
    print(f"Training wake word: '{wake_word}'")
    print("You will record 10 samples. Speak clearly and consistently.")
    
    for i in range(10):
        input(f"\nPress Enter to record sample {i+1}/10...")
        filename = samples_dir / f"sample_{i+1:02d}.wav"
        record_audio(str(filename))
        time.sleep(1)
    
    # Create metadata
    metadata = {
        "wake_word": wake_word,
        "samples": 10,
        "sample_rate": 16000,
        "created": time.strftime("%Y-%m-%d %H:%M:%S")
    }
    
    with open(samples_dir / "metadata.json", "w") as f:
        json.dump(metadata, f, indent=2)
    
    print(f"\nTraining complete! Samples saved to {samples_dir}")
    print("To use this wake word, restart the OpenWakeWord service.")

if __name__ == "__main__":
    main()
EOF

    # Model update script
    cat > "$CONFIG_DIR/scripts/update_models.py" <<'EOF'
#!/usr/bin/env python3
"""
Voice Model Update Script
"""
import os
import sys
import requests
import json
from pathlib import Path

def download_piper_voices():
    """Download available Piper TTS voices"""
    voices_url = "https://huggingface.co/rhasspy/piper-voices/resolve/main/voices.json"
    
    try:
        response = requests.get(voices_url)
        voices = response.json()
        
        print("Available Piper voices:")
        for lang, lang_voices in voices.items():
            print(f"\n{lang}:")
            for voice_name in lang_voices.keys():
                print(f"  - {voice_name}")
        
        # Download specific voice if requested
        voice_choice = input("\nEnter voice name to download (or press Enter to skip): ").strip()
        if voice_choice:
            download_voice(voices, voice_choice)
            
    except Exception as e:
        print(f"Error downloading voice list: {e}")

def download_voice(voices, voice_name):
    """Download a specific Piper voice"""
    models_dir = Path(os.path.expanduser("~/.ai_assistant/models/piper"))
    models_dir.mkdir(parents=True, exist_ok=True)
    
    # Find the voice in the voices dictionary
    for lang, lang_voices in voices.items():
        if voice_name in lang_voices:
            voice_info = lang_voices[voice_name]
            
            # Download .onnx file
            onnx_url = f"https://huggingface.co/rhasspy/piper-voices/resolve/main/{voice_info['files'][0]}"
            onnx_file = models_dir / f"{voice_name}.onnx"
            
            print(f"Downloading {voice_name}...")
            response = requests.get(onnx_url)
            with open(onnx_file, "wb") as f:
                f.write(response.content)
            
            # Download .onnx.json file
            json_url = f"https://huggingface.co/rhasspy/piper-voices/resolve/main/{voice_info['files'][1]}"
            json_file = models_dir / f"{voice_name}.onnx.json"
            
            response = requests.get(json_url)
            with open(json_file, "wb") as f:
                f.write(response.content)
            
            print(f"Downloaded {voice_name} to {models_dir}")
            return
    
    print(f"Voice '{voice_name}' not found")

def update_whisper_models():
    """Update Whisper models"""
    import whisper
    
    models = ["tiny", "base", "small", "medium", "large"]
    print("Available Whisper models:")
    for i, model in enumerate(models):
        print(f"{i+1}. {model}")
    
    try:
        choice = input("Enter model number to download (or press Enter to skip): ").strip()
        if choice.isdigit() and 1 <= int(choice) <= len(models):
            model_name = models[int(choice) - 1]
            print(f"Downloading Whisper {model_name} model...")
            whisper.load_model(model_name)
            print(f"Whisper {model_name} model downloaded successfully")
    except Exception as e:
        print(f"Error downloading Whisper model: {e}")

def main():
    """Main update function"""
    print("Voice Model Update Utility")
    print("=" * 30)
    
    print("\n1. Update Piper TTS voices")
    print("2. Update Whisper models")
    print("3. Both")
    
    choice = input("\nEnter your choice (1-3): ").strip()
    
    if choice in ["1", "3"]:
        download_piper_voices()
    
    if choice in ["2", "3"]:
        update_whisper_models()
    
    print("\nUpdate complete!")

if __name__ == "__main__":
    main()
EOF

    # Service status checker
    cat > "$CONFIG_DIR/scripts/check_services.py" <<'EOF'
#!/usr/bin/env python3
"""
Voice Assistant Service Status Checker
"""
import requests
import subprocess
import json
import sys

def check_service_status(service_name):
    """Check if a systemd service is running"""
    try:
        result = subprocess.run(
            ["systemctl", "is-active", service_name],
            capture_output=True,
            text=True
        )
        return result.stdout.strip() == "active"
    except:
        return False

def check_wyoming_service(name, port):
    """Check Wyoming service via HTTP"""
    try:
        response = requests.get(f"http://localhost:{port}/info", timeout=5)
        if response.status_code == 200:
            info = response.json()
            return True, info.get("name", "Unknown")
        return False, "HTTP Error"
    except:
        return False, "Connection Error"

def check_ollama():
    """Check Ollama service"""
    try:
        response = requests.get("http://localhost:11434/api/version", timeout=5)
        if response.status_code == 200:
            version = response.json().get("version", "Unknown")
            return True, version
        return False, "HTTP Error"
    except:
        return False, "Connection Error"

def main():
    """Main status check"""
    print("Voice Assistant Service Status")
    print("=" * 40)
    
    services = [
        ("wyoming-whisper", "wyoming-whisper.service", 10300),
        ("wyoming-piper", "wyoming-piper.service", 10200),
        ("wyoming-openwakeword", "wyoming-openwakeword.service", 10400),
    ]
    
    all_good = True
    
    for name, service, port in services:
        # Check systemd service
        systemd_status = check_service_status(service)
        
        # Check HTTP endpoint
        http_status, info = check_wyoming_service(name, port)
        
        status_icon = "✓" if (systemd_status and http_status) else "✗"
        status_text = "Running" if (systemd_status and http_status) else "Error"
        
        print(f"{status_icon} {name:<20} {status_text:<10} {info}")
        
        if not (systemd_status and http_status):
            all_good = False
    
    # Check Ollama
    ollama_systemd = check_service_status("ollama.service")
    ollama_http, ollama_info = check_ollama()
    
    status_icon = "✓" if (ollama_systemd and ollama_http) else "✗"
    status_text = "Running" if (ollama_systemd and ollama_http) else "Error"
    print(f"{status_icon} {'ollama':<20} {status_text:<10} {ollama_info}")
    
    if not (ollama_systemd and ollama_http):
        all_good = False
    
    # Check Home Assistant
    ha_status = check_service_status("home-assistant@homeassistant.service")
    try:
        ha_response = requests.get("http://localhost:8123", timeout=5)
        ha_http = ha_response.status_code == 200
    except:
        ha_http = False
    
    status_icon = "✓" if (ha_status and ha_http) else "✗"
    status_text = "Running" if (ha_status and ha_http) else "Error"
    print(f"{status_icon} {'home-assistant':<20} {status_text:<10}")
    
    if not (ha_status and ha_http):
        all_good = False
    
    print("\n" + "=" * 40)
    if all_good:
        print("✓ All services are running correctly!")
        sys.exit(0)
    else:
        print("✗ Some services have issues. Check logs for details.")
        sys.exit(1)

if __name__ == "__main__":
    main()
EOF

    # Make scripts executable
    chmod +x "$CONFIG_DIR/scripts/"*.py
    
    log "Python helper scripts created"
}

create_systemd_service_monitoring() {
    log "Setting up service monitoring..."
    
    # Create service monitor script
    cat > "$CONFIG_DIR/scripts/monitor_services.sh" <<'EOF'
#!/bin/bash

# Service monitoring script for voice assistant
SERVICES=("wyoming-whisper" "wyoming-piper" "wyoming-openwakeword" "ollama" "home-assistant@homeassistant")
LOG_FILE="$HOME/.ai_assistant/service_monitor.log"

log_message() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

check_and_restart() {
    local service=$1
    
    if ! systemctl is-active --quiet "$service"; then
        log_message "Service $service is down, attempting restart..."
        sudo systemctl restart "$service"
        
        sleep 10
        
        if systemctl is-active --quiet "$service"; then
            log_message "Service $service restarted successfully"
        else
            log_message "Failed to restart service $service"
        fi
    fi
}

# Main monitoring loop
for service in "${SERVICES[@]}"; do
    check_and_restart "$service"
done

# Check if all Wyoming services can be reached
python3 "$HOME/.ai_assistant/scripts/check_services.py" >> "$LOG_FILE" 2>&1
EOF

    chmod +x "$CONFIG_DIR/scripts/monitor_services.sh"
    
    # Create cron job for monitoring
    (crontab -l 2>/dev/null; echo "*/5 * * * * $CONFIG_DIR/scripts/monitor_services.sh") | crontab -
    
    log "Service monitoring configured"
}

configure_wyoming_integrations() {
    log "Configuring Wyoming integrations in Home Assistant..."
    
    # Wait for Home Assistant to be ready
    wait_for_homeassistant
    
    # Create integration configuration file
    sudo tee "$HA_CONFIG/integrations.yaml" > /dev/null <<'EOF'
# Wyoming Integration Configurations

# Whisper Speech-to-Text
wyoming_whisper:
  uri: "tcp://localhost:10300"
  
# Piper Text-to-Speech  
wyoming_piper:
  uri: "tcp://localhost:10200"
  
# OpenWakeWord
wyoming_openwakeword:
  uri: "tcp://localhost:10400"
EOF

    # Add to main configuration
    echo "" | sudo tee -a "$HA_CONFIG/configuration.yaml"
    echo "# Wyoming Integrations" | sudo tee -a "$HA_CONFIG/configuration.yaml"
    echo "wyoming: !include integrations.yaml" | sudo tee -a "$HA_CONFIG/configuration.yaml"
    
    log "Wyoming integrations configured"
}

setup_assist_pipeline() {
    log "Setting up Assist pipeline..."
    
    # Create assist pipeline configuration
    sudo tee "$HA_CONFIG/assist_pipeline.yaml" > /dev/null <<'EOF'
# Assist Pipeline Configuration

conversation:
  intents:
    GetTime:
      - "What time is it"
      - "Tell me the time"
      - "Current time"
    
    GetDate:
      - "What's the date"
      - "Tell me the date"
      - "What day is it"
    
    ControlLights:
      - "Turn on the lights"
      - "Turn off the lights"
      - "Lights on"
      - "Lights off"
    
    GetStatus:
      - "How are you"
      - "Status report"
      - "System status"

# Pipeline configuration
assist_pipeline:
  - name: "Local AI Assistant"
    language: "en"
    conversation_agent: "homeassistant"
    stt_engine: "wyoming_whisper"
    tts_engine: "wyoming_piper"  
    wake_word_engine: "wyoming_openwakeword"
    wake_word_id: "hey_jarvis"
    audio_settings:
      noise_suppression_level: 2
      auto_gain_control: true
      voice_activity_detection: true
EOF

    # Include in main configuration
    echo "assist_pipeline: !include assist_pipeline.yaml" | sudo tee -a "$HA_CONFIG/configuration.yaml"
    
    log "Assist pipeline configured"
}

create_dashboard() {
    log "Creating voice assistant dashboard..."
    
    # Create dashboard configuration
    sudo tee "$HA_CONFIG/dashboards/voice_assistant.yaml" > /dev/null <<'EOF'
# Voice Assistant Dashboard

title: "Voice Assistant Control"
views:
  - title: "Main"
    cards:
      - type: entities
        title: "Voice Assistant Status"
        entities:
          - entity: input_boolean.voice_assistant_enabled
            name: "Assistant Enabled"
          - entity: sensor.voice_assistant_status
            name: "Current Status"
          - entity: input_select.voice_response_style
            name: "Response Style"
          - entity: input_number.voice_confidence_threshold
            name: "Confidence Threshold"
      
      - type: horizontal-stack
        cards:
          - type: button
            entity: script.voice_assistant_test
            name: "Test Assistant"
            icon: mdi:microphone-variant
          - type: button
            entity: script.voice_assistant_restart
            name: "Restart Services"
            icon: mdi:restart
      
      - type: entities
        title: "System Monitoring"
        entities:
          - entity: sensor.processor_use
            name: "CPU Usage"
          - entity: sensor.memory_use_percent
            name: "Memory Usage"
          - entity: sensor.disk_use_percent
            name: "Disk Usage"
          - entity: sensor.processor_temperature
            name: "CPU Temperature"
      
      - type: logbook
        title: "Recent Activity"
        entities:
          - input_boolean.voice_assistant_enabled
          - sensor.voice_assistant_status
        hours_to_show: 24
      
      - type: markdown
        content: |
          ## Quick Commands
          
          **Voice Commands:**
          - "What time is it?"
          - "Turn on the lights"
          - "System status"
          - "How are you?"
          
          **Wake Words:**
          - "Hey Jarvis"
          - "Computer"
          
          **Service URLs:**
          - Whisper: http://localhost:10300
          - Piper: http://localhost:10200
          - OpenWakeWord: http://localhost:10400
          - Ollama: http://localhost:11434
EOF

    # Create dashboards directory
    sudo mkdir -p "$HA_CONFIG/dashboards"
    
    log "Voice assistant dashboard created"
}

restart_homeassistant() {
    log "Restarting Home Assistant to apply configuration..."
    sudo systemctl restart home-assistant@homeassistant.service
    wait_for_homeassistant
    log "Home Assistant restarted successfully"
}

print_configuration_summary() {
    log "==============================================================================="
    log "Home Assistant Voice Assistant Configuration Complete!"
    log "==============================================================================="
    info ""
    info "Configuration Summary:"
    info "- Advanced configuration with voice controls"
    info "- Wyoming integrations configured"
    info "- Assist pipeline set up"
    info "- Voice assistant dashboard created"
    info "- Service monitoring enabled"
    info "- Python helper scripts installed"
    info ""
    info "Next Steps:"
    info "1. Access Home Assistant: http://localhost:8123"
    info "2. Complete onboarding if first time"
    info "3. Go to Settings > Devices & Services"
    info "4. Add Wyoming integrations manually if not auto-discovered"
    info "5. Configure Assist pipeline in Settings > Voice Assistants"
    info "6. Test voice commands"
    info ""
    info "Useful Commands:"
    info "- Check services: $CONFIG_DIR/scripts/check_services.py"
    info "- Train wake word: $CONFIG_DIR/scripts/train_wake_word.py"
    info "- Update models: $CONFIG_DIR/scripts/update_models.py"
    info "- Monitor services: $CONFIG_DIR/scripts/monitor_services.sh"
    info ""
    info "Dashboard URL: http://localhost:8123/dashboards/voice_assistant"
    log "==============================================================================="
}

main() {
    log "Starting Home Assistant configuration for voice assistant..."
    
    create_advanced_configuration
    create_python_scripts
    create_systemd_service_monitoring
    configure_wyoming_integrations
    setup_assist_pipeline
    create_dashboard
    restart_homeassistant
    print_configuration_summary
    
    log "Configuration completed successfully!"
}

# Check if Home Assistant is installed
if [[ ! -d "/srv/homeassistant" ]]; then
    error "Home Assistant not found. Run the main installation script first."
fi

# Run configuration
main
