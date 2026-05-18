# Guia de Desenvolvimento de UI — Hermes

## Visão geral do fluxo

```
src/hermes-app/qml/*.qml   ← edita aqui
        ↓
make hermes-app-rebuild    ← recompila só o app
        ↓
make                       ← gera hermes-pi5.img
        ↓
dd → cartão SD             ← flasha no Pi
```

---

## 1. Onde editar

Todos os arquivos de UI ficam em:
```
src/hermes-app/
├── qml/
│   ├── Main.qml          # janela raiz, dialog WiFi, navegação
│   ├── TopBar.qml        # barra superior (relógio, WiFi, botão menu)
│   ├── AppDrawer.qml     # menu lateral (Music, Settings, Map)
│   ├── PlayerStrip.qml   # mini player na base da tela
│   ├── MusicView.qml     # tela de música completa
│   ├── SettingsView.qml  # tela de configurações
│   └── MapView.qml       # mapa (fundo fixo)
├── ThemeManager.h        # paleta de cores (dark/light)
├── ThemeManager.cpp      # lógica de tema (auto/dark/light, hora)
└── icons/                # SVGs dos ícones
```

---

## 2. Sistema de tema (ThemeManager)

O objeto `Theme` fica disponível globalmente em todos os QML.

### Cores disponíveis

| Propriedade | Light | Dark | Uso |
|---|---|---|---|
| `Theme.background` | `#F4F4F4` | `#0E1014` | Fundo de telas |
| `Theme.surface` | `#FFFFFF` | `#171A20` | Cards, barras, dialogs |
| `Theme.surface2` | `#F4F4F4` | `#1F2229` | Hover, inputs |
| `Theme.surface3` | `#EEEEEE` | `#252A33` | Press state |
| `Theme.border` | `#EEEEEE` | `#2A2E38` | Linhas divisórias sutis |
| `Theme.border2` | `#D0D1D2` | `#363A45` | Bordas de inputs |
| `Theme.textPrimary` | `#171A20` | `#F0F0F5` | Texto principal |
| `Theme.textSecond` | `#393C41` | `#8A8D98` | Texto secundário |
| `Theme.textMuted` | `#5C5E62` | `#5C5E6A` | Texto terciário/placeholder |
| `Theme.textDisabled` | `#8E8E8E` | `#3A3D48` | Texto desabilitado |
| `Theme.accent` | `#3E6AE1` | `#3E6AE1` | CTA único (Electric Blue) |
| `Theme.switchOff` | `#D0D1D2` | `#363A45` | Toggle desligado |
| `Theme.inputBg` | `#FFFFFF` | `#0E1014` | Fundo de inputs |

### Como mudar uma cor

Edite `ThemeManager.h`, função correspondente:
```cpp
QColor surface() const { return m_isDark ? QColor("#171A20") : QColor("#FFFFFF"); }
//                                          ^^^ dark           ^^^ light
```

### Adicionar nova cor ao tema

1. Declare em `ThemeManager.h`:
```cpp
Q_PROPERTY(QColor minhaCorNova READ minhaCorNova NOTIFY isDarkChanged)
// ...
QColor minhaCorNova() const { return m_isDark ? QColor("#...") : QColor("#..."); }
```
2. Use em QML: `Theme.minhaCorNova`

---

## 3. Regras de design (inspirado Tesla)

| Regra | Valor |
|---|---|
| Border-radius botões/inputs | `4px` |
| Border-radius cards grandes | `12px` |
| Border-radius dots/toggles | `50%` |
| Transições | `330ms` (`Behavior on color { ColorAnimation { duration: 330 } }`) |
| Peso de fonte normal | `Font.Normal` (400) |
| Peso de fonte UI | `Font.Medium` (500) |
| Nenhum gradiente | nunca use `Gradient {}` |
| Nenhuma sombra | nunca use `layer.effect` ou `dropShadow` |
| Acento único | só `Theme.accent` (`#3E6AE1`) como cor cromática |
| Hover | muda `color` para `Theme.surface2` |
| Press | muda `color` para `Theme.surface3` |

### Padrão de botão
```qml
Rectangle {
    width: 88; height: 36; radius: 4
    color: area.pressed ? Theme.surface3 : Theme.surface2
    Behavior on color { ColorAnimation { duration: 330 } }

    Text {
        anchors.centerIn: parent
        text: "Label"
        color: Theme.textSecond
        font.pixelSize: 13; font.weight: Font.Medium
    }
    MouseArea { id: area; anchors.fill: parent; onClicked: { /* ... */ } }
}
```

