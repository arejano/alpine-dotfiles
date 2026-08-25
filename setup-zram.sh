#!/bin/bash
# setup-zram.sh - Instala e configura zram swap
# Execute com: sudo ./setup-zram.sh

set -euo pipefail

GREEN='\033[0;32m'
NC='\033[0m'
log() { echo -e "${GREEN}[✓]${NC} $1"; }

[[ $EUID -ne 0 ]] && { echo "Execute como root: sudo ./setup-zram.sh"; exit 1; }

echo "[1/4] Instalando zram-generator..."
pacman -S --noconfirm --needed zram-generator

echo "[2/4] Criando configuracao do zram..."
cat > /etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = min(ram / 2, 4096)
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF
log "/etc/systemd/zram-generator.conf criado (zram = metade da RAM, max 4G)"

echo "[3/4] Ativando zram agora..."
systemctl daemon-reload
systemctl start systemd-zram-setup@zram0.service

echo "[4/4] Reiniciando waybar sem modulo pacman (como usuario mek)..."
runuser -u mek -- systemctl --user restart waybar.service || true

echo ""
echo "============================================="
echo -e "${GREEN} ZRAM ATIVO${NC}"
echo "============================================="
swapon --show
free -h
