#!/bin/bash
# ct-bootstrap.sh — Bootstrap configuration for the current LXC container.
# This script runs INSIDE a container, not on the Proxmox host.
# Configures hostname, updates, tools, users, SSH, and FTP within the container.
# Usage:
#   ./ct-bootstrap.sh                   # bootstrap current container interactively
#   ./ct-bootstrap.sh -n web1           # set hostname to web1, use defaults
#   ./ct-bootstrap.sh -t -U             # skip tools and user creation
set -e

# === Config ===
USERNAME="admin"
PASSWORD_FILE="/root/${USERNAME}_password.txt"
UPDATE_SCRIPT_URL="https://raw.githubusercontent.com/poziel/pve-scripts/refs/heads/main/ct-scripts/ct-update.sh"
TOOLS_SCRIPT_URL="https://raw.githubusercontent.com/poziel/pve-scripts/refs/heads/main/ct-scripts/ct-tools.sh"
SSHD_CONFIG="/etc/ssh/sshd_config"

# === Default values when parameters are passed (configurable) ===
DEFAULT_UPDATES="yes"       # "yes" or "no" - enable system updates by default
DEFAULT_TOOLS="yes"         # "yes" or "no" - install essential tools by default
DEFAULT_USER="yes"          # "yes" or "no" - create admin user by default
DEFAULT_SSH="yes"           # "yes" or "no" - configure SSH by default
DEFAULT_FTP="no"            # "yes" or "no" - configure FTP by default

# === Command line options ===
AUTO_HOSTNAME=""
AUTO_UPDATES=""
AUTO_TOOLS=""
AUTO_USER=""
AUTO_SSH=""
AUTO_FTP=""
INTERACTIVE=true
MULTIPLE_MODE=false  # When true, suppress big title display
VERBOSE=false        # When true, show detailed information
SILENT=false         # When true, suppress all output

# === Keep step did in memory ===
DID_SET_HOSTNAME=false
DID_INSTALL_TOOLS=false
DID_CREATE_USER=false
DID_CONFIGURE_SSH=false
DID_CONFIGURE_FTP=false

# === Parse command line arguments ===
usage() {
  cat <<EOF
Usage: $(basename "$0") [options]
  -n, --hostname NAME  Set hostname to NAME (skips prompt)
  -u, --no-updates     Skip system updates (default: enabled)
  -t, --no-tools       Skip essential tools installation (default: enabled)
  -U, --no-user        Skip admin user creation (default: enabled)
  -s, --no-ssh         Skip SSH configuration (default: enabled)
  -f, --ftp            Enable FTP server configuration (default: disabled)
  -y, --yes            Enable all components (overrides other flags)
  -M, --multiple       Multiple execution mode (suppress title display)
  -V, --verbose        Show detailed information during bootstrap
  -S, --silent         Suppress all output (silent mode)
  -h, --help           Show this help

Behavior:
  - NO PARAMETERS: Interactive mode - prompts for each step
  - ANY PARAMETER: Uses defaults for unspecified options, arguments toggle opposite of defaults

This script runs inside a container to bootstrap its configuration.
Use ct-executor.sh to run this across multiple containers.

Current defaults when parameters are used:
  - Updates: $DEFAULT_UPDATES (use -u/--no-updates to skip)
  - Tools: $DEFAULT_TOOLS (use -t/--no-tools to skip)
  - User: $DEFAULT_USER (use -U/--no-user to skip)
  - SSH: $DEFAULT_SSH (use -s/--no-ssh to skip)  
  - FTP: $DEFAULT_FTP (use -f/--ftp to enable)

Examples:
  $(basename "$0")                     # Interactive mode (asks for each step)
  $(basename "$0") -n myserver         # Set hostname, use all defaults
  $(basename "$0") -t -U               # Skip tools and user creation
  $(basename "$0") -f                  # Enable FTP, use other defaults
  $(basename "$0") -n web1 -u -t -s    # Set hostname, skip updates/tools/SSH
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--hostname) AUTO_HOSTNAME="$2"; INTERACTIVE=false; shift 2;;
    -u|--no-updates) AUTO_UPDATES="no"; INTERACTIVE=false; shift;;    # Toggle: default=yes, flag=no
    -t|--no-tools) AUTO_TOOLS="no"; INTERACTIVE=false; shift;;        # Toggle: default=yes, flag=no
    -U|--no-user) AUTO_USER="no"; INTERACTIVE=false; shift;;          # Toggle: default=yes, flag=no
    -s|--no-ssh) AUTO_SSH="no"; INTERACTIVE=false; shift;;            # Toggle: default=yes, flag=no
    -f|--ftp) AUTO_FTP="yes"; INTERACTIVE=false; shift;;              # Toggle: default=no, flag=yes
    -y|--yes) AUTO_UPDATES="yes"; AUTO_TOOLS="yes"; AUTO_USER="yes"; AUTO_SSH="yes"; AUTO_FTP="yes"; INTERACTIVE=false; shift;;
    -M|--multiple) MULTIPLE_MODE=true; shift;;                        # Multiple execution mode
    -V|--verbose) VERBOSE=true; shift;;                               # Verbose mode
    -S|--silent) SILENT=true; shift;;                                 # Silent mode
    -h|--help) usage; exit 0;;
    *) echo "Unknown option: $1"; usage; exit 1;;
  esac
