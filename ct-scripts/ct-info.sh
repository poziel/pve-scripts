#!/usr/bin/env bash
# ct-info.sh — Display container system information including hostname and IP
# This script runs INSIDE a container to gather and display system info
set -euo pipefail

# --- Load core library ---
CORE_LIB_URL="https://raw.githubusercontent.com/poziel/pve-scripts/refs/heads/main/lib/core.sh"

# Load core library (contains logging and use_lib function)
if [[ -f "../lib/core.sh" ]]; then
  source "../lib/core.sh"
elif [[ -f "./lib/core.sh" ]]; then
  source "./lib/core.sh"
else
  if command -v wget >/dev/null 2>&1; then
    source <(wget -qO- "$CORE_LIB_URL") || {
      echo "❌ Failed to load core library from $CORE_LIB_URL"
      exit 1
    }
  elif command -v curl >/dev/null 2>&1; then
    source <(curl -fsSL "$CORE_LIB_URL") || {
      echo "❌ Failed to load core library from $CORE_LIB_URL"
      exit 1
    }
  else
    echo "❌ Core library not found and neither wget nor curl available"
    exit 1
  fi
fi

# Load additional libraries as needed
use_lib "ui"         # For print_title
use_lib "system"     # For system detection and info functions
use_lib "network"    # For connectivity testing
use_lib "validation" # For is_numeric and other validation functions

# --- Args ---
VERBOSE=false
JSON_OUTPUT=false
MULTIPLE_MODE=false  # When true, suppress big title display
SILENT=false         # When true, suppress all output

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]
  -v, --verbose    Show detailed information
  -j, --json       Output in JSON format
  -M, --multiple   Multiple execution mode (suppress title display)
  -S, --silent     Suppress all output (silent mode)
  -h, --help       Show this help

This script displays container hostname and IP information.
Use ct-executor.sh to run this across multiple containers.

Examples:
  $(basename "$0")                    # Basic container information
  $(basename "$0") --verbose          # Detailed network information
  $(basename "$0") --json             # JSON output format
EOF
}
CORE_LIB_URL="https://raw.githubusercontent.com/poziel/pve-scripts/refs/heads/main/lib/core.sh"

# Load core library (contains logging and use_lib function)
if [[ -f "../lib/core.sh" ]]; then
  source "../lib/core.sh"
elif [[ -f "./lib/core.sh" ]]; then
  source "./lib/core.sh"
else
  if command -v wget >/dev/null 2>&1; then
    source <(wget -qO- "$CORE_LIB_URL") || {
      echo "❌ Failed to load core library from $CORE_LIB_URL"
      exit 1
    }
  elif command -v curl >/dev/null 2>&1; then
    source <(curl -fsSL "$CORE_LIB_URL") || {
      echo "❌ Failed to load core library from $CORE_LIB_URL"
      exit 1
    }
  else
    echo "❌ Core library not found and neither wget nor curl available"
    exit 1
  fi
fi

# Load additional libraries as needed
use_lib "ui"         # For print_title
use_lib "system"     # For system detection and info functions
use_lib "network"    # For connectivity testing
use_lib "validation" # For is_numeric and other validation functions

# --- Args ---
VERBOSE=false
JSON_OUTPUT=false
MULTIPLE_MODE=false  # When true, suppress big title display
SILENT=false         # When true, suppress all output

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]
  -v, --verbose    Show detailed information
  -j, --json       Output in JSON format
  -M, --multiple   Multiple execution mode (suppress title display)
  -h, --help       Show this help

This script displays container hostname and IP information.
Use ct-executor.sh to run this across multiple containers.

Examples:
  $(basename "$0")                    # Basic hostname and IP
  $(basename "$0") --verbose          # Detailed network information
  $(basename "$0") --json             # JSON output format
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--verbose) VERBOSE=true; shift;;
    -j|--json) JSON_OUTPUT=true; shift;;
    -M|--multiple) MULTIPLE_MODE=true; shift;;
    -S|--silent) SILENT=true; shift;;
    -h|--help) usage; exit 0;;
    -*) fatal_error "Unknown option: $1";;
    *) fatal_error "Unexpected argument: $1";;
  esac
done

# Silent mode overrides everything
if [[ "$SILENT" == "true" ]]; then
  exec 1>/dev/null 2>/dev/null
fi

# Function to echo only if not silent
safe_echo() {
  if [[ "$SILENT" == "false" ]]; then
    echo "$@"
  fi
}

# --- Get system information ---
get_hostname() {
  hostname 2>/dev/null || echo "unknown"
}

get_primary_ip() {
  # Try multiple methods to get the primary IP
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
  
  # Default if nothing found
  echo "${ip:-unknown}"
}

