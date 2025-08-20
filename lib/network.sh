#!/bin/bash
# network.sh - Network utility functions

# === Network functions ===

# Get the primary IP address of the system using multiple fallback methods
# Returns: IP address as string, or "unknown" if no IP can be determined
# Uses three methods in order: hostname -I, ip route, ifconfig (legacy)
# Arguments: None
# Example: PRIMARY_IP=$(get_primary_ip)
get_primary_ip() {
  local ip=""
  
  # Method 1: hostname -I (most reliable)
  if command -v hostname >/dev/null 2>&1; then
    ip=$(hostname -I 2>/dev/null | awk '{print $1}')
  fi
  
  # Method 2: ip route (fallback)
  if [[ -z "$ip" ]] && command -v ip >/dev/null 2>&1; then
    ip=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
  fi
  
  # Method 3: ifconfig (legacy fallback)
  if [[ -z "$ip" ]] && command -v ifconfig >/dev/null 2>&1; then
    ip=$(ifconfig 2>/dev/null | grep -E 'inet [0-9]' | grep -v '127.0.0.1' | awk '{print $2}' | head -n1)
  fi
  
  echo "${ip:-unknown}"
}

# Test network connectivity to a host
# Returns: 0 if connection successful, 1 if failed or ping unavailable
# Arguments:
#   $1 - Host to ping (optional, defaults to "8.8.8.8")
#   $2 - Timeout in seconds (optional, defaults to 3)
# Example: test_connectivity "google.com" 5
test_connectivity() {
  local host="${1:-8.8.8.8}"
  local timeout="${2:-3}"
  
  if command -v ping >/dev/null 2>&1; then
    ping -c 1 -W "$timeout" "$host" >/dev/null 2>&1
  else
    return 1
  fi
}