done

# Silent mode overrides verbose and multiple mode
if [[ "$SILENT" == "true" ]]; then
  VERBOSE=false
  MULTIPLE_MODE=true  # Silent implies no title
  exec 1>/dev/null 2>/dev/null
fi

# === Apply defaults when parameters are used but specific options not set ===
if [[ "$INTERACTIVE" == "false" ]]; then
  [[ -z "$AUTO_UPDATES" ]] && AUTO_UPDATES="$DEFAULT_UPDATES"
  [[ -z "$AUTO_TOOLS" ]] && AUTO_TOOLS="$DEFAULT_TOOLS"
  [[ -z "$AUTO_USER" ]] && AUTO_USER="$DEFAULT_USER"
  [[ -z "$AUTO_SSH" ]] && AUTO_SSH="$DEFAULT_SSH"
  [[ -z "$AUTO_FTP" ]] && AUTO_FTP="$DEFAULT_FTP"
fi

# === Load core library ---
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
use_lib "ui"         # For print_title and banners
use_lib "validation" # For ask_to_proceed and validation functions
use_lib "system"     # For system detection and package management
use_lib "packages"   # For package installation functions

# === Bootstrap Functions ===

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

# Function to set hostname and update /etc/hosts
bootstrap_hostname() {
  local current_hostname=$(hostname)
  local new_hostname

  if [[ -n "$AUTO_HOSTNAME" ]]; then
    new_hostname="$AUTO_HOSTNAME"
    if [[ "$VERBOSE" == "true" ]]; then
      safe_echo "🖥️  Using hostname: $new_hostname"
    fi
  else
    read -rp "🖥️  Enter the hostname for this container [$current_hostname]: " new_hostname
    [[ -z "$new_hostname" ]] && new_hostname="$current_hostname"
  fi

  if [ "$new_hostname" == "$current_hostname" ]; then
    safe_log log_success "Hostname already set to '$new_hostname'. No changes needed."
    return 0
  fi

  # Determine if we should proceed
  local proceed=false
  if [[ -n "$AUTO_HOSTNAME" ]]; then
    proceed=true
  elif ask_to_proceed "hostname" "Y"; then
    proceed=true
  fi

  if [[ "$proceed" == "true" ]]; then
    safe_log log_step "🔧" "Updating hostname to '$new_hostname'..."
    if [[ "$VERBOSE" == "true" ]]; then
      safe_echo "  Executing: hostnamectl set-hostname '$new_hostname'"
    fi
    hostnamectl set-hostname "$new_hostname"

    # Update /etc/hosts
    if [[ "$VERBOSE" == "true" ]]; then
      safe_echo "  Updating /etc/hosts file..."
    fi
    if grep -q "^127.0.1.1" /etc/hosts; then
      sed -i "s/^127.0.1.1.*/127.0.1.1       $new_hostname/" /etc/hosts
    else
      echo "127.0.1.1       $new_hostname" >> /etc/hosts
    fi

    DID_SET_HOSTNAME=true
    safe_log log_success "Hostname set to '$new_hostname' and /etc/hosts updated."
  fi
}

