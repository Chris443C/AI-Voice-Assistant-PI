#!/usr/bin/env python3
"""
Comprehensive Voice Assistant Pipeline Test
Tests all components of the voice assistant system
"""

import requests
import time
import subprocess
import json
import sys
import os
from pathlib import Path

# Colors for output
RED = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
BLUE = '\033[0;34m'
NC = '\033[0m'  # No Color

def print_status(message, status="INFO"):
    """Print colored status message"""
    if status == "SUCCESS":
        print(f"{GREEN}✓ {message}{NC}")
    elif status == "ERROR":
        print(f"{RED}✗ {message}{NC}")
    elif status == "WARNING":
        print(f"{YELLOW}⚠ {message}{NC}")
    else:
        print(f"{BLUE}ℹ {message}{NC}")

def test_systemd_service(service_name):
    """Test if a systemd service is running"""
    try:
        result = subprocess.run(
            ["systemctl", "is-active", service_name],
            capture_output=True,
            text=True
        )
        return result.stdout.strip() == "active"
    except Exception:
        return False

def test_http_service(name, port, endpoint="/info", timeout=5):
    """Test HTTP service endpoint"""
    try:
        url = f"http://localhost:{port}{endpoint}"
        response = requests.get(url, timeout=timeout)
        if response.status_code == 200:
            return True, response.json() if response.headers.get('content-type', '').startswith('application/json') else response.text
        return False, f"HTTP {response.status_code}"
    except requests.exceptions.RequestException as e:
        return False, str(e)

def test_ollama_service():
    """Test Ollama LLM service"""
    print_status("Testing Ollama LLM service...")
    
    # Check systemd service
    if not test_systemd_service("ollama.service"):
        print_status("Ollama systemd service not running", "ERROR")
        return False
    
    # Check HTTP endpoint
    success, info = test_http_service("Ollama", 11434, "/api/version")
    if success:
        print_status(f"Ollama service responding - Version: {info.get('version', 'Unknown')}", "SUCCESS")
        return True
    else:
        print_status(f"Ollama HTTP endpoint failed: {info}", "ERROR")
        return False

def test_wyoming_services():
    """Test all Wyoming services"""
    services = [
        ("Wyoming Whisper", 10300),
        ("Wyoming Piper", 10200),
        ("Wyoming OpenWakeWord", 10400)
    ]
    
    all_good = True
    
    for name, port in services:
        service_name = f"wyoming-{name.lower().split()[1]}.service"
        print_status(f"Testing {name}...")
        
        # Check systemd service
        if not test_systemd_service(service_name):
            print_status(f"{name} systemd service not running", "ERROR")
            all_good = False
            continue
        
        # Check HTTP endpoint
        success, info = test_http_service(name, port)
        if success:
            service_info = info.get('name', 'Unknown') if isinstance(info, dict) else info
            print_status(f"{name} responding - {service_info}", "SUCCESS")
        else:
            print_status(f"{name} HTTP endpoint failed: {info}", "ERROR")
            all_good = False
    
    return all_good

def test_home_assistant():
    """Test Home Assistant"""
    print_status("Testing Home Assistant...")
    
    # Check systemd service
    if not test_systemd_service("home-assistant@homeassistant.service"):
        print_status("Home Assistant systemd service not running", "ERROR")
        return False
    
    # Check HTTP endpoint
    success, info = test_http_service("Home Assistant", 8123, "/")
    if success:
        print_status("Home Assistant web interface responding", "SUCCESS")
        return True
    else:
        print_status(f"Home Assistant HTTP endpoint failed: {info}", "ERROR")
        return False

def test_audio_devices():
    """Test audio devices"""
    print_status("Testing audio devices...")
    
    try:
        # Check for ReSpeaker HAT
        result = subprocess.run(["aplay", "-l"], capture_output=True, text=True)
        if "seeedvoicecard" in result.stdout.lower():
            print_status("ReSpeaker HAT detected", "SUCCESS")
        else:
            print_status("ReSpeaker HAT not detected", "WARNING")
        
        # Check for recording devices
        result = subprocess.run(["arecord", "-l"], capture_output=True, text=True)
        if "seeedvoicecard" in result.stdout.lower():
            print_status("Microphone input available", "SUCCESS")
        else:
            print_status("Microphone input not detected", "WARNING")
        
        return True
    except Exception as e:
        print_status(f"Audio device test failed: {e}", "ERROR")
        return False

