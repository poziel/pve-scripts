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

> The script interacts with the user at each step, asking whether to proceed before making changes.

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
- **Internet connection** for package installation

---

## 🚀 Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/pve-scripts.git
cd pve-scripts

# Make scripts executable
chmod +x *.sh
```

---

## 📖 Usage

**Bootstrap a new Proxmox node:**
```bash
sudo ./bootstrap.sh
```
Follow the interactive prompts to set up the hostname, tools, users, and services.

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
