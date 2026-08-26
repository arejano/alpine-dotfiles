#!/bin/bash
# install-nvidia.sh - Instalação segura do driver NVIDIA 580xx para Sway/Wayland
# GTX 1050 (GP107) - Manjaro
# Execute com: sudo ./install-nvidia.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()   { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# -----------------------------------------------------------
# 0. Pré-checagens
# -----------------------------------------------------------
[[ $EUID -ne 0 ]] && error "Execute como root: sudo ./install-nvidia.sh"

GPU_INFO=$(lspci | grep -i "VGA.*NVIDIA")
[[ -z "$GPU_INFO" ]] && error "Nenhuma GPU NVIDIA detectada"

DRIVER_ACTIVE=$(lspci -k | grep -A3 -i "VGA.*NVIDIA" | grep "Kernel driver" | awk '{print $NF}')
if [[ "$DRIVER_ACTIVE" == "nvidia" ]]; then
    warn "Driver nvidia já está carregado. Desinstalando antes de reinstalar..."
    mhwd -r pci video-nvidia-580xx 2>/dev/null || true
    sleep 2
fi

log "GPU detectada: $GPU_INFO"
log "Driver atual: $DRIVER_ACTIVE"

# -----------------------------------------------------------
# 1. Salvar config sway atual (backup de segurança)
# -----------------------------------------------------------
BACKUP_DIR="$HOME/.config/sway-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -a "$HOME/.config/sway/config" "$BACKUP_DIR/" 2>/dev/null || true
cp -a "$HOME/.config/waybar/" "$BACKUP_DIR/" 2>/dev/null || true
log "Backup salvo em $BACKUP_DIR"

# -----------------------------------------------------------
# 2. Instalar driver via MHWD
# -----------------------------------------------------------
log "Instalando video-nvidia-580xx via MHWD..."
mhwd -i pci video-nvidia-580xx
log "Pacotes nvidia instalados"

# -----------------------------------------------------------
# 3. Verificar blacklist do nouveau
# -----------------------------------------------------------
BLACKLIST_FILE="/usr/lib/modprobe.d/manjaro-nvidia.conf"
if [[ -f "$BLACKLIST_FILE" ]]; then
    if grep -q "blacklist nouveau" "$BLACKLIST_FILE"; then
        log "Blacklist do nouveau já configurada"
    else
        echo "blacklist nouveau" >> "$BLACKLIST_FILE"
        log "Blacklist do nouveau adicionada"
    fi
else
    # Fallback: criar arquivo próprio
    cat > /etc/modprobe.d/blacklist-nouveau.conf <<'EOF'
blacklist nouveau
options nouveau modeset=0
EOF
    log "Blacklist do nouveau criada em /etc/modprobe.d/"
fi

# -----------------------------------------------------------
# 4. Configurar initramfs com módulo nvidia
# -----------------------------------------------------------
MKINITCPIO="/etc/mkinitcpio.conf"
MODULES_LINE=$(grep "^MODULES=" "$MKINITCPIO")

if ! echo "$MODULES_LINE" | grep -q "nvidia"; then
    # Adiciona módulos nvidia necessários
    sed -i 's/^MODULES=(.*/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' "$MKINITCPIO"
    log "Módulos nvidia adicionados ao initramfs"
else
    log "Módulos nvidia já presentes no initramfs"
fi

# -----------------------------------------------------------
# 5. Adicionar nvidia-drm.modeset=1 ao GRUB (essencial para Wayland)
# -----------------------------------------------------------
GRUB_CFG="/etc/default/grub"
GRUB_PARAMS="nvidia-drm.modeset=1 nvidia_drm.fbdev=1"

if grep -q "nvidia-drm.modeset" "$GRUB_CFG"; then
    log "Parâmetro nvidia-drm já presente no GRUB"
else
    # Adiciona aos CMDLINE_LINUX_DEFAULT
    sed -i "s|^\(GRUB_CMDLINE_LINUX_DEFAULT='[^']*\)|\1 nvidia-drm.modeset=1 nvidia_drm.fbdev=1|" "$GRUB_CFG"
    log "nvidia-drm.modeset=1 adicionado ao GRUB"
fi

# -----------------------------------------------------------
# 6. Rebuildar initramfs para TODOS os kernels instalados
# -----------------------------------------------------------
log "Reconstruindo initramfs..."
mkinitcpio -P
log "Initramfs reconstruído"

# -----------------------------------------------------------
# 7. Atualizar GRUB
# -----------------------------------------------------------
log "Atualizando GRUB..."
grub-mkconfig -o /boot/grub/grub.cfg
log "GRUB atualizado"

# -----------------------------------------------------------
# 8. Configurar Sway para NVIDIA (adicionar flags se necessário)
# -----------------------------------------------------------
SWAY_WRAPPER="/usr/local/bin/sway"
if [[ -f "$SWAY_WRAPPER" ]] && grep -q "unsupported-gpu" "$SWAY_WRAPPER"; then
    log "Wrapper sway já configura --unsupported-gpu"
else
    warn "Verificar se /usr/local/bin/sway passa --unsupported-gpu para nvidia"
fi

# -----------------------------------------------------------
# 9. Configurar variáveis de ambiente para NVIDIA no sway env
# -----------------------------------------------------------
SWAY_ENV="$HOME/.config/sway/env"
NVIDIA_ENV_VARS=(
    "LIBVA_DRIVER_NAME=nvidia"
    "__NV_PRIME_RENDER_OFFLOAD=1"
    "__GLX_VENDOR_LIBRARY_NAME=nvidia"
)

for var in "${NVIDIA_ENV_VARS[@]}"; do
    VAR_NAME="${var%%=*}"
    if ! grep -q "^${VAR_NAME}=" "$SWAY_ENV" 2>/dev/null; then
        echo "$var" >> "$SWAY_ENV"
        log "Adicionado: $var"
    fi
done

# -----------------------------------------------------------
# 10. Instalar pacotes de suporte se ausentes
# -----------------------------------------------------------
SUPPORT_PKGS=("libva-nvidia-driver" "nvidia-utils" "lib32-nvidia-utils")
for pkg in "${SUPPORT_PKGS[@]}"; do
    if ! pacman -Qi "$pkg" &>/dev/null; then
        log "Instalando $pkg..."
        pacman -S --noconfirm "$pkg" 2>/dev/null || warn "Falha ao instalar $pkg (pode não existir)"
    fi
done

# -----------------------------------------------------------
# Resumo
# -----------------------------------------------------------
echo ""
echo "============================================="
echo -e "${GREEN} INSTALAÇÃO CONCLUÍDA${NC}"
echo "============================================="
echo ""
echo "Driver:       nvidia-580xx"
echo "GPU:          GTX 1050 (GP107)"
echo "Wayland:      nvidia-drm.modeset=1"
echo "Initramfs:    nvidia modules incluídos"
echo "Blacklist:    nouveau desabilitado"
echo ""
echo -e "${YELLOW} PRÓXIMO PASSO:${NC}"
echo "  sudo reboot"
echo ""
echo "Após o reboot, verifique com:"
echo "  nvidia-smi"
echo "  lsmod | grep nvidia"
echo "  swaymsg -t get_version"
echo ""
echo "Se algo der errado, boot pelo kernel alternativo (linux71)"
echo "no menu do GRUB (pressione Shift durante o boot)."
echo ""
echo "Backup da config anterior: $BACKUP_DIR"
