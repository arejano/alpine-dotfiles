# Objetivo

Adaptar os dotfiles de outro usuário (`/home/mek/git/dotfiles`) para o meu ambiente (`/home/mek/git/noh_dotfiles`).

## Requisitos

### Fluxo de desenvolvimento
- O comando `dev` deve funcionar da mesma forma que no repositório original
- Utilizar **helix** como editor + **zellij** como multiplexador

### Linguagens
- Apenas **Zig** e **TypeScript**

### Configurações específicas
- **Sway**: abrir menu com `Win+Espaço` (não `Win+D`)
- **Helix**: alias `hx`

## Tarefas

1. Clonar e analisar `/home/mek/git/dotfiles`
2. Criar `/home/mek/git/noh_dotfiles` com as adaptações
3. Implementar comando `dev` (helix + zellij)
4. Configurar suporte apenas para Zig e TypeScript
5. Ajustar atalho do menu no Sway
6. Adicionar alias `hx` para helix
7. Criar script de instalação

## Instalação

Para instalar o ambiente, execute:

```bash
cd ~/git/noh_dotfiles
./install.sh
```

O script irá:
- Instalar pacotes necessários (helix, zellij, sway, etc.)
- Instalar language servers (zls, typescript-language-server)
- Copiar configurações para os locais corretos
- Configurar o shell

## Status

✅ Concluído
