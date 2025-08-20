#!/bin/bash
# validation.sh - Validation and utility functions

# === Validation functions ===

# Check if the current user is root (UID 0)
# Returns: 0 if running as root, 1 if not
# Arguments: None
# Example: is_root || fatal_error "This script must be run as root"
is_root() {
  [[ "$(id -u)" -eq 0 ]]
}

# Check if a string contains only numeric characters
# Returns: 0 if string is numeric, 1 if not
# Arguments:
#   $1 - String to validate
# Example: is_numeric "123" && echo "Valid number"
is_numeric() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

# Validate hostname format according to RFC standards
# Returns: 0 if valid hostname, 1 if invalid
# Checks for alphanumeric characters, hyphens, and proper length (max 63 chars)
# Arguments:
#   $1 - Hostname string to validate
# Example: is_valid_hostname "web-server-01" && echo "Valid hostname"
is_valid_hostname() {
  [[ "$1" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]
}

# Validate IPv4 address format
# Returns: 0 if valid IP address, 1 if invalid
# Checks format and ensures each octet is within 0-255 range
# Arguments:
#   $1 - IP address string to validate
# Example: is_valid_ip "192.168.1.1" && echo "Valid IP"
is_valid_ip() {
  local ip="$1"
  local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
  
  if [[ $ip =~ $regex ]]; then
    local IFS='.'
    local parts=($ip)
    for part in "${parts[@]}"; do
      if [[ $part -gt 255 ]]; then
        return 1
      fi
    done
    return 0
  fi
  return 1
}

# Check if a file exists
# Returns: 0 if file exists, 1 if not
# Arguments:
#   $1 - File path to check
# Example: file_exists "/etc/passwd" && echo "File found"
file_exists() { [[ -f "$1" ]]; }

# Check if a directory exists
# Returns: 0 if directory exists, 1 if not
# Arguments:
#   $1 - Directory path to check
# Example: dir_exists "/var/log" && echo "Directory found"
dir_exists() { [[ -d "$1" ]]; }

# Check if a command is available in the system PATH
# Returns: 0 if command exists, 1 if not
# Arguments:
#   $1 - Command name to check
# Example: command_exists "curl" || install_package "curl"
command_exists() { command -v "$1" >/dev/null 2>&1; }

# Check if running inside a container (not on Proxmox host)
# Returns: 0 if in container, 1 if on host
# Uses absence of 'pct' command as indicator
# Arguments: None
# Example: is_container || fatal_error "This script runs inside containers only"
is_container() { ! command_exists pct; }

# Check if running on a Proxmox host
# Returns: 0 if on Proxmox host, 1 if not
# Uses presence of 'pct' command as indicator
# Arguments: None
# Example: is_proxmox_host || fatal_error "This script must run on Proxmox host"
is_proxmox_host() { command_exists pct; }
