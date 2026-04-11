# Hermes — Módulos do Sistema

## Estrutura de Módulos

```
hermes/
├── core/           Sistema base, boot, ciclo de vida
├── map/            Mapas, navegação, routing
├── player/         Música local, Spotify, streaming
├── media/          YouTube, browser (WebEngine)
├── alerts/         Alertas de trânsito, clima, POIs
├── settings/       Configurações, WiFi, Bluetooth
└── integrations/   Bridges para serviços externos
```

---

## core

**Responsabilidade:** inicialização do sistema, gerenciamento de processos,
comunicação D-Bus, ciclo de vida da aplicação.

- Boot splash animado (logo Hermes)
- Gerenciamento de processos externos (librespot, MPD, Valhalla, Chromium)
- Bridge D-Bus para comunicação entre módulos
- Gerenciamento de estado global (rota ativa, mídia ativa, etc.)
- Watchdog para reiniciar processos que falham

---

## map

**Responsabilidade:** renderização de mapas, navegação turn-by-turn,
busca de endereços, POIs, alertas de trânsito.

### Componentes

| Componente | Tecnologia | Descrição |
|---|---|---|
| Renderizador | MapLibre GL Native (Qt plugin) | Mapa 3D, tiles, estilos |
| Routing engine | Valhalla (processo local) | Cálculo de rotas, turn-by-turn |
| Tile source (online) | MapTiler API | Tiles HD, 3D buildings, terrain |
| Tile cache (offline) | PMTiles / MBTiles local | Áreas pré-baixadas no SD |
| Tráfego | Here Maps Traffic API | Fluxo em tempo real |
| Busca | Nominatim (OSM) | Geocoding, busca de endereços |
| POIs | Overpass API (OSM) | Postos, restaurantes, etc. |

### Features
- Mapa 3D com pitch e bearing seguindo direção do veículo
- Turn-by-turn com instruções em voz (TTS)
- Recálculo automático de rota
- Busca de destino com teclado virtual
- Download de região para uso offline
- Camada de tráfego (verde/amarelo/vermelho)
- Velocímetro overlay com limite da via atual
- ETA dinâmico

---

## player

**Responsabilidade:** playback de áudio — local, Spotify, YouTube/SoundCloud.

### Fontes de Áudio

#### Música Local
- Backend: **MPD** (Music Player Daemon)
- Interface: cliente Qt customizado via MPD protocol socket
- Features: biblioteca, playlists, shuffle, busca

#### Spotify
- Backend: **librespot** (implementação open-source Spotify Connect)
- Modo: daemon headless, controlado via socket/D-Bus pelo Hermes
- Features: busca, playlists, Spotify Connect (controle pelo celular)
- Requer: conta Spotify Premium

#### YouTube / YouTube Music / SoundCloud
- Backend: **yt-dlp** chamado on-demand
- Playback: Qt Multimedia ou libmpv integrado
- Features: busca, stream, fila de reprodução
- Obs: yt-dlp extrai URL do stream — não faz download completo por padrão

### UI do Player
- Mini card flutuante (sempre acessível sobre o mapa)
- Tela fullscreen com artwork, waveform, fila
- Modo split: player na metade inferior da tela
- Controles no volante (futura integração via GPIO/CAN)

---

## media

**Responsabilidade:** YouTube (vídeo), navegador web.

### YouTube
- **QtWebEngine** carregando `youtube.com/tv`
- User agent: Chromium (necessário para youtube.com/tv)
- Modo: fullscreen sobre o mapa, dock permanece visível
- Controle de volume integrado ao sistema

### Navegador
- **QtWebEngine** em modo browser completo
- Barra de endereço retrátil (some após 3s)
- Favoritos rápidos no dock do browser
- Teclado virtual Maliit

---

## alerts

**Responsabilidade:** sistema de notificações contextuais em tempo real.

### Tipos de Alerta

| Tipo | Fonte | Duração |
|---|---|---|
| Radar / Polícia | Waze API / dados OSM | 8s + persist se próximo |
| Acidente | Waze API | 10s |
| Chuva / Clima | OpenWeatherMap API | 12s |
| Velocidade excessiva | GPS + dados de limite | Persiste até normalizar |
| Ponto de interesse | OSM / lógica de proximidade | 6s |
| Boas-vindas / chegada | Lógica interna | 5s |

### Sistema de Cards
- Cards empilhados no canto superior direito
- Máximo 2 cards simultâneos (terceiro espera fila)
- Animação: slide from right + fade in/out
- Swipe right para dispensar manualmente
- Prioridade: segurança > navegação > info > entretenimento

---

## settings

**Responsabilidade:** configurações do sistema, periféricos, preferências.

### Quick Settings (Drawer)
- Volume master
- Brilho da tela
- WiFi on/off + seleção de rede
- Bluetooth on/off

### Settings Fullscreen
- **Rede:** WiFi — lista de redes, conectar, esquecer
- **Bluetooth:** pareamento, dispositivos conectados, perfis A2DP/HFP
- **Áudio:** equalizer, balanço, fonte padrão
- **Mapa:** unidades (km/mi), voz de navegação, modo offline
- **Display:** brilho automático, tema (noturno/diurno automático)
- **Sistema:** sobre o Hermes, versão, storage, atualização

---

## integrations

**Responsabilidade:** bridges e adaptadores para serviços externos.

### Serviços

| Serviço | Protocolo | Uso |
|---|---|---|
| librespot | Unix socket / D-Bus | Controle Spotify |
| MPD | MPD protocol (TCP 6600) | Controle música local |
| Valhalla | HTTP REST (localhost) | Routing requests |
| MapTiler | HTTPS / tile URLs | Tiles de mapa |
| Here Maps | HTTPS REST | Tráfego em tempo real |
| OpenWeatherMap | HTTPS REST | Dados climáticos |
| yt-dlp | QProcess (subprocess) | Extração de URLs de stream |
| Waze/OSM | HTTPS REST | Dados de alertas |

---

## Fases de Desenvolvimento

### Fase 1 — Base (MVP)
- [ ] Buildroot para Pi 5 com Qt 6 + Wayland + Cage
- [ ] App Qt mínima: boot direto, fullscreen, toque funcionando
- [ ] MapLibre GL renderizando mapa estático (sem navegação)
- [ ] Dock inferior + Quick Settings drawer

### Fase 2 — Navegação
- [ ] Valhalla rodando localmente
- [ ] Turn-by-turn com instruções
- [ ] Nav strip dinâmica
- [ ] Teclado virtual (Maliit) para busca de destino

### Fase 3 — Áudio
- [ ] MPD integrado, biblioteca de música local
- [ ] librespot, UI Spotify
- [ ] yt-dlp stream, UI YouTube Music / SoundCloud
- [ ] Mini card player sobre o mapa

### Fase 4 — Alertas e POIs
- [ ] Sistema de cards flutuantes
- [ ] Integração clima (OpenWeatherMap)
- [ ] Alertas de trânsito (Waze/Here)
- [ ] Velocímetro + limite de velocidade

### Fase 5 — Media
- [ ] YouTube via QtWebEngine
- [ ] Navegador web
- [ ] Modo split screen

### Fase 6 — Polimento
- [ ] Tema visual final (cores, fontes, animações)
- [ ] Otimização de boot (< 8 segundos)
- [ ] Tiles offline de região
- [ ] Testes em condições reais no carro
