#!/bin/sh
# gh-setup.sh — Instalar GitHub CLI e autenticar via browser
# Execute como root para instalar, depois como usuario normal para autenticar

set -eu

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# ----------------------------------------------------------
# 1. Instalar gh (requer root)
# ----------------------------------------------------------
if [ "$(id -u)" -eq 0 ]; then
    echo "=== INSTALACAO (root) ==="
    echo ""

    # Adicionar repo edge se necessario (gh pode nao estar no stable)
    apk update

    if ! command -v gh >/dev/null 2>&1; then
        # Tentar instalar do repo atual
        apk add gh 2>/dev/null && {
            log "gh instalado via apk"
        } || {
            # Se falhar, adicionar repo edge temporariamente
            echo "  gh nao encontrado no repo atual. Tentando edge..."

            # Backup repos
            cp /etc/apk/repositories /etc/apk/repositories.bak 2>/dev/null || true

            # Pegar URL do repo atual e trocar para edge
            CUR=$(head -1 /etc/apk/repositories)
            BASE=$(echo "$CUR" | sed 's|/v[0-9.]*/*|/edge|')
            echo "$BASE" >> /etc/apk/repositories

            # Precisa do edge/testing para gh
            TESTING=$(echo "$BASE" | sed 's|/edge$|/edge/testing|')
            echo "$TESTING" >> /etc/apk/repositories

            apk update
            apk add gh 2>/dev/null && {
                log "gh instalado via edge/testing"
            } || {
                # Restaurar repos
                mv /etc/apk/repositories.bak /etc/apk/repositories 2>/dev/null || true
                err "Nao foi possivel instalar gh. Instale manualmente: https://github.com/cli/cli/blob/trunk/install_linux.md"
            }

            # Restaurar repos (edge nao e recomendado para tudo)
            mv /etc/apk/repositories.bak /etc/apk/repositories 2>/dev/null || true
        }
    fi

    log "gh instalado: $(gh --version | head -1)"
    echo ""
    echo "Agora rode como usuario normal:"
    echo "  sh $0"
    echo ""
    exit 0
fi

# ----------------------------------------------------------
# 2. Autenticar (usuario normal)
# ----------------------------------------------------------
echo "=== AUTENTICACAO GITHUB ==="
echo ""

command -v gh >/dev/null 2>&1 || err "gh nao encontrado. Rode como root primeiro: sh $0"

echo "Isso vai abrir o Firefox para autenticar."
echo ""

# Verificar se ja esta autenticado
if gh auth status >/dev/null 2>&1; then
    log "Ja autenticado!"
    gh auth status
    echo ""
    echo "Para reautenticar: gh auth logout && sh $0"
    exit 0
fi

echo "Iniciando autenticacao via browser..."
echo ""

# Web-based auth (abre o Firefox automaticamente)
# --web usa o browserpadrao do sistema
gh auth login --hostname github.com --web --git-protocol https

echo ""
log "Autenticacao concluida!"
echo ""
echo "Verificando..."
gh auth status
echo ""
echo "Para salvar seus scripts:"
echo "  git add ."
echo "  git commit -m 'sua mensagem'"
echo "  git push"
