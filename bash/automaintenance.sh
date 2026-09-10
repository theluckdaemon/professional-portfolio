#!/usr/bin/env bash
set -e

echo "=== Starting System Upgrade ==="
# Path to your custom upgrade script
/home/$USER/systemupgrade.sh || /bin/bash /home/jordan/systemupgrade.sh

echo "=== Updating ClamAV Definitions ==="
# Stop daemon temporarily to prevent log lock, then update
systemctl stop clamav-freshclam.service || true
freshclam
systemctl start clamav-freshclam.service || true

echo "=== Running Full System Scan ==="
counter=0
stdbuf -oL clamscan -r \
  --exclude-dir="^/proc" \
  --exclude-dir="^/sys" \
  --exclude-dir="^/dev" \
  -l /var/log/clamav/full_system_scan.log / | while read -r line; do
    counter=$((counter + 1))
    echo -ne "Scanning files... Total processed: $counter\r"
done
echo -e "\nScan complete. Full log saved to /var/log/clamav/full_system_scan.log"