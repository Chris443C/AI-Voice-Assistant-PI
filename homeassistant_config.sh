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
