#!/bin/sh
# alpine-bt-setup.sh — Setup Bluetooth Realtek RTL8761BU + Logitech MX Keys Mini
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

[ "$(id -u)" -ne 0 ] && err "Execute como root: sh ./alpine-bt-setup.sh"

# ============================================================
# 0. Verificar Alpine 3.18 / kernel 6.6
# ============================================================
KVER=$(uname -r)
case "$KVER" in
    6.6*) log "Kernel $KVER — compativel" ;;
    *)    warn "Kernel $KVER detectado. Este script foi feito para 6.6.x. Continuando mesmo assim..." ;;
esac

# ============================================================
# 1. Configurar repositorios do Alpine 3.18
# ============================================================
echo "[1/12] Configurando repositorios..."

if ! grep -q "alpine-stable" /etc/apk/repositories 2>/dev/null; then
    cat > /etc/apk/repositories <<'EOF'
https://dl-cdn.alpinelinux.org/alpine/v3.18/main
https://dl-cdn.alpinelinux.org/alpine/v3.18/community
EOF
fi
log "Repositorios configurados"

# ============================================================
# 2. Atualizar sistema e instalar pacotes essenciais
# ============================================================
echo "[2/12] Instalando pacotes essenciais..."

apk update
apk upgrade
apk add \
    bluez \
    bluez-openrc \
    linux-firmware \
    linux-headers \
    dbus \
    usbutils \
    greetd \
    greetd-tuigreet \
    dwm \
    xorg-server \
    xinit \
    mesa-dri-gallium \
    foot

log "Pacotes essenciais instalados"

# ============================================================
# 3. Verificar se firmware RTL8761BU existe
# ============================================================
echo "[3/12] Verificando firmware Realtek RTL8761BU..."

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

    # Tentar extrair do pacote linux-firmware atualizado
    apk fetch linux-firmware 2>/dev/null || true
    if [ -f /var/cache/apk/x86_64/linux-firmware*.apk ]; then
        cd /tmp
        apk add --allow-untrusted /var/cache/apk/x86_64/linux-firmware*.apk 2>/dev/null || true
    fi

    # Se ainda nao existe, buscar do firmware-main repo
    if [ ! -f "$FWDIR/rtl8761bu_fw.bin" ]; then
        warn "Baixando firmware do Linux firmware repo..."
        mkdir -p /tmp/fw-dl
        for fw in rtl8761bu_fw.bin rtl8761bu_config.bin; do
            wget -q "https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/rtl_bt/$fw" \
                -O "$FWDIR/$fw" 2>/dev/null || warn "Falha ao baixar $fw — baixe manualmente"
        done
    fi

    # Verificar novamente
    for fw in rtl8761bu_fw.bin rtl8761bu_config.bin; do
        [ -f "$FWDIR/$fw" ] || err "Firmware $fw ausente — baixe manualmente de https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/tree/rtl_bt"
    done
fi

# Garantir permissao correta
chmod 644 "$FWDIR"/rtl8761bu*.bin
log "Firmware RTL8761BU pronto em $FWDIR"

# ============================================================
# 4. Carregar modulos btusb + btrtl no boot
# ============================================================
echo "[4/12] Configurando modulos do kernel..."

cat > /etc/modules-load.d/bluetooth.conf <<'EOF'
btusb
btrtl
EOF

# Carregar agora tambem (se nao estiverem)
modprobe btusb 2>/dev/null || true
modprobe btrtl 2>/dev/null || true
log "Modulos btusb + btrtl configurados para boot"

# ============================================================
# 5. Prevenir conflito com modulo carregado genericamente
# ============================================================
echo "[5/12] Garantindo que btusb nao e bloqueado..."

# Em alguns kernels, modulo generico bluetooth pode assumir antes do btusb
cat > /etc/modprobe.d/bluetooth.conf <<'EOF'
# Garantir carregamento correto do btusb para dongles Realtek USB
options btusb enable_autosuspend=0
EOF
log "Configuracao de modulo OK"

# ============================================================
# 6. Configurar e iniciar servicos bluetooth
# ============================================================
echo "[6/12] Habilitando servicos bluetooth..."

# Adicionar servicos necessarios ao boot
rc-update add dbus default 2>/dev/null || true
rc-update add bluetooth default

# Garantir que dbus esta rodando
rc-service dbus start 2>/dev/null || true

# Iniciar bluetooth agora
rc-service bluetooth start
log "Servicos bluetooth habilitados e iniciados"

# ============================================================
# 7. Configurar bluetoothd
# ============================================================
echo "[7/12] Configurando bluetoothd..."

cat > /etc/conf.d/bluetooth <<'EOF'
# Bluetooth daemon configuration
BLUEZ_ARGS="--experimental"
EOF

# Reiniciar com experimental para suporte a LE features
rc-service bluetooth stop 2>/dev/null || true
sleep 1
rc-service bluetooth start
log "bluetoothd rodando com --experimental"

# ============================================================
# 8. Verificar dongle detectado
# ============================================================
echo "[8/12] Verificando dongle Bluetooth..."

sleep 2

if hciconfig | grep -q "hci0"; then
    HCI_ADDR=$(hciconfig hci0 | grep "BD Address" | awk '{print $3}')
    log "Dongle HCI detectado: hci0 — $HCI_ADDR"
else
    err "Nenhum dongle HCI detectado. Verifique se o dongle esta plugado e modprobe btusb carregou."
fi

# Ativar HCI
hciconfig hci0 up
log "Interface hci0 ativada"

