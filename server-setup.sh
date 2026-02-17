#!/usr/bin/env bash
# =============================================================================
#  SERVER SETUP SCRIPT
#  Automates initial Linux server configuration (Ubuntu/Debian)
#
#  Steps:
#    1. System update & upgrade
#    2. Install essential packages
#    3. Create a non-root user
#    4. Add user to the sudo group
#    5. Configure timezone & NTP
#    6. Install & enable common services (UFW, Fail2Ban)
#    7. Print a summary of all results
#
#  Usage:
#    sudo ./server_setup.sh
#
#  Requirements:
#    - Ubuntu 20.04+ or Debian 11+
#    - Must be run as root (or via sudo)
# =============================================================================

set -euo pipefail

# ─────────────────────────────────────────────
#  CONFIGURATION — Edit these values before running
# ─────────────────────────────────────────────
NEW_USER="devops"
USER_PASS="ChangeMe123!"           # Change this before running the script!
TIMEZONE="Asia/Jakarta"            # See: timedatectl list-timezones
PACKAGES=(
    curl wget git vim nano unzip htop
    net-tools build-essential ca-certificates
    ufw fail2ban
)
SERVICES=(ufw fail2ban)            # Services to enable and start

# ─────────────────────────────────────────────
#  COLORS & HELPER FUNCTIONS
# ─────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

OK="[${GREEN}✔${RESET}]"
FAIL="[${RED}✘${RESET}]"
INFO="[${CYAN}→${RESET}]"
WARN="[${YELLOW}!${RESET}]"

SUMMARY=()     # Collects all step results for the final summary
ERRORS=0       # Error counter

log()   { echo -e "${INFO} $*"; }
ok()    { echo -e "${OK}  $*"; SUMMARY+=("${GREEN}✔${RESET} $*"); }
warn()  { echo -e "${WARN} $*"; SUMMARY+=("${YELLOW}!${RESET} $*"); }
fail()  { echo -e "${FAIL} $*"; SUMMARY+=("${RED}✘${RESET} $*"); ((ERRORS++)); }

section() {
    echo
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
    echo -e "${BOLD}${CYAN}  $*${RESET}"
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
}

# ─────────────────────────────────────────────
#  PRE-FLIGHT CHECKS
# ─────────────────────────────────────────────

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${FAIL} This script must be run as root. Try: sudo ./server_setup.sh"
    exit 1
fi

# Warn if the OS is not Ubuntu/Debian
if ! grep -qiE "ubuntu|debian" /etc/os-release 2>/dev/null; then
    warn "OS does not appear to be Ubuntu/Debian — some steps may need adjustment."
fi

START_TIME=$(date +%s)
echo
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${CYAN}║        SERVER SETUP SCRIPT               ║${RESET}"
echo -e "${BOLD}${CYAN}║  $(date '+%Y-%m-%d %H:%M:%S')                   ║${RESET}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════╝${RESET}"

# ─────────────────────────────────────────────
#  STEP 1 — SYSTEM UPDATE
# ─────────────────────────────────────────────
section "Step 1 — System Update"
log "Refreshing package lists..."
if apt-get update -y -q; then
    log "Upgrading installed packages..."
    if apt-get upgrade -y -q; then
        ok "System successfully updated and upgraded"
    else
        fail "apt-get upgrade failed"
    fi
else
    fail "apt-get update failed"
fi

# ─────────────────────────────────────────────
#  STEP 2 — INSTALL ESSENTIAL PACKAGES
# ─────────────────────────────────────────────
section "Step 2 — Install Essential Packages"
INSTALLED_PKG=()
FAILED_PKG=()

for pkg in "${PACKAGES[@]}"; do
    log "Installing: ${pkg}"
    if apt-get install -y -q "$pkg" 2>/dev/null; then
        INSTALLED_PKG+=("$pkg")
    else
        FAILED_PKG+=("$pkg")
        warn "Failed to install: $pkg"
    fi
done

