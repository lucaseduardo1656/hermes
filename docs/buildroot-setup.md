# Hermes — Guia de Setup Buildroot (Pi 5)

## Visão Geral

O Buildroot compila todo o sistema operacional do zero: kernel, toolchain,
bibliotecas e o rootfs final. O resultado é uma imagem .img gravável no SD card.

> Raspberry Pi 5 é suportado no Buildroot desde ~2024. Alguns ajustes manuais
> são necessários para o RP1 (chip de I/O do Pi 5) e VideoCore VII (GPU).

---

## Pré-requisitos (máquina de desenvolvimento)

```bash
# Ubuntu/Debian
sudo apt-get install -y \
  make gcc g++ git wget cpio unzip rsync bc \
  python3 python3-dev libssl-dev libelf-dev \
  flex bison pkg-config

# Espaço necessário no host: ~20GB para compilação completa
```

---

## Estrutura do Repositório Hermes

```
hermes/
├── buildroot/              → Buildroot como submodule (git)
├── board/
│   └── hermes-pi5/
│       ├── config/
│       │   └── hermes_defconfig    → configuração Buildroot completa
│       ├── rootfs-overlay/         → arquivos extras para o rootfs
│       │   ├── etc/
│       │   │   ├── systemd/system/ → units do systemd
│       │   │   └── weston.ini      → config do Wayland compositor
│       │   └── home/hermes/        → configs do usuário hermes
│       ├── patches/                → patches para pacotes (se necessário)
│       └── post-build.sh           → script pós-build
├── app/                    → código fonte do Hermes Qt
└── docs/
```

---

## Configuração Principal do Buildroot

Pacotes essenciais a habilitar no `hermes_defconfig`:

### Toolchain
```
BR2_aarch64=y
BR2_TOOLCHAIN_BUILDROOT_GLIBC=y
BR2_ARM_EABI=y
BR2_GCC_VERSION_14_X=y
```

### Kernel
```
BR2_LINUX_KERNEL=y
BR2_LINUX_KERNEL_CUSTOM_VERSION=y
BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE="6.6"    # LTS com suporte Pi 5
BR2_LINUX_KERNEL_DEFCONFIG="bcm2712"           # defconfig Pi 5
```

### Bootloader
```
BR2_TARGET_UBOOT=n         # Pi 5 usa bootloader próprio (firmware Broadcom)
BR2_PACKAGE_RPI_FIRMWARE=y # firmware Pi 5 + VideoCore
```

### Display / Wayland
```
BR2_PACKAGE_WAYLAND=y
BR2_PACKAGE_WAYLAND_PROTOCOLS=y
BR2_PACKAGE_WESTON=y           # pode ser substituído por Cage
BR2_PACKAGE_CAGE=y             # kiosk compositor (preferido)
BR2_PACKAGE_MESA3D=y
BR2_PACKAGE_MESA3D_GALLIUM_DRIVER_V3D=y    # driver VideoCore VII
BR2_PACKAGE_MESA3D_OPENGL_EGL=y
BR2_PACKAGE_MESA3D_OPENGL_ES=y
BR2_PACKAGE_LIBDRM=y
BR2_PACKAGE_LIBINPUT=y         # input touchscreen
```

### Qt 6
```
BR2_PACKAGE_QT6=y
BR2_PACKAGE_QT6BASE=y
BR2_PACKAGE_QT6BASE_GUI=y
BR2_PACKAGE_QT6BASE_OPENGL_DESKTOP=n
BR2_PACKAGE_QT6BASE_OPENGL=y       # OpenGL ES
BR2_PACKAGE_QT6BASE_EGLFS=y
BR2_PACKAGE_QT6BASE_WAYLAND=y
BR2_PACKAGE_QT6DECLARATIVE=y       # Qt Quick / QML
BR2_PACKAGE_QT6MULTIMEDIA=y        # Qt Multimedia (áudio/vídeo)
BR2_PACKAGE_QT6WEBENGINE=y         # QtWebEngine (YouTube, browser)
BR2_PACKAGE_QT6POSITIONING=y       # GPS / QtPositioning
```

> **Atenção:** QtWebEngine aumenta significativamente o tempo de compilação
> (~1-2h extras) e o tamanho da imagem (~300MB). Necessário para YouTube e browser.

