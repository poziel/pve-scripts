# proxmox-scripts

A collection of shell scripts to simplify the creation, configuration, and maintenance of containers and virtual machines within a Proxmox environment.

These scripts are designed to help automate common tasks like:
- Bootstrapping Linux containers (LXC) or virtual machines (VMs)
- Initial system updates and user creation
- Network or system tweaks
- Lightweight provisioning tools for homelab or production Proxmox setups

> ⚠️ These scripts are not specific to any software stack (e.g., Laravel, Docker, etc.) — they are general-purpose utilities intended to improve Proxmox workflow automation.

---

## 🧰 Requirements

- Proxmox VE 7 or 8
- Bash-compatible environment (inside LXC or VM)
- Internet access (for script fetching and updates)

---

## 🚀 Getting Started

To run a remote script directly:

```bash
curl -fsSL https://raw.githubusercontent.com/poziel/proxmox-scripts/main/init.sh | bash
```
