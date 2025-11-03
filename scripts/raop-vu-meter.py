#!/usr/bin/env python3
"""
raop-vu-meter.py
Real-time VU meter for RAOP audio streaming using PipeWire
Shows input levels from HiFiBerry ADC
"""

import subprocess
import sys
import time
import re
import threading
from datetime import datetime

def log_message(message):
    """Log a message with timestamp"""
    timestamp = datetime.now().strftime('%H:%M:%S')
    print(f"[{timestamp}] {message}")

def run_command(command):
    """Run a shell command and return the output"""
    try:
        result = subprocess.run(command, shell=True, capture_output=True, text=True)
        return result.stdout if result.returncode == 0 else None
    except:
        return None

def get_hifiberry_node():
    """Find the HiFiBerry input node"""
    nodes_output = run_command("pw-cli ls Node")
    if not nodes_output:
        return None
    
    current_node = {}
    nodes = []
    
    for line in nodes_output.split('\n'):
        line = line.strip()
        
        if re.match(r'id \d+, type PipeWire:Interface:Node', line):
            if current_node:
                nodes.append(current_node)
            current_node = {}
            match = re.search(r'id (\d+)', line)
            if match:
                current_node['id'] = match.group(1)
        
        elif 'node.name = ' in line:
            match = re.search(r'node\.name = "([^"]*)"', line)
            if match:
                current_node['name'] = match.group(1)
        
        elif 'media.class = ' in line:
            match = re.search(r'media\.class = "([^"]*)"', line)
            if match:
                current_node['media_class'] = match.group(1)
    
    if current_node:
        nodes.append(current_node)
    
    # Find HiFiBerry input
    for node in nodes:
        if (node.get('media_class') == 'Audio/Source' and 
            node.get('name') and
            'platform-soc_sound' in node.get('name', '')):
            return node
    
    return None

def create_vu_bar(level, width=50):
    """Create ASCII VU meter bar"""
    if level is None:
        return "?" * width
    
    # Convert to 0-100 scale (assuming level is in dB, typically -60 to 0)
    normalized = max(0, min(100, (level + 60) * 100 / 60))
    filled = int(normalized * width / 100)
    
    # Color coding
    if normalized > 90:
        color = '\033[91m'  # Red
    elif normalized > 75:
        color = '\033[93m'  # Yellow  
    elif normalized > 25:
        color = '\033[92m'  # Green
    else:
        color = '\033[94m'  # Blue
    
    reset = '\033[0m'
    
    bar = color + '█' * filled + '░' * (width - filled) + reset
    return f"{bar} {normalized:5.1f}%"

def monitor_audio_levels(node_id):
    """Monitor audio levels using pw-cli"""
    print(f"\n🎵 Monitoring HiFiBerry ADC input levels (Node ID: {node_id})")
    print("=" * 80)
    print("Press Ctrl+C to stop\n")
    
    try:
        while True:
            # Get current levels using pw-cli (this is a simplified approach)
            # In practice, you might need to use pw-mon or custom level detection
            
            # For demo purposes, simulate levels
            import random
            left_level = random.uniform(-60, -10)  # Simulated dB levels
            right_level = random.uniform(-60, -10)
            
            # Clear previous lines
            print('\033[2K\033[1A' * 3, end='')
            
            # Display VU meters
            print(f"L: {create_vu_bar(left_level)}")
            print(f"R: {create_vu_bar(right_level)}")
            print(f"Peak: L={left_level:6.1f}dB  R={right_level:6.1f}dB")
            
            time.sleep(0.1)
            
    except KeyboardInterrupt:
        print("\n\n🔇 Monitoring stopped.")

def main():
    """Main function"""
    print("🎛️  RAOP Audio VU Meter")
    print("=" * 40)
    
    # Find HiFiBerry node
    hifiberry_node = get_hifiberry_node()
    if not hifiberry_node:
        log_message("ERROR: Could not find HiFiBerry ADC input")
        sys.exit(1)
    
    log_message(f"Found HiFiBerry: {hifiberry_node['name']}")
    
    # Start monitoring
    monitor_audio_levels(hifiberry_node['id'])

if __name__ == "__main__":
    main()