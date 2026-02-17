# 🖥️ Server Setup Script

A Bash script that automates the initial configuration of a fresh Linux server (Ubuntu / Debian). Run it once on a new machine and get a secure, ready-to-use environment in minutes.

[![GitHub](https://img.shields.io/badge/GitHub-alghifari0101%2Fserver--setup-181717?logo=github)](https://github.com/alghifari0101/server-setup)
[![Script](https://img.shields.io/badge/Script-server--setup.sh-4EAA25?logo=gnu-bash)](https://github.com/alghifari0101/server-setup/blob/main/server-setup.sh)

---

## 📋 What It Does

| Step | Action |
|------|--------|
| 1 | **System Update** — runs `apt-get update` and `apt-get upgrade` |
| 2 | **Install Packages** — installs a curated set of essential tools |
| 3 | **Create User** — adds a non-root user with a home directory and bash shell |
| 4 | **Sudo Access** — adds the user to the `sudo` group and creates a sudoers drop-in file |
| 5 | **Timezone & NTP** — sets the system timezone and enables NTP synchronization |
| 6 | **Services** — configures UFW firewall and Fail2Ban intrusion prevention |
| 7 | **Summary** — prints a color-coded report of every step's result |

---

## ⚙️ Requirements

- **OS**: Ubuntu 20.04+ or Debian 11+
- **Privileges**: Must be run as `root` or via `sudo`
- **Shell**: Bash 4.0+

---

## 🚀 Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/alghifari0101/server-setup.git
cd server-setup
```

Or download the script directly:

```bash
curl -O https://raw.githubusercontent.com/alghifari0101/server-setup/main/server-setup.sh
```

### 2. Edit the configuration block

Open the script and update the values at the top before running:

```bash
nano server-setup.sh
```

```bash
NEW_USER="devops"           # Username to create
USER_PASS="ChangeMe123!"    # Initial password (change after first login!)
TIMEZONE="Asia/Jakarta"     # Your timezone
PACKAGES=(...)              # Packages to install
SERVICES=(ufw fail2ban)     # Services to enable
```

### 3. Make it executable and run

```bash
chmod +x server-setup.sh
sudo ./server-setup.sh
```

---

## 🔧 Configuration Reference

### Timezone

Use any valid timezone string. To list available options:

```bash
timedatectl list-timezones
```

Common examples:

| Region | Timezone string |
|--------|----------------|
| Indonesia (WIB) | `Asia/Jakarta` |
| Indonesia (WITA) | `Asia/Makassar` |
| Indonesia (WIT) | `Asia/Jayapura` |
| Singapore | `Asia/Singapore` |
| UTC | `UTC` |
| US Eastern | `America/New_York` |

### Default Packages

| Package | Purpose |
|---------|---------|
| `curl`, `wget` | File downloads / API calls |
| `git` | Version control |
| `vim`, `nano` | Text editors |
| `unzip` | Archive extraction |
| `htop` | Interactive process viewer |
| `net-tools` | Network diagnostics (`ifconfig`, `netstat`) |
| `build-essential` | C/C++ compiler toolchain |
| `ca-certificates` | SSL/TLS root certificates |
| `ufw` | Uncomplicated Firewall |
| `fail2ban` | Brute-force intrusion prevention |

To add or remove packages, edit the `PACKAGES` array in the configuration block.

---

## 🔒 Security Details

### UFW Firewall Rules (applied automatically)

| Rule | Action |
|------|--------|
| Default inbound | **Deny** |
| Default outbound | **Allow** |
| Port 22 (SSH) | **Allow** |
| Port 80 (HTTP) | **Allow** |
| Port 443 (HTTPS) | **Allow** |

To open additional ports after setup:

```bash
sudo ufw allow 3000/tcp     # Example: Node.js app
sudo ufw status
```

### Fail2Ban Configuration (`/etc/fail2ban/jail.local`)

| Setting | Value | Meaning |
|---------|-------|---------|
| `bantime` | `3600` | Ban duration: 1 hour |
| `findtime` | `600` | Detection window: 10 minutes |
| `maxretry` | `5` | Max failed attempts before ban |

The `[sshd]` jail is enabled by default to protect against SSH brute-force attacks.

### Passwordless Sudo

The script creates `/etc/sudoers.d/<username>` with `NOPASSWD:ALL`. If you prefer to require a password for sudo commands, remove or comment out this block in the script:

```bash
# Optional — remove this block if password prompt is preferred
SUDOERS_FILE="/etc/sudoers.d/${NEW_USER}"
if [[ ! -f "$SUDOERS_FILE" ]]; then
    echo "${NEW_USER} ALL=(ALL) NOPASSWD:ALL" > "$SUDOERS_FILE"
    ...
fi
```

---

## 📊 Example Output

```
╔══════════════════════════════════════════╗
║        SERVER SETUP SCRIPT               ║
║  2026-02-17 10:00:00                     ║
╚══════════════════════════════════════════╝

══════════════════════════════════════════
  Step 1 — System Update
══════════════════════════════════════════
[→] Refreshing package lists...
[→] Upgrading installed packages...
[✔]  System successfully updated and upgraded

...

╔══════════════════════════════════════════╗
║            SETUP SUMMARY                 ║
╚══════════════════════════════════════════╝
  [✔] System successfully updated and upgraded
  [✔] All packages installed successfully
  [✔] User 'devops' created successfully
  [✔] User 'devops' added to the sudo group
  [✔] Timezone set to: Asia/Jakarta
  [✔] UFW enabled — ports open: SSH(22), HTTP(80), HTTPS(443)
  [✔] Service 'fail2ban' is: active

  User created       : devops
  Timezone           : Asia/Jakarta
  Packages installed : 10 package(s)
  Duration           : 42 second(s)
──────────────────────────────────────────
[✔] All steps completed successfully — no errors!

[!] Reminder: Change the default password for 'devops' after first login!
[→] Run: passwd devops
```

---

## 🛠️ Post-Setup Checklist

After the script completes, it's recommended to:

1. **Change the user password**
   ```bash
   passwd devops
   ```

2. **Set up SSH key authentication** (disable password login)
   ```bash
   # On your local machine
   ssh-copy-id devops@your-server-ip

   # Then disable password auth on the server
   sudo nano /etc/ssh/sshd_config
   # Set: PasswordAuthentication no
   sudo systemctl restart sshd
   ```

3. **Verify firewall status**
   ```bash
   sudo ufw status verbose
   ```

4. **Check Fail2Ban is running**
   ```bash
   sudo fail2ban-client status
   sudo fail2ban-client status sshd
   ```

5. **Confirm timezone and NTP**
   ```bash
   timedatectl status
   ```

---

## 🐛 Troubleshooting

**Script fails with "permission denied"**
```bash
sudo ./server-setup.sh
```

**`apt-get update` fails**
Check your internet connection and DNS:
```bash
ping -c 3 archive.ubuntu.com
```

**Timezone not found**
Verify the exact string:
```bash
timedatectl list-timezones | grep Asia
```

**Service fails to start**
Check its logs:
```bash
sudo journalctl -u fail2ban --no-pager -n 30
sudo journalctl -u ufw --no-pager -n 30
```

---

## 📁 File Structure

```
alghifari0101/server-setup
├── server-setup.sh    # Main setup script
└── README.md          # This documentation
```

---

## 🔗 Links

- **Repository**: [github.com/alghifari0101/server-setup](https://github.com/alghifari0101/server-setup)
- **Script**: [server-setup.sh](https://github.com/alghifari0101/server-setup/blob/main/server-setup.sh)
- **Raw download**: [raw.githubusercontent.com/.../server-setup.sh](https://raw.githubusercontent.com/alghifari0101/server-setup/main/server-setup.sh)

---

## 📄 License

This script is provided as-is for personal and commercial use. Modify freely to suit your infrastructure needs.