# ============================================================
# 9. Parear Logitech MX Keys Mini
# ============================================================
echo "[9/12] Pareando Logitech MX Keys Mini..."

echo ""
echo "=========================================="
echo " PASSO PARA PAREAR O TECLADO:"
echo "=========================================="
echo ""
echo "1. No teclado MX Keys Mini, pressione o botao de"
echo "   pareamento (1, 2 ou 3) por 3 segundos ate"
echo "   a luz comecar a piscar"
echo ""
echo "2. Execute os comandos abaixo:"
echo ""
echo "   bluetoothctl"
echo "     [bluetooth]# power on"
echo "     [bluetooth]# agent on"
echo "     [bluetooth]# default-agent"
echo "     [bluetooth]# scan on"
echo ""
echo "   Aguarde aparecer o MX Keys Mini na lista."
echo "   Copie o MAC address (ex: D5:61:99:B4:ED:99)"
echo ""
echo "     [bluetooth]# pair XX:XX:XX:XX:XX:XX"
echo "     [bluetooth]# trust XX:XX:XX:XX:XX:XX"
echo "     [bluetooth]# connect XX:XX:XX:XX:XX:XX"
echo "     [bluetooth]# quit"
echo ""
echo "3. Depois de pareado, o teclado reconecta"
echo "   automaticamente no boot."
echo ""
echo "=========================================="

# Criar script auxiliar de reconexao automatica
cat > /usr/local/bin/bt-autoconnect.sh <<'BTSCRIPT'
#!/bin/sh
# Reconectar dispositivos bluetooth conhecidos no boot
sleep 5

if ! command -v bluetoothctl >/dev/null 2>&1; then
    exit 0
fi

for dev in $(bluetoothctl paired-devices 2>/dev/null | awk '{print $2}'); do
    bluetoothctl connect "$dev" 2>/dev/null &
done
BTSCRIPT
chmod +x /usr/local/bin/bt-autoconnect.sh

# Criar servico OpenRC para autoconnect no boot
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
# 10. Configurar greetd + tuigreet (login manager)
# ============================================================
echo "[10/12] Configurando greetd com tuigreet..."

# Criar diretorio de sessoes
mkdir -p /usr/share/wayland-sessions
mkdir -p /usr/share/xsessions

# Sessao: Sway
cat > /usr/share/wayland-sessions/sway.desktop <<'EOF'
[Desktop Entry]
Name=Sway
Comment=Wyland compositor
Exec=sway
Type=Application
DesktopNames=sway
EOF

# Sessao: DWM (via startx)
cat > /usr/share/xsessions/dwm.desktop <<'EOF'
[Desktop Entry]
Name=DWM
Comment=Dynamic Window Manager
Exec=startx ~/.xinitrc-dwm
Type=Application
DesktopNames=dwm
EOF

# Sessao: TTY (shell direto)
cat > /usr/share/wayland-sessions/tty.desktop <<'EOF'
[Desktop Entry]
Name=TTY
Comment=Shell direto (TTY)
Exec=/bin/login
Type=Application
DesktopNames=TTY
EOF

# Configuracao do greetd
cat > /etc/greetd/config.toml <<'EOF'
[terminal]
vt = "next"

[default_session]
command = "tuigreet --user-menu --user-menu-min-uid 1000 --remember --sessions /usr/share/wayland-sessions:/usr/share/xsessions --time --issue --asterisks"
user = "greeter"
EOF

# Configuracao do usuario greeter
chown -R greeter:greeter /var/lib/greetd 2>/dev/null || true

log "greetd configurado com sessoes: Sway, DWM, TTY"

# Criar xinitrc para DWM
cat > /root/.xinitrc-dwm <<'XINIT'
#!/bin/sh
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=dwm
exec dwm
XINIT
chmod +x /root/.xinitrc-dwm
log "xinitrc-dwm criado"

# ============================================================
# 11. Habilitar greetd no boot
# ============================================================
echo "[11/12] Habilitando greetd no boot..."

rc-update add greetd default
log "greetd habilitado no boot"

# ============================================================
# 12. Verificar servicos
# ============================================================
echo "[12/12] Verificando servicos..."

rc-status default 2>/dev/null | grep -E "bluetooth|greetd|bt-autoconnect" || true
log "Verificacao concluida"

# ============================================================
# Resumo
# ============================================================
echo ""
echo "============================================="
echo -e "${GREEN} SETUP CONCLUIDO${NC}"
echo "============================================="
echo ""
echo "=== Bluetooth ==="
echo "Dongle:    Realtek RTL8761BU (33fa:0010)"
echo "Driver:    btusb + btrtl"
echo "Firmware:  rtl8761bu_fw.bin"
echo "HCI:       hci0 ativo"
echo "Servicos:  bluetooth + bt-autoconnect"
echo ""
echo "=== Login Manager ==="
echo "greeter:   greetd + tuigreet"
echo "Sessoes:   Sway (Wayland) | DWM (X11) | TTY"
echo "Selecao:   F2 no tuigreet para trocar sessao"
echo ""
echo -e "${YELLOW}PROXIMOS PASSOS:${NC}"
echo "1. Pareie o teclado com 'bluetoothctl' (passo acima)"
echo "2. Reinicie o sistema"
echo "3. No greetd, F2 troca entre sessoes (Sway/DWM/TTY)"
echo "4. O teclado reconecta automaticamente no boot"
echo ""
echo "Para verificar no futuro:"
echo "  bluetoothctl info          # ver dispositivos"
echo "  bluetoothctl devices       # listar dispositivos"
echo "  hciconfig -a               # status dongle"
echo "  dmesg | tail -10           # verificar firmware"
