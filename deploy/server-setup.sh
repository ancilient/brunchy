#!/usr/bin/env bash
# One-time setup of a fresh Ubuntu 24.04 VPS for Brunchy. Run as root on the server:
#   bash server-setup.sh
# Installs Docker (from Ubuntu's own packages), turns on automatic security updates, opens only SSH/HTTP/HTTPS
# in the firewall, adds 2 GB of swap, and schedules the nightly database backup.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then echo "Run as root (or with sudo)."; exit 1; fi

echo "==> Updating packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y

echo "==> Installing Docker, Compose, git, firewall, automatic security updates"
apt-get install -y docker.io docker-compose-v2 git ufw unattended-upgrades
systemctl enable --now docker
dpkg-reconfigure -f noninteractive unattended-upgrades

echo "==> Firewall: allow SSH, HTTP, HTTPS only"
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 443/udp
ufw --force enable

echo "==> Swap (2 GB) so a busy moment can't run the server out of memory"
if ! swapon --show | grep -q /swapfile; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

echo "==> Server time zone: UTC (the app stores UTC and shows IST itself)"
timedatectl set-timezone UTC

echo "==> Nightly database backup at 02:30 IST (21:00 UTC)"
mkdir -p /var/backups/brunchy
cat > /etc/cron.d/brunchy-backup <<'CRON'
0 21 * * * root /opt/brunchy/deploy/backup.sh >> /var/log/brunchy-backup.log 2>&1
CRON

echo
echo "Done. Next: clone the repository to /opt/brunchy and follow deploy/README.md (step 4)."
docker --version
docker compose version
