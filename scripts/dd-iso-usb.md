# Como gravar uma ISO em um pendrive USB com `dd` (Alpine Linux)

O `dd` é uma ferramenta de baixo nível que copia dados de forma bruta
(byte a byte). Usá-lo para gravar uma ISO em um USB faz uma cópia exata da
imagem, inclusive da tabela de partições e do bootloader, criando um
pendrive bootável.

> **Atenção:** o `dd` não pergunta confirmação e não mostra progresso por
> padrão. Qualquer erro de digitação no dispositivo de destino pode apagar
> dados de outros discos. **Confira o dispositivo duas vezes.**

---

## 1. Identificar o dispositivo USB

Conecte o pendrive e liste os discos:

```sh
lsblk
```

ou, mais detalhado:

```sh
sudo fdisk -l
```

Identifique o pendrive pelo tamanho (ex.: 8G, 16G, 32G). Ele normalmente
aparece como `/dev/sdX` (ex.: `/dev/sdb`), às vezes com partições como
`/dev/sdb1`.

> No Alpine, para ter permissão de `sudo`, o usuário `root` ou o grupo
> `wheel` devem estar configurados. Referência oficial:
> https://wiki.alpinelinux.org/wiki/Setting_up_a_new_user

---

## 2. Gravar a ISO no USB

Desmonte o pendrive, se estiver montado (mude a letra para a correta):

```sh
sudo umount /dev/sdb1
```

Grave a ISO (mude o caminho do arquivo e a letra do dispositivo):

```sh
sudo dd if=/caminho/para/imagem.iso of=/dev/sdb bs=4M status=progress conv=fsync
```

Explicação dos parâmetros:

| Parâmetro | O que faz |
|-----------|-----------|
| `if=` | arquivo de entrada (a ISO) |
| `of=` | dispositivo de saída (o USB, **sem** número de partição) |
| `bs=4M` | tamanho do bloco (4 MiB acelera bastante a escrita) |
| `status=progress` | mostra o progresso e a velocidade (opcional) |
| `conv=fsync` | força a gravação dos dados no disco antes de terminar |

Ao final, aparecerá um resumo como:

```
... bytes copied, ... s, ... MB/s
```

Possíveis avisos para ignorar:

- `dd: error writing ... No space left on device` — normal quando a ISO é
  menor que o pendrive; o resumo final ainda assim aparece.
- `Operation not permitted` — esqueceu o `sudo`.

---

## 3. Sincronizar e ejetar

Mesmo com `conv=fsync`, é recomendado sincronizar e ejetar o dispositivo:

```sh
sync
sudo eject /dev/sdb      # expulsa o pendrive
```

Pronto, o pendrive está bootável. Agora é só inseri-lo na máquina de destino
e configurar o boot pelo USB no firmware (BIOS/UEFI).

---

## Extras e dicas

### Verificar a gravação (opcional)

Comparar o hash da ISO com o conteúdo do pendrive:

```sh
sudo dd if=/dev/sdb bs=4M status=progress | sha256sum
sha256sum /caminho/para/imagem.iso
```

Se os dois hashes forem iguais, a gravação foi bem-sucedida.

### Gravar sem sudo (como root)

Se estiver logado como `root`, pode simplesmente rodar:

```sh
dd if=imagem.iso of=/dev/sdb bs=4M status=progress conv=fsync
```

### Desfazer / retornar o pendrive ao uso normal

Depois de gravar, o pendrive fica com a partição da ISO. Para reutilizá-lo,
apague a tabela de partições (muito cuidado com a letra):

```sh
sudo dd if=/dev/zero of=/dev/sdb bs=1M count=20 status=progress
```

Depois forme uma nova tabela e particione com `fdisk` ou `cfdisk`.

---

## Cuidados importantes

- **Sempre use o dispositivo inteiro** (`/dev/sdb`) e **nunca** a partição
  (`/dev/sdb1`) como destino. Escrever numa partição não cria um pendrive
  bootável.
- Confira duas vezes que `of=` aponta para o USB e não para o disco do
  sistema (ex.: `/dev/sda`).
- O `dd` não tem "lixeira": dados sobrescritos não podem ser recuperados.

---

## Referências

- Wiki oficial do Alpine: https://wiki.alpinelinux.org/wiki/Installing_Alpine_on_USB
- Página `man`: `man dd`
