#!/bin/bash
# packages.sh - Package management functions

# === Package management functions ===

# Check if a package is installed on the system
# Returns: 0 if package is installed, 1 if not installed or unsupported package manager
# Uses the appropriate package manager command based on system detection
# Arguments:
#   $1 - Package name to check
# Example: is_package_installed "curl" && echo "curl is installed"
is_package_installed() {
  local package="$1"
  local pkg_mgr=$(detect_package_manager)
  
  case "$pkg_mgr" in
    apt) dpkg -s "$package" >/dev/null 2>&1 ;;
    dnf) rpm -q "$package" >/dev/null 2>&1 ;;
    apk) apk info -e "$package" >/dev/null 2>&1 ;;
    pacman) pacman -Q "$package" >/dev/null 2>&1 ;;
    *) return 1 ;;
  esac
}

# Install a package using the appropriate package manager
# Installs silently unless VERBOSE is true, respects VERBOSE environment variable
# Exits with fatal_error if package manager is unsupported
# Arguments:
#   $1 - Package name to install
# Example: install_package "curl"
install_package() {
  local package="$1"
  local pkg_mgr=$(detect_package_manager)
  
  case "$pkg_mgr" in
    apt)
      export DEBIAN_FRONTEND=noninteractive
      if [[ "${VERBOSE:-false}" == "true" ]]; then
        apt-get install -y "$package"
      else
        apt-get install -y "$package" >/dev/null 2>&1
      fi
      ;;
    dnf)
      if [[ "${VERBOSE:-false}" == "true" ]]; then
        dnf install -y "$package"
      else
        dnf install -y "$package" >/dev/null 2>&1
      fi
      ;;
    apk)
      if [[ "${VERBOSE:-false}" == "true" ]]; then
        apk add "$package"
      else
        apk add "$package" >/dev/null 2>&1
      fi
      ;;
    pacman)
      if [[ "${VERBOSE:-false}" == "true" ]]; then
        pacman -S --noconfirm "$package"
      else
        pacman -S --noconfirm "$package" >/dev/null 2>&1
      fi
      ;;
    *)
      fatal_error "Unsupported package manager for installing $package"
      ;;
  esac
  
  echo "🔹  Installing: $package"
}
