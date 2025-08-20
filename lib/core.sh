#!/bin/bash
# core.sh - Core library with essential functions and dynamic library loading
# This is the mandatory base library that all scripts should load first

# Colors
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
PURPLE="\033[1;35m"
RESET="\033[0m"

# === Essential logging functions (always needed) ===

# Display a step message with blue color and step icon
# Arguments:
#   $1 - Step icon/number (e.g., "1", "🔧")
#   $2 - Step description text
# Example: log_step "1" "Installing packages"
log_step() {
  local icon="${1:-📋}"
  local message="${2:-Step}"
  echo -e "${BLUE}$icon  $message${RESET}"
}

# Display a success message with green color and checkmark
# Arguments:
#   $1 - Success message text
# Example: log_success "Package installation completed"
log_success() {
  local message="${1:-Success}"
  echo -e "${GREEN}✅  $message${RESET}"
}

# Display a warning message with yellow color and warning icon
# Arguments:
#   $1 - Warning message text
# Example: log_warn "Package not found, skipping"
log_warn() {
  local message="${1:-Warning}"
  echo -e "${YELLOW}⚠️  $message${RESET}"
}

# Display an informational message with cyan color and info icon
# Arguments:
#   $1 - Information message text
# Example: log_info "Configuration file backed up"
log_info() {
  local message="${1:-Information}"
  echo -e "${CYAN}ℹ️  $message${RESET}"
}

# Display a debug message only if DEBUG environment variable is set to "true"
# Arguments:
#   $1 - Debug message text
# Example: log_debug "Variable value: $myvar"
log_debug() {
  if [[ "${DEBUG:-false}" == "true" ]]; then
    local message="${1:-Debug message}"
    echo -e "${PURPLE}🐛  DEBUG: $message${RESET}"
  fi
}

# Display an error message and exit the script with code 1
# Arguments:
#   $1 - Error message text
# Example: fatal_error "Configuration file not found"
fatal_error() {
  local message="${1:-Fatal error occurred}"
  echo -e "${RED}❌  $message${RESET}"
  exit 1
}

# === Essential validation functions ===

# Check if a command is available in the system PATH
# Returns: 0 if command exists, 1 if not
# Arguments:
#   $1 - Command name to check
# Example: command_exists "curl" || fatal_error "curl is required"
command_exists() { 
  command -v "$1" >/dev/null 2>&1; 
}

# === Dynamic library loading system ===

# Configuration for library loading
CORE_LIB_URL_BASE="https://raw.githubusercontent.com/poziel/pve-scripts/refs/heads/main/lib"
CORE_LIB_DIR=""
declare -A LOADED_LIBS

# Initialize library system - detect local lib directory
_init_lib_system() {
  if [[ -n "$CORE_LIB_DIR" ]]; then
    return 0  # Already initialized
  fi
  
  # Try to find lib directory relative to current script
  local script_dir="$(dirname "${BASH_SOURCE[1]}")"
  
  # Check different possible locations
  if [[ -d "$script_dir/lib" ]]; then
    CORE_LIB_DIR="$script_dir/lib"
  elif [[ -d "$script_dir/../lib" ]]; then
    CORE_LIB_DIR="$script_dir/../lib"
  elif [[ -d "./lib" ]]; then
    CORE_LIB_DIR="./lib"
  else
    log_debug "No local lib directory found, will use remote only"
    CORE_LIB_DIR=""
  fi
  
  log_debug "Library system initialized, local dir: ${CORE_LIB_DIR:-none}"
}

# Load a library module dynamically
# Tries local file first, then downloads from GitHub if needed
# Tracks loaded libraries to prevent duplicate loading
# Arguments:
#   $1 - Library name (without .sh extension)
# Example: use_lib "system" loads system.sh
# Returns: 0 on success, exits with fatal_error on failure
use_lib() {
  local lib_name="$1"
  local lib_file="${lib_name}.sh"
  
  # Initialize library system if needed
  _init_lib_system
  
  # Check if already loaded
  if [[ -n "${LOADED_LIBS[$lib_name]:-}" ]]; then
    log_debug "Library '$lib_name' already loaded, skipping"
    return 0
  fi
  
  log_debug "Loading library: $lib_name"
  
  # Try local file first
  if [[ -n "$CORE_LIB_DIR" && -f "$CORE_LIB_DIR/$lib_file" ]]; then
    log_debug "Loading local library: $CORE_LIB_DIR/$lib_file"
    if source "$CORE_LIB_DIR/$lib_file"; then
      LOADED_LIBS[$lib_name]="local"
      log_debug "Successfully loaded local library: $lib_name"
      return 0
    else
      fatal_error "Failed to load local library: $CORE_LIB_DIR/$lib_file"
    fi
  fi
  
  # Try remote download
  local lib_url="$CORE_LIB_URL_BASE/$lib_file"
  log_debug "Downloading library from: $lib_url"
  
  if command_exists wget; then
    if source <(wget -qO- "$lib_url"); then
      LOADED_LIBS[$lib_name]="remote"
      log_debug "Successfully loaded remote library: $lib_name"
      return 0
    else
      fatal_error "Failed to download library from: $lib_url"
    fi
  elif command_exists curl; then
    if source <(curl -fsSL "$lib_url"); then
      LOADED_LIBS[$lib_name]="remote"
      log_debug "Successfully loaded remote library: $lib_name"
      return 0
    else
      fatal_error "Failed to download library from: $lib_url"
    fi
  else
    fatal_error "Neither wget nor curl available for downloading library: $lib_name"
  fi
}

# Get status of loaded libraries (useful for debugging)
# Shows which libraries are loaded and their source (local/remote)
# Arguments: None
# Example: show_loaded_libs
show_loaded_libs() {
  if [[ ${#LOADED_LIBS[@]} -eq 0 ]]; then
    log_info "No additional libraries loaded"
    return
  fi
  
  log_info "Loaded libraries:"
  for lib in "${!LOADED_LIBS[@]}"; do
    echo "  📚 $lib (${LOADED_LIBS[$lib]})"
  done
}

# Mark core library as loaded
LOADED_LIBS["core"]="loaded"

log_debug "Core library loaded successfully"