get_all_ips() {
  local ips=()
  
  # Get all non-loopback IPs
  if command -v ip >/dev/null 2>&1; then
    while IFS= read -r line; do
      [[ -n "$line" ]] && ips+=("$line")
    done < <(ip addr show 2>/dev/null | grep -oE 'inet [0-9.]+' | grep -v '127.0.0.1' | awk '{print $2}')
  elif command -v ifconfig >/dev/null 2>&1; then
    while IFS= read -r line; do
      [[ -n "$line" ]] && ips+=("$line")
    done < <(ifconfig 2>/dev/null | grep -E 'inet [0-9]' | grep -v '127.0.0.1' | awk '{print $2}')
  fi
  
  printf '%s\n' "${ips[@]}"
}

get_network_interfaces() {
  local interfaces=()
  
  if command -v ip >/dev/null 2>&1; then
    while IFS= read -r line; do
      [[ -n "$line" ]] && interfaces+=("$line")
    done < <(ip link show 2>/dev/null | grep -E '^[0-9]+:' | awk -F': ' '{print $2}' | grep -v 'lo')
  elif command -v ifconfig >/dev/null 2>&1; then
    while IFS= read -r line; do
      [[ -n "$line" ]] && interfaces+=("$line")
    done < <(ifconfig 2>/dev/null | grep -E '^[a-zA-Z]' | awk '{print $1}' | grep -v 'lo')
  fi
  
  printf '%s\n' "${interfaces[@]}"
}

# --- Display functions ---
display_basic() {
  local hostname=$(get_hostname)
  local primary_ip=$(get_primary_ip)
  
  # Show title only if not in multiple mode
  if [[ "$MULTIPLE_MODE" == "false" ]]; then
    print_title "Container Info"
  fi
  safe_echo "🖥️  Hostname: $hostname"
  safe_echo "🌐 Primary IP: $primary_ip"
}

display_verbose() {
  local hostname=$(get_hostname)
  local primary_ip=$(get_primary_ip)
  
  # Show title only if not in multiple mode
  if [[ "$MULTIPLE_MODE" == "false" ]]; then
    print_title "Container Network Information"
  fi
  
  safe_echo "🖥️  Hostname: $hostname"
  safe_echo "🌐 Primary IP: $primary_ip"
  safe_echo ""
  
  log_step "1" "All IP Addresses:"
  local all_ips
  readarray -t all_ips < <(get_all_ips)
  if [[ ${#all_ips[@]} -gt 0 ]]; then
    for ip in "${all_ips[@]}"; do
      safe_echo $'\t'"📍 $ip"
    done
  else
    safe_echo $'\t'"⚠️  No IP addresses found"
  fi
  safe_echo ""
  
  log_step "2" "Network Interfaces:"
  local interfaces
  readarray -t interfaces < <(get_network_interfaces)
  if [[ ${#interfaces[@]} -gt 0 ]]; then
    for interface in "${interfaces[@]}"; do
      safe_echo $'\t'"🔗 $interface"
    done
  else
    safe_echo $'\t'"⚠️  No network interfaces found"
  fi
  safe_echo ""
  
  # Additional network info if available
  if command -v ss >/dev/null 2>&1; then
    log_step "3" "Listening Services:"
    local listening_ports
    listening_ports=$(ss -tuln 2>/dev/null | grep LISTEN | awk '{print $5}' | sort -u | head -5)
    if [[ -n "$listening_ports" ]]; then
      echo "$listening_ports" | while read -r port; do
        safe_echo $'\t'"🔌 $port"
      done
    else
      safe_echo $'\t'"ℹ️  No listening services detected"
    fi
  fi
}

display_json() {
  local hostname=$(get_hostname)
  local primary_ip=$(get_primary_ip)
  local all_ips
  local interfaces
  
  readarray -t all_ips < <(get_all_ips)
  readarray -t interfaces < <(get_network_interfaces)
  
  # Build JSON manually to avoid dependencies
  safe_echo "{"
  safe_echo "  \"hostname\": \"$hostname\","
  safe_echo "  \"primary_ip\": \"$primary_ip\","
  safe_echo "  \"all_ips\": ["
  for i in "${!all_ips[@]}"; do
    safe_echo -n $'\t'"\"${all_ips[i]}\""
    [[ $i -lt $((${#all_ips[@]} - 1)) ]] && safe_echo "," || safe_echo ""
  done
  safe_echo "  ],"
  safe_echo "  \"interfaces\": ["
  for i in "${!interfaces[@]}"; do
    safe_echo -n $'\t'"\"${interfaces[i]}\""
    [[ $i -lt $((${#interfaces[@]} - 1)) ]] && safe_echo "," || safe_echo ""
  done
  safe_echo "  ]"
  safe_echo "}"
}

# Main function
main() {
  # --- Main execution ---
  if [[ "$JSON_OUTPUT" == "true" ]]; then
    display_json
  elif [[ "$VERBOSE" == "true" ]]; then
    display_verbose
  else
    display_basic
  fi

  # Exit successfully
  exit 0
}

# Run the main function
main
