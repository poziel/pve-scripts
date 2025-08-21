#!/usr/bin/env bash
# ct-update.sh — Update packages in the current LXC container.
# This script runs INSIDE a container, not on the Proxmox host.
# Supports Debian/Ubuntu (apt), RHEL/Fedora (dnf), Alpine (apk), and Arch (pacman).
# Usage:
#   ./ct-update.sh                      # update current container
#   ./ct-update.sh --dry-run            # show what would run
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
use_lib "system"     # For detect_package_manager and get_distro_name
use_lib "ui"         # For print_title function

# --- Args ---
DRY_RUN=false
MULTIPLE_MODE=false  # When true, suppress big title display
VERBOSE=false        # When true, show detailed information
SILENT=false         # When true, suppress all output

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]
  -d, --dry-run    Show what would run without executing
  -M, --multiple   Multiple execution mode (suppress title display)
  -V, --verbose    Show detailed information during update
  -S, --silent     Suppress all output (silent mode)
  -h, --help       Show this help

This script runs inside a container to update its packages.
Use ct-executor.sh to run this across multiple containers.

Examples:
  $(basename "$0")                    # Update current container
  $(basename "$0") --dry-run          # Show what would be done
  $(basename "$0") --verbose          # Show detailed update information
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--dry-run) DRY_RUN=true; shift;;
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

# --- Update function ---
# Return codes:
#   0 success, 1 skipped (unsupported), 2 failure
update_container() {
  local header="Container $(hostname)"

  # Detect package manager using shared function
  local pkg_mgr=$(detect_package_manager)
  local distro_name=$(get_distro_name)
  
  if [[ "$pkg_mgr" == "unknown" ]]; then
    log_warn "${header}: unsupported distribution, skipping"
    return 1
  fi

  # Build command based on package manager
  local cmd="export DEBIAN_FRONTEND=noninteractive; "
  
  case "$pkg_mgr" in
    apt)
      cmd+='apt-get update -y && apt-get full-upgrade -y && apt-get autoremove -y && apt-get clean -y && apt-get autoclean -y'
      ;;
    dnf)
      cmd+='dnf -y upgrade --refresh && dnf -y autoremove && dnf clean all'
      ;;
    apk)
      cmd+='apk update && apk upgrade --no-cache'
      ;;
    pacman)
      cmd+='pacman -Syu --noconfirm'
      ;;
  esac

  safe_log log_step "${header}: detected $distro_name ($pkg_mgr)"

  if [[ "$DRY_RUN" == "true" ]]; then
    safe_echo "${header}: would run -> ${cmd}"
    return 0
  fi

  safe_log log_step "${header}: starting updates..."
  if [[ "$VERBOSE" == "true" ]]; then
    safe_echo "  Executing command: $cmd"
    # Show all output in verbose mode
    if bash -c "${cmd}"; then
      safe_log log_success "${header}: update complete"
      return 0
    else
      safe_echo ""
      safe_log log_warn "${header}: update failed"
      return 2
    fi
  else
    # Hide output in normal mode
    if bash -c "${cmd}" >/dev/null 2>&1; then
      safe_log log_success "${header}: update complete"
      return 0
    else
      safe_echo ""
      safe_log log_warn "${header}: update failed"
      return 2
    fi
  fi
}

# Main function
main() {
  # Show title only if not in multiple mode
  if [[ "$MULTIPLE_MODE" == "false" ]]; then
    print_title "Container Package Update"
  fi

  # --- Execute update ---
  if update_container; then
    safe_echo ""
    safe_log log_success "Container $(hostname) updated successfully"
    exit 0
  else
    rc=$?
    safe_echo ""
    if [[ $rc -eq 1 ]]; then
      safe_log log_warn "Container $(hostname) was skipped"
    else
      fatal_error "Container $(hostname) update failed"
    fi
    exit $rc
  fi
}

# Run the main function
main
