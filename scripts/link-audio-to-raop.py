#!/usr/bin/env python3
"""
link-audio-to-raop.py
Links the HiFiBerry ADC input to the selected RAOP sink
Reads the target sink from ~/.config/raop-sink-name
"""

import subprocess
import sys
import time
import os
import re
from datetime import datetime
from pathlib import Path

def log_message(message):
    """Log a message with timestamp"""
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    print(f"{timestamp} [raop-audio-link] {message}")

def run_command(command, capture_output=True):
    """Run a shell command and return the output"""
    try:
        result = subprocess.run(command, shell=True, capture_output=capture_output, text=True)
        if result.returncode != 0 and capture_output:
            log_message(f"Command failed: {command}")
            log_message(f"Error: {result.stderr}")
            return None
        return result.stdout if capture_output else result.returncode == 0
    except Exception as e:
        log_message(f"Error running command '{command}': {e}")
        return None

def check_prerequisites():
    """Check if required tools are available"""
    if not run_command("which pw-cli", capture_output=True):
        log_message("ERROR: pw-cli not found. Please install PipeWire.")
        return False
    
    if not run_command("which pw-link", capture_output=True):
        log_message("ERROR: pw-link not found. Please install PipeWire tools.")
        return False
    
    # Check if PipeWire is running
    if not run_command("pw-cli info", capture_output=True):
        log_message("ERROR: PipeWire is not running or accessible.")
        return False
    
    return True

def read_target_sink():
    """Read the target sink from config file"""
    config_file = Path.home() / ".config" / "raop-sink-name"
    
    if not config_file.exists():
        log_message(f"ERROR: Configuration file not found: {config_file}")
        log_message("Please run select-raop-sink script first to choose a target sink.")
        return None
    
    try:
        target_sink = config_file.read_text().strip()
        if not target_sink:
            log_message(f"ERROR: No target sink specified in {config_file}")
            return None
        return target_sink
    except Exception as e:
        log_message(f"ERROR: Could not read config file: {e}")
        return None

def find_hifiberry_input():
    """Find the HiFiBerry ADC input node"""
    nodes_output = run_command("pw-cli ls Node")
    if not nodes_output:
        log_message("ERROR: Could not get node list from PipeWire")
        return None
    
    # Parse nodes to find HiFiBerry input
    current_node = {}
    nodes = []
    
    for line in nodes_output.split('\n'):
        line = line.strip()
        
        # Start of new node
        if re.match(r'id \d+, type PipeWire:Interface:Node', line):
            if current_node:
                nodes.append(current_node)
            current_node = {}
            match = re.search(r'id (\d+)', line)
            if match:
                current_node['id'] = match.group(1)
        
        # Node properties
        elif 'node.name = ' in line:
            match = re.search(r'node\.name = "([^"]*)"', line)
            if match:
                current_node['name'] = match.group(1)
        
        elif 'node.description = ' in line:
            match = re.search(r'node\.description = "([^"]*)"', line)
            if match:
                current_node['description'] = match.group(1)
        
        elif 'media.class = ' in line:
            match = re.search(r'media\.class = "([^"]*)"', line)
            if match:
                current_node['media_class'] = match.group(1)
    
    # Don't forget the last node
    if current_node:
        nodes.append(current_node)
    
    # Find HiFiBerry input (Audio/Source with specific patterns)
    for node in nodes:
        if (node.get('media_class') == 'Audio/Source' and 
            node.get('name') and
            ('platform-soc_sound' in node.get('name', '') or 
             'sndrpihifiberry' in node.get('name', '') or 
             'hifiberry' in node.get('description', '').lower())):
            return node
    
    return None

def verify_target_sink(target_sink):
    """Verify that the target RAOP sink exists and get its node info"""
    nodes_output = run_command("pw-cli ls Node")
    if not nodes_output:
        return None
    
    # Parse nodes to find the target sink
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
    
    # Find the target sink
    for node in nodes:
        if (node.get('name') == target_sink and 
            node.get('media_class') == 'Audio/Sink'):
            return node
    
    return None

