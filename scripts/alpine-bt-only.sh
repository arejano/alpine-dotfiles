#!/bin/sh
# alpine-bt-only.sh — Setup Bluetooth Realtek RTL8761BU (dongle only)
# Compatível com Alpine 3.18 (kernel 6.6 LTS)
# Execute como root no Alpine recém-instalado

set -eu

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }

[ "$(id -u)" -ne 0 ] && err "Execute como root: sh ./alpine-bt-only.sh"

# ============================================================
# 0. Verificar Alpine 3.18 / kernel 6.6
# ============================================================
KVER=$(uname -r)
case "$KVER" in
    6.6*) log "Kernel $KVER — compativel" ;;
    *)    warn "Kernel $KVER detectado. Continuando mesmo assim..." ;;
esac

# ============================================================
# 1. Configurar repositorios
# ============================================================
echo "[1/8] Configurando repositorios..."

if ! grep -q "alpine-stable" /etc/apk/repositories 2>/dev/null; then
    cat > /etc/apk/repositories <<'EOF'
https://dl-cdn.alpinelinux.org/alpine/v3.18/main
https://dl-cdn.alpinelinux.org/alpine/v3.18/community
EOF
fi
log "Repositorios configurados"

# ============================================================
# 2. Instalar pacotes Bluetooth
# ============================================================
echo "[2/8] Instalando pacotes Bluetooth..."

apk update
apk upgrade
apk add \
    bluez \
    bluez-openrc \
    linux-firmware \
    linux-headers \
    dbus \
    usbutils

log "Pacotes Bluetooth instalados"

# ============================================================
# 3. Verificar firmware RTL8761BU
# ============================================================
echo "[3/8] Verificando firmware Realtek RTL8761BU..."

FWDIR="/lib/firmware/rtl_bt"
mkdir -p "$FWDIR"

FW_FOUND=0
for fw in rtl8761bu_fw.bin rtl8761bu_config.bin; do
    if [ -f "$FWDIR/$fw" ]; then
        log "Firmware $fw encontrado"
        FW_FOUND=$((FW_FOUND + 1))
    fi
done

if [ "$FW_FOUND" -lt 2 ]; then
    warn "Firmware RTL8761BU nao encontrado em $FWDIR"
    warn "Baixando do repositorio linux-firmware-git..."

    apk fetch linux-firmware 2>/dev/null || true
    if [ -f /var/cache/apk/x86_64/linux-firmware*.apk ]; then
        cd /tmp
        apk add --allow-untrusted /var/cache/apk/x86_64/linux-firmware*.apk 2>/dev/null || true
    fi

    if [ ! -f "$FWDIR/rtl8761bu_fw.bin" ]; then
        warn "Baixando firmware do Linux firmware repo..."
        for fw in rtl8761bu_fw.bin rtl8761bu_config.bin; do
            wget -q "https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/rtl_bt/$fw" \
                -O "$FWDIR/$fw" 2>/dev/null || warn "Falha ao baixar $fw — baixe manualmente"
        done
    fi

    for fw in rtl8761bu_fw.bin rtl8761bu_config.bin; do
        [ -f "$FWDIR/$fw" ] || err "Firmware $fw ausente — baixe manualmente de https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/tree/rtl_bt"
    done
fi

chmod 644 "$FWDIR"/rtl8761bu*.bin
log "Firmware RTL8761BU pronto em $FWDIR"

# ============================================================
# 4. Carregar modulos btusb + btrtl no boot
# ============================================================
echo "[4/8] Configurando modulos do kernel..."

cat > /etc/modules-load.d/bluetooth.conf <<'EOF'
btusb
btrtl
EOF

modprobe btusb 2>/dev/null || true
modprobe btrtl 2>/dev/null || true
log "Modulos btusb + btrtl configurados para boot"

# ============================================================
# 5. Prevenir conflito com modulo carregado genericamente
# ============================================================
echo "[5/8] Garantindo que btusb nao e bloqueado..."

cat > /etc/modprobe.d/bluetooth.conf <<'EOF'
options btusb enable_autosuspend=0
EOF
log "Configuracao de modulo OK"

