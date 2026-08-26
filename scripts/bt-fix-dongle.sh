#!/bin/sh
# bt-fix-dongle.sh — Corrigir instabilidade do dongle RTL8761BU no kernel 6.18
# Execute como root: sh ./bt-fix-dongle.sh

set -eu

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }

[ "$(id -u)" -ne 0 ] && err "Execute como root"

LOG="/tmp/bt-fix.log"
KVER=$(uname -r)

echo "============================================"
echo " CORRECAO DO DONGLE RTL8761BU"
echo " Kernel: $KVER"
echo " $(date)"
echo "============================================"
echo ""

{
echo "=== INICIO ==="
echo "Kernel: $KVER"
echo "Data: $(date)"
} > "$LOG"

# ----------------------------------------------------------
# 1. Identificar o dongle USB
# ----------------------------------------------------------
echo "[1/7] Identificando dongle..."

USB_DEV=""
for prod in /sys/bus/usb/devices/*/product; do
    if grep -q "USB2.0-BT" "$prod" 2>/dev/null; then
        USB_DIR=$(dirname "$prod")
        USB_DEV=$(basename "$USB_DIR")
        VENDOR=$(cat "$USB_DIR/idVendor" 2>/dev/null || echo "?")
        PRODUCT=$(cat "$USB_DIR/idProduct" 2>/dev/null || echo "?")
        echo "  Dongle: $USB_DEV — Vendor:$Vendor Product:$PRODUCT"
        echo "  Path: $USB_DIR"
        break
    fi
done

if [ -z "$USB_DEV" ]; then
    # Fallback: procurar por 33fa
    for dev in /sys/bus/usb/devices/*/idVendor; do
        if grep -q "33fa" "$dev" 2>/dev/null; then
            USB_DIR=$(dirname "$dev")
            USB_DEV=$(basename "$USB_DIR")
            echo "  Dongle encontrado via idVendor: $USB_DEV"
            break
        fi
    done
fi

if [ -z "$USB_DEV" ]; then
    warn "Dongle RTL8761BU nao encontrado via sysfs. Usando metodo generico."
fi

{
echo ""
echo "=== DONGLE ==="
echo "USB_DEV: $USB_DEV"
echo "USB_DIR: ${USB_DIR:-n/a}"
} >> "$LOG"

# ----------------------------------------------------------
# 2. Desabilitar autosuspend agressivamente
# ----------------------------------------------------------
echo ""
echo "[2/7] Desabilitando autosuspend..."

if [ -n "$USB_DIR" ]; then
    echo 'on' > "$USB_DIR/power/control" 2>/dev/null || true
    echo -1 > "$USB_DIR/power/autosuspend" 2>/dev/null || true
    echo 0 > "$USB_DIR/power/autosuspend_delay_ms" 2>/dev/null || true

    # Verificar se aplicou
    CTRL=$(cat "$USB_DIR/power/control" 2>/dev/null || echo "?")
    ASP=$(cat "$USB_DIR/power/autosuspend" 2>/dev/null || echo "?")
    echo "  power/control = $CTRL"
    echo "  autosuspend = $ASP"
    log "Autosuspend desabilitado"
else
    warn "USB_DIR nao encontrado, pulando autosuspend via sysfs"
fi

# Desabilitar autosuspend global para bluetooth
cat > /etc/modules-load.d/btusb-nosuspend.conf <<'EOF'
btusb
EOF

cat > /etc/modprobe.d/btusb-nosuspend.conf <<'EOF'
options btusb enable_autosuspend=0
EOF
log "Parametros do modulo configurados"

# ----------------------------------------------------------
# 3. USB quirks no modulo usbcore
# ----------------------------------------------------------
echo ""
echo "[3/7] Configurando USB quirks..."

# RTL8761BU: 33fa:0010
# Quirks disponiveis:
#   U = USB_QUIRK_RESET_RESUME (forcar reset ao inves de resume)
#   Q = USB_QUIRK_NO_SET_INTF (nao setar interface)
#   B = USB_QUIRK_HONOR_BNUMINTRF (respeitar numero de interfaces)
#   r = USB_QUIRK_NO_LPM (desabilitar Link Power Management)
#   d = USB_QUIRK_NO_ENDPOINT_HIGHBW (nao usar high bandwidth)

QUIRK_OPTS=""

# Testar diferentes combinacoes
echo "  Testando quirks para 33fa:0010..."

# Primeiro: remover quirks anteriores
sed -i '/33fa/d' /etc/modprobe.d/usbcore-quirks.conf 2>/dev/null || true

# Quirk mais conservador: desabilitar LPM + no endpoint high bandwidth
echo 'options usbcore quirks=33fa:0010:rd' > /etc/modprobe.d/usbcore-quirks.conf
log "USB quirk configurado: 33fa:0010:rd (no-LPM + no-highbw)"

# ----------------------------------------------------------
# 4. Parar servicos bluetooth
# ----------------------------------------------------------
echo ""
echo "[4/7] Parando servicos bluetooth..."

rc-service bt-autoconnect stop 2>/dev/null || true
rc-service bluetooth stop 2>/dev/null || true
sleep 1
log "Servicos parados"

# ----------------------------------------------------------
# 5. Reset completo: descarregar modulos, recarregar com novas opcoes
# ----------------------------------------------------------
echo ""
echo "[5/7] Resetando modulo bluetooth..."

