#!/bin/bash
set -euo pipefail

# =============================
# Variables
# =============================
KEY_URL="https://raw.githubusercontent.com/franiekidos/antisos-repo-install/main/key/antisos.gpg"
ARCH=$(uname -m)
REPO_URL="https://raw.githubusercontent.com/franiekidos/antisos-repo/main"
MAX_WAIT=30  # Max wait time for pacman lock in seconds

# =============================
# Functions
# =============================
wait_for_pacman_lock() {
    local wait_time=0
    while sudo fuser /var/lib/pacman/db.lck >/dev/null 2>&1; do
        echo "Pacman database is locked. Waiting..."
        sleep 5
        ((wait_time++))
        if [ "$wait_time" -ge "$MAX_WAIT" ]; then
            echo "Pacman database is still locked after $MAX_WAIT seconds. Exiting."
            exit 1
        fi
    done
}

# =============================
# 1️⃣ Download, import, and locally sign the GPG key
# =============================
echo "==> Initializing pacman keyring..."
sudo pacman-key --init

echo "==> Downloading and importing AntisOS GPG key..."
curl -sL "$KEY_URL" | sudo pacman-key --add -

KEY_ID=$(curl -sL "$KEY_URL" | gpg --with-colons --import-options show-only --import 2>/dev/null | awk -F: '/^pub/ {print $5}')
sudo pacman-key --lsign-key "$KEY_ID"

# =============================
# 2️⃣ Wait for pacman, then install keyring package
# =============================
wait_for_pacman_lock
echo "==> Installing antisos-keyring..."
sudo pacman -Sy --noconfirm
sudo pacman -U "$REPO_URL/$ARCH/antisos-keyring-1-1-any.pkg.tar.zst" --noconfirm --needed

# =============================
# 3️⃣ Enable the repo in pacman.conf if not present
# =============================
if ! grep -q "\[antisos\]" /etc/pacman.conf; then
    echo "==> Adding AntisOS repo to /etc/pacman.conf..."
    echo -e "\n[antisos]\nSigLevel = Required DatabaseOptional\nServer = $REPO_URL/\$arch" | sudo tee -a /etc/pacman.conf
fi

# =============================
# 4️⃣ Update pacman database
# =============================
wait_for_pacman_lock
echo "==> Syncing package database..."
sudo pacman -Sy --noconfirm

echo "✅ AntisOS repo setup completed!"
