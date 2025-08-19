#!/bin/bash
set -e
clear

# === Config ===
USERNAME="admin"
PASSWORD_FILE="/root/${USERNAME}_password.txt"
SHARED_NAME="shared.sh"
SHARED_URL="https://raw.githubusercontent.com/poziel/pve-scripts/refs/heads/main/$SHARED_NAME"
CURRENT_HOSTNAME=$(hostname)
COMMON_TOOLS=(curl wget nano vim git unzip htop net-tools gnupg lsb-release ca-certificates software-properties-common ufw vsftpd)
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
  -h, --help           Show this help

Behavior:
  - NO PARAMETERS: Interactive mode - prompts for each step
  - ANY PARAMETER: Uses defaults for unspecified options, arguments toggle opposite of defaults

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

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--hostname) AUTO_HOSTNAME="$2"; INTERACTIVE=false; shift 2;;
    -u|--no-updates) AUTO_UPDATES="no"; INTERACTIVE=false; shift;;    # Toggle: default=yes, flag=no
    -t|--no-tools) AUTO_TOOLS="no"; INTERACTIVE=false; shift;;        # Toggle: default=yes, flag=no
    -U|--no-user) AUTO_USER="no"; INTERACTIVE=false; shift;;          # Toggle: default=yes, flag=no
    -s|--no-ssh) AUTO_SSH="no"; INTERACTIVE=false; shift;;            # Toggle: default=yes, flag=no
    -f|--ftp) AUTO_FTP="yes"; INTERACTIVE=false; shift;;              # Toggle: default=no, flag=yes
    -y|--yes) AUTO_UPDATES="yes"; AUTO_TOOLS="yes"; AUTO_USER="yes"; AUTO_SSH="yes"; AUTO_FTP="yes"; INTERACTIVE=false; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown option: $1"; usage; exit 1;;
  esac
done

# === Apply defaults when parameters are used but specific options not set ===
if [[ "$INTERACTIVE" == "false" ]]; then
  [[ -z "$AUTO_UPDATES" ]] && AUTO_UPDATES="$DEFAULT_UPDATES"
  [[ -z "$AUTO_TOOLS" ]] && AUTO_TOOLS="$DEFAULT_TOOLS"
  [[ -z "$AUTO_USER" ]] && AUTO_USER="$DEFAULT_USER"
  [[ -z "$AUTO_SSH" ]] && AUTO_SSH="$DEFAULT_SSH"
  [[ -z "$AUTO_FTP" ]] && AUTO_FTP="$DEFAULT_FTP"
fi

# === Fetch and source shared.sh from GitHub ===
if [ -f "./$SHARED_NAME" ]; then
  source "./$SHARED_NAME"
else
  source <(wget -qO- "$SHARED_URL")
fi

# === Show the title ===
print_title "PVE bootstrap script"

# === MUST BE SUDO ===
if [ "$(id -u)" -ne 0 ]; then
  fatal_error "This script must be run as root. Try again with: sudo ./bootstrap.sh"
  exit 1
fi

# === Step 1: Set hostname and update /etc/hosts ===
if [[ -n "$AUTO_HOSTNAME" ]]; then
  NEW_HOSTNAME="$AUTO_HOSTNAME"
  echo "🖥️  Using hostname: $NEW_HOSTNAME"
else
  read -rp "🖥️  Enter the hostname for this machine: " NEW_HOSTNAME
fi

if [ "$NEW_HOSTNAME" == "$CURRENT_HOSTNAME" ]; then
  log_success "Hostname already set to '$NEW_HOSTNAME'. No changes needed."
else
  # Determine if we should proceed
  PROCEED=false
  if [[ -n "$AUTO_HOSTNAME" ]]; then
    PROCEED=true
  elif ask_to_proceed "hostname"; then
    PROCEED=true
  fi

  if [[ "$PROCEED" == "true" ]]; then
    log_step "🔧" "Updating hostname to '$NEW_HOSTNAME'..."
    hostnamectl set-hostname "$NEW_HOSTNAME"

    # Check if 127.0.1.1 line exists
    if grep -q "^127.0.1.1" /etc/hosts; then
      # Replace old hostname
      sed -i "s/^127.0.1.1.*/127.0.1.1       $NEW_HOSTNAME/" /etc/hosts
    else
      # Add new hostname line
      echo "127.0.1.1       $NEW_HOSTNAME" >> /etc/hosts
    fi

    DID_SET_HOSTNAME=true
    log_success "Hostname set to '$NEW_HOSTNAME' and /etc/hosts updated."
  fi
fi

# === Step 2: System update ===
PROCEED=false
if [[ "$AUTO_UPDATES" == "yes" ]]; then
  PROCEED=true
elif [[ "$AUTO_UPDATES" == "no" ]]; then
  PROCEED=false
elif ask_to_proceed "system updates (apt update, upgrade, cleanup)"; then
  PROCEED=true
fi