# ============================================================
# 6. Configurar e iniciar servicos bluetooth
# ============================================================
echo "[6/8] Habilitando servicos bluetooth..."

rc-update add dbus default 2>/dev/null || true
rc-update add bluetooth default

rc-service dbus start 2>/dev/null || true
rc-service bluetooth start
log "Servicos bluetooth habilitados e iniciados"

# ============================================================
# 7. Configurar bluetoothd
# ============================================================
echo "[7/8] Configurando bluetoothd..."

cat > /etc/conf.d/bluetooth <<'EOF'
BLUEZ_ARGS="--experimental"
EOF

rc-service bluetooth stop 2>/dev/null || true
sleep 1
rc-service bluetooth start
log "bluetoothd rodando com --experimental"

# ============================================================
# 8. Verificar dongle detectado
# ============================================================
echo "[8/8] Verificando dongle Bluetooth..."

sleep 2

BT_ADDR=$(bluetoothctl show 2>/dev/null | grep "Controller" | head -1 | awk '{print $2}')
if [ -n "$BT_ADDR" ]; then
    log "Dongle Bluetooth detectado: $BT_ADDR"
else
    err "Nenhum dongle Bluetooth detectado. Verifique se o dongle esta plugado e modprobe btusb carregou."
fi

bluetoothctl power on 2>/dev/null
log "Interface Bluetooth ativada"

# ============================================================
# Criar servico de reconexao automatica
# ============================================================
cat > /usr/local/bin/bt-autoconnect.sh <<'BTSCRIPT'
#!/bin/sh
sleep 5
if ! command -v bluetoothctl >/dev/null 2>&1; then
    exit 0
fi
for dev in $(bluetoothctl paired-devices 2>/dev/null | awk '{print $2}'); do
    bluetoothctl connect "$dev" 2>/dev/null &
done
BTSCRIPT
chmod +x /usr/local/bin/bt-autoconnect.sh

cat > /etc/init.d/bt-autoconnect <<'INITEOF'
#!/sbin/openrc-run
name="bt-autoconnect"
description="Auto-reconnect paired Bluetooth devices"
command="/usr/local/bin/bt-autoconnect.sh"
command_background=true
command_timeout=10
depend() {
    need localmount
    after bluetooth
    before default
}
INITEOF
chmod 755 /etc/init.d/bt-autoconnect

rc-update add bt-autoconnect default
log "Servico bt-autoconnect configurado"

# ============================================================
# Resumo
# ============================================================
echo ""
echo "============================================="
echo -e "${GREEN} SETUP BLUETOOTH CONCLUIDO${NC}"
echo "============================================="
echo ""
echo "Dongle:    Realtek RTL8761BU (33fa:0010)"
echo "Driver:    btusb + btrtl"
echo "Firmware:  rtl8761bu_fw.bin"
echo "HCI:       hci0 ativo"
echo "Servicos:  bluetooth + bt-autoconnect"
echo ""
echo -e "${YELLOW}PROXIMOS PASSOS:${NC}"
echo "1. Pareie o teclado com 'bluetoothctl':"
echo ""
echo "   bluetoothctl"
echo "     [bluetooth]# power on"
echo "     [bluetooth]# agent on"
echo "     [bluetooth]# default-agent"
echo "     [bluetooth]# scan on"
echo ""
echo "   Aguarde aparecer o dispositivo. Copie o MAC."
echo ""
echo "     [bluetooth]# pair XX:XX:XX:XX:XX:XX"
echo "     [bluetooth]# trust XX:XX:XX:XX:XX:XX"
echo "     [bluetooth]# connect XX:XX:XX:XX:XX:XX"
echo "     [bluetooth]# quit"
echo ""
echo "2. Depois de pareado, reconecta automaticamente no boot"
echo ""
echo "Verificar no futuro:"
echo "  bluetoothctl show          # status dongle"
echo "  bluetoothctl info          # ver dispositivos"
echo "  bluetoothctl devices       # listar dispositivos"
echo "  dmesg | tail -10           # verificar firmware"
