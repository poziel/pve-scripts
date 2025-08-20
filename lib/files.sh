#!/bin/bash
# files.sh - File and system utility functions

# === File and system functions ===

# Create a backup copy of a file with optional suffix
# Creates a copy of the original file with backup suffix appended
# Logs the backup operation using log_info
# Arguments:
#   $1 - Original file path to backup
#   $2 - Backup suffix (optional, defaults to ".bak")
# Example: backup_file "/etc/ssh/sshd_config" ".backup"
backup_file() {
  local file="$1"
  local backup_suffix="${2:-.bak}"
  
  if [[ -f "$file" ]]; then
    cp "$file" "${file}${backup_suffix}"
    log_info "Backed up $file to ${file}${backup_suffix}"
  fi
}

# Download a file from URL using wget or curl
# Attempts wget first, falls back to curl, exits with fatal_error if neither available
# Arguments:
#   $1 - URL to download from
#   $2 - Local output path to save the file
# Example: download_file "https://example.com/script.sh" "/tmp/script.sh"
download_file() {
  local url="$1"
  local output_path="$2"
  
  if command -v wget >/dev/null 2>&1; then
    wget -qO "$output_path" "$url"
  elif command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$output_path"
  else
    fatal_error "Neither wget nor curl available for downloading"
  fi
}

# Get the size of a file in bytes
# Returns: File size in bytes, or "0" if file doesn't exist or stat unavailable
# Uses platform-appropriate stat command (BSD vs GNU)
# Arguments:
#   $1 - File path to check
# Example: SIZE=$(get_file_size "/var/log/syslog")
get_file_size() {
  local file="$1"
  if [[ -f "$file" ]]; then
    stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0"
  else
    echo "0"
  fi
}

# === Exit handlers ===

# Clean up temporary files created by the current script
# Removes temporary files older than 1 day that match the script name pattern
# Uses the current script's basename to identify relevant temp files
# Arguments: None
# Example: cleanup_temp_files (typically called in script exit handler)
cleanup_temp_files() {
  local temp_dir="/tmp"
  local script_name=$(basename "${0}")
  
  # Remove any temporary files created by this script
  find "$temp_dir" -name "${script_name}_*" -type f -mtime +1 -delete 2>/dev/null || true
}