# Function to perform system updates
bootstrap_updates() {
  local proceed=false
  if [[ "$AUTO_UPDATES" == "yes" ]]; then
    proceed=true
  elif [[ "$AUTO_UPDATES" == "no" ]]; then
    proceed=false
  elif ask_to_proceed "system updates" "${DEFAULT_UPDATES:0:1}"; then
    proceed=true
  fi

  if [[ "$proceed" == "true" ]]; then
    log_step "🔄" "Updating system packages using ct-update.sh..."
    
    # Download and execute ct-update.sh
    local update_downloaded=false
    if command -v wget >/dev/null 2>&1; then
      if wget -qO /tmp/ct-update.sh "$UPDATE_SCRIPT_URL"; then
        update_downloaded=true
      fi
    elif command -v curl >/dev/null 2>&1; then
      if curl -fsSL "$UPDATE_SCRIPT_URL" -o /tmp/ct-update.sh; then
        update_downloaded=true
      fi
    else
      fatal_error "Neither wget nor curl available to download ct-update.sh"
    fi
    
    if [[ "$update_downloaded" == "true" ]]; then
      chmod +x /tmp/ct-update.sh
      
      # Build arguments to pass to ct-update.sh
      local update_args="--multiple"
      if [[ "$VERBOSE" == "true" ]]; then
        update_args="$update_args --verbose"
      elif [[ "$SILENT" == "true" ]]; then
        update_args="$update_args --silent"
      fi
      
      if /tmp/ct-update.sh $update_args; then
        log_success "System updated successfully."
      else
        fatal_error "System update failed"
      fi
      rm -f /tmp/ct-update.sh
    else
      fatal_error "Could not download ct-update.sh from $UPDATE_SCRIPT_URL"
    fi
  else
    log_step "⏭️" "Skipping system updates."
  fi
}

# Function to install essential tools
bootstrap_tools() {
  local proceed=false
  if [[ "$AUTO_TOOLS" == "yes" ]]; then
    proceed=true
  elif [[ "$AUTO_TOOLS" == "no" ]]; then
    proceed=false
  elif ask_to_proceed "the essential tools installation" "${DEFAULT_TOOLS:0:1}"; then
    proceed=true
  fi

  if [[ "$proceed" == "true" ]]; then
    log_step "🔧" "Installing essential tools using ct-tools.sh..."
    
    # Download and execute ct-tools.sh
    local tools_downloaded=false
    if command -v wget >/dev/null 2>&1; then
      if wget -qO /tmp/ct-tools.sh "$TOOLS_SCRIPT_URL"; then
        tools_downloaded=true
      fi
    elif command -v curl >/dev/null 2>&1; then
      if curl -fsSL "$TOOLS_SCRIPT_URL" -o /tmp/ct-tools.sh; then
        tools_downloaded=true
      fi
    else
      fatal_error "Neither wget nor curl available to download ct-tools.sh"
    fi
    
    if [[ "$tools_downloaded" == "true" ]]; then
      chmod +x /tmp/ct-tools.sh
      
      # Build arguments to pass to ct-tools.sh
      local tools_args="--multiple"
      if [[ "$VERBOSE" == "true" ]]; then
        tools_args="$tools_args --verbose"
      elif [[ "$SILENT" == "true" ]]; then
        tools_args="$tools_args --silent"
      fi
      
      if /tmp/ct-tools.sh $tools_args; then
        DID_INSTALL_TOOLS=true
        log_success "Essential tools installed successfully."
      else
        fatal_error "Essential tools installation failed"
      fi
      rm -f /tmp/ct-tools.sh
    else
      fatal_error "Could not download ct-tools.sh from $TOOLS_SCRIPT_URL"
    fi
  else
    log_step "⏭️" "Skipping essential tools installation."
  fi
}

