#!/bin/bash
# revert-nouveau.sh - Reverte para o driver nouveau (estado anterior que funcionava)
# Execute com: sudo ./revert-nouveau.sh

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }

[[ $EUID -ne 0 ]] && { echo "Execute como root: sudo ./revert-nouveau.sh"; exit 1; }

echo "=== Revertendo para nouveau ==="
echo ""

# -----------------------------------------------------------
# 1. Remover pacotes NVIDIA
# -----------------------------------------------------------
echo "[1/7] Removendo pacotes nvidia..."
PACOTES=$(pacman -Qqs "^nvidia|^lib32-nvidia|^linux66-nvidia|^linux71-nvidia" | grep -vE "firmware|driver-assistant|mhwd|settings" || true)
if [[ -n "$PACOTES" ]]; then
    # shellcheck disable=SC2086
    pacman -Rns --noconfirm $PACOTES 2>/dev/null || \
    pacman -Rdd --noconfirm $(pacman -Qqs "^nvidia|^lib32-nvidia|^linux66-nvidia|^linux71-nvidia" | grep -vE "firmware|driver-assistant") || true
fi
log "Pacotes nvidia removidos"

# -----------------------------------------------------------
# 2. Remover blacklist do nouveau
# -----------------------------------------------------------
rm -f /etc/modprobe.d/nouveau-blacklist.conf
rm -f /etc/modprobe.d/blacklist-nouveau.conf
log "Blacklist do nouveau removida"

# -----------------------------------------------------------
# 3. Restaurar MODULES do initramfs
# -----------------------------------------------------------
sed -i 's/^MODULES=.*/MODULES=()/' /etc/mkinitcpio.conf
log "MODULES do initramfs restaurado"

# -----------------------------------------------------------
# 4. Remover parametros nvidia do GRUB
# -----------------------------------------------------------
sed -i 's/ nvidia-drm.modeset=1//g' /etc/default/grub
log "Parametros nvidia removidos do GRUB"

# -----------------------------------------------------------
# 5. Limpar env do sway
# -----------------------------------------------------------
SWAY_ENV="/home/mek/.config/sway/env"
if [[ -f "$SWAY_ENV" ]]; then
    sed -i '/^WLR_/d; /^LIBVA_DRIVER_NAME=nvidia/d; /^__GLX_VENDOR_LIBRARY_NAME=nvidia/d' "$SWAY_ENV"
    log "Variaveis nvidia/WLR removidas do env do sway"
fi

# -----------------------------------------------------------
# 6. Rebuildar initramfs e GRUB
# -----------------------------------------------------------
mkinitcpio -P
log "Initramfs reconstruido"

grub-mkconfig -o /boot/grub/grub.cfg
log "GRUB atualizado"

# -----------------------------------------------------------
# 7. Verificar estado MHWD
# -----------------------------------------------------------
mhwd -li | grep -q "video-linux" && log "MHWD: video-linux OK (nouveau)" || warn "MHWD: video-linux nao registrado"

echo ""
echo "============================================="
echo -e "${GREEN} REVERSAO CONCLUIDA${NC}"
echo "============================================="
echo ""
echo "Driver:       nouveau (open-source)"
echo ""
echo -e "${YELLOW} EXECUTE:${NC}"
echo "  sudo reboot"
echo ""
echo "Apos o reboot, confirme com:"
echo "  lsmod | grep nouveau   # deve listar modulos"
echo "  swaymsg -t get_outputs # monitores HDMI-A-1 e DVI-D-1"
