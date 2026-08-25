#!/bin/sh
# bt-diag.sh — Diagnostico Bluetooth
# Execute como root e cole o conteudo de /tmp/bt-diag.log

LOG="/tmp/bt-diag.log"

{
echo "=== DATA ==="
date

echo ""
echo "=== USB ==="
lsusb 2>&1

echo ""
echo "=== DMESG (btusb/btrtl/firmware/rtl) ==="
dmesg 2>&1 | grep -i -E "btusb|btrtl|bluetooth|firmware|rtl" || echo "(nenhum resultado)"

echo ""
echo "=== DMESG completo (ultimas 50 linhas) ==="
dmesg 2>&1 | tail -50

echo ""
echo "=== BLUETOOTHCTL SHOW ==="
bluetoothctl show 2>&1 || echo "(bluetoothctl falhou)"

echo ""
echo "=== MODULOS CARREGADOS ==="
lsmod 2>&1 | grep -i -E "btusb|btrtl|bluetooth" || echo "(nenhum modulo BT carregado)"

echo ""
echo "=== FIRMWARE ==="
ls -la /lib/firmware/rtl_bt/ 2>&1 || echo "(diretorio nao existe)"

echo ""
echo "=== MODPROBE BTUSB ==="
modprobe btusb 2>&1; echo "exit: $?"
modprobe btrtl 2>&1; echo "exit: $?"

echo ""
echo "=== BLUETOOTHCTL SHOW APOS MODPROBE ==="
bluetoothctl show 2>&1 || echo "(bluetoothctl falhou)"

echo ""
echo "=== SERVICOS ==="
rc-service -l 2>&1 | grep -i bluetooth || echo "(nenhum servico bluetooth)"
rc-status 2>&1 | grep -i bluetooth || echo "(servicos nao rodando)"

} > "$LOG" 2>&1

echo "Log salvo em $LOG"
