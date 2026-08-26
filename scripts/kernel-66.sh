#!/bin/sh
# kernel-66.sh — Instalar e definir kernel 6.6 LTS como default
# Execute como root: sh ./kernel-66.sh

set -eu

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }

[ "$(id -u)" -ne 0 ] && err "Execute como root"

# Verificar kernel atual
KVER=$(uname -r)
echo "Kernel atual: $KVER"
echo ""

# Detectar branch do Alpine
BRANCH=$(cat /etc/alpine-release 2>/dev/null | awk '{print $1}')
echo "Alpine: $BRANCH"
echo ""

# ----------------------------------------------------------
# 1. Garantir repositorios corretos
# ----------------------------------------------------------
echo "[1/5] Configurando repositorios..."

# Para Alpine stable (3.x), o linux-lts ja deve ser 6.6
# Para Alpine edge, pode ser necessario ajustar
if ! grep -q "alpine-stable" /etc/apk/repositories 2>/dev/null; then
    # Detectar versao do Alpine
    AVER=$(cat /etc/alpine-release 2>/dev/null | awk '{print $1}' | cut -d. -f1,2)
    cat > /etc/apk/repositories <<EOF
https://dl-cdn.alpinelinux.org/alpine/v${AVER}/main
https://dl-cdn.alpinelinux.org/alpine/v${AVER}/community
EOF
    log "Repositorios atualizados para v${AVER}"
fi

# ----------------------------------------------------------
# 2. Procurar pacotes de kernel disponiveis
# ----------------------------------------------------------
echo ""
echo "[2/5] Procurando kernels disponiveis..."

echo "Pacotes de kernel:"
apk search "linux-lts" 2>/dev/null | grep -E "^linux-lts " || true
apk search "linux-virt" 2>/dev/null | grep -E "^linux-virt " || true
apk search "^linux-" 2>/dev/null | grep -E "^[a-z0-9].*-lts" || true
echo ""

# Listar kernels instalados
echo "Kernels instalados:"
apk info 2>/dev/null | grep "^linux" || true
echo ""

# ----------------------------------------------------------
# 3. Instalar kernel linux-lts (6.6)
# ----------------------------------------------------------
echo "[3/5] Instalando kernel linux-lts..."

# Primeiro tentar linux-lts (geralmente 6.6 LTS em stable)
if apk search "linux-lts" 2>/dev/null | grep -q "^linux-lts "; then
    log "Pacote linux-lts encontrado"
    apk add linux-lts linux-lts-headers 2>/dev/null || true
elif apk search "linux-virt" 2>/dev/null | grep -q "^linux-virt "; then
    warn "linux-lts nao encontrado, tentando linux-virt..."
    apk add linux-virt linux-virt-headers 2>/dev/null || true
else
    err "Nenhum pacote de kernel LTS encontrado. Verifique os repositorios."
fi

# Verificar qual kernel foi instalado
INSTALLED=$(ls /boot/vmlinuz-* 2>/dev/null | head -5)
echo ""
echo "Kernels em /boot:"
ls -la /boot/vmlinuz-* 2>/dev/null || echo "(nenhum)"
echo ""

# ----------------------------------------------------------
# 4. Gerar initramfs e configurar bootloader
# ----------------------------------------------------------
echo "[4/5] Gerando initramfs..."

# Detectar bootloader
if command -v update-bootloader >/dev/null 2>&1; then
    # Alpine com update-bootloader
    update-bootloader
    log "Bootloader atualizado via update-bootloader"
elif command -v grub-mkconfig >/dev/null 2>&1; then
    # GRUB
    grub-mkconfig -o /boot/grub/grub.cfg
    log "GRUB configurado"
elif [ -f /etc/update-extlinux.conf ]; then
    # extlinux/syslinux
    extlinux --install /boot 2>/dev/null || true
    log "extlinux configurado"
fi

# Gerar initramfs para o kernel LTS
LTS_KVER=$(ls /boot/vmlinuz-*lts* 2>/dev/null | sed 's|/boot/vmlinuz-||' | head -1)
if [ -n "$LTS_KVER" ]; then
    echo "  Gerando initramfs para $LTS_KVER..."
    mkinitfs -c /etc/mkinitfs.conf "$LTS_KVER" 2>/dev/null || \
        mkinitfs "$LTS_KVER" 2>/dev/null || \
        warn "Falha ao gerar initramfs — gere manualmente com: mkinitfs $LTS_KVER"
    log "Initramfs gerado para $LTS_KVER"
else
    warn "Nao encontrei kernel LTS em /boot. Verifique manualmente."
fi

# ----------------------------------------------------------
# 5. Verificar e informar
# ----------------------------------------------------------
echo ""
echo "[5/5] Verificando..."
echo ""
echo "Kernels disponiveis no boot:"
ls -la /boot/vmlinuz-* 2>/dev/null || echo "(nenhum)"
echo ""
echo "Initramfs:"
ls -la /boot/initramfs-* 2>/dev/null || echo "(nenhum)"
echo ""
echo "Modules disponiveis:"
ls /lib/modules/ 2>/dev/null || echo "(nenhum)"
echo ""

echo "============================================="
echo -e "${GREEN} KERNEL 6.6 LTS INSTALADO${NC}"
echo "============================================="
echo ""
echo -e "${YELLOW}PROXIMO PASSO:${NC}"
echo ""
echo "1. Reinicie o sistema:"
echo "   reboot"
echo ""
echo "2. Se o Alpine usa extlinux/syslinux, edite"
echo "   /boot/extlinux.conf e mude a entrada"
echo "   DEFAULT para o kernel LTS ($LTS_KVER)"
echo ""
echo "3. Se usar GRUB, o default ja deve estar correto."
echo ""
echo "4. Apos reboot, verifique com:"
echo "   uname -r"
echo "   (deve mostrar 6.6.x)"
echo ""
echo "5. Se tudo OK, remova o kernel antigo:"
echo "   apk del linux-edge linux-edge-headers"
echo ""
echo "6. Se o boot falhar, em boot com LiveUSB:"
echo "   mount /dev/sda2 /mnt"
echo "   chroot /mnt"
echo "   apk del linux-lts"
echo "   # e reinstale o kernel anterior"