### Maliit (teclado virtual)
```
BR2_PACKAGE_MALIIT_FRAMEWORK=y
BR2_PACKAGE_MALIIT_KEYBOARD=y
```

### Áudio
```
BR2_PACKAGE_PIPEWIRE=y             # servidor de áudio moderno
BR2_PACKAGE_WIREPLUMBER=y          # session manager do PipeWire
BR2_PACKAGE_MPD=y                  # Music Player Daemon
BR2_PACKAGE_MPD_ALSA=y
```

### Serviços / Utilitários
```
BR2_PACKAGE_SYSTEMD=y
BR2_PACKAGE_DBUS=y
BR2_PACKAGE_BLUEZ5_UTILS=y         # Bluetooth
BR2_PACKAGE_WPA_SUPPLICANT=y       # WiFi
BR2_PACKAGE_DHCPCD=y               # DHCP client
BR2_PACKAGE_CURL=y
BR2_PACKAGE_OPENSSL=y
BR2_PACKAGE_CA_CERTIFICATES=y      # TLS para APIs HTTPS
BR2_PACKAGE_SQLITE=y               # cache local de dados
```

### Python (para yt-dlp)
```
BR2_PACKAGE_PYTHON3=y
BR2_PACKAGE_PYTHON3_PIP=n          # instalar yt-dlp via overlay
```

---

## Usuário e Sessão

O sistema faz boot diretamente como usuário `hermes` (não root) e inicia
o Wayland compositor que lança o app Hermes automaticamente.

### systemd unit: hermes-session.service
```ini
# board/hermes-pi5/rootfs-overlay/etc/systemd/system/hermes-session.service
[Unit]
Description=Hermes Car System Session
After=systemd-udevd.service
Wants=bluetooth.service pipewire.service

[Service]
User=hermes
Group=hermes
PAMName=login
Environment=XDG_RUNTIME_DIR=/run/user/1000
Environment=WAYLAND_DISPLAY=wayland-1
ExecStart=/usr/bin/cage -- /usr/bin/hermes
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
```

---

## Processo de Build

```bash
# 1. Clonar Buildroot como submodule
git submodule add https://github.com/buildroot/buildroot buildroot
cd buildroot
git checkout 2024.11  # versão LTS

# 2. Copiar defconfig
cp ../board/hermes-pi5/config/hermes_defconfig configs/

# 3. Carregar configuração
make hermes_defconfig

# 4. (Opcional) Ajustar via menuconfig
make menuconfig

# 5. Compilar (primeira vez: 3-6 horas dependendo do hardware)
make -j$(nproc)

# 6. Imagem gerada em:
# buildroot/output/images/sdcard.img
```

### Gravar no SD Card
```bash
sudo dd if=output/images/sdcard.img of=/dev/sdX bs=4M status=progress
sudo sync
```

---

## Iteração Rápida Durante Desenvolvimento

Para não recompilar o Buildroot inteiro a cada mudança no app Hermes:

```bash
# Recompilar apenas o pacote hermes
make hermes-rebuild

# Ou durante dev: copiar binário direto para Pi via SSH/SCP
# (manter um Pi com RPi OS para desenvolvimento, Buildroot para produção)
```

---

## Notas Específicas do Pi 5

- O Pi 5 usa o chip **RP1** para periféricos (USB, I2C, SPI, GPIO) — precisa de
  suporte no kernel 6.1+ (melhor no 6.6+)
- O VideoCore VII precisa do driver **V3D Mesa** (não vc4 como Pi 4)
- O bootloader é `firmware-rpi` — não precisa de U-Boot
- Para touchscreen HDMI: verificar driver específico do painel (geralmente `goodix` ou `edt-ft5x06`)
- Memória: com 8GB RAM, ajustar `gpu_mem=256` no `config.txt` do firmware

---

## Ordem de Implementação Sugerida

1. Buildroot mínimo (kernel + shell) bootando no Pi 5
2. Adicionar Wayland + Cage + app Qt "Hello World" na tela
3. Adicionar MapLibre + mapa estático funcionando
4. Adicionar PipeWire + MPD + reproduzir áudio
5. Adicionar QtWebEngine (passo lento — grande compilação)
6. Integrar librespot e yt-dlp
7. Otimizar boot time
