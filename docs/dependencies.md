# Hermes — Dependências

## 1. Máquina de Build (Host)

Dependências necessárias para compilar o Buildroot e gerar a imagem do sistema.

### Arch Linux
```bash
sudo pacman -S \
  base-devel \
  wget \
  cpio \
  rsync \
  bc \
  git \
  unzip \
  python3 \
  ncurses \
  openssl \
  libelf \
  flex \
  bison \
  perl \
  xz \
  file \
  which \
  diffutils \
  patch \
  zlib \
  gperf \
  help2man \
  ccache
```

### Ubuntu / Debian
```bash
sudo apt-get install -y \
  build-essential \
  wget \
  cpio \
  rsync \
  bc \
  git \
  unzip \
  python3 \
  python3-dev \
  libncurses-dev \
  libssl-dev \
  libelf-dev \
  flex \
  bison \
  perl \
  xz-utils \
  file \
  diffutils \
  patch
```

### Fedora / RHEL
```bash
sudo dnf install -y \
  gcc gcc-c++ make \
  wget \
  cpio \
  rsync \
  bc \
  git \
  unzip \
  python3 \
  ncurses-devel \
  openssl-devel \
  elfutils-libelf-devel \
  flex \
  bison \
  perl \
  xz \
  file \
  diffutils \
  patch
```

---

## 2. Ferramentas Opcionais de Build

Úteis mas não obrigatórias para o build básico.

### Arch Linux
```bash
sudo pacman -S \
  ccache \       # cache de compilação — reduz rebuilds de ~3h para ~20min
  ninja \        # alternativa ao make para builds Qt
  cmake \        # necessário para compilar o app Hermes no host
  qt6-base \     # para desenvolver/testar o app localmente antes de enviar ao Pi
  qt6-declarative \
  clang \        # alternativa ao GCC (linting, IDEs)
  bear           # gera compile_commands.json para IDEs (clangd, etc.)
```

---

## 3. Dependências do Buildroot (geradas automaticamente)

O Buildroot baixa e compila automaticamente durante o `make`:

| Pacote | Versão | Uso |
|---|---|---|
| binutils | 2.41 | toolchain cross-compiler |
| gcc | 13.x | compilador aarch64 |
| glibc | 2.38 | libc do target |
| linux | 6.6.51 | kernel para Pi 5 |
| Qt6 Base | 6.6.x | framework UI |
| Qt6 Declarative | 6.6.x | QML engine |
| Qt6 Multimedia | 6.6.x | áudio/vídeo |
| Qt6 Wayland | 6.6.x | integração Wayland |
| Qt6 WebEngine | 6.6.x | YouTube, browser (compilação longa) |
| Mesa3D | 24.x | driver V3D (VideoCore VII) |
| Wayland | 1.22.x | protocolo display |
| Cage | latest | compositor kiosk |
| Maliit Framework | 2.x | teclado virtual |
| PipeWire | 1.x | servidor de áudio |
| WirePlumber | 0.5.x | session manager PipeWire |
| MPD | 0.23.x | music player daemon |
| GStreamer | 1.22.x | backend multimídia |
| BlueZ | 5.x | stack Bluetooth |
| wpa_supplicant | 2.x | WiFi |
| Python 3 | 3.12.x | runtime para yt-dlp |
| OpenSSL | 3.x | TLS para APIs HTTPS |
| libcurl | 8.x | requisições HTTP |
| SQLite | 3.x | cache local |
| systemd | 255.x | init system |

> Espaço necessário em disco para output completo: **~15-20GB**
> Tempo estimado de build (primeira vez, i7 8 cores): **3-5 horas**

---

## 4. Dependências de Runtime no Pi 5 (pós-boot)

Instaladas via pip/script após o primeiro boot, ou pré-instaladas via rootfs-overlay.

### yt-dlp
```bash
# Instalar/atualizar no Pi (requer Python3 + pip no target)
pip3 install -U yt-dlp
```

Dependências do yt-dlp no target:
- `python3` — já incluso no Buildroot
- `ffmpeg` — necessário para muxing de streams; adicionar ao defconfig:
  ```
  BR2_PACKAGE_FFMPEG=y
  BR2_PACKAGE_FFMPEG_FFMPEG=y
  BR2_PACKAGE_FFMPEG_FFPROBE=y
  ```

### librespot (Spotify)
Binário estático em Rust — será compilado como pacote Buildroot customizado.
Sem dependências extras em runtime além do PipeWire (já incluso).

### Valhalla (routing local)
Será compilado como pacote Buildroot customizado.

Dependências em runtime (adicionadas ao defconfig quando implementado):
```
BR2_PACKAGE_BOOST=y
BR2_PACKAGE_PROTOBUF=y
BR2_PACKAGE_ZLIB=y
BR2_PACKAGE_LZ4=y
```

---

## 5. APIs Externas (requerem chaves/cadastro)

| Serviço | Uso | Free tier | Cadastro |
|---|---|---|---|
| MapTiler | Tiles de mapa HD + 3D | 100k tiles/mês | maptiler.com |
| Here Maps | Tráfego em tempo real | 250k req/mês | developer.here.com |
| OpenWeatherMap | Clima e alertas | 1M calls/mês | openweathermap.org |
| Spotify | librespot (sem API key — usa protocolo Connect) | Premium obrigatório | — |

> As chaves de API devem ser armazenadas em `board/hermes-pi5/rootfs-overlay/etc/hermes/secrets.env`
> (arquivo no `.gitignore` — nunca commitar)

---

## 6. Desenvolvimento do App Qt (host)

Para desenvolver e testar o app Hermes localmente antes de cross-compilar para o Pi.

### Arch Linux
```bash
sudo pacman -S \
  qt6-base \
  qt6-declarative \
  qt6-multimedia \
  qt6-positioning \
  qt6-svg \
  qt6-wayland \
  cmake \
  ninja \
  clang
```

### IDE recomendada
- **Qt Creator** — integração nativa com QML, debugger, profiler
  ```bash
  sudo pacman -S qtcreator
  ```
- **VS Code** com extensões: `Qt for Python`, `QML`, `clangd`

---

## 7. Checklist de Ambiente

Rode antes de iniciar o build para verificar se tudo está instalado:

```bash
for cmd in make gcc g++ git wget cpio rsync bc python3 flex bison perl; do
  which $cmd &>/dev/null && echo "✓ $cmd" || echo "✗ $cmd — FALTANDO"
done
```
