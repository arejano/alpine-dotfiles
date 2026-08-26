#!/bin/sh
LOG="/tmp/kernel-diag.log"
{
echo "=== ALPINE VERSION ==="
cat /etc/alpine-release 2>/dev/null || echo "(erro)"

echo ""
echo "=== REPOSITORIOS ==="
cat /etc/apk/repositories 2>/dev/null || echo "(erro)"

echo ""
echo "=== KERNEL ATUAL ==="
uname -r

echo ""
echo "=== MODULOS INSTALADOS ==="
ls /lib/modules/ 2>/dev/null || echo "(nenhum)"

echo ""
echo "=== PACOTES LINUX INSTALADOS ==="
apk info 2>/dev/null | grep linux || echo "(nenhum)"

echo ""
echo "=== KERNEL PACKAGES DISPONIVEIS ==="
apk search "linux" 2>/dev/null | grep -E "^linux-(lts|virt|edge|aarch|main)" | head -20 || echo "(nenhum)"

echo ""
echo "=== TODOS OS PACOTES linux- ==="
apk search "^linux-" 2>/dev/null | head -30 || echo "(nenhum)"

echo ""
echo "=== APK ESTIVEIS ==="
apk update 2>&1 | tail -5

echo ""
echo "=== BOOT ==="
ls /boot/vmlinuz-* 2>/dev/null || echo "(nenhum)"
ls /boot/initramfs-* 2>/dev/null || echo "(nenhum)"

echo ""
echo "=== BOOTLOADER ==="
ls /boot/extlinux.conf 2>/dev/null && cat /boot/extlinux.conf 2>/dev/null || echo "(sem extlinux)"
ls /boot/grub/grub.cfg 2>/dev/null && echo "(grub existe)" || echo "(sem grub)"
ls /boot/syslinux.cfg 2>/dev/null && echo "(syslinux existe)" || echo "(sem syslinux)"

} > "$LOG" 2>&1
echo "Log salvo em $LOG"
