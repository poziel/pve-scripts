# PVE Scripts – Proxmox Automation & Setup Tools ⚙️🖥️

**PVE Scripts** is a collection of **ready-to-use Bash scripts** that simplify **Proxmox Virtual Environment (PVE)** management by automating essential setup and provisioning tasks.  
These scripts are actively used to prepare new Proxmox nodes, configure core services, and ensure your environment is ready for production.

---

## 📂 Included Scripts

### `bootstrap.sh` – Node Initialization Script
Automates the first-time setup of a Proxmox node or container by:
- **Setting the hostname** and updating `/etc/hosts`.
- **Updating the system** (`apt update`, `upgrade`, cleanup).
- **Installing essential tools**:
  - `curl`, `wget`, `nano`, `vim`, `git`, `unzip`, `htop`, `net-tools`, `gnupg`, `lsb-release`, `ca-certificates`, `software-properties-common`, `ufw`, `vsftpd`.
- **Creating an admin user** with sudo access and a randomly generated password.
- **Configuring SSH**:
  - Disables root login.
  - Enables password authentication.
  - Installs and starts OpenSSH if missing.
- **Configuring FTP (vsftpd)**:
  - Enables write access.
  - Restricts users to their home directory.
  - Sets up FTP root for the admin user.
- **Final summary** showing configured hostname, user credentials path, and connection details.

> The script is **interactive** and asks for confirmation before each major step, allowing you to skip components you don't need.

---

### `ct-update-all.sh` – LXC Container Mass Update Script
Updates packages across all LXC containers on a Proxmox node with support for multiple distributions:
- **Multi-distro support**: Debian/Ubuntu (apt), RHEL/Fedora (dnf), Alpine (apk), Arch (pacman)
- **Flexible execution**: Update running containers only or include stopped ones
- **Parallel processing**: Run multiple updates simultaneously for faster execution
- **Container exclusion**: Skip specific containers by CTID
- **Safety features**: Dry-run mode and confirmation prompts
- **Comprehensive reporting**: Success, skipped, and failed container counts

**Supported options:**
- `--all`: Include stopped containers (skipped if not running during execution)
- `--parallel N`: Run up to N updates in parallel (default: 1)
- `--exclude CTID,CTID`: Exclude specific container IDs
- `--yes`: Skip confirmation prompt
- `--dry-run`: Show what would be executed without running

---

### `shared.sh` – Utility Functions & UI
A shared library providing:
- **Color-coded logging** (`log_step`, `log_success`, `log_warn`, `fatal_error`).
- **Pretty ASCII banner** for script intros.
- **Dynamic line breaks** for formatting.
- **User confirmation prompts** (`ask_to_proceed`).

This script is sourced by other scripts in the collection to keep the UI consistent.

---

## 🛠️ Requirements

- **Proxmox Virtual Environment** (Debian-based host)
- **Root access** (scripts must be run as `root` or with `sudo`)
- **Internet connection** for downloading scripts and package installation
- **wget** (usually pre-installed on Proxmox)

---

## 🚀 Quick Start (Recommended)

**Execute directly from GitHub** - no cloning required:

```bash
# Bootstrap a Proxmox node (interactive mode)
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/bootstrap.sh)

# Bootstrap with specific options (using defaults for others)
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/bootstrap.sh) -n myserver -f

# Update all LXC containers (interactive mode)
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-update-all.sh)

# Update containers with options (using defaults for others)
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-update-all.sh) -a -p 3 -y
```

---

## 💾 Local Installation (Alternative)

If you prefer to clone and run locally:

```bash
# Clone the repository
git clone https://github.com/poziel/pve-scripts.git
cd pve-scripts

# Make scripts executable
chmod +x *.sh
```

---

## 📖 Usage

### Bootstrap a new Proxmox node:

**Direct execution from GitHub (recommended):**
```bash
# Interactive mode - prompts for each option
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/bootstrap.sh)

# Enable all components
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/bootstrap.sh) -y

# Set hostname only, use defaults for others (updates, tools, user, SSH enabled; FTP disabled)
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/bootstrap.sh) -n myserver

# Set hostname and enable FTP, skip tools and user creation
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/bootstrap.sh) --hostname myserver --ftp --no-tools --no-user

# Skip updates and SSH, enable FTP (using long arguments for clarity)
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/bootstrap.sh) --no-updates --no-ssh --ftp
```

**Local execution (if cloned):**
```bash
# Interactive mode (default)
sudo ./bootstrap.sh

# Command-line mode with options
sudo ./bootstrap.sh -n webserver -u -s
```

**Available options:**
- `-n, --hostname NAME`: Set hostname to NAME (skips prompt)
- `-u, --no-updates`: Skip system updates (default: enabled)
- `-t, --no-tools`: Skip essential tools installation (default: enabled)
- `-U, --no-user`: Skip admin user creation (default: enabled)
- `-s, --no-ssh`: Skip SSH configuration (default: enabled)
- `-f, --ftp`: Enable FTP server configuration (default: disabled)
- `-y, --yes`: Enable all components (overrides other flags)
- `-h, --help`: Show usage information

**Behavior:**
- **No parameters**: Interactive mode - prompts for each step
- **Any parameter**: Uses default values for unspecified options
- **Arguments toggle opposite of defaults**: If default is enabled, the flag disables it; if default is disabled, the flag enables it

### Update all LXC containers:

**Direct execution from GitHub (recommended):**
```bash
# Interactive mode - prompts for update options
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-update-all.sh)

# Update all running containers (use defaults)
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-update-all.sh) -y

# Update all containers including stopped ones
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-update-all.sh) -a -y

# Run 3 updates in parallel for faster execution
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-update-all.sh) -p 3 -y

# Exclude specific containers (e.g., production containers)
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-update-all.sh) -e 101,105,200 -y

# See what would be updated without making changes
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-update-all.sh) -d

# Combine options
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-update-all.sh) -a -p 2 -e 101 -y
```

**Local execution (if cloned):**
```bash
# Interactive mode
sudo ./ct-update-all.sh

# Command-line mode
sudo ./ct-update-all.sh -a -p 3 -y
```

**Available options:**
- `-a, --all`: Include stopped containers (default: false)
- `-p, --parallel N`: Run up to N updates in parallel (default: 1)
- `-e, --exclude LIST`: Comma-separated CTIDs to exclude (default: none)
- `-y, --yes`: Skip confirmation prompt
- `-d, --dry-run`: Show what would be executed without running (default: false)
- `-h, --help`: Show usage information

**Behavior:**
- **No parameters**: Interactive mode - prompts for each option
- **Any parameter**: Uses default values for unspecified options

**Container update process:**
1. Detects the Linux distribution in each container
2. Uses the appropriate package manager (apt, dnf, apk, or pacman)
3. Performs full system update, upgrade, and cleanup
4. Provides detailed progress and final summary

**Usage modes:**
- **Interactive**: Run without arguments to be prompted for each option
- **Automatic**: Specify arguments to use defaults for unspecified options
- **Simplified**: Only specify the options you want to enable (no `--no-*` flags needed)

---

## 📌 Roadmap

Planned future scripts include:
- **Multi-node command executor** — run a command on all Proxmox nodes at once.
- **Node IP fetcher** — gather and write all nodes’ IP addresses into their `/etc/hosts`.
- **Cluster-wide configuration sync** — keep settings consistent across all nodes.

---

## 🤝 Contributing

We welcome tested and production-ready Proxmox automation scripts.  
Submit a pull request to have your script added to the collection.

---

## 📜 License

Licensed under the MIT License — see LICENSE file for details.
