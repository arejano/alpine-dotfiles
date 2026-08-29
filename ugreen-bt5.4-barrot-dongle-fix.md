# UGREEN CM748 (Barrot BR8554) — Dongle Bluetooth não funciona no Linux

> Knowledge base sobre o problema do dongle `33fa:0010` e como resolvê-lo.
> Criado: 2026-08-29. Contexto: detecção/teste em Alpine Linux 3.24 (kernel 6.18.44-lts).

## Identificação do hardware

| Campo | Valor |
|-------|-------|
| **VID:PID** | `33fa:0010` |
| **Produto USB** | USB2.0-BT |
| **Chipset real** | **Barrot Technology BR8554** (não é MediaTek!) |
| **Modelos** | UGREEN CM748 (sem antena) / CM749 (com antena) |
| **Variantes** | `33fa:0010` (CM748), `33fa:0012` (BT 6.0), `33fa:0013` |
| **Fabricante HCI ID** | `2279` (0x08E7) = Barrot Technology Limited |
| **Bluetooth** | 5.4 (hci_version 0x0D) |
| **FCC ID** | 2AQI5-CM748 |
| **Driver** | `btusb` (nenhum driver específico; capturado pelo alias genérico de classe E0) |

## Sintomas

- `dmesg` repete em cada inicialização do HCI:
  - `Bluetooth: hci0: Unexpected continuation: 1 bytes` (2× por boot)
  - `Bluetooth: hci0: command 0x1005 tx timeout`
  - `Bluetooth: hci0: Opcode 0x1005 failed: -110`
- O HCI sobe (`UP RUNNING`) mas:
  - `hciconfig -a` mostra `Name: ''` e `Class: 0x000000` (leitura falha)
  - `hcitool scan` **não retorna nenhum dispositivo**
- Na prática: rádio inutilizável / loop conectando-desconectando / hang no init.
- `lsusb` mostra o dispositivo normalmente (é detectado no nível USB, mas não funciona).

## Causa raiz (bug documentado)

O chip **Barrot BR8554** tem um bug de firmware: ao receber o comando
`HCI_OP_READ_LOCAL_EXT_FEATURES` (opcode `0x1005`) durante a **inicialização do HCI**,
ele responde mal:

1. Envia **1 byte extra/aleatório** na resposta, o que **desalinha o próximo frame HCI**.
2. O kernel emite `Unexpected continuation: 1 bytes` → a inicialização falha
   (`tx timeout`, opcode falho com `-110`) → rádio não fica operável.

É um mau funcionamento **do firmware do chip**, não do kernel. O driver Linux precisa
de um quirk para contornar.

## Correções disponíveis

### 1. Kernel atualizado (mais simples — RECOMENDADO)

A correção principal foi incorporada ao mainline do Linux e backportada:

- Commit upstream: `7722d6fb54e4`
  ("Bluetooth: hci_sync: Fix crash in hci_read_local_ext_features_all_sync").
- Presente no mainline desde **6.18** e **backportado** para **6.12.58+** e **6.6.117+**.
- Qualquer distro com kernel vanilla ≥ 6.12.58 / ≥ 6.6.117 já o contém.

**Conclusão:** distros atualizadas (Arch/Manjaro kernel 7.x ou 6.18.x, Ubuntu 25.04+,
Fedora 41+, etc.) **resolvem o problema sem nenhum esforço**.

⚠️ Ressalva: alguns kernels *derivados/patcheados* podem NÃO ter o cherry-pick do fix
(ex.: SteamOS 3.8 usava 6.16.12 sem o backport). Usar o **kernel vanilla do upstream**
evita esse problema.

### 2. Quirk `BTUSB_BARROT` (recompilar `btusb.ko`)

Patch (arkq / Arkadiusz Bokowy) que faz o driver **descartar o byte extra** apenas para
dispositivos Barrot. Para kernels que **não** têm a correção:

- Define `BTUSB_BARROT` e adiciona as entradas `33fa:0010` e `33fa:0012` ao
  `quirks_table` do `drivers/bluetooth/btusb.c`.
- Define `HCI_QUIRK_FIXUP_LOCAL_EXT_FEATURES_URB_BUFFER` em `include/net/bluetooth/hci.h`.
- Em `btusb_recv_intr()`: se o quirk estiver ativo e for uma resposta ao
  `HCI_OP_READ_LOCAL_EXT_FEATURES` com `count == 1`, zera `count` (descarta o byte).

### 3. Patch alternativo do `bluetooth.ko` (nwrafael)

Remove as duas chamadas `HCI_INIT(hci_read_local_ext_features_*_sync)` de
`net/bluetooth/hci_sync.c`. Isso pula o comando problemático e o dongle inicializa.
Referência: `github.com/nwrafael/CM748-ugreen-bluetooth-adapter-patch-linux`.

## O que NÃO resolve

- **Firmware MediaTek** (`linux-firmware-mediatek`, pacote `mt76/pr2h`) — irrelevante,
  o chip não é MediaTek. Testado: não muda nada.
- Reinstalar o driver `btusb` (`modprobe -r/btusb && modprobe btusb`) — volta o mesmo erro.
- O driver mascara o dispositivo como "CSR clone" — os workarounds de CSR não se aplicam.

## Status observado (2026-08-29, Alpine 3.24 / kernel 6.18.44-0-lts)

- Kernel do Alpine 3.24 (`linux-lts` 6.18.44/6.18.48) **NÃO contém** a correção
  (nem o quirk `BTUSB_BARROT` nem o guard do `hci_read_local_ext_features` no `hci_sync`).
- O Alpine 3.24 **só oferece kernel `linux-lts` 6.18** — não há kernel alternativo no repo
  ativado (sem `linux-edge`/`linux-vanilla` disponíveis).
- Conclusão: neste kernel NÃO dá para só "atualizar". As opções são:
  a) migrar para uma distro com kernel vanilla ≥6.12.58 (ex.: Manjaro/Arch); ou
  b) recompilar `btusb.ko` (quirk) ou `bluetooth.ko` (patch hci_sync) contra o source.

## Referências externas

- GitLab Ulab/ueblue (missing firmware UGREEN BT 5.4, BCM20702A1 misdetect)
- `github.com/nwrafael/CM748-ugreen-bluetooth-adapter-patch-linux`
- LKML bluez: "[PATCH] Bluetooth: btusb: Fixup quirk for reading ext features on some Barrot controllers" (arkq)
- **bluez issue 1326** — causa idêntica para `33fa:0010`
- **ValveSoftware/SteamOS issue 2472** — mesmo bug, drivers valvados sem backport
- `drivers/bluetooth/btusb.c` upstream (definição `BTUSB_BARROT` / quirks)

## Comandos úteis para diagnóstico

```sh
lsusb                                    # ver 33fa:0010
lsusb -v -d 33fa:0010                    # detalhes USB (bcdDevice 88.91, classe e0-01)
dmesg | grep -iE "hci0|opcode|continuation|timeout"   # ver os erros
hciconfig -a                             # estado do HCI (Name/Class vazios = falha)
hcitool cmd 0x04 0x0001                  # Read Local Version (Manufacturer 0x08E7)
hcitool cmd 0x04 0x0005 0x00             # Read Local Extended Features (0x1005)
hcitool scan                             # scan vazio = rádio não opera
/usr/sbin/rfkill list bluetooth          # estado rfkill
```
