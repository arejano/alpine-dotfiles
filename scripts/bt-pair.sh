#!/bin/sh
# bt-pair.sh — Pareamento MX Keys Mini (com estabilizacao do dongle)
# Execute como root: sh ./bt-pair.sh

[ "$(id -u)" -ne 0 ] && { echo "Execute como root"; exit 1; }

LOG="/tmp/bt-pair.log"
FIFO="/tmp/bt-fifo"
TIMEOUT=90

cleanup() {
    rm -f "$FIFO"
    kill $BT_PID 2>/dev/null || true
    wait $BT_PID 2>/dev/null || true
}
trap cleanup EXIT

rm -f "$FIFO"
mkfifo "$FIFO"
> "$LOG"

KVER=$(uname -r)
echo "========================================"
echo " PAREAMENTO MX KEYS MINI"
echo " Kernel: $KVER"
echo " $(date)"
echo "========================================"
echo ""

# ----------------------------------------------------------
# 0. Parar servicos que podem interferir
# ----------------------------------------------------------
echo "[0] Parando servicos conflitantes..."
rc-service bt-autoconnect stop 2>/dev/null || true

# ----------------------------------------------------------
# 1. Estabilizar o dongle — desabilitar autosuspend via sysfs
# ----------------------------------------------------------
echo "[1] Estabilizando dongle USB..."

for prod in /sys/bus/usb/devices/*/product; do
    if grep -q "USB2.0-BT" "$prod" 2>/dev/null; then
        USB_DIR=$(dirname "$prod")
        echo 'on' > "$USB_DIR/power/control" 2>/dev/null || true
        echo -1 > "$USB_DIR/power/autosuspend" 2>/dev/null || true
        echo 0 > "$USB_DIR/power/autosuspend_delay_ms" 2>/dev/null || true
        echo "  Autosuspend desabilitado em $USB_DIR"
    fi
done

# ----------------------------------------------------------
# 2. Descarregar e recarregar modulo btusb (reset limpo)
# ----------------------------------------------------------
echo "[2] Resetando modulo btusb..."

modprobe -r btusb 2>/dev/null || true
sleep 2
modprobe btusb 2>/dev/null || true
modprobe btrtl 2>/dev/null || true
sleep 3

# ----------------------------------------------------------
# 3. Esperar controller estabilizar (nao ficar em ciclo)
# ----------------------------------------------------------
echo "[3] Aguardando controller estabilizar..."

STABLE=0
CYCLES=0
PREV_STATE=""
for i in $(seq 1 15); do
    sleep 1
    STATE=$(bluetoothctl show 2>/dev/null | grep "Powered:" | awk '{print $2}')

    if [ "$STATE" = "$PREV_STATE" ] && [ -n "$STATE" ]; then
        STABLE=$((STABLE + 1))
    else
        STABLE=0
        CYCLES=$((CYCLES + 1))
    fi
    PREV_STATE="$STATE"

    if [ "$STABLE" -ge 3 ]; then
        echo "  Controller estavel apos ${i}s (${CYCLES} ciclos iniciais)"
        break
    fi
    printf "\r  Aguardando... %ds (state: %s) " "$i" "${STATE:-none}"
done
echo ""

if [ "$STABLE" -lt 3 ]; then
    echo "  AVISO: Controller pode nao estar estavel. Continuando mesmo assim..."
fi

# Verificar se o controller existe
if ! bluetoothctl show 2>/dev/null | grep -q "Controller"; then
    echo "ERRO: Nenhum controller encontrado apos estabilizacao"
    echo "Tente: modprobe btusb && sleep 3"
    exit 1
fi

echo ""
echo "Controller:"
bluetoothctl show 2>/dev/null | head -3
echo ""

# ----------------------------------------------------------
# 4. Iniciar bluetoothctl
# ----------------------------------------------------------
echo "[4] Iniciando bluetoothctl..."

tail -f "$FIFO" | bluetoothctl > "$LOG" 2>&1 &
BT_PID=$!

exec 3>"$FIFO"

send() {
    echo "$1" >&3
    sleep "$2"
}

send "power on" 1
send "pairable on" 0.5
send "agent on" 0.5
send "default-agent" 0.5

# ----------------------------------------------------------
# 5. Escanear
# ----------------------------------------------------------
echo "[5] Escanear por $TIMEOUT segundos..."
echo ">>> Coloque o teclado em modo pareamento (segure 1 por 3s) <<<"
echo ""

send "scan on" 0.5

ELAPSED=0
FOUND_MAC=""
while [ $ELAPSED -lt $TIMEOUT ] && [ -z "$FOUND_MAC" ]; do
    sleep 2
    ELAPSED=$((ELAPSED + 2))

    # Verificar se o controller ainda existe (ciclo de reset)
    if ! bluetoothctl show 2>/dev/null | grep -q "Controller"; then
        echo ""
        echo "  AVISO: Controller sumiu! Aguardando reciclo..."
        sleep 5
    fi

    send "devices" 0.3
    sleep 0.5

    FOUND_MAC=$(grep -i "MX Keys" "$LOG" | grep "^Device " | tail -1 | awk '{print $2}')

    if [ -z "$FOUND_MAC" ]; then
        FOUND_MAC=$(grep -i "Keyboard" "$LOG" | grep "^Device " | tail -1 | awk '{print $2}')
    fi

    printf "\r  Escaneando... %ds/%ds " $ELAPSED $TIMEOUT
done
echo ""

if [ -z "$FOUND_MAC" ]; then
    echo "MX Keys Mini nao encontrado."
    echo ""
    echo "Dispositivos detectados:"
    grep "^Device " "$LOG" 2>/dev/null | tee -a "$LOG" || echo "(nenhum)"
    echo ""
    echo "Log: $LOG"
    exit 1
fi

echo ""
echo ">>> MX Keys Mini encontrado: $FOUND_MAC <<<"
echo ""

# ----------------------------------------------------------
# 6. Parear
# ----------------------------------------------------------
echo "[6] Pareando..."
send "pair $FOUND_MAC" 3

# Verificar se pediu PIN/codigo
if grep -q "Request confirmation" "$LOG" || grep -q "Confirm PIN" "$LOG"; then
    PIN=$(grep -oP '\d{6}' "$LOG" | tail -1)
    echo ""
    echo "=========================================="
    echo " CODIGO DE PAREAMENTO: $PIN"
    echo ""
    echo " Digite $PIN no teclado MX Keys Mini"
    echo " e pressione Enter"
    echo "=========================================="
    echo ""
    sleep 15
fi

# Confiar
echo "[7] Confiando..."
send "trust $FOUND_MAC" 1

# Conectar
echo "[8] Conectando..."
send "connect $FOUND_MAC" 3

# Status
send "info $FOUND_MAC" 1
sleep 1

send "scan off" 0.5

exec 3>&-

echo ""
echo "========================================"
echo " RESULTADO"
echo "========================================"
echo ""

if grep -q "Connection successful" "$LOG" || grep -q "state: connected" "$LOG"; then
    echo "PAREAMENTO E CONEXAO OK!"
    rc-service bt-autoconnect start 2>/dev/null || true
else
    echo "Pareamento pode ter falhado."
    echo ""
    echo "Eventos relevantes:"
    grep -E "pair|connect|error|fail|PIN|confirm|New|Device" "$LOG" | tail -20
    echo ""
    echo "Log completo: $LOG"
    echo ""
    echo "Se o dongle continua reiniciando, o problema e o kernel $KVER"
    echo "com o RTL8761BU. Considere:"
    echo "  - Usar kernel 6.6 LTS (edgeTesting)"
    echo "  - Atualizar firmware do dongle"
fi
