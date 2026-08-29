# Dongle Bluetooth

## Identificação

| Campo | Valor |
|-------|-------|
| **Porta USB** | Bus 004, Device 010 (`4-2`) |
| **VID:PID** | `33fa:0010` |
| **Produto** | USB2.0-BT |
| **Fabricante** | *(vazio / não declarado)* |
| **Nº de série** | *(vazio)* |
| **bcdDevice** | 0x8891 |
| **Classe USB** | `e0` (Wireless Controller) / `01` (RF) |
| **Driver do kernel** | `btusb` + `btmtk` |

## Chipset real (confirmado)

- **Barrot Technology Limited (BR8554)** — UGREEN CM748/CM749 "USB BT 5.4".
- Manufacturer HCI ID: **2279 (0x08E7)** = Barrot Technology Limited.
- Bluetooth **5.4** (hci_version 0x0D).
- **Não é MediaTek** — o sub-driver `btmtk`/`btrtl`/`btbcm`/`btintel` carregados são apenas dependências padrão do `btusb` e **não estão ativos** para este dongle.

## Observações

- O VID `33fa` **não pertence a nenhum fabricante registrado**:
  - Realtek → `0bda`
  - Intel → `8087`
  - Broadcom → `0a5c`
  - MediaTek → `0e8d`
  - CSR → `0a12`
- Trata-se de um **dongle genérico / sem marca**, comumente vendido como "USB Bluetooth 4.0/5.0".
- O fabricante real **não é declarado** no dispositivo; o kernel o gerencia via `btusb` com o sub-driver `btmtk`.
- BD Address: `90:DE:80:51:EE:92` — HCI/USB, Bluetooth 5.4 (hci_version 0x0D), Manufacturer ID 0x08E7.

## Diagnóstico (validação do bug) — causa raiz confirmada

- O chip **Barrot** envia **1 byte extra/aleatório** na resposta ao comando `HCI_OP_READ_LOCAL_EXT_FEATURES` (0x1005) durante a inicialização, **desalinhando o próximo frame HCI**.
- Sintoma no kernel: `Bluetooth: hci0: Unexpected continuation: 1 bytes` (2× por inicialização do HCI) + `command 0x1005 tx timeout` / `Opcode 0x1005 failed: -110`.
- Consequência: a **inicialização do HCI falha** → `scan` não retorna dispositivos, `Name: ''` e `Class: 0x000000`, e o comportamento fica errático (conexões caem / loop conectando-desconectando / rádio inutilizável).
- **Firmware MediaTek não tem relação** com este chip. Instalar `linux-firmware-mediatek` **não resolveu** (testado).
- **Obs.:** em monitoramento direto (USB e estado HCI por 30s+), o HCI ficou `UP RUNNING` estável — o loop/erratismo se manifesta ao usar o rádio (scan/conexões), não como reconnect USB contínuo.

### Correções possíveis

1. **Kernel com o quirk `BTUSB_BARROT`** para `33fa:0010`/`33fa:0012` — existe um patch (jeffmerkey/linux, 2025) que trata o byte extra e torna o dongle utilizável. **Não está presente no kernel `6.18.44-0-lts` do Alpine.**
2. Testar em kernel upstream recente que eventualmente já contenha o quirk (ou aplicar o patch e recompilar).
3. Se a correção via quirk não for viável, usar outro dongle com VID de fabricante com suporte adequado (Realtek `0bda`, Intel `8087`).
4. Workaround temporário sem quirk: ciclar `rfkill block bluetooth` / `rfkill unblock bluetooth` ou religar o HCI, que às vezes faz funcionar após a inicialização falha (não confiável).

### Testes feitos

- `apk add linux-firmware-mediatek` → instalado; `Unexpected continuation` **persiste** e scan **continua vazio**.
- `hciconfig hci0 up` → OK (`UP RUNNING`), mas scan sem resultados.
- `hcitool cmd 0x04 0x0001` (Read Local Version) → HCI 5.4, Manufacturer `0x08E7` (Barrot).
- `hcitool cmd 0x04 0x0005` (Read Local Ext Features) manual → responde OK isolado; o byte extra ocorre na sequência automática de init.
