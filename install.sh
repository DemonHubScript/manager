#!/data/data/com.termux/files/usr/bin/bash
# Manager installer for Termux
# Usage: bash install.sh

URL="https://github.com/DemonHubScript/manager/raw/refs/heads/main/manager.py"
FILE="manager.py"
CFG="$HOME/roblox_config"

echo "[*] Installing requirements..."
pkg update -y && pkg install -y python curl || exit 1

mkdir -p "$CFG"

echo "[*] Downloading $FILE..."
curl -fsSL -o "$HOME/$FILE" "$URL" || { echo "[!] Download failed. Make sure the repo is Public."; exit 1; }

if [ ! -s "$HOME/$FILE" ]; then
    echo "[!] Downloaded file is empty."
    exit 1
fi

echo "[*] Checking root access..."
if ! su -c "id" >/dev/null 2>&1; then
    echo "[!] Root access denied. Grant root to Termux and run again."
    exit 1
fi

echo "[*] Done. Starting manager..."
cd "$HOME" && python "
$FILE"