# Function to create admin user
bootstrap_user() {
  if id "$USERNAME" &>/dev/null; then
    log_success "User '$USERNAME' already exists."
    return 0
  fi

  local proceed=false
  if [[ "$AUTO_USER" == "yes" ]]; then
    proceed=true
  elif [[ "$AUTO_USER" == "no" ]]; then
    proceed=false
  elif ask_to_proceed "admin user creation" "${DEFAULT_USER:0:1}"; then
    proceed=true
  fi

  if [[ "$proceed" == "true" ]]; then
    log_step "👤" "Creating user '$USERNAME'..."
    local password=$(openssl rand -base64 16)
    useradd -m -G sudo -s /bin/bash "$USERNAME"
    echo "${USERNAME}:${password}" | chpasswd
    echo "$password" > "$PASSWORD_FILE"
    chmod 600 "$PASSWORD_FILE"
    DID_CREATE_USER=true
    log_success "User '$USERNAME' created with sudo access."
  else
    log_step "⏭️" "Skipping admin user creation."
  fi
}

# Function to configure SSH
bootstrap_ssh() {
  # Check if SSH is properly configured
  local ssh_configured=false
  if grep -q '^PermitRootLogin no' "$SSHD_CONFIG" && grep -q '^PasswordAuthentication yes' "$SSHD_CONFIG"; then
    ssh_configured=true
  fi

  if [[ "$ssh_configured" == "true" ]]; then
    log_success "SSH is already configured properly."
    return 0
  fi

  local proceed=false
  if [[ "$AUTO_SSH" == "yes" ]]; then
    proceed=true
  elif [[ "$AUTO_SSH" == "no" ]]; then
    proceed=false
  elif ask_to_proceed "SSH configuration" "${DEFAULT_SSH:0:1}"; then
    proceed=true
  fi

  if [[ "$proceed" == "true" ]]; then
    # Install SSH server if missing
    if ! dpkg -s openssh-server >/dev/null 2>&1; then
      if [[ "$VERBOSE" == "true" ]]; then
        safe_echo "📦  Installing OpenSSH server..."
      fi
      export DEBIAN_FRONTEND=noninteractive
      if [[ "$VERBOSE" == "true" ]]; then
        apt-get install -y openssh-server
      else
        apt-get install -y openssh-server >/dev/null 2>&1
      fi
    fi

    # Configure SSH permissions
    echo "🔐  Configuring SSH..."
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG"
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' "$SSHD_CONFIG"

    # Start & enable SSH if needed
    if ! systemctl is-active ssh >/dev/null; then
      echo "🔌  Starting SSH service..."
      systemctl enable ssh > /dev/null 2>&1
      systemctl start ssh
    fi

    # Reload if active
    if systemctl is-active ssh >/dev/null; then
      echo "🔁  Reloading SSH service..."
      systemctl reload ssh
      log_success "SSH configuration updated and service reloaded."
    else
      log_warn "SSH service is not active and could not be reloaded."
    fi
    DID_CONFIGURE_SSH=true
  else
    log_step "⏭️" "Skipping SSH configuration."
  fi
}