def get_ports(node_id, direction):
    """Get ports for a node with specific direction"""
    ports_output = run_command("pw-cli ls Port")
    if not ports_output:
        return []
    
    current_port = {}
    ports = []
    
    for line in ports_output.split('\n'):
        line = line.strip()
        
        # Start of new port
        if re.match(r'id \d+, type PipeWire:Interface:Port', line):
            if current_port:
                ports.append(current_port)
            current_port = {}
            match = re.search(r'id (\d+)', line)
            if match:
                current_port['id'] = match.group(1)
        
        # Port properties
        elif 'node.id = ' in line:
            match = re.search(r'node\.id = "([^"]*)"', line)
            if match:
                current_port['node_id'] = match.group(1)
        
        elif 'port.direction = ' in line:
            match = re.search(r'port\.direction = "([^"]*)"', line)
            if match:
                current_port['direction'] = match.group(1)
        
        elif 'port.monitor = ' in line:
            current_port['is_monitor'] = 'true' in line
        
        elif 'audio.channel = ' in line:
            match = re.search(r'audio\.channel = "([^"]*)"', line)
            if match:
                current_port['audio_channel'] = match.group(1)
    
    if current_port:
        ports.append(current_port)
    
    # Filter ports for the specific node, direction, and exclude monitors
    matching_ports = []
    for port in ports:
        if (port.get('node_id') == node_id and 
            port.get('direction') == direction and 
            not port.get('is_monitor', False) and 
            'audio_channel' in port):
            matching_ports.append(port)
    
    # Sort by audio channel (FL before FR)
    matching_ports.sort(key=lambda p: p.get('audio_channel', ''))
    
    return matching_ports

def main():
    """Main function"""
    log_message("Starting RAOP audio linking...")
    
    # Check prerequisites
    if not check_prerequisites():
        sys.exit(1)
    
    # Read target sink
    target_sink = read_target_sink()
    if not target_sink:
        sys.exit(1)
    
    log_message(f"Target RAOP sink: {target_sink}")
    
    # Wait for audio devices to initialize
    log_message("Waiting 5 seconds for audio devices to initialize...")
    time.sleep(5)
    
    # Find HiFiBerry input
    log_message("Searching for HiFiBerry ADC input...")
    hifiberry_node = find_hifiberry_input()
    if not hifiberry_node:
        log_message("ERROR: Could not find HiFiBerry ADC input device.")
        
        # Show available audio sources for debugging
        nodes_output = run_command("pw-cli ls Node")
        if nodes_output:
            log_message("Available audio sources:")
            for line in nodes_output.split('\n'):
                if 'Audio/Source' in line:
                    log_message(f"  {line.strip()}")
        sys.exit(1)
    
    log_message(f"Found HiFiBerry input: {hifiberry_node['name']} (ID: {hifiberry_node['id']})")
    
    # Verify target sink
    log_message("Verifying target RAOP sink exists...")
    sink_node = verify_target_sink(target_sink)
    if not sink_node:
        log_message(f"ERROR: Target sink not found: {target_sink}")
        sys.exit(1)
    
    log_message(f"Target sink verified: {target_sink} (ID: {sink_node['id']})")
    
    # Get ports
    log_message("Finding audio ports...")
    input_ports = get_ports(hifiberry_node['id'], 'out')
    sink_ports = get_ports(sink_node['id'], 'in')
    
    if not input_ports:
        log_message(f"ERROR: No output ports found for HiFiBerry input (node ID: {hifiberry_node['id']})")
        sys.exit(1)
    
    if not sink_ports:
        log_message(f"ERROR: No input ports found for RAOP sink (node ID: {sink_node['id']})")
        sys.exit(1)
    
    log_message(f"Found {len(input_ports)} HiFiBerry output ports and {len(sink_ports)} RAOP input ports")
    
    # Create audio links
    log_message("Creating audio links...")
    success_count = 0
    
    for i, (input_port, sink_port) in enumerate(zip(input_ports, sink_ports)):
        input_id = input_port['id']
        sink_id = sink_port['id']
        input_channel = input_port.get('audio_channel', f'port_{i}')
        sink_channel = sink_port.get('audio_channel', f'port_{i}')
        
        log_message(f"Linking: {input_channel} (port {input_id}) -> {sink_channel} (port {sink_id})")
        
        if run_command(f"pw-link {input_id} {sink_id}", capture_output=False):
            log_message(f"Successfully linked {input_channel} -> {sink_channel}")
            success_count += 1
        else:
            log_message(f"WARNING: Failed to link {input_channel} -> {sink_channel}")
    
    # Verify connections
    log_message("Verifying audio connections...")
    if success_count > 0:
        log_message(f"SUCCESS: {success_count} audio links established")
        log_message("HiFiBerry ADC input is now streaming to RAOP sink")
    else:
        log_message("ERROR: No audio links were created successfully")
        sys.exit(1)
    
    log_message("Audio linking completed.")

if __name__ == "__main__":
    main()