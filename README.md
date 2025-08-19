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

# Bootstrap with specific options
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/bootstrap.sh) --hostname myserver --ssh --ftp

# Update all LXC containers (interactive mode)
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-update-all.sh)

# Update containers with options
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-update-all.sh) --all --parallel 3 --yes
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
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/bootstrap.sh) --yes

# Set hostname and configure SSH + FTP only
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/bootstrap.sh) --hostname myserver --ssh --ftp

# System updates and tools only (skip user creation and services)
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/bootstrap.sh) --updates --tools --no-user --no-ssh --no-ftp
```

**Local execution (if cloned):**
```bash
# Interactive mode (default)
sudo ./bootstrap.sh

# Command-line mode with options
sudo ./bootstrap.sh --hostname webserver --updates --ssh --no-tools --no-ftp
```

**Available options:**
- `--hostname NAME`: Set hostname to NAME (skips prompt)
- `--updates` / `--no-updates`: Enable/skip system updates
- `--tools` / `--no-tools`: Install/skip essential tools
- `--user` / `--no-user`: Create/skip admin user creation
- `--ssh` / `--no-ssh`: Configure/skip SSH setup
- `--ftp` / `--no-ftp`: Configure/skip FTP server
- `--yes`: Enable all components (equivalent to all --enable flags)
- `--help`: Show usage information

### Update all LXC containers:

**Direct execution from GitHub (recommended):**
```bash
# Interactive mode - prompts for update options
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-update-all.sh)

# Update all running containers (sequential)
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-update-all.sh) --yes

# Update all containers including stopped ones
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-update-all.sh) --all --yes

# Run 3 updates in parallel for faster execution
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-update-all.sh) --parallel 3 --yes

# Exclude specific containers (e.g., production containers)
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-update-all.sh) --exclude 101,105,200 --yes

# See what would be updated without making changes
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-update-all.sh) --dry-run

# Combine options
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-update-all.sh) --all --parallel 2 --exclude 101 --yes
```

**Local execution (if cloned):**
```bash
# Interactive mode
sudo ./ct-update-all.sh

# Command-line mode
sudo ./ct-update-all.sh --all --parallel 3 --yes
```

**Available options:**
- `--all`: Include stopped containers (skipped if not running during execution)
- `--parallel N`: Run up to N updates in parallel (default: 1)
- `--exclude LIST`: Comma-separated CTIDs to exclude
- `--yes`: Skip confirmation prompt
- `--dry-run`: Show what would be executed without running
- `--help`: Show usage information

**Container update process:**
1. Detects the Linux distribution in each container
2. Uses the appropriate package manager (apt, dnf, apk, or pacman)
3. Performs full system update, upgrade, and cleanup
4. Provides detailed progress and final summary

**Usage modes:**
- **Interactive**: Run without arguments to be prompted for each option
- **Command-line**: Specify arguments for automated/scripted execution
- **Mixed**: Combine both - specify some arguments and be prompted for others

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