### Padrão de botão primário (CTA)
```qml
Rectangle {
    width: 88; height: 36; radius: 4
    color: area.pressed ? "#2F5AC7" : Theme.accent
    Behavior on color { ColorAnimation { duration: 330 } }

    Text {
        anchors.centerIn: parent
        text: "Conectar"
        color: "#FFFFFF"
        font.pixelSize: 13; font.weight: Font.Medium
    }
    MouseArea { id: area; anchors.fill: parent; onClicked: { /* ... */ } }
}
```

### Padrão de linha divisória
```qml
Rectangle {
    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
    height: 1; color: Theme.border
}
```

### Transição de cor (obrigatório em todos os estados interativos)
```qml
Behavior on color { ColorAnimation { duration: 330 } }
```

---

## 4. Adicionar uma nova tela

1. Crie `src/hermes-app/qml/MinhaView.qml`:
```qml
import QtQuick

Rectangle {
    id: root
    color: Theme.background

    Text {
        anchors.centerIn: parent
        text: "Minha tela"
        color: Theme.textPrimary
        font.pixelSize: 22; font.weight: Font.Medium
    }
}
```

2. Em `Main.qml`, declare o componente e conecte na navegação:
```qml
Component {
    id: minhaComp
    MinhaView { }
}

function navigateTo(view) {
    // ...
    else if (view === "minha") appStack.push(minhaComp)
}
```

3. Em `AppDrawer.qml`, adicione no model do `Repeater`:
```qml
{ view: "minha", label: qsTr("Minha View"), icon: "qrc:/icons/meu-icone.svg" }
```

4. Adicione o ícone SVG em `src/hermes-app/icons/meu-icone.svg`

5. Registre o ícone no `CMakeLists.txt` (seção `qt_add_resources` de icons)

---

## 5. Adicionar ícone SVG

Ícones ficam em `src/hermes-app/icons/`. Para adicionar um novo:

1. Coloque o `.svg` na pasta `icons/`
2. Abra `src/hermes-app/CMakeLists.txt` e localize:
```cmake
qt_add_resources(elise "elise_icons"
    PREFIX "/icons"
    FILES
        icons/arrow-left.svg
        # ...
)
```
3. Adicione sua linha: `icons/meu-icone.svg`
4. Use em QML: `source: "qrc:/icons/meu-icone.svg"`

---

## 6. Build e flash

### Rebuild rápido (só o app)
```bash
cd /home/mirage/Projects/hermes/buildroot
make hermes-app-dirclean && make hermes-app && make
```

> **Importante:** use sempre `dirclean` antes de rebuild, não `rebuild`. O `rebuild` reutiliza `.cpp` de QML em cache — se o QML mudou mas o cache ficou stale, o binário gerado tem registros de tipo QML conflitantes e aborta com SIGABRT na inicialização. `dirclean` garante build limpo.

### Flash no cartão SD
```bash
# Descubra o device do cartão (ex: /dev/sdb, /dev/mmcblk0)
lsblk

# Flash (substitua /dev/sdX pelo device correto)
sudo dd if=output/images/hermes-pi5.img of=/dev/sdX bs=4M status=progress
sudo sync
```

> **Atenção:** confirme o device correto com `lsblk` antes do `dd`. Device errado apaga disco do sistema.

### Full rebuild (raro — só se mudar Buildroot/kernel)
```bash
cd /home/mirage/Projects/hermes/buildroot
make
```

---

## 7. Testar sem flashar (desktop preview)

O app pode rodar no desktop Linux para preview rápido sem Pi:

```bash
cd /home/mirage/Projects/hermes/build
cmake ../src/hermes-app -DCMAKE_BUILD_TYPE=Debug
make -j$(nproc)
./elise
```

Requer Qt6 instalado no host (`sudo pacman -S qt6-declarative qt6-svg`).

---

## 8. Referência rápida de cores Tesla

| Nome | Hex | Uso |
|---|---|---|
| Electric Blue | `#3E6AE1` | Único acento, CTAs |
| Carbon Dark | `#171A20` | Texto principal (light), surface dark |
| Graphite | `#393C41` | Texto secundário |
| Pewter | `#5C5E62` | Texto terciário |
| Silver Fog | `#8E8E8E` | Disabled/placeholder |
| Cloud Gray | `#EEEEEE` | Bordas |
| Pale Silver | `#D0D1D2` | Bordas de input |
| Light Ash | `#F4F4F4` | Background light |
| Pure White | `#FFFFFF` | Surface light |
