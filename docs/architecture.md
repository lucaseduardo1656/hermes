# Hermes — Arquitetura do Sistema

## Visão Geral

Hermes é um sistema de multimídia automotivo embarcado desenvolvido para Raspberry Pi 5,
com interface Qt/QML nativa, design inspirado no estilo Mapbox Automotive / Tesla Model 3.

O sistema prioriza: mapa 3D como tela principal, UI responsiva ao toque, boot rápido,
e integração com serviços de streaming sem depender de Android Auto ou CarPlay.

---

## Hardware Alvo

| Componente     | Especificação                          |
|----------------|----------------------------------------|
| SBC            | Raspberry Pi 5 — 8GB RAM              |
| Tela           | 1024×600px touchscreen                |
| Áudio          | Amplificador externo + alto-falantes  |
| Conectividade  | WiFi (sempre disponível no veículo)   |
| Veículo        | Carro carburado — sem OBD-II          |

---

## Stack de Software

### Sistema Operacional
- **Base:** Buildroot (custom para Pi 5)
- **Kernel:** Linux com patches para VideoCore VII (GPU Pi 5) e RP1
- **Init system:** systemd mínimo ou s6 (a definir na fase Buildroot)
- **Target:** imagem < 512MB, boot < 10 segundos

### Display e Compositor
- **Display server:** Wayland
- **Compositor:** Cage (kiosk mode — gerencia janelas de processos externos)
- **Qt renderização:** via Wayland (não EGLFS, para suportar apps externas)

### UI Principal
- **Framework:** Qt 6.x
- **Linguagem UI:** QML + Qt Quick
- **Linguagem lógica:** C++17
- **GPU:** OpenGL ES 3.x via VideoCore VII

### Teclado Virtual
- **Maliit Framework** — padrão Wayland, customizável via QML

---

## Módulos Funcionais

| Módulo         | Tecnologia principal                        | Online | Offline |
|----------------|---------------------------------------------|--------|---------|
| Mapas          | MapLibre GL Native (Qt plugin nativo)       | ✓      | ✓       |
| Roteamento     | Valhalla (processo local na Pi)             | ✓      | ✓       |
| Tráfego        | Here Maps Traffic API                       | ✓      | —       |
| Busca/POIs     | Nominatim + Overpass API (OSM)              | ✓      | parcial |
| Música local   | MPD (Music Player Daemon)                   | —      | ✓       |
| Spotify        | librespot (daemon, protocolo nativo)        | ✓      | —       |
| YT / SoundCloud| yt-dlp (stream on-demand)                  | ✓      | —       |
| YouTube (vídeo)| QtWebEngine → youtube.com/tv               | ✓      | —       |
| Navegador      | QtWebEngine (fullscreen)                    | ✓      | —       |
| Alertas        | Waze API / dados OSM comunitários (TBD)     | ✓      | —       |

---

## Tiles de Mapa

- **Provedor:** MapTiler (free tier: 100k tiles/mês — suficiente para uso pessoal)
- **Formato offline:** PMTiles ou MBTiles armazenados localmente no cartão SD
- **Estilo:** Estilo customizado automotivo (baseado na especificação MapLibre Style Spec)
- **3D buildings:** camada fill-extrusion via dados OSM
- **Terrain 3D:** DEM tiles (Digital Elevation Model) via MapTiler Terrain

---

## Comunicação entre Processos

```
┌─────────────────────────────────────────────┐
│             Hermes Qt Process               │
│                                             │
│  QML UI  ←→  C++ Core  ←→  D-Bus / Sockets │
└──────────────────┬──────────────────────────┘
                   │ D-Bus / Unix Sockets
       ┌───────────┼───────────┐
       ▼           ▼           ▼
   librespot      MPD       Valhalla
   (Spotify)   (música     (routing
    daemon)     local)      server)
```

Apps externas (Chromium para YouTube) rodam como processos Wayland separados,
gerenciados pelo Cage. O Hermes controla quando abrir/fechar esses processos.

---

## Decisões de Arquitetura — Justificativas

### Por que Buildroot e não RPi OS?
Boot rápido (~8s vs ~25s), imagem mínima sem pacotes desnecessários,
controle total sobre o que roda no sistema. Custo: setup inicial mais trabalhoso.

### Por que MapLibre e não Google Maps?
Google Maps não possui SDK nativo para Linux/C++. MapLibre GL Native
oferece renderização 3D nativa como componente Qt, suporte offline completo,
e o mesmo nível visual das soluções automotivas comerciais (mesmo motor do Mapbox).

### Por que Wayland + Cage e não EGLFS?
EGLFS não permite rodar processos externos com UI própria. Cage permite
que o Hermes gerencie apps como Chromium como janelas Wayland, mantendo
a barra do sistema sempre visível.

### Por que librespot e não Spotify Web API?
librespot implementa o protocolo Spotify Connect nativamente em C++/Rust,
sem necessidade de browser ou electron. A UI fica 100% em QML.

### Por que yt-dlp e não YouTube API?
YouTube Data API não permite streaming de mídia. yt-dlp extrai a URL
de stream diretamente, que o player Qt reproduz via Qt Multimedia / mpv.
