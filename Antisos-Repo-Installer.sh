#!/bin/bash
set -euo pipefail

# =============================
# Variables
# =============================
KEY_URL="https://raw.githubusercontent.com/franiekidos/antisos-repo-install/main/key/antisos.gpg"
ARCH=$(uname -m)
REPO_URL="https://raw.githubusercontent.com/franiekidos/antisos-repo/main"

# =============================
# 1️⃣ Download, import, and locally sign the GPG key
# =============================
sudo pacman-key --init
echo "==> Downloading and importing Antisos GPG key..."
curl -sL "$KEY_URL" | sudo pacman-key --add -
KEY_ID=$(curl -sL "$KEY_URL" | gpg --with-colons --import-options show-only --import 2>/dev/null | awk -F: '/^pub/ {print $5}')
sudo pacman-key --lsign-key "$KEY_ID"

# =============================
# 2️⃣ Install the keyring package
# =============================
echo "==> Installing antisos-keyring..."
sudo pacman -U "$REPO_URL/$ARCH/antisos-keyring-1-1-any.pkg.tar.zst" --noconfirm --needed

# =============================
# 3️⃣ Enable the repo in pacman.conf
# =============================
if ! grep -q "\[antisos\]" /etc/pacman.conf; then
    echo "==> Adding Antisos repo to /etc/pacman.conf..."
    echo -e "\n[antisos]\nSigLevel = Required DatabaseOptional\nServer = $REPO_URL/\$arch" | sudo tee -a /etc/pacman.conf
fi

# =============================
# 4️⃣ Update pacman database
# =============================
echo "==> Syncing package database..."
sudo pacman -Sy --noconfirm

# Optional: install a test package automatically
# sudo pacman -S <your-package>
