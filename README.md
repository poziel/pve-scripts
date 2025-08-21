# PVE Scripts – Proxmox Container Management Tools ⚙️🖥️

**PVE Scripts** is a collection of **ready-to-use Bash scripts** that simplify **Proxmox Virtual Environment (PVE)** LXC container management.

# 📌 Roadmap

Planned future scripts include:
- **Additional container scripts** for specialized tasks (monitoring, backups, etc.)
- **Multi-node command executor** — run commands across Proxmox cluster nodes
- **Node IP fetcher** — gather and distribute all nodes' IP addresses
- **Cluster-wide configuration sync** — keep settings consistent across all nodes
- **Template-based container provisioning** — standardized container deployments

**Current Status:**
- ✅ **Modular architecture implemented** with separated host/container scripts
- ✅ **Universal script executor** for running any container operation
- ✅ **Clean, focused codebase** with removed legacy scripts
- ✅ **Streamlined workflow** for container managementth a modern **modular architecture**.  
These scripts automate container configuration, updates, and maintenance tasks at scale.

---

## 📂 Script Collection

### **Host Scripts** (Run on Proxmox Host)

#### `ct-executor.sh` – **Universal Container Script Executor**
The **core orchestrator** that executes any script from `ct-scripts/` across multiple LXC containers:
- **Universal execution**: Run any CT script across containers
- **Flexible targeting**: Include/exclude specific containers
- **Parallel processing**: Execute on multiple containers simultaneously
- **Smart copying**: Automatically copies scripts into containers and executes them
- **Safety features**: Dry-run mode and confirmation prompts
- **Comprehensive reporting**: Success, skipped, and failed container counts

### **Container Scripts** (`ct-scripts/` directory)
*These scripts run INSIDE containers, not on the Proxmox host*

#### `ct-update.sh` – Single Container Package Update
Updates packages in the current container with multi-distro support:
- **Multi-distro support**: Debian/Ubuntu (apt), RHEL/Fedora (dnf), Alpine (apk), Arch (pacman)
- **Auto-detection**: Automatically detects the Linux distribution
- **Comprehensive updates**: Full system update, upgrade, and cleanup
- **Verbose/Silent modes**: `--verbose` for detailed output, `--silent` for no output

#### `ct-bootstrap.sh` – Single Container Bootstrap
Configures a container from the inside with:
- **Hostname configuration** and `/etc/hosts` updates
- **System updates** (uses `ct-update.sh` internally)
- **Essential tools installation** (uses `ct-tools.sh` internally)
- **Admin user creation** with sudo access
- **SSH server configuration**
- **FTP server setup** (optional)
- **Verbose/Silent modes**: `--verbose` for detailed output, `--silent` for no output

#### `ct-tools.sh` – Essential Tools Installation
Installs a comprehensive set of development and system tools:
- **Predefined tool list**: curl, wget, nano, vim, git, unzip, htop, net-tools, etc.
- **Multi-distro support**: Works across different Linux distributions
- **Direct installation**: Installs tools immediately when script runs (no confirmation needed)
- **Tool listing**: `--list` to show what will be installed
- **Verbose/Silent modes**: `--verbose` for detailed output, `--silent` for no output

#### `ct-info.sh` – Container Network Information
Displays container hostname and IP information:
- **IP detection**: Multiple fallback methods for reliable IP retrieval
- **Multiple formats**: Basic, verbose, and JSON output modes
- **Network interface**: Comprehensive network information display
- **Flexible output**: Suitable for both interactive use and automation
- **Verbose/Silent modes**: `--verbose` for detailed output, `--silent` for no output

#### `ct-test.sh` – Container System Test
Simple test script to verify container functionality:
- **System information** gathering
- **Package manager detection**
- **Network connectivity testing**
- **Resource usage reporting**
- **Verbose/Silent modes**: `--verbose` for detailed output, `--silent` for no output

#### `shared.sh` – LEGACY: Original Shared Functions (DEPRECATED)
This file is now **deprecated** in favor of the new modular library system.  
**Use `lib/core.sh` and `use_lib()` instead** for new scripts.

---

## 🏗️ Modular Library System

The **new modular architecture** features a **core library** system with dynamic loading:

### **Core Library (`lib/core.sh`)**
The foundation library that every script loads first:
- **Essential logging functions**: `log_info`, `log_success`, `log_warning`, `log_error`, `fatal_error`
- **Utility functions**: `command_exists`, basic system checks
- **Dynamic library loader**: `use_lib()` function for on-demand module loading
- **Smart loading**: Handles local and remote library loading with fallbacks
- **Duplicate prevention**: Tracks loaded libraries to prevent re-loading

### **Focused Library Modules**
- **lib/ui.sh**: User interface, colors, banners, and interactive prompts
- **lib/system.sh**: OS detection, system info, and performance monitoring  
- **lib/packages.sh**: Multi-distro package management functions
- **lib/network.sh**: IP detection, connectivity testing
- **lib/validation.sh**: Input validation and utility checks
- **lib/files.sh**: File operations and cleanup functions

### **Usage Pattern**
```bash
# Load core library first (contains use_lib function)
source "lib/core.sh" || source <(wget -qO- "$CORE_LIB_URL")

# Load additional modules as needed
use_lib "ui"         # For banners and prompts
use_lib "system"     # For OS detection
use_lib "network"    # For IP functions
```

