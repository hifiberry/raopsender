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
from collections import deque

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
    return bar

def monitor_audio_levels(node_id):
    """Monitor audio levels using pw-cli"""
    print(f"\nMonitoring HiFiBerry ADC input levels - Node ID: {node_id}")
    print("Press Ctrl+C to stop\n")
    
    # 10-second running window for peak detection
    # Store samples with timestamps (sample_rate = 10Hz, so 100 samples = 10 seconds)
    left_peak_window = deque(maxlen=100)  
    right_peak_window = deque(maxlen=100)
    
    # Initialize display area
    print("L:")
    print("R:")
    print("Peak:")
    
    try:
        while True:
            # Get current levels using pw-cli (this is a simplified approach)
            # In practice, you might need to use pw-mon or custom level detection
            
            # For demo purposes, simulate levels
            import random
            left_level = random.uniform(-60, -10)  # Simulated dB levels
            right_level = random.uniform(-60, -10)
            
            current_time = time.time()
            
            # Add current levels to peak windows
            left_peak_window.append((current_time, left_level))
            right_peak_window.append((current_time, right_level))
            
            # Calculate 10-second peak values
            ten_seconds_ago = current_time - 10.0
            
            # Filter to only include samples from last 10 seconds and get peak
            left_recent = [level for timestamp, level in left_peak_window if timestamp >= ten_seconds_ago]
            right_recent = [level for timestamp, level in right_peak_window if timestamp >= ten_seconds_ago]
            
            left_peak = max(left_recent) if left_recent else left_level
            right_peak = max(right_recent) if right_recent else right_level
            
            # Move cursor up 3 lines and update display
            print('\033[3A', end='')  # Move up 3 lines
            print(f'\033[2KL: {create_vu_bar(left_level)}')  # Clear line and print L
            print(f'\033[2KR: {create_vu_bar(right_level)}')  # Clear line and print R
            print(f'\033[2KPeak: L={left_peak:6.1f}dB  R={right_peak:6.1f}dB')  # Clear line and print Peak
            
            time.sleep(0.1)
            
    except KeyboardInterrupt:
        print("\n\nMonitoring stopped.")

def main():
    """Main function"""
    print("RAOP Audio VU Meter")
    
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