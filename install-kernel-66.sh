#!/bin/bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Execute como root: sudo bash $0${NC}"
    exit 1
fi

echo -e "${YELLOW}==> Instalando kernel 6.6 LTS (linux66)...${NC}"
pacman -S --needed --noconfirm linux66 linux66-headers

echo -e "${YELLOW}==> Gerando configuração do GRUB...${NC}"
grub-mkconfig -o /boot/grub/grub.cfg

echo -e "${YELLOW}==> Definindo kernel 6.6 como default no GRUB...${NC}"

GRUB_CFG="/etc/default/grub"

if ! grep -q "^GRUB_DEFAULT=" "$GRUB_CFG"; then
    echo "GRUB_DEFAULT=0" >> "$GRUB_CFG"
fi

ENTRY=$(grep -n "menuentry.*Linux.*6\.6\|menuentry.*linux66\|menuentry.*Manjaro.*6\.6" /boot/grub/grub.cfg | head -n1 | cut -d: -f1)

if [[ -z "$ENTRY" ]]; then
    echo -e "${YELLOW}=> Buscando entrada do kernel 6.6 no GRUB...${NC}"
    ENTRY=$(awk '/menuentry / { count++; if ($0 ~ /6\.6/) { print count-1; exit } }' /boot/grub/grub.cfg)
fi

if [[ -n "$ENTRY" ]]; then
    sed -i "s/^GRUB_DEFAULT=.*/GRUB_DEFAULT=$ENTRY/" "$GRUB_CFG"
    echo -e "${GREEN}==> GRUB_DEFAULT definido como $ENTRY${NC}"
else
    echo -e "${YELLOW}=> Não encontrei entrada exata. Listando entradas do GRUB:${NC}"
    awk '/menuentry / { printf "%d: %s\n", NR-1, $0 }' /boot/grub/grub.cfg | head -20
    echo -e "${YELLOW}=> Definindo GRUB_DEFAULT=0 (primeira entrada). Ajuste manualmente se necessário.${NC}"
    sed -i "s/^GRUB_DEFAULT=.*/GRUB_DEFAULT=0/" "$GRUB_CFG"
fi

echo -e "${YELLOW}==> Regenerando GRUB com nova configuração...${NC}"
grub-mkconfig -o /boot/grub/grub.cfg

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Kernel 6.6 LTS instalado com sucesso!${NC}"
echo -e "${GREEN}  Reinicie o sistema para usar o novo kernel.${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "${YELLOW}Dica: Para gerenciar kernels depois, use o mhwd-kernel:${NC}"
echo -e "  mhwd-kernel list"
echo ""