if [[ "$PROCEED" == "true" ]]; then
  log_step "🔄" "Updating system packages..."
  apt update -y > /dev/null 2>&1
  apt full-upgrade -y > /dev/null 2>&1
  apt autoremove -y > /dev/null 2>&1
  apt clean -y > /dev/null 2>&1
  apt autoclean -y > /dev/null 2>&1
  log_success "System updated."
else
  log_step "⏭️" "Skipping system updates."
fi

# === Step 3: Install common tools ===
PROCEED=false
if [[ "$AUTO_TOOLS" == "yes" ]]; then
  PROCEED=true
elif [[ "$AUTO_TOOLS" == "no" ]]; then
  PROCEED=false
elif ask_to_proceed "the essential tools installation"; then
  PROCEED=true
fi

if [[ "$PROCEED" == "true" ]]; then
  log_step "🔧" "Installing essential tools..."
  for pkg in "${COMMON_TOOLS[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
      echo "🔹  Installing: $pkg"
      apt install -y "$pkg" > /dev/null
    else
      echo "✔️  $pkg already installed"
    fi
  done
  DID_INSTALL_TOOLS=true
  log_success "Essential tools installation complete."
else
  log_step "⏭️" "Skipping essential tools installation."
fi

# === Step 4: Create admin user ===
if id "$USERNAME" &>/dev/null; then
  log_success "User '$USERNAME' already exists."
else
  PROCEED=false
  if [[ "$AUTO_USER" == "yes" ]]; then
    PROCEED=true
  elif [[ "$AUTO_USER" == "no" ]]; then
    PROCEED=false
  elif ask_to_proceed "admin user creation"; then
    PROCEED=true
  fi

  if [[ "$PROCEED" == "true" ]]; then
    log_step "👤" "Creating user '$USERNAME'..."
    PASSWORD=$(openssl rand -base64 16)
    useradd -m -G sudo -s /bin/bash "$USERNAME"
    echo "${USERNAME}:${PASSWORD}" | chpasswd
    echo "$PASSWORD" > "$PASSWORD_FILE"
    chmod 600 "$PASSWORD_FILE"
    DID_CREATE_USER=true
    log_success "User '$USERNAME' created with sudo access."
  else
    log_step "⏭️" "Skipping admin user creation."
  fi
fi

# === Step 5: Configure SSH ===

# Apply config only if needed
if grep -q '^PermitRootLogin no' "$SSHD_CONFIG" && grep -q '^PasswordAuthentication yes' "$SSHD_CONFIG"; then
  log_success "SSH is already configured properly."
else
  PROCEED=false
  if [[ "$AUTO_SSH" == "yes" ]]; then
    PROCEED=true
  elif [[ "$AUTO_SSH" == "no" ]]; then
    PROCEED=false
  elif ask_to_proceed "SSH configuration"; then
    PROCEED=true
  fi

  if [[ "$PROCEED" == "true" ]]; then
    # Install SSH server if missing
    if ! dpkg -s openssh-server >/dev/null 2>&1; then
      echo "📦  Installing OpenSSH server..."
      apt install -y openssh-server > /dev/null 2>&1
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
fi


# === Step 6: Configure FTP (vsftpd) ===
if systemctl is-active vsftpd &>/dev/null; then
  log_success "FTP server (vsftpd) is already running."
else
  PROCEED=false
  if [[ "$AUTO_FTP" == "yes" ]]; then
    PROCEED=true
  elif [[ "$AUTO_FTP" == "no" ]]; then
    PROCEED=false
  elif ask_to_proceed "FTP server configuration"; then
    PROCEED=true
  fi

  if [[ "$PROCEED" == "true" ]]; then
    echo "🌐  Configuring FTP with vsftpd..."
    cp /etc/vsftpd.conf /etc/vsftpd.conf.bak
    sed -i 's/^#write_enable=YES/write_enable=YES/' /etc/vsftpd.conf
    sed -i 's/^#local_umask=022/local_umask=022/' /etc/vsftpd.conf
    sed -i 's/^#chroot_local_user=YES/chroot_local_user=YES/' /etc/vsftpd.conf
    echo "user_sub_token=$USERNAME" >> /etc/vsftpd.conf
    echo "local_root=/home/$USERNAME" >> /etc/vsftpd.conf
    systemctl enable vsftpd
    systemctl restart vsftpd
    DID_CONFIGURE_FTP=true
    log_success "FTP server configured and started."
  else
    log_step "⏭️" "Skipping FTP server configuration."
  fi
fi

# === Final Summary ===
IP=$(hostname -I | awk '{print $1}')
echo ""
echo "🎉  Initialization Complete!"
if [ "$DID_SET_HOSTNAME" = true ]; then
  echo "🖥️  Hostname       : $(hostname)"
fi
if [ "$DID_CREATE_USER" = true ]; then
  echo "👤 Admin user     : $USERNAME"
  echo "🔐 Password saved : $PASSWORD_FILE"
fi
if [ "$DID_CONFIGURE_SSH" = true ]; then
  echo "🌍 SSH access     : ssh $USERNAME@$IP"
fi
if [ "$DID_CONFIGURE_FTP" = true ]; then
  echo "🌐 FTP access     : ftp://$IP"
fi
echo ""