if [[ ${#FAILED_PKG[@]} -eq 0 ]]; then
    ok "All packages installed successfully: ${INSTALLED_PKG[*]}"
else
    fail "Packages that failed to install: ${FAILED_PKG[*]}"
    ok "Packages successfully installed: ${INSTALLED_PKG[*]}"
fi

# ─────────────────────────────────────────────
#  STEP 3 — CREATE NON-ROOT USER
# ─────────────────────────────────────────────
section "Step 3 — Create Non-Root User: ${NEW_USER}"

if id "$NEW_USER" &>/dev/null; then
    warn "User '${NEW_USER}' already exists — skipping creation"
else
    log "Creating user: ${NEW_USER}"
    useradd -m -s /bin/bash "$NEW_USER"
    echo "${NEW_USER}:${USER_PASS}" | chpasswd
    ok "User '${NEW_USER}' created successfully"
fi

# ─────────────────────────────────────────────
#  STEP 4 — ADD USER TO SUDO GROUP
# ─────────────────────────────────────────────
section "Step 4 — Add User to Sudo Group"
log "Adding '${NEW_USER}' to the sudo group..."

if usermod -aG sudo "$NEW_USER"; then
    ok "User '${NEW_USER}' added to the sudo group"
else
    fail "Failed to add '${NEW_USER}' to the sudo group"
fi

# Create a sudoers drop-in file for passwordless sudo
# (Optional — remove this block if password prompt is preferred)
SUDOERS_FILE="/etc/sudoers.d/${NEW_USER}"
if [[ ! -f "$SUDOERS_FILE" ]]; then
    echo "${NEW_USER} ALL=(ALL) NOPASSWD:ALL" > "$SUDOERS_FILE"
    chmod 440 "$SUDOERS_FILE"
    ok "Sudoers file created: ${SUDOERS_FILE}"
fi

# ─────────────────────────────────────────────
#  STEP 5 — CONFIGURE TIMEZONE
# ─────────────────────────────────────────────
section "Step 5 — Configure Timezone: ${TIMEZONE}"
log "Setting timezone to ${TIMEZONE}..."

if timedatectl set-timezone "$TIMEZONE" 2>/dev/null; then
    CURRENT_TZ=$(timedatectl show --property=Timezone --value)
    ok "Timezone set to: ${CURRENT_TZ}"
else
    # Fallback: manual symlink method
    if ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime; then
        echo "$TIMEZONE" > /etc/timezone
        ok "Timezone set (manual fallback): ${TIMEZONE}"
    else
        fail "Failed to set timezone: ${TIMEZONE}"
    fi
fi

# ─────────────────────────────────────────────
#  STEP 6 — INSTALL & ENABLE SERVICES
# ─────────────────────────────────────────────
section "Step 6 — Install & Enable Services"

# --- UFW Firewall ---
log "Configuring UFW firewall..."
if command -v ufw &>/dev/null; then
    ufw --force reset > /dev/null 2>&1      # Reset to clean slate
    ufw default deny incoming  > /dev/null  # Block all inbound by default
    ufw default allow outgoing > /dev/null  # Allow all outbound by default
    ufw allow ssh              > /dev/null  # Allow SSH (port 22)
    ufw allow 80/tcp           > /dev/null  # Allow HTTP
    ufw allow 443/tcp          > /dev/null  # Allow HTTPS
    ufw --force enable         > /dev/null
    ok "UFW enabled — ports open: SSH(22), HTTP(80), HTTPS(443)"
else
    fail "UFW not found — skipping firewall configuration"
fi

# --- Fail2Ban ---
log "Configuring Fail2Ban..."
if command -v fail2ban-client &>/dev/null; then
    F2B_CONFIG="/etc/fail2ban/jail.local"

    if [[ ! -f "$F2B_CONFIG" ]]; then
        # Write a minimal jail.local config for SSH protection
        cat > "$F2B_CONFIG" <<'EOF'
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5
backend  = systemd

[sshd]
enabled = true
port    = ssh
logpath = %(sshd_log)s
EOF
        ok "Fail2Ban jail.local config created"
    else
        warn "Fail2Ban jail.local already exists — skipping"
    fi

    # Enable and start all configured services
    for svc in "${SERVICES[@]}"; do
        log "Enabling and starting service: ${svc}"
        if systemctl enable "$svc" --quiet 2>/dev/null && \
           systemctl restart "$svc" 2>/dev/null; then
            STATUS=$(systemctl is-active "$svc")
            ok "Service '${svc}' is: ${STATUS}"
        else
            fail "Failed to start service: ${svc}"
        fi
    done
else
    fail "Fail2Ban not found — skipping intrusion prevention setup"
fi

# --- NTP Sync ---
log "Enabling NTP time synchronization..."
if timedatectl set-ntp true 2>/dev/null; then
    ok "NTP synchronization enabled"
else
    warn "Could not enable NTP synchronization"
fi

# ─────────────────────────────────────────────
#  STEP 7 — SUMMARY
# ─────────────────────────────────────────────
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${CYAN}║            SETUP SUMMARY                 ║${RESET}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════╝${RESET}"

for line in "${SUMMARY[@]}"; do
    echo -e "  ${line}"
done

echo
echo -e "${BOLD}──────────────────────────────────────────${RESET}"
echo -e "  ${BOLD}User created${RESET}       : ${NEW_USER}"
echo -e "  ${BOLD}Timezone${RESET}           : ${TIMEZONE}"
echo -e "  ${BOLD}Packages installed${RESET} : ${#INSTALLED_PKG[@]} package(s)"
echo -e "  ${BOLD}Duration${RESET}           : ${DURATION} second(s)"
echo -e "${BOLD}──────────────────────────────────────────${RESET}"

if [[ $ERRORS -eq 0 ]]; then
    echo -e "${OK} ${BOLD}${GREEN}All steps completed successfully — no errors!${RESET}"
else
    echo -e "${FAIL} ${BOLD}${RED}Completed with ${ERRORS} error(s) — review the log above.${RESET}"
fi

echo
echo -e "${WARN} ${YELLOW}Reminder:${RESET} Change the default password for '${NEW_USER}' after first login!"
echo -e "${INFO} Run: ${CYAN}passwd ${NEW_USER}${RESET}"
echo

exit $ERRORS
