# Hermes — Especificação de Layout e UI

## Resolução Alvo
**1024 × 600px** — landscape, touchscreen capacitivo

---

## Filosofia Visual

Inspirado em: Mapbox Automotive SDK, Tesla Model 3
- Fundo escuro (near-black), não preto puro
- Alto contraste nos elementos de navegação
- Tipografia grande, legível em movimento
- Toque como input primário — elementos mínimos de 48×48px
- Mapa 3D é sempre o "fundo" da interface
- Informação aparece quando necessária, some quando não

---

## Layout Principal

```
┌─────────────────────────────────────────────────────┐  600px
│                                     ┌─────────────┐ │
│                                     │  CARD ZONA  │ │ ← cards flutuantes
│            MAPA 3D                  │  (alertas,  │ │   aparecem/somem
│         (MapLibre GL)               │   player,   │ │   com animação
│                                     │   clima)    │ │
│         [ícone posição]             └─────────────┘ │
│                                                     │
├─────────────────────────────────────────────────────┤ ← 540px
│  ↑  Vire à direita em 420m   Av. Paulista     12min │  nav strip (40px)
├──────────┬──────────┬──────────┬───────────────────┤ ← 580px
│  [  🗺  ]│  [  🎵  ]│  [  ⚙  ]│  📶  🔊  11:42   │  dock (60px)
└──────────┴──────────┴──────────┴───────────────────┘  600px
          |←─────────── 1024px ──────────────────────→|
```

### Zonas do Layout

| Zona | Posição | Tamanho | Conteúdo |
|------|---------|---------|----------|
| Mapa | 0,0 | 1024×540px | MapLibre GL Native (fullscreen) |
| Nav Strip | 0,540 | 1024×40px | Instrução atual + distância + ETA |
| Dock | 0,580 | 1024×60px | Botões de app + status icons |
| Card Zone | top-right | ~280×auto | Cards flutuantes empilhados |

---

## Nav Strip (Barra de Navegação)

Visível apenas durante navegação ativa. Recolhe quando não há rota.

```
┌──────────────────────────────────────────────────────┐
│  [seta manobra]  Vire à direita em 420m  |  ETA 12min │
└──────────────────────────────────────────────────────┘
```

- Cor de fundo: `#1A1A2E` com leve translucidez sobre o mapa
- Ícone de manobra: SVG dinâmico (esquerda, direita, rotatória, etc.)
- Distância em destaque — fonte grande
- ETA e nome da rua em fonte menor

---

## Dock (App Bar)

Sempre visível. 3 botões de app à esquerda + status à direita.

```
┌──────────┬──────────┬──────────┬────────────────────┐
│    🗺    │    🎵    │    ⚙    │  📶  🔊  11:42    │
│   Mapa   │  Player  │  Config  │                    │
└──────────┴──────────┴──────────┴────────────────────┘
```

- Botão ativo tem indicador visual (linha/glow na cor de acento)
- Botão de app abre aquele módulo na área do mapa (ou sobre ele)
- Toque longo no botão de config → abre Quick Settings (drawer de cima para baixo)

---

## Card Zone (Canto Superior Direito)

Cards aparecem empilhados verticalmente. Cada card tem animação de entrada
(slide from right + fade) e saída automática após timeout ou com swipe.

### Tipos de Card

#### Mini Player (música tocando)
```
┌──────────────────────────────┐
│ 🎵  Tokyo Tuesday        ×  │
│     Nujabes                  │
│     ◀◀  ▶▶  ▶▶            │
└──────────────────────────────┘
```
- Aparece quando música inicia
- Tap expande para player fullscreen
- Persiste até fechar manualmente

#### Alerta de Trânsito / Perigo
```
┌──────────────────────────────┐
│ ⚠️  Radar policial           │
│     600m à frente            │
└──────────────────────────────┘
```
- Auto-dismiss após 8 segundos
- Borda colorida conforme severidade (amarelo, vermelho)

#### Clima
```
┌──────────────────────────────┐
│ 🌧  Chuva moderada           │
│     Visibilidade reduzida    │
└──────────────────────────────┘
```
- Aparece ao entrar em área com chuva
- Auto-dismiss após 12 segundos

#### Bem-vindo / Ponto de Interesse
```
┌──────────────────────────────┐
│ 📍  Parque Ibirapuera        │
│     A 200m do seu destino    │
└──────────────────────────────┘
```

---

## Modos de Tela

### Modo Mapa (padrão)
Mapa ocupa 100% da área acima do dock. Cards flutuam sobre ele.

### Modo Split — Mapa + Player
Ativado segurando o botão 🎵 no dock ou arrastando o player para cima.

```
┌─────────────────────────────────────────────────────┐
│                                                     │
│              MAPA 3D  (60% altura)                  │
│                                                     │
├─────────────────────────────────────────────────────┤
│                                                     │
│           PLAYER / OUTRA TELA (40% altura)          │  ← 216px
│                                                     │
├─────────────────────────────────────────────────────┤
│  nav strip                                          │
├─────────────────────────────────────────────────────┤
│  dock                                               │
└─────────────────────────────────────────────────────┘
```

### Modo App Fullscreen
Browser, YouTube: ocupam toda a área (0 até 580px, sobre o nav strip).
Um botão fixo (X) no canto retorna ao mapa. Dock permanece visível.

---

## Quick Settings (Drawer)

Ativado por toque longo no ⚙ ou swipe down do topo da tela.
Desce sobre o conteúdo com animação. Fundo com blur/overlay escuro.

```
┌─────────────────────────────────────────────────────┐
│  CONFIGURAÇÕES RÁPIDAS                          ×   │
├──────────────────┬──────────────────────────────────┤
│  WiFi            │  ████████████ Rede_Casa  ▼      │
│  Bluetooth       │  ○ desconectado          ▼      │
│  Volume          │  ──────●────────  75%           │
│  Brilho          │  ───────────●───  90%           │
├──────────────────┴──────────────────────────────────┤
│  [ Dispositivos BT ]  [ Redes WiFi ]  [ Sobre ]    │
└─────────────────────────────────────────────────────┘
```

---

## Paleta de Cores (base — tema noturno)

| Token             | Valor     | Uso                          |
|-------------------|-----------|------------------------------|
| `bg.primary`      | `#0D0D14` | Fundo principal              |
| `bg.surface`      | `#1A1A2E` | Cards, dock, nav strip       |
| `bg.elevated`     | `#252540` | Elementos sobre surface      |
| `accent.primary`  | A definir | Botão ativo, highlights      |
| `text.primary`    | `#F0F0F5` | Texto principal              |
| `text.secondary`  | `#8888AA` | Labels, informação secundária|
| `status.warning`  | `#F5A623` | Alertas amarelos             |
| `status.danger`   | `#E74C3C` | Alertas vermelhos            |
| `status.ok`       | `#2ECC71` | Confirmações                 |

> Cor de acento (`accent.primary`) a ser definida na fase de design visual.

---

## Tipografia

| Uso                  | Tamanho | Peso     |
|----------------------|---------|----------|
| Instrução navegação  | 22px    | SemiBold |
| Nome de rua          | 16px    | Regular  |
| ETA / distância      | 18px    | Bold     |
| Labels do dock       | 11px    | Medium   |
| Cards — título       | 15px    | SemiBold |
| Cards — subtítulo    | 13px    | Regular  |

Fonte: Inter, Geist, ou fonte customizada — a definir na fase de design.
