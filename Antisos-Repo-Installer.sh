#!/bin/bash
set -euo pipefail

# =============================
# Variables
# =============================
KEY_URL="https://raw.githubusercontent.com/franiekidos/antisos-repo-install/main/key/antisos.gpg"
ARCH=$(uname -m)
REPO_URL="https://raw.githubusercontent.com/franiekidos/antisos-repo/main"
PACMAN_CONF="/etc/pacman.conf"

log() {
    echo -e "[INFO] $*"
}

error_exit() {
    echo -e "[ERROR] $*" >&2
    exit 1
}

# =============================
# 1️⃣ Initialize and import GPG key
# =============================
log "Initializing pacman keyring..."
sudo pacman-key --init

log "Downloading AntisOS GPG key..."
KEY_TMP=$(mktemp)
curl -fsSL "$KEY_URL" -o "$KEY_TMP" || error_exit "Failed to download GPG key."

log "Adding and locally signing the GPG key..."
sudo pacman-key --add "$KEY_TMP" || error_exit "Failed to add GPG key."
KEY_ID=$(gpg --with-colons --import-options show-only --import "$KEY_TMP" 2>/dev/null | awk -F: '/^pub/ {print $5}')
rm -f "$KEY_TMP"

if [[ -z "$KEY_ID" ]]; then
    error_exit "Failed to extract key ID from GPG key."
fi

sudo pacman-key --lsign-key "$KEY_ID" || error_exit "Failed to locally sign the key."

# =============================
# 2️⃣ Install antisos-keyring package
# =============================
log "Updating pacman database..."
sudo pacman -Sy --noconfirm

KEYRING_PKG="$REPO_URL/$ARCH/antisos-keyring-1-1-any.pkg.tar.zst"
log "Installing antisos-keyring from $KEYRING_PKG..."
sudo pacman -U "$KEYRING_PKG" --noconfirm --needed || error_exit "Failed to install antisos-keyring."

# =============================
# 3️⃣ Enable AntisOS repo
# =============================
if ! grep -q "^\[antisos\]" "$PACMAN_CONF"; then
    log "Adding AntisOS repo to $PACMAN_CONF..."
    echo -e "\n[antisos]\nSigLevel = Required DatabaseOptional\nServer = $REPO_URL/\$arch" | sudo tee -a "$PACMAN_CONF" >/dev/null
else
    log "AntisOS repo already enabled in $PACMAN_CONF."
fi

# =============================
# 4️⃣ Update pacman database
# =============================
log "Synchronizing pacman package database..."
sudo pacman -Sy --noconfirm

log "AntisOS repository setup complete."