# Function to configure FTP server
bootstrap_ftp() {
  if systemctl is-active vsftpd &>/dev/null; then
    log_success "FTP server (vsftpd) is already running."
    return 0
  fi

  local proceed=false
  if [[ "$AUTO_FTP" == "yes" ]]; then
    proceed=true
  elif [[ "$AUTO_FTP" == "no" ]]; then
    proceed=false
  elif ask_to_proceed "FTP server configuration" "${DEFAULT_FTP:0:1}"; then
    proceed=true
  fi

  if [[ "$proceed" == "true" ]]; then
    safe_log log_step "🌐" "Installing and configuring FTP with vsftpd..."
    
    # Install vsftpd if not already installed
    if ! dpkg -s vsftpd >/dev/null 2>&1; then
      if [[ "$VERBOSE" == "true" ]]; then
        safe_echo "📦  Installing vsftpd package..."
      fi
      export DEBIAN_FRONTEND=noninteractive
      if [[ "$VERBOSE" == "true" ]]; then
        apt-get update -qq
        apt-get install -y vsftpd
      else
        apt-get update -qq >/dev/null 2>&1
        apt-get install -y vsftpd >/dev/null 2>&1
      fi
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
      safe_echo "🔧  Configuring vsftpd..."
    fi
    
    # Backup original config if it exists
    if [[ -f /etc/vsftpd.conf ]]; then
      cp /etc/vsftpd.conf /etc/vsftpd.conf.bak
    fi
    
    # Configure vsftpd
    sed -i 's/^#write_enable=YES/write_enable=YES/' /etc/vsftpd.conf
    sed -i 's/^#local_umask=022/local_umask=022/' /etc/vsftpd.conf
    sed -i 's/^#chroot_local_user=YES/chroot_local_user=YES/' /etc/vsftpd.conf
    echo "user_sub_token=$USERNAME" >> /etc/vsftpd.conf
    echo "local_root=/home/$USERNAME" >> /etc/vsftpd.conf
    
    if [[ "$VERBOSE" == "true" ]]; then
      safe_echo "🚀  Starting vsftpd service..."
    fi
    systemctl enable vsftpd > /dev/null 2>&1
    systemctl restart vsftpd
    DID_CONFIGURE_FTP=true
    safe_log log_success "FTP server configured and started."
  else
    log_step "⏭️" "Skipping FTP server configuration."
  fi
}

# Function to display final summary
bootstrap_summary() {
  local ct_ip=$(hostname -I | awk '{print $1}')
  echo ""
  echo "🎉  Container $(hostname) Initialization Complete!"
  if [ "$DID_SET_HOSTNAME" = true ]; then
    echo "🖥️  Hostname       : $(hostname)"
  fi
  if [ "$DID_CREATE_USER" = true ]; then
    echo "👤 Admin user     : $USERNAME"
    echo "🔐 Password saved : $PASSWORD_FILE"
  fi
  if [ "$DID_CONFIGURE_SSH" = true ]; then
    echo "🌍 SSH access     : ssh $USERNAME@$ct_ip"
  fi
  if [ "$DID_CONFIGURE_FTP" = true ]; then
    echo "🌐 FTP access     : ftp://$ct_ip"
  fi
  echo ""
}

# Main bootstrap function
main() {
  # === Verify we're in a container (not Proxmox host) ===
  if [[ "$(id -u)" -ne 0 ]]; then
    fatal_error "This script must be run as root inside a container."
  fi

  # Check if we're in a container (not on Proxmox host)
  if command -v pct >/dev/null 2>&1; then
    fatal_error "This script should run inside a container, not on the Proxmox host. Use ct-executor.sh instead."
  fi

  # Show title only if not in multiple mode
  if [[ "$MULTIPLE_MODE" == "false" ]]; then
    clear
    print_title "Container Bootstrap - $(hostname)"
  fi

  # Execute bootstrap steps
  bootstrap_hostname
  bootstrap_updates
  bootstrap_tools
  bootstrap_user
  bootstrap_ssh
  bootstrap_ftp
  bootstrap_summary
}

# Run the main bootstrap function
main
