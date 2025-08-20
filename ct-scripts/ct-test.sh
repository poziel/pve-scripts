#!/usr/bin/env bash
# ct-test.sh — Simple test script to verify the modular architecture
# This script runs INSIDE a container to test basic functionality
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
MULTIPLE_MODE=false  # When true, suppress big title display
VERBOSE=false        # When true, show detailed information
SILENT=false         # When true, suppress all output

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]
  -M, --multiple   Multiple execution mode (suppress title display)
  -V, --verbose    Show detailed test information
  -S, --silent     Suppress all output (silent mode)
  -h, --help       Show this help

This script runs basic tests inside a container.
Use ct-executor.sh to run this across multiple containers.
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -M|--multiple) MULTIPLE_MODE=true; shift;;
    -V|--verbose) VERBOSE=true; shift;;
    -S|--silent) SILENT=true; shift;;
    -h|--help) usage; exit 0;;
    -*) fatal_error "Unknown option: $1";;
    *) fatal_error "Unexpected argument: $1";;
  esac
done

# Silent mode overrides verbose and multiple mode
if [[ "$SILENT" == "true" ]]; then
  VERBOSE=false
  MULTIPLE_MODE=true  # Silent implies no title
  exec 1>/dev/null 2>/dev/null
fi

# Function to log only if not silent
safe_log() {
  if [[ "$SILENT" == "false" ]]; then
    "$@"
  fi
}

# Function to echo only if not silent
safe_echo() {
  if [[ "$SILENT" == "false" ]]; then
    echo "$@"
  fi
}

# Main function
main() {
  # Show title only if not in multiple mode
  if [[ "$MULTIPLE_MODE" == "false" ]]; then
    print_title "Container Test Script - $(hostname)"
  fi

  # Test basic system info using shared functions
  safe_log log_step "📊" "System Information:"
  if [[ "$VERBOSE" == "true" ]]; then
    get_system_info | while read -r line; do
      safe_echo $'\t'"$line"
    done
  else
    safe_echo $'\t'"$(get_distro_name) - $(uname -r)"
  fi

  # Test package manager detection using shared function
  safe_log log_step "📦" "Package Manager Detection:"
  pkg_mgr=$(detect_package_manager)
  distro_name=$(get_distro_name)
  safe_echo $'\t'"$distro_name ($pkg_mgr) detected"

  # Test network connectivity using shared function
  safe_log log_step "🌐" "Network Connectivity:"
  if test_connectivity; then
    safe_echo $'\tInternet connectivity: OK'
    if [[ "$VERBOSE" == "true" ]]; then
      safe_echo $'\tPrimary IP: '"$(hostname -I | awk '{print $1}')"
    fi
  else
    safe_echo $'\tInternet connectivity: FAILED'
  fi

  # Test disk space using shared function
  safe_log log_step "💽" "Disk Space:"
  safe_echo $'\tRoot filesystem: '"$(get_disk_usage /)"
  if [[ "$VERBOSE" == "true" ]]; then
    safe_echo $'\tAvailable space: '"$(df -h / | awk 'NR==2 {print $4}')"
  fi

  # Test memory using shared function
  safe_log log_step "🧠" "Memory Usage:"
  safe_echo $'\tMemory: '"$(get_memory_usage)"
  if [[ "$VERBOSE" == "true" ]]; then
    safe_echo $'\tTotal RAM: '"$(free -h | awk 'NR==2 {print $2}')"
  fi

  # Test system load using shared function
  safe_log log_step "⚡" "System Load:"
  safe_echo $'\tLoad average: '"$(get_load_average)"
  if [[ "$VERBOSE" == "true" ]]; then
    safe_echo $'\tUptime: '"$(uptime -p 2>/dev/null || uptime | awk -F, '{print $1}' | sed 's/.*up //')"
  fi
  
  safe_log log_success "Container test completed successfully!"
  safe_echo ""
  safe_echo $'🎯 This container is ready for automation!'
  safe_echo ""
}

# Run the main function
main