```
📁 pve-scripts/
├── 🖥️ Host Scripts (run on Proxmox)
│   ├── ct-executor.sh        # Universal container orchestrator
│   ├── ct-update-all.sh      # Bulk container updates
│   └── bootstrap.sh          # Host-side bootstrapping
├── 📦 ct-scripts/ (run inside containers)
│   ├── ct-update.sh          # Package updates
│   ├── ct-bootstrap.sh       # Container setup
│   ├── ct-tools.sh           # Essential tools installation
│   ├── ct-info.sh            # Network information
│   └── ct-test.sh            # System testing
├── 📚 lib/ (modular shared libraries)
│   ├── core.sh               # 🔥 Core library with use_lib() loader
│   ├── ui.sh                 # UI, logging, and colors
│   ├── system.sh             # System detection and info
│   ├── packages.sh           # Package management
│   ├── network.sh            # Network utilities
│   ├── validation.sh         # Validation functions
│   └── files.sh              # File operations
└── shared.sh                 # 🚫 DEPRECATED - use lib/core.sh instead
└── 📖 README.md & LICENSE
```

**Benefits:**
- **Modularity**: Each script and library module has a single responsibility
- **Reusability**: Container scripts can be used independently
- **Scalability**: Easy to add new container operations and library functions
- **Maintainability**: Clear separation between host/container logic and focused library modules
- **Flexibility**: Mix and match operations as needed
- **Reliability**: Strict dependency checking prevents runtime failures
- **Organization**: Shared functionality split into logical, manageable modules

---

## 🛠️ Requirements

- **Proxmox Virtual Environment** (Debian-based host)
- **Root access** (scripts must be run as `root` or with `sudo`)
- **Internet connection** for downloading scripts and package installation
- **wget** (usually pre-installed on Proxmox)

---

## 🚀 Quick Start (Recommended)

**Execute directly from GitHub** - no cloning required:

### Host Operations (run on Proxmox host)

```bash
# Update all LXC containers using the modular approach
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-executor.sh) ct-update.sh -y

# Bootstrap all containers with custom hostname pattern
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-executor.sh) ct-bootstrap.sh -n web -p 3 -y

# Test all containers
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-executor.sh) ct-test.sh -y

# Install essential tools on all containers
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-executor.sh) ct-tools.sh -y

# Get network information from all containers
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-executor.sh) ct-info.sh -y

# Execute with verbose output
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-executor.sh) ct-update.sh --verbose -y

# Execute in silent mode
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-executor.sh) ct-bootstrap.sh --silent -y

# Execute any CT script with options
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-executor.sh) ct-update.sh -p 2 -e 101,105 -y
```

### Container Operations (run inside containers)

```bash
# Update packages in current container
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-scripts/ct-update.sh)

# Bootstrap current container
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-scripts/ct-bootstrap.sh) -n mycontainer -y

# Install essential tools in current container
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-scripts/ct-tools.sh)

# Test current container
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-scripts/ct-test.sh)

# Get network information for current container
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-scripts/ct-info.sh)
```

---

## 💾 Local Installation (Alternative)

If you prefer to clone and run locally:

```bash
# Clone the repository
git clone https://github.com/poziel/pve-scripts.git
cd pve-scripts

# Make scripts executable
chmod +x ct-executor.sh ct-scripts/*.sh
```

---

## 📖 Usage

### Container Script Execution (Recommended)

The **modular approach** using `ct-executor.sh` is the primary way to manage containers:

**Direct execution from GitHub (recommended):**
```bash
# Interactive mode - prompts for execution options
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-executor.sh) ct-update.sh

# Update all running containers
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-executor.sh) ct-update.sh -y

# Update specific containers only
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-executor.sh) ct-update.sh -i 101,105,200 -y

# Update all containers including stopped ones (in parallel)
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-executor.sh) ct-update.sh -a -p 3 -y

# Bootstrap all containers with custom settings
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-executor.sh) ct-bootstrap.sh -n web -t -U -p 2 -y

# Install tools on specific containers with verbose output
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-executor.sh) ct-tools.sh -i 101,105 --verbose -y

# Test all containers
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-executor.sh) ct-test.sh -y

# Get network information from all containers
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-executor.sh) ct-info.sh -y

# Exclude specific containers from operations
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-executor.sh) ct-bootstrap.sh -e 101,105 -y

# See what would be executed without making changes
bash <(wget -qO- https://raw.githubusercontent.com/poziel/pve-scripts/main/ct-executor.sh) ct-update.sh -d
```

**Local execution (if cloned):**
```bash
# Interactive mode
sudo ./ct-executor.sh ct-update.sh

# Command-line mode
sudo ./ct-executor.sh ct-bootstrap.sh -n webserver -p 3 -y
```

**ct-executor.sh options:**
- `SCRIPT_NAME`: Required - script from ct-scripts/ to execute (e.g., ct-update.sh)
- `[script_args...]`: Arguments to pass to the script
- `-a, --all`: Include stopped containers (default: false)
- `-p, --parallel N`: Run up to N containers in parallel (default: 1)
- `-e, --exclude LIST`: Comma-separated CTIDs to exclude
- `-i, --include LIST`: Comma-separated CTIDs to include only
- `-y, --yes`: Skip confirmation prompt
- `-d, --dry-run`: Show what would be executed without running
- `-h, --help`: Show usage information

**Container script arguments:**
- **ct-update.sh**: `--dry-run` (show what would be updated), `--verbose` (detailed output), `--silent` (no output)
- **ct-bootstrap.sh**: `-n hostname`, `-u` (no updates), `-t` (no tools), `-U` (no user), `-s` (no SSH), `-f` (enable FTP), `-y` (yes to all), `--verbose` (detailed output), `--silent` (no output)
- **ct-tools.sh**: `--list` (show tools list), `--verbose` (detailed output), `--silent` (no output)
- **ct-info.sh**: `-v` (verbose), `-j` (JSON format), `--verbose` (detailed output), `--silent` (no output)
- **ct-test.sh**: `--verbose` (detailed test information), `--silent` (no output)

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
