#!/usr/bin/env bash
# ct-tools.sh — Install essential tools in the current LXC container.
# This script runs INSIDE a container, not on the Proxmox host.
# Installs a predefined list of essential development and system tools.
# Usage:
#   ./ct-tools.sh                       # install tools interactively
#   ./ct-tools.sh --yes                 # install all tools without prompts
#   ./ct-tools.sh --list               # show list of tools to be installed
set -euo pipefail

# === Config ===
# List of essential tools to install (configurable)
ESSENTIAL_TOOLS=(
  curl
  wget
  nano
  vim
  git
  unzip
  htop
  net-tools
  gnupg
  lsb-release
  ca-certificates
  software-properties-common
  ufw
  tree
  rsync
  screen
  tmux
)

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
use_lib "system"     # For detect_package_manager
use_lib "packages"   # For package installation functions
use_lib "ui"         # For print_title function
use_lib "validation" # For ask_to_proceed function

# --- Args ---
MULTIPLE_MODE=false  # When true, suppress big title display
VERBOSE=false        # When true, show detailed information
SILENT=false         # When true, suppress all output
LIST_ONLY=false      # When true, only list tools

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]
  -l, --list       Show list of tools to be installed and exit
  -M, --multiple   Multiple execution mode (suppress title display)
  -V, --verbose    Show detailed information during installation
  -S, --silent     Suppress all output (silent mode)
  -h, --help       Show this help

This script installs essential development and system tools directly.
No confirmation is required - tools are installed automatically when script runs.
Use ct-executor.sh to run this across multiple containers.

Tools to be installed:
$(printf '  %s\n' "${ESSENTIAL_TOOLS[@]}")

Examples:
  $(basename "$0")                    # Install all tools with standard output
  $(basename "$0") --verbose          # Install with detailed output
  $(basename "$0") --silent           # Install silently
  $(basename "$0") --list             # Show tools list only
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -l|--list) LIST_ONLY=true; shift;;
    -M|--multiple) MULTIPLE_MODE=true; shift;;
    -V|--verbose) VERBOSE=true; shift;;
    -S|--silent) SILENT=true; shift;;
    -h|--help) usage; exit 0;;
    -*) fatal_error "Unknown option: $1";;
    *) fatal_error "Unexpected argument: $1";;
  esac
done

# Silent mode overrides verbose
if [[ "$SILENT" == "true" ]]; then
  VERBOSE=false
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

# Function to install tools
install_tools() {
  local header="Container $(hostname)"
  
  # Detect package manager
  local pkg_mgr=$(detect_package_manager)
  local distro_name=$(get_distro_name)
  
  if [[ "$pkg_mgr" == "unknown" ]]; then
    safe_log log_warn "${header}: unsupported distribution, cannot install tools"
    return 1
  fi

  safe_log log_step "🔧" "Installing essential tools on $distro_name ($pkg_mgr)..."
  
  local installed_count=0
  local skipped_count=0
  local failed_count=0
  
  for tool in "${ESSENTIAL_TOOLS[@]}"; do
    if is_package_installed "$tool"; then
      if [[ "$VERBOSE" == "true" ]]; then
        safe_echo "✔️  $tool already installed"
      fi
      ((skipped_count++))
    else
      if [[ "$VERBOSE" == "true" ]]; then
        safe_echo "🔹  Installing: $tool"
      fi
      
      if install_package "$tool"; then
        ((installed_count++))
        if [[ "$VERBOSE" == "true" ]]; then
          safe_echo "✅  $tool installed successfully"
        fi
      else
        ((failed_count++))
        if [[ "$VERBOSE" == "true" ]]; then
          safe_log log_warn "❌  Failed to install: $tool"
        fi
      fi
    fi
  done
  
  # Summary
  safe_log log_success "Tool installation complete:"
  safe_echo "  📦 Installed: $installed_count"
  safe_echo "  ✔️  Already present: $skipped_count"
  if [[ $failed_count -gt 0 ]]; then
    safe_echo "  ❌ Failed: $failed_count"
  fi
  
  return 0
}

# Function to list tools
list_tools() {
  safe_echo "Essential tools that will be installed:"
  safe_echo ""
  for tool in "${ESSENTIAL_TOOLS[@]}"; do
    safe_echo "  📦 $tool"
  done
  safe_echo ""
  safe_echo "Total: ${#ESSENTIAL_TOOLS[@]} tools"
}

# Main function
main() {
  # Show title only if not in multiple or silent mode
  if [[ "$MULTIPLE_MODE" == "false" && "$SILENT" == "false" ]]; then
    print_title "Container Essential Tools Installation"
  fi

  # Handle list-only mode
  if [[ "$LIST_ONLY" == "true" ]]; then
    list_tools
    exit 0
  fi

  # Install tools directly - no confirmation needed since user chose to run this script
  if install_tools; then
    safe_log log_success "Essential tools installation completed successfully"
    exit 0
  else
    fatal_error "Essential tools installation failed"
  fi
}

# Run the main function
main
