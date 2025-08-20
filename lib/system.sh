#!/bin/bash
# system.sh - System detection and information functions

# === System detection functions ===

# Detect operating system information
# Returns: "os_id|os_like" format from /etc/os-release
# Example output: "ubuntu|debian" or "alpine|"
# Arguments: None
detect_os() {
  local os_id=""
  local os_like=""
  
  if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    os_id="${ID:-}"
    os_like="${ID_LIKE:-}"
  fi
  
  echo "${os_id}|${os_like}"
}

# Detect the system's package manager
# Returns: Package manager name (apt, dnf, apk, pacman, or unknown)
# Uses OS detection and command availability to determine the appropriate package manager
# Arguments: None
detect_package_manager() {
  local os_info
  os_info=$(detect_os)
  local os_id="${os_info%%|*}"
  local os_like="${os_info#*|}"
  
  if [[ "$os_id" =~ (debian|ubuntu) ]] || [[ "$os_like" =~ (debian|ubuntu) ]]; then
    echo "apt"
  elif command -v dnf >/dev/null 2>&1; then
    echo "dnf"
  elif [[ -f /etc/alpine-release ]]; then
    echo "apk"
  elif command -v pacman >/dev/null 2>&1; then
    echo "pacman"
  else
    echo "unknown"
  fi
}

# Get human-readable distribution name
# Returns: Friendly distribution name based on package manager
# Example: "Debian/Ubuntu", "RHEL/Fedora", "Alpine", "Arch", "Unknown"
# Arguments: None
get_distro_name() {
  local pkg_mgr=$(detect_package_manager)
  case "$pkg_mgr" in
    apt) echo "Debian/Ubuntu" ;;
    dnf) echo "RHEL/Fedora" ;;
    apk) echo "Alpine" ;;
    pacman) echo "Arch" ;;
    *) echo "Unknown" ;;
  esac
}

# === Container/system info functions ===

# Detect container ID if running inside an LXC container
# Returns: Container ID number or "unknown" if not detectable
# Checks /proc/1/cgroup for LXC info, falls back to hostname if numeric
# Arguments: None
get_container_id() {
  # Try to detect if we're in a container and get its ID
  local container_id=""
  
  # Check for systemd container environment
  if [[ -f /proc/1/cgroup ]]; then
    container_id=$(grep -o 'lxc/[0-9]*' /proc/1/cgroup 2>/dev/null | cut -d/ -f2)
  fi
  
  # Fallback to hostname if it's numeric (common in LXC)
  if [[ -z "$container_id" ]]; then
    local hostname=$(hostname)
    if is_numeric "$hostname"; then
      container_id="$hostname"
    fi
  fi
  
  echo "${container_id:-unknown}"
}

# Get comprehensive system information
# Returns: Multi-line system information including hostname, OS, kernel, etc.
# Displays: Hostname, OS, Kernel, Architecture, Primary IP, Container ID
# Arguments: None
get_system_info() {
  echo "Hostname: $(hostname)"
  echo "OS: $(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || echo 'Unknown')"
  echo "Kernel: $(uname -r)"
  echo "Architecture: $(uname -m)"
  echo "Primary IP: $(get_primary_ip)"
  echo "Container ID: $(get_container_id)"
}

# === Performance and monitoring ===

# Get current memory usage information
# Returns: "used/total" format (e.g., "2.1G/8.0G") or "unknown" if unavailable
# Uses the 'free' command with human-readable output
# Arguments: None
get_memory_usage() {
  if command -v free >/dev/null 2>&1; then
    free -h | grep Mem | awk '{print $3 "/" $2}'
  else
    echo "unknown"
  fi
}

# Get disk usage for a specified path
# Returns: "used/total (percentage used)" format or "unknown" if unavailable
# Arguments:
#   $1 - Path to check (optional, defaults to "/")
# Example: get_disk_usage "/var" returns "5.2G/20G (26% used)"
get_disk_usage() {
  local path="${1:-/}"
  if command -v df >/dev/null 2>&1; then
    df -h "$path" | tail -n 1 | awk '{print $3 "/" $2 " (" $5 " used)"}'
  else
    echo "unknown"
  fi
}

# Get system load averages
# Returns: "1min 5min 15min" load averages or "unknown" if unavailable
# Reads from /proc/loadavg which shows load over 1, 5, and 15 minute intervals
# Arguments: None
get_load_average() {
  if [[ -f /proc/loadavg ]]; then
    awk '{print $1, $2, $3}' /proc/loadavg
  else
    echo "unknown"
  fi
}