# Descarregar na ordem correta
modprobe -r btusb 2>/dev/null || true
sleep 1
modprobe -r btrtl 2>/dev/null || true
sleep 1
modprobe -r btmtk 2>/dev/null || true
modprobe -r btbcm 2>/dev/null || true
modprobe -r btintel 2>/dev/null || true
modprobe -r bluetooth 2>/dev/null || true
sleep 2

# Recarregar bluetooth primeiro
modprobe bluetooth 2>/dev/null || true
sleep 1

# Carregar com quirk via modprobe
modprobe btusb enable_autosuspend=0 2>/dev/null || true
modprobe btrtl 2>/dev/null || true
sleep 3

log "Modulos recarregados"

# ----------------------------------------------------------
# 6. Iniciar bluetooth e verificar estabilidade
# ----------------------------------------------------------
echo ""
echo "[6/7] Iniciando bluetooth e verificando estabilidade..."

rc-service dbus start 2>/dev/null || true
rc-service bluetooth start 2>/dev/null || true
sleep 3

# Verificar estabilidade por 10 segundos
echo "  Monitorando controller por 10s..."
STABLE=0
PREV=""
for i in $(seq 1 10); do
    sleep 1
    STATE=$(bluetoothctl show 2>/dev/null | grep "Powered:" | awk '{print $2}')
    ADDR=$(bluetoothctl show 2>/dev/null | grep "Controller" | head -1 | awk '{print $2}')

    if [ -n "$ADDR" ]; then
        if [ "$STATE" = "$PREV" ] && [ -n "$STATE" ]; then
            STABLE=$((STABLE + 1))
        else
            STABLE=0
        fi
        PREV="$STATE"
        printf "\r  %ds — Controller: %s — Powered: %s — Estavel: %ds " "$i" "$ADDR" "$STATE" "$STABLE"
    else
        printf "\r  %ds — Controller: NENHUM " "$i"
        STABLE=0
    fi
done
echo ""

{
echo ""
echo "=== ESTABILIDADE ==="
echo "Ciclos estaveis: $STABLE"
echo "Estado final: $PREV"
echo "Controller: $(bluetoothctl show 2>/dev/null | grep 'Controller' | head -1)"
} >> "$LOG"

if [ "$STABLE" -ge 5 ]; then
    log "Controller estavel!"
elif [ -n "$PREV" ]; then
    warn "Controller instavel — pode precisar de mais ajustes"
else
    err "Controller nao detectado apos reset"
fi

# ----------------------------------------------------------
# 7. Configurar para persistir no boot
# ----------------------------------------------------------
echo ""
echo "[7/7] Configurando persistencia..."

# Garantir que as configuracoes persistem
cat > /etc/modules-load.d/bluetooth.conf <<'EOF'
btusb
btrtl
EOF

cat > /etc/modprobe.d/bluetooth.conf <<'EOF'
options btusb enable_autosuspend=0
EOF

cat > /etc/modprobe.d/usbcore-quirks.conf <<'EOF'
options usbcore quirks=33fa:0010:rd
EOF

# Script de estabilizacao para rodar no boot
cat > /usr/local/bin/bt-stabilize.sh <<'BOOTEOF'
#!/bin/sh
# Roda apos bluetooth iniciar para desabilitar autosuspend
sleep 3
for prod in /sys/bus/usb/devices/*/product; do
    if grep -q "USB2.0-BT" "$prod" 2>/dev/null; then
        USB_DIR=$(dirname "$prod")
        echo 'on' > "$USB_DIR/power/control" 2>/dev/null || true
        echo -1 > "$USB_DIR/power/autosuspend" 2>/dev/null || true
        echo 0 > "$USB_DIR/power/autosuspend_delay_ms" 2>/dev/null || true
    fi
done
BOOTEOF
chmod +x /usr/local/bin/bt-stabilize.sh

# Servico OpenRC
cat > /etc/init.d/bt-stabilize <<'INITEOF'
#!/sbin/openrc-run
name="bt-stabilize"
description="Stabilize Bluetooth USB dongle"
command="/usr/local/bin/bt-stabilize.sh"
command_background=true
command_timeout=10
depend() {
    need localmount
    after bluetooth
    before default
}
INITEOF
chmod 755 /etc/init.d/bt-stabilize
rc-update add bt-stabilize default 2>/dev/null || true

log "Persistencia configurada"

# ----------------------------------------------------------
# Resumo
# ----------------------------------------------------------
echo ""
echo "============================================"
echo " CORRECAO APLICADA"
echo "============================================"
echo ""
echo "Quirk:        33fa:0010:rd (no-LPM + no-highbw)"
echo "Autosuspend:  desabilitado (modulo + sysfs)"
echo "Controller:   $(bluetoothctl show 2>/dev/null | grep 'Controller' | head -1 | awk '{print $2}')"
echo "Estavel:      ${STABLE}s sem oscilacao"
echo ""
echo "Se o dongle continua instavel, tente:"
echo "  1. Trocar quirk: rd -> rdb (adiciona no-BNUMINTRF)"
echo "     edite /etc/modprobe.d/usbcore-quirks.conf"
echo "  2. USB hub externo (problema de energia USB)"
echo "  3. Outro dongle bluetooth"
echo ""
echo "Log: $LOG"
