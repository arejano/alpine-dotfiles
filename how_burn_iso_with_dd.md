primeiro checar se o pendrive esta acessivel com:

lsblk -f [-f vai mostrar os pontos de montagem, se algo estiver montado, deve ser desmontado primeiro]


❯ lsblk -f
NAME   FSTYPE  FSVER            LABEL             UUID                                 FSAVAIL FSUSE% MOUNTPOINTS
sda                                                                                                   
└─sda1 btrfs                                      214df157-3b73-426c-bd02-6d6788d8ac45   96.7G    19% /home
                                                                                                      /var/log
                                                                                                      /var/cache
                                                                                                      /
sdb    iso9660 Joliet Extension MANJARO_SWAY_2600 2026-08-16-03-49-22-00                              
├─sdb1 iso9660 Joliet Extension MANJARO_SWAY_2600 2026-08-16-03-49-22-00                              
└─sdb2 vfat    FAT12            MISO_EFI          0430-E67D                                           
zram0  swap    1                zram0             b2da1b77-f8ef-48b9-943e-3f284e7c9b41                [SWAP]



sudo dd if="imagem.iso" of=/dev/sdb bs=4M status=progress oflag=sync
