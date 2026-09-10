#!/usr/bin/env bash

# ANSI Color Codes
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color


# Array to track failed steps
FAILED_STEPS=()

log_info() { echo -e "${CYAN}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Ensure script is executed with root privileges
if [ "$EUID" -ne 0 ]; then
    log_error "Please run this script with sudo or as root."
    exit 1
fi

echo -e "${BOLD}${CYAN}==============================================${NC}"
echo -e "${BOLD}${CYAN}      CUSTOM SYSTEM UPGRADE SUITE             ${NC}"
echo -e "${BOLD}${CYAN}==============================================${NC}"

# ---------------------------------------------------------
# Step 1: Update Repositories
# ---------------------------------------------------------
log_info "[1/5] Updating APT package repositories..."
if apt-get update -y; then
    log_success "Repository lists updated successfully."
else
    log_error "Repository update failed! Aborting script to maintain system safety."
    exit 1
fi

# Update Step 2 in systemupgrade.sh
log_info "[2/5] Upgrading installed DEB packages..."
if ! apt-get upgrade --with-new-pkgs -y; then
    log_error "DEB package upgrades encountered errors."
    FAILED_STEPS+=("DEB Package Upgrades")
else
    log_success "DEB packages upgraded."
fi

if command -v snap &> /dev/null; then
    log_info "Refreshing Snap packages..."
    if ! snap refresh; then
        log_error "Snap package refresh encountered errors."
        FAILED_STEPS+=("Snap Package Refresh")
    else
        log_success "Snap packages refreshed."
    fi
else
    log_warn "Snap is not installed. Skipping..."
fi

# ---------------------------------------------------------
# Step 3: Update Flatpaks
# ---------------------------------------------------------
log_info "[3/5] Updating Flatpak packages..."
if command -v flatpak &> /dev/null; then
    if ! flatpak update -y; then
        log_error "Flatpak updates encountered errors."
        FAILED_STEPS+=("Flatpak Updates")
    else
        log_success "Flatpaks updated successfully."
    fi
else
    log_warn "Flatpak is not installed. Skipping..."
fi

# ---------------------------------------------------------
# Step 4: System Updates Prompt & Execution
# ---------------------------------------------------------
log_info "[4/5] Checking for full system distribution updates..."

# Dry-run to see if dist-upgrade has pending packages
PENDING_UPDATES=$(apt-get -s dist-upgrade | grep -E "^[0-9]+ upgraded" || true)
echo -e "${YELLOW}Pending System Upgrades:${NC} ${PENDING_UPDATES:-None}"

echo ""
read -p "Do you want to proceed with full System Updates (dist-upgrade)? (y/N) and press Enter: " PROMPT_RESPONSE

if [[ $PROMPT_RESPONSE =~ ^[Yy]$ ]]; then
    log_info "Executing system updates..."
    if ! apt-get dist-upgrade -y; then
        log_error "System updates encountered errors."
        FAILED_STEPS+=("Full System Updates (dist-upgrade)")
    else
        log_success "System updates completed."
    fi
    
    log_info "Cleaning up unneeded dependencies..."
    apt-get autoremove -y
    apt-get autoclean -y
else
    log_warn "System updates skipped by user."
fi

# ---------------------------------------------------------
# Step 5: Check for Reboot Requirement
# ---------------------------------------------------------
log_info "[5/5] Checking system reboot state..."
REBOOT_NEEDED=false
if [ -f /var/run/reboot-required ]; then
    REBOOT_NEEDED=true
fi

# ---------------------------------------------------------
# Final Notification & Status Summary (Terminal Only)
# ---------------------------------------------------------
echo ""
echo -e "${BOLD}${CYAN}==============================================${NC}"
echo -e "${BOLD}${CYAN}            EXECUTION SUMMARY                 ${NC}"
echo -e "${BOLD}${CYAN}==============================================${NC}"

# Installation Status Bar Display
echo -n "Installation Progress: ["
if [ ${#FAILED_STEPS[@]} -eq 0 ]; then
    echo -e "${GREEN}██████████████████████████████${NC}] 100% SUCCESS"
else
    echo -e "${YELLOW}████████████████░░░░░░░░░░░░░░${NC}] COMPLETED WITH ERRORS"
fi

# Terminal Notification for Failures
if [ ${#FAILED_STEPS[@]} -gt 0 ]; then
    echo -e "\n${RED}${BOLD}FAILED COMPONENT NOTIFICATIONS:${NC}"
    for step in "${FAILED_STEPS[@]}"; do
        echo -e " ${RED}-${NC} $step"
    done
else
    echo -e "\n${GREEN}${BOLD}NOTIFICATION:${NC} All update tasks ran smoothly without failures."
fi

# Reboot Status Report
if [ "$REBOOT_NEEDED" = true ]; then
    echo -e "\n${YELLOW}${BOLD}REBOOT STATUS:${NC} A system reboot IS required to apply kernel or core library updates."
else
    echo -e "\n${GREEN}${BOLD}REBOOT STATUS:${NC} No reboot is required."
fi

echo -e "${BOLD}${CYAN}==============================================${NC}"