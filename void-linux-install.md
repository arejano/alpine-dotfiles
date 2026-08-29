# Instalar Void Linux em hardware antigo + git + Zig 0.16.0

> Guia passo a passo de instalação do Void Linux numa máquina antiga, seguido da
> instalação do `git` e do Zig **0.16.0** (toolchain oficial da ziglang.org).
> Criado: 2026-08-29.

## 1. Escolha da imagem (32 bits ou 64 bits?)

| Situação do hardware | Arquitetura | Imagem a usar |
|----------------------|-------------|---------------|
| CPU 32 bits (Pentium 4/Atom/primeiros Core) | **i686** | `void-live-i686-*-base.iso` (só glibc, sem musl) |
| CPU 64 bits com pouca RAM/armazenamento | **x86_64-musl** | `void-live-x86_64-musl-*-base.iso` |
| CPU 64 bits normal | **x86_64-glibc** | `void-live-x86_64-*-base.iso` |

Requisitos mínimos (fonte: docs.voidlinux.org):

| Arquitetura | CPU | RAM | Disco |
|-------------|-----|-----|-------|
| x86_64-glibc | x86_64 | 520 MB | 700 MB |
| x86_64-musl | x86_64 | 520 MB | 600 MB |
| i686-glibc | Pentium 4 (SSE2) | 520 MB | 700 MB |

> ⚠️ **i686**: o Void exige **SSE2** (Pentium 4 ou superior). **Não** há suporte
> para i386/i486/i586. o musl **não** existe para i686 (somente glibc).

> ⚠️ **Zig 0.16.0 × i686**: a ziglang.org **não publica build oficial para i686**
> na 0.16.0 (só x86_64, aarch64, arm, riscv64 e powerpc64le). Em máquina 100%
> 32 bits o Zig 0.16.0 só poderia ser compilado do source (praticamente inviável
> em hardware antigo). Para usar o tarball pronto, a máquina precisa ser **x86_64**.

## 2. Download e gravação no pendrive

```sh
# Baixar (ajuste o nome conforme a arquitetura escolhida)
curl -LO https://repo-default.voidlinux.org/live/current/void-live-x86_64-20250202-base.iso

# Verificar checksum e assinatura (usar o sha256sum.txt do mesmo diretório)
curl -LO https://repo-default.voidlinux.org/live/current/sha256sum.txt
sha256sum -c sha256sum.txt --ignore-missing

# Gravar no pendrive (SUBSTITUA /dev/sdX pelo dispositivo correto — confira com lsblk!)
dd bs=4M if=void-live-x86_64-20250202-base.iso of=/dev/sdX conv=fsync oflag=sync status=progress
```

## 3. Boot e instalação com `void-installer`

1. Boote pelo pendrive (menu: escolha o kernel; tecla `s` ativa leitor de tela).
2. Login na máquina ao vivo: usuário **root**, senha **voidlinux**.
3. Rode o instalador:

```sh
void-installer
```

O instalador é um menu sequencial. Opções a preencher:

| Item | Observação |
|------|------------|
| **Keyboard** | escolher layout (ex.: `br` / `uk-us`), senão deixar padrão |
| **Network** | selecionar e ativar a interface (DHCP) antes de continuar |
| **Source** | `Local` (usa pacotes da ISO) ou `Network` (baixa tudo da internet) |
| **Hostname** | nome da máquina |
| **Locale** | `pt_BR.UTF-8` (ou `en_US.UTF-8`) |
| **Timezone** | ex.: America/Sao_Paulo |
| **Root password** | definir senha do root |
| **User account** | criar usuário normal (login, senha, grupos) |
| **Image / kernel** | manter o kernel da imagem (dontskip `linux`) |
| **Partition** | particionar com `cfdisk`/`fdisk` |
| **Filesystems** | formatar partições e definir pontos de montagem |
| **Done/Install** | confirmar e instalar |
| **Bootloader** | **GRUB** (UEFI) ou **Syslinux** (BIOS legado) |

**Particionamento — BIOS legado (comum em hardware antigo):**

```text
/dev/sdX1  /boot   ext4   ~200 MB
/dev/sdX2  /       ext4   resto do disco (swap opcional: 3ª partição)
```

UEFI: criar partição EFI (`/dev/sdX1`, tipo EFI System, ~150 MB) montada em
`/boot/efi` e usar GRUB.

4. Ao final, reinicie e remova o pendrive:

```sh
reboot
```

## 4. Pós-instalação (primeiro boot)

```sh
# Atualizar o sistema (rolling release)
xbps-install -Su

# Rede: habilitar dhcpcd e/ou o serviço de rede com runit
ln -s /etc/sv/dhcpcd /var/service/
ln -s /etc/sv/sshd /var/service/    # opcional, acesso remoto
```

## 5. Instalar o git

```sh
xbps-install -S git
git --version
```

### (Opcional) Pacotes uteis de desenvolvimento

```sh
xbps-install -S curl xz tar ca-certificates xz
```

## 6. Instalar o Zig 0.16.0 (build oficial)

> O pacote `zig` dos repositórios do Void está desatualizado (parado em ~0.13,
> por incompatibilidade com a versão do LLVM do Void). Para a **0.16.0** exata,
> use o tarball oficial da ziglang.org.

```sh
# Baixar e extrair (USB/HDD precisa de ~300 MB livres em /usr/local)
cd /tmp
curl -LO https://ziglang.org/download/0.16.0/zig-x86_64-linux-0.16.0.tar.xz

# Extrair para /usr/local e criar symlink
tar -xf zig-x86_64-linux-0.16.0.tar.xz -C /usr/local
ln -s /usr/local/zig-x86_64-linux-0.16.0/zig /usr/local/bin/zig

# Verificar
zig version          # deve imprimir 0.16.0
zig env              # mostra o toolchain resolvido
```

Se não houver espaço em `/usr/local`, instale no home:

```sh
mkdir -p ~/.local/opt && cd ~/.local/opt
curl -LO https://ziglang.org/download/0.16.0/zig-x86_64-linux-0.16.0.tar.xz
tar -xf zig-x86_64-linux-0.16.0.tar.xz
echo 'export PATH="$HOME/.local/opt/zig-x86_64-linux-0.16.0:$PATH"' >> ~/.bashrc
source ~/.bashrc
zig version
```

### Verificação da assinatura (opcional)

```sh
xbps-install -S minisign
mv zig-x86_64-linux-0.16.0.tar.xz.minisig /tmp/  # manter junto do arquivo
cd /tmp
curl -LO https://ziglang.org/download/0.16.0/zig-x86_64-linux-0.16.0.tar.xz.minisig
minisign -Vm zig-x86_64-linux-0.16.0.tar.xz -p /dev/stdin <<< "$(curl -Ls https://ziglang.org/keys/ziglang.pub)"
```

## 7. Teste rápido do toolchain

```zig
// /tmp/hello.zig
const std = @import("std");

pub fn main() !void {
    std.debug.print("Void + Zig {s}\n", .{@import("builtin").zig_version_string});
}
```

```sh
cd /tmp
zig run hello.zig    #  ->  Void + Zig 0.16.0
zig build-exe hello.zig -O ReleaseSafe -femit-bin=hello
./hello
```

## Referências

- Downloads das imagens e checksums: `https://repo-default.voidlinux.org/live/current/`
- Manual de instalação (handbook): `https://docs.voidlinux.org/installation/`
- Downloads do Zig (builds oficiais): `https://ziglang.org/download/`
- Pacotes do Void (buscar `zig` para ver a versão do repo): `https://voidlinux.org/packages/`