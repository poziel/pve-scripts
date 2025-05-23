#!/bin/bash
set -e
clear

# === Config ===
USERNAME="admin"
PASSWORD_FILE="/root/${USERNAME}_password.txt"
SHARED_NAME="shared.sh"
SHARED_URL="https://raw.githubusercontent.com/poziel/pve-script/main/$SHARED_NAME"
CURRENT_HOSTNAME=$(hostname)
COMMON_TOOLS=(curl wget nano vim git unzip htop net-tools gnupg lsb-release ca-certificates software-properties-common ufw vsftpd)
SSHD_CONFIG="/etc/ssh/sshd_config"

# === Keep step did in memory ===
DID_SET_HOSTNAME=false
DID_INSTALL_TOOLS=false
DID_CREATE_USER=false
DID_CONFIGURE_SSH=false
DID_CONFIGURE_FTP=false

# === Fetch and source shared.sh from GitHub ===
if [ -f "./shared.sh" ]; then
  source ./shared.sh
else
  SHARED_URL="https://raw.githubusercontent.com/poziel/pve-script/main/shared.sh"
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
read -rp "🖥️  Enter the hostname for this machine: " NEW_HOSTNAME

if [ "$NEW_HOSTNAME" == "$CURRENT_HOSTNAME" ]; then
  log_success "Hostname already set to '$NEW_HOSTNAME'. No changes needed."
elif ask_to_proceed "hostname"; then
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

# === Step 2: System update ===
log_step "🔄" "Checking for system updates..."
apt update -y > /dev/null 2>&1
apt full-upgrade -y > /dev/null 2>&1
apt autoremove -y > /dev/null 2>&1
apt clean -y > /dev/null 2>&1
apt autoclean -y > /dev/null 2>&1
log_success "System updated."

# === Step 3: Install common tools ===
log_step "🔧" "Checking and installing essential tools..."
if ask_to_proceed "the essential tools"; then
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
fi

# === Step 4: Create admin user ===
if id "$USERNAME" &>/dev/null; then
  log_success "User '$USERNAME' already exists."
elif ask_to_proceed "admin user"; then
  log_step "👤" "Creating user '$USERNAME'..."
  PASSWORD=$(openssl rand -base64 16)
  useradd -m -G sudo -s /bin/bash "$USERNAME"
  echo "${USERNAME}:${PASSWORD}" | chpasswd
  echo "$PASSWORD" > "$PASSWORD_FILE"
  chmod 600 "$PASSWORD_FILE"
  DID_CREATE_USER=true
  log_success "User '$USERNAME' created with sudo access."
fi

# === Step 5: Configure SSH ===

# Apply config only if needed
if grep -q '^PermitRootLogin no' "$SSHD_CONFIG" && grep -q '^PasswordAuthentication yes' "$SSHD_CONFIG"; then
  log_success "SSH is already configured properly."
elif ask_to_proceed "SSH"; then

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
fi


# === Step 6: Configure FTP (vsftpd) ===
if systemctl is-active vsftpd &>/dev/null; then
  log_success "FTP server (vsftpd) is already running."
elif ask_to_proceed "FTP"; then
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
