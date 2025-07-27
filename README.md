# 🎙️ Local AI Voice Assistant

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-Raspberry%20Pi%20%7C%20Linux-blue.svg)](https://www.raspberrypi.org/)
[![Home Assistant](https://img.shields.io/badge/Home%20Assistant-Compatible-green.svg)](https://www.home-assistant.io/)

> **Replace Amazon Alexa with your own completely local, privacy-focused AI voice assistant!**

A comprehensive solution for building a fully local AI voice assistant using Raspberry Pi, Home Assistant, and cutting-edge open-source AI models. No cloud dependencies, complete privacy, and full customization.

## ✨ Features

### 🔒 **Privacy First**
- **100% Local Processing** - No data ever leaves your network
- **No Cloud Dependencies** - Works completely offline
- **Open Source** - Transparent and auditable code
- **Your Data Stays Yours** - Complete control over all voice data

### 🧠 **Advanced AI Capabilities**
- **Local LLMs** with Ollama (Llama 3.2, CodeLlama, and more)
- **State-of-the-art Speech Recognition** with OpenAI Whisper
- **Natural Text-to-Speech** with Piper TTS
- **Custom Wake Word Detection** with OpenWakeWord
- **Conversational AI** that understands context

### 🏠 **Smart Home Integration**
- **Home Assistant Integration** for complete home automation
- **Voice Control** of lights, switches, sensors, and more
- **Custom Commands** and automations
- **Multi-room Audio** support
- **Scene Control** via voice commands

### ⚙️ **Easy Installation & Management**
- **One-Click Installation** with automated setup scripts
- **Interactive Management Interface** for ongoing maintenance
- **Real-time Monitoring** and health checks
- **Automatic Service Recovery** and error handling
- **Backup & Restore** functionality

## 🎯 Quick Start

### Requirements

#### Hardware
- **Raspberry Pi 4/5** (4GB+ RAM recommended) or Linux server
- **ReSpeaker 2-Mic Pi HAT** for audio processing
- **Speakers** for audio output
- **MicroSD Card** (32GB+ recommended)
- **Stable internet** for initial model downloads

#### Software
- **Raspberry Pi OS** (Debian/Ubuntu-based system)
- **8GB+ free disk space**
- **Python 3.8+**

### Installation

1. **Download the installation script:**
   ```bash
   wget https://raw.githubusercontent.com/your-repo/local-ai-assistant/main/local_ai_assistant_setup.sh
   chmod +x local_ai_assistant_setup.sh
   ```

2. **Run the automated installation:**
   ```bash
   ./local_ai_assistant_setup.sh
   ```

3. **Reboot your system:**
   ```bash
   sudo reboot
   ```

4. **Configure Home Assistant:**
   ```bash
   wget https://raw.githubusercontent.com/your-repo/local-ai-assistant/main/homeassistant_config.sh
   chmod +x homeassistant_config.sh
   ./homeassistant_config.sh
   ```

5. **Start using your voice assistant:**
   ```bash
   wget https://raw.githubusercontent.com/your-repo/local-ai-assistant/main/voice_assistant_manager.sh
   chmod +x voice_assistant_manager.sh
   ./voice_assistant_manager.sh
   ```

That's it! Your local AI voice assistant is ready to use.

## 🗣️ Voice Commands

Once installed, you can use these default voice commands:

### Basic Commands
- **"Hey Jarvis, what time is it?"**
- **"Computer, turn on the lights"**
- **"Assistant, what's the weather?"**
- **"Hey AI, system status"**

### Home Automation
- **"Turn off all lights"**
- **"Set living room to 50%"**
- **"Activate movie mode"**
- **"Lock all doors"**

### System Control
- **"Restart voice services"**
- **"Check system health"**
- **"Update voice models"**

## 🛠️ Advanced Configuration

### Custom Installation Options

```bash
# Raspberry Pi 4 with lightweight model
./local_ai_assistant_setup.sh --device pi4 --ollama-model llama3.2:1b

# Server installation without Home Assistant
./local_ai_assistant_setup.sh --device server --no-homeassistant

# Custom voice and models
./local_ai_assistant_setup.sh \
  --ollama-model llama3.2:7b \
  --whisper-model medium \
  --piper-voice en_US-amy-medium

# See all options
./local_ai_assistant_setup.sh --help
```

### Service URLs

After installation, these services will be available:

| Service | URL | Purpose |
|---------|-----|---------|
| Home Assistant | http://localhost:8123 | Main control interface |
| Whisper STT | http://localhost:10300 | Speech-to-text API |
| Piper TTS | http://localhost:10200 | Text-to-speech API |
| OpenWakeWord | http://localhost:10400 | Wake word detection |
| Ollama LLM | http://localhost:11434 | Language model API |

## 📱 Management Interface

The included management script provides an intuitive interface for:

### Service Management
- ✅ **Real-time Status Monitoring**
- 🔄 **Service Control** (start/stop/restart)
- 📊 **Health Checks** and diagnostics
- 🔧 **Automated Troubleshooting**

### Testing & Validation
- 🎤 **Audio System Testing**
- 🗣️ **Voice Pipeline Validation**
- 🔊 **Text-to-Speech Testing**
- 📡 **Network Connectivity Checks**

### Model Management
- 📥 **Download New Models** (Ollama, Whisper, Piper)
- 🎯 **Train Custom Wake Words**
- 🔄 **Update Existing Models**
- 🗂️ **Model Library Management**

### System Maintenance
- 📋 **Configuration Backup/Restore**
- 📊 **System Resource Monitoring**
- 📜 **Log File Management**
- 🔧 **Automated Issue Resolution**

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Voice Assistant Stack                    │
├─────────────────────────────────────────────────────────────┤
│  User Voice Input → ReSpeaker HAT → Audio Processing       │
│                                                             │
│  ┌─────────────┐    ┌──────────────┐    ┌────────────────┐ │
│  │OpenWakeWord │───▶│Whisper STT   │───▶│Home Assistant  │ │
│  │Wake Detection│    │Speech-to-Text│    │Intent Processing│ │
│  └─────────────┘    └──────────────┘    └────────────────┘ │
│                                                   │         │
│  ┌─────────────┐    ┌──────────────┐    ┌────────▼────────┐ │
│  │   Speakers  │◀───│  Piper TTS   │◀───│  Ollama LLM     │ │
│  │Audio Output │    │Text-to-Speech│    │Language Model   │ │
│  └─────────────┘    └──────────────┘    └─────────────────┘ │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┤
│  │              Wyoming Protocol Layer                     │
│  │         (Secure inter-service communication)           │
│  └─────────────────────────────────────────────────────────┘
└─────────────────────────────────────────────────────────────┘
```

## 🧩 Components

### Core Services

| Component | Description | Technology |
|-----------|-------------|------------|
| **Home Assistant** | Central automation hub | Python/AsyncIO |
| **Whisper** | Speech-to-text processing | OpenAI Whisper |
| **Piper** | Natural text-to-speech | Neural TTS |
| **OpenWakeWord** | Wake word detection | PyTorch |
| **Ollama** | Local language models | Go/GGML |

### Communication

- **Wyoming Protocol** - Secure, efficient inter-service communication
- **REST APIs** - Standard HTTP interfaces for all services
- **WebSocket** - Real-time communication with Home Assistant
- **MQTT** (Optional) - IoT device integration

## 🎨 Customization

### Wake Words
Train custom wake words for personalized activation:

```bash
# Train your own wake word
python3 ~/.ai_assistant/scripts/train_wake_word.py

# Available default wake words:
# - "Hey Jarvis"
# - "Computer"
# - "Assistant"
# - "OK House"
```

### Voice Personalities
Choose from different response styles:

- **Professional** - Formal, business-like responses
- **Casual** - Friendly, conversational tone
- **Humorous** - Witty and entertaining
- **Detailed** - Comprehensive, informative answers

### Language Models
Compatible with various Ollama models:

| Model | Size | Best For | Memory Required |
|-------|------|----------|-----------------|
| `llama3.2:1b` | 1.3GB | Speed, basic tasks | 2GB RAM |
| `llama3.2:3b` | 2.0GB | Balanced performance | 4GB RAM |
| `llama3.2:7b` | 4.1GB | Quality responses | 8GB RAM |
| `codellama:7b` | 4.1GB | Programming tasks | 8GB RAM |

## 🔧 Troubleshooting

### Common Issues

#### Audio Problems
```bash
# Test audio devices
./voice_assistant_manager.sh
# Select option 6: Test Audio System
```

#### Service Failures
```bash
# Check service status
./voice_assistant_manager.sh
# Select option 1: Service Status

# Restart all services
./voice_assistant_manager.sh
# Select option 4: Restart All Services
```

#### Model Download Issues
```bash
# Update models manually
./voice_assistant_manager.sh
# Select option 10: Manage Models
```

### Log Files

| Component | Log Location |
|-----------|--------------|
| Installation | `~/.ai_assistant/ai_assistant_install.log` |
| Home Assistant | `journalctl -u home-assistant@homeassistant.service` |
| Whisper | `journalctl -u wyoming-whisper.service` |
| Piper | `journalctl -u wyoming-piper.service` |
| Ollama | `journalctl -u ollama.service` |

### Getting Help

1. **Check the management interface** for automated diagnostics
2. **Review log files** for error messages
3. **Run the troubleshooting wizard** in the manager
4. **Create an issue** on GitHub with logs and system info

## 🌟 Advanced Features

### Multi-Room Audio
Extend your voice assistant to multiple rooms:

```yaml
# Home Assistant configuration
media_player:
  - platform: mpd
    host: livingroom-pi.local
  - platform: mpd  
    host: bedroom-pi.local
```

### Custom Integrations
Add support for additional smart home devices:

```yaml
# Example: Philips Hue integration
light:
  - platform: hue
    host: 192.168.1.100
```

### Voice Training
Improve accuracy with personalized voice training:

```bash
# Record training samples
python3 ~/.ai_assistant/scripts/train_wake_word.py

# Customize voice commands
# Edit: ~/.homeassistant/configuration.yaml
```

## 📊 Performance Optimization

### Raspberry Pi Optimization

```bash
# Increase GPU memory split
echo "gpu_mem=128" | sudo tee -a /boot/config.txt

# Enable CPU frequency scaling
echo "arm_freq=1800" | sudo tee -a /boot/config.txt

# Optimize SD card performance
echo "dtparam=sd_overclock=100" | sudo tee -a /boot/config.txt
```

### Model Optimization

- **Use smaller models** on resource-constrained devices
- **Offload LLM processing** to a separate server
- **Cache frequently used responses** for faster replies
- **Adjust confidence thresholds** based on room acoustics

## 🔄 Updates and Maintenance

### Automatic Updates
```bash
# Set up automatic model updates
crontab -e
# Add: 0 2 * * 0 /home/pi/.ai_assistant/scripts/update_models.py
```

### Manual Updates
```bash
# Update all components
./voice_assistant_manager.sh
# Select option 10: Manage Models
# Then select: Update All
```

### Backup Strategy
```bash
# Create regular backups
./voice_assistant_manager.sh
# Select option 12: Troubleshooting
# Then select: Backup/Restore configuration
```

## 🤝 Contributing

We welcome contributions! Here's how to get started:

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Make your changes** and test thoroughly
4. **Commit your changes**: `git commit -m 'Add amazing feature'`
5. **Push to the branch**: `git push origin feature/amazing-feature`
6. **Open a Pull Request**

### Development Setup
```bash
# Clone the repository
git clone https://github.com/your-repo/local-ai-assistant.git
cd local-ai-assistant

# Set up development environment
./setup_dev.sh

# Run tests
./run_tests.sh
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Home Assistant** team for the incredible automation platform
- **OpenAI** for the Whisper speech recognition model
- **Ollama** team for making local LLMs accessible
- **Piper TTS** for high-quality text-to-speech
- **Wyoming Protocol** developers for efficient voice communication
- **NetworkChuck** for the inspiring tutorial that started this project

## 📞 Support

- **Documentation**: [Wiki](https://github.com/your-repo/local-ai-assistant/wiki)
- **Issues**: [GitHub Issues](https://github.com/your-repo/local-ai-assistant/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-repo/local-ai-assistant/discussions)
- **Discord**: [Community Server](https://discord.gg/your-server)

## 🗺️ Roadmap

### Upcoming Features
- [ ] **Multi-language support** for international users
- [ ] **Visual interface** with touchscreen support  
- [ ] **Mobile app** for remote control
- [ ] **Cloud sync** (optional) for multi-device setup
- [ ] **Plugin system** for easy extensions
- [ ] **Voice biometrics** for user identification
- [ ] **Continuous conversation** mode
- [ ] **Integration marketplace** for third-party add-ons

### Version History
- **v1.0.0** - Initial release with core functionality
- **v1.1.0** - Added management interface and troubleshooting
- **v1.2.0** - Enhanced model management and custom wake words
- **v2.0.0** - Multi-room support and advanced integrations (planned)

---

**Made with ❤️ for privacy-conscious smart home enthusiasts**

*Give us a ⭐ if this project helped you build your dream voice assistant!*
