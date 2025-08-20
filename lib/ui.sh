#!/bin/bash
# ui.sh - User interface and logging functions

# === UI Functions ===

# Create a line break with specified character and length
# Arguments:
#   $1 - Character to use for line (optional, defaults to "-")
#   $2 - Length of line (optional, defaults to 80)
# Example: linebreak "=" 50 creates "=================================================="
linebreak() {
  local char="${1:-'-'}"
  local length="${2:-80}"

  # Use printf with seq for dynamic repetition
  printf -- "${char}%.0s" $(seq 1 "$length")
  echo
}

# Display the main PVE Scripts ASCII banner with title
# Shows the PVE Scripts logo and a customizable welcome message
# Arguments:
#   $1 - Title text (optional, defaults to "PVE script")
# Example: print_title "Container Bootstrap" shows custom title
print_title() {
  local title="${1:-PVE script}"
  local longtitle="🚀  Welcome to the $title – Automated container/VM provisioning for Proxmox"
  local underline=$(linebreak "─" 100)

  echo -e "
    
██████╗ ██╗   ██╗███████╗                           
██╔══██╗██║   ██║██╔════╝                           
██████╔╝██║   ██║█████╗                             
██╔═══╝ ╚██╗ ██╔╝██╔══╝                             
██║      ╚████╔╝ ███████╗                           
╚═╝       ╚═══╝  ╚══════╝                           
                                                    
███████╗ ██████╗██████╗ ██╗██████╗ ████████╗███████╗
██╔════╝██╔════╝██╔══██╗██║██╔══██╗╚══██╔══╝██╔════╝
███████╗██║     ██████╔╝██║██████╔╝   ██║   ███████╗
╚════██║██║     ██╔══██╗██║██╔═══╝    ██║   ╚════██║
███████║╚██████╗██║  ██║██║██║        ██║   ███████║
╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝╚═╝        ╚═╝   ╚══════╝

$longtitle
$underline
"
}

# === Interactive functions ===

# Ask user if they want to proceed with a specific configuration step
# Returns: 0 if user confirms (y/Y), 1 if user declines or no response
# Displays a warning message if user skips the step
# Arguments:
#   $1 - Name of the configuration step
# Example: ask_to_proceed "SSH configuration"
ask_to_proceed() {
  local step_name="$1"
  read -rp "❓  Do you want to configure $step_name? [y/N]: " CONFIRM
  if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    return 0  # Yes
  else
    log_warn "Skipped $step_name setup."
    return 1  # No
  fi
}

# Ask a yes/no question with customizable default answer
# Returns: 0 if user confirms (y/Y), 1 if user declines (n/N)
# Arguments:
#   $1 - Question text to display
#   $2 - Default answer (optional, defaults to "N")
# Example: ask_yes_no "Enable debug mode?" "Y"
ask_yes_no() {
  local question="$1"
  local default="${2:-N}"
  local prompt="[y/N]"
  
  if [[ "$default" =~ ^[Yy]$ ]]; then
    prompt="[Y/n]"
  fi
  
  read -rp "❓  $question $prompt: " response
  
  # Use default if no response
  if [[ -z "$response" ]]; then
    response="$default"
  fi
  
  [[ "$response" =~ ^[Yy]$ ]]
}
