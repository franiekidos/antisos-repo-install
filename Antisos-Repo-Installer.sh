#!/bin/bash
set -euo pipefail

KEY_URL="https://raw.githubusercontent.com/franiekidos/antisos-repo-install/main/key/antisos.gpg"
REPO_URL="https://raw.githubusercontent.com/franiekidos/antisos-repo/main"
ARCH=$(uname -m)
MAX_WAIT=60

wait_for_pacman_lock() {
    local waited=0
    while sudo fuser /var/lib/pacman/db.lck >/dev/null 2>&1; do
        echo "Pacman database is locked. Waiting..."
        sleep 5
        waited=$((waited+5))
        if [ "$waited" -ge "$MAX_WAIT" ]; then
            echo "Pacman is still locked after $MAX_WAIT seconds. Exiting."
            exit 1
        fi
    done
}

echo "==> Ensuring pacman-key is initialized..."
if [ ! -f /etc/pacman.d/gnupg/pubring.gpg ]; then
    sudo pacman-key --init
fi

echo "==> Fetching AntisOS GPG key..."
curl -fsSL "$KEY_URL" -o /tmp/antisos.gpg
sudo pacman-key --add /tmp/antisos.gpg

KEY_ID=$(gpg --with-colons --import-options show-only --import /tmp/antisos.gpg 2>/dev/null | awk -F: '/^pub/ {print $5}')
sudo pacman-key --lsign-key "$KEY_ID"

echo "==> Refreshing pacman databases..."
wait_for_pacman_lock
sudo pacman -Sy --noconfirm

echo "==> Installing AntisOS keyring package..."
sudo pacman -U "$REPO_URL/$ARCH/antisos-keyring-1-1-any.pkg.tar.zst" --noconfirm --needed || {
    echo "❌ Failed to install keyring package from $REPO_URL"
    exit 1
}

if ! grep -q "^\[antisos\]" /etc/pacman.conf; then
    echo "==> Adding AntisOS repo to pacman.conf..."
    cat <<EOF | sudo tee -a /etc/pacman.conf

[antisos]
SigLevel = Required DatabaseOptional
Server = $REPO_URL/\$arch
EOF
fi

echo "==> Final sync..."
wait_for_pacman_lock
sudo pacman -Sy --noconfirm

echo "✅ AntisOS repo is ready!"