def test_voice_pipeline():
    """Test the complete voice pipeline"""
    print_status("Testing complete voice pipeline...")
    
    # Test each component
    components = [
        ("Ollama LLM", test_ollama_service),
        ("Wyoming Services", test_wyoming_services),
        ("Home Assistant", test_home_assistant),
        ("Audio Devices", test_audio_devices)
    ]
    
    results = {}
    all_passed = True
    
    for name, test_func in components:
        print(f"\n{BLUE}=== Testing {name} ==={NC}")
        try:
            result = test_func()
            results[name] = result
            if not result:
                all_passed = False
        except Exception as e:
            print_status(f"{name} test failed with exception: {e}", "ERROR")
            results[name] = False
            all_passed = False
    
    return all_passed, results

def test_system_resources():
    """Test system resource usage"""
    print_status("Testing system resources...")
    
    try:
        # Check disk space
        result = subprocess.run(["df", "/"], capture_output=True, text=True)
        lines = result.stdout.strip().split('\n')
        if len(lines) > 1:
            parts = lines[1].split()
            if len(parts) >= 5:
                usage = int(parts[4].replace('%', ''))
                if usage < 90:
                    print_status(f"Disk usage: {usage}%", "SUCCESS")
                else:
                    print_status(f"Disk usage critical: {usage}%", "WARNING")
        
        # Check memory usage
        result = subprocess.run(["free", "-m"], capture_output=True, text=True)
        lines = result.stdout.strip().split('\n')
        if len(lines) > 1:
            parts = lines[1].split()
            if len(parts) >= 3:
                total = int(parts[1])
                used = int(parts[2])
                usage = (used / total) * 100
                if usage < 90:
                    print_status(f"Memory usage: {usage:.1f}%", "SUCCESS")
                else:
                    print_status(f"Memory usage critical: {usage:.1f}%", "WARNING")
        
        # Check CPU temperature (Raspberry Pi)
        temp_file = Path("/sys/class/thermal/thermal_zone0/temp")
        if temp_file.exists():
            temp = int(temp_file.read_text().strip()) / 1000
            if temp < 80:
                print_status(f"CPU temperature: {temp}°C", "SUCCESS")
            else:
                print_status(f"CPU temperature high: {temp}°C", "WARNING")
        
        return True
    except Exception as e:
        print_status(f"System resource test failed: {e}", "ERROR")
        return False

def test_network_connectivity():
    """Test network connectivity"""
    print_status("Testing network connectivity...")
    
    try:
        # Test internet connectivity
        response = requests.get("https://httpbin.org/get", timeout=5)
        if response.status_code == 200:
            print_status("Internet connectivity: OK", "SUCCESS")
        else:
            print_status("Internet connectivity: Limited", "WARNING")
        
        # Test local network
        response = requests.get("http://localhost:8123", timeout=5)
        if response.status_code == 200:
            print_status("Local network: OK", "SUCCESS")
        else:
            print_status("Local network: Issues detected", "WARNING")
        
        return True
    except Exception as e:
        print_status(f"Network test failed: {e}", "ERROR")
        return False

def generate_report(results):
    """Generate a test report"""
    print(f"\n{BLUE}=== Voice Assistant Test Report ==={NC}")
    
    total_tests = len(results)
    passed_tests = sum(1 for result in results.values() if result)
    failed_tests = total_tests - passed_tests
    
    print(f"Total Tests: {total_tests}")
    print(f"Passed: {GREEN}{passed_tests}{NC}")
    print(f"Failed: {RED}{failed_tests}{NC}")
    
    if failed_tests == 0:
        print_status("All tests passed! Voice assistant is ready to use.", "SUCCESS")
        return True
    else:
        print_status(f"{failed_tests} test(s) failed. Please check the errors above.", "ERROR")
        return False

def main():
    """Main test function"""
    print(f"{BLUE}Voice Assistant Pipeline Test{NC}")
    print("=" * 40)
    
    # Run all tests
    tests = [
        ("System Resources", test_system_resources),
        ("Network Connectivity", test_network_connectivity),
        ("Voice Pipeline", test_voice_pipeline)
    ]
    
    results = {}
    
    for test_name, test_func in tests:
        print(f"\n{BLUE}=== {test_name} ==={NC}")
        try:
            if test_name == "Voice Pipeline":
                success, component_results = test_func()
                results[test_name] = success
                # Add individual component results
                for comp_name, comp_result in component_results.items():
                    results[f"  {comp_name}"] = comp_result
            else:
                results[test_name] = test_func()
        except Exception as e:
            print_status(f"{test_name} test failed with exception: {e}", "ERROR")
            results[test_name] = False
    
    # Generate final report
    success = generate_report(results)
    
    # Exit with appropriate code
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main() 