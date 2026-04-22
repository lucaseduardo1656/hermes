import QtQuick

Item {
    id: root

    property bool open: false
    signal closeRequested()

    property int selectedCategory: 0

    // Local display/audio state
    property int  displayTheme:    2       // 0=Dia 1=Noite 2=Auto
    property bool nightShift:      false
    property real brightness:      0.08
    property bool brightnessAuto:  true
    property real volume:          0.75
    property int  audioBalance:    1       // 0=Esq 1=Centro 2=Dir
    property int  displayLanguage: 0       // 0=Português 1=English

    // WiFi connect dialog state
    property string _connectSsid:     ""
    property bool   _connectSecured:  false
    property bool   _showPassDialog:  false

    readonly property var categories: [
        { name: "Rede",      icon: "qrc:/icons/wifi.svg"     },
        { name: "Bluetooth", icon: "qrc:/icons/bluetooth.svg"},
        { name: "Áudio",     icon: "qrc:/icons/volume-2.svg" },
        { name: "Display",   icon: "qrc:/icons/monitor.svg"  },
        { name: "Sistema",   icon: "qrc:/icons/settings.svg" }
    ]

    // ── EliseSwitch ───────────────────────────────────────────
    component EliseSwitch: Item {
        id: sw
        property bool checked: false
        signal toggled(bool value)
        width: 44; height: 26

        Rectangle {
            anchors.fill: parent
            radius: 13
            color: sw.checked ? "#005AFF" : "#3D3D3D"
            Behavior on color { ColorAnimation { duration: 150 } }

            Rectangle {
                width: 22; height: 22; radius: 11
                color: "#FFFFFF"
                anchors.verticalCenter: parent.verticalCenter
                x: sw.checked ? parent.width - width - 2 : 2
                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: { sw.checked = !sw.checked; sw.toggled(sw.checked) }
        }
    }

    // ── EliseSegmented ────────────────────────────────────────
    component EliseSegmented: Item {
        id: seg
        property var options: []
        property int currentIndex: 0
        signal selected(int index)
        height: 38

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: "#252525"
            border.color: "#333333"; border.width: 1

            Repeater {
                model: seg.options
                Item {
                    x: 2 + index * ((seg.width - 4) / seg.options.length)
                    y: 2
                    width: (seg.width - 4) / seg.options.length
                    height: parent.height - 4

                    Rectangle {
                        anchors.fill: parent; anchors.margins: 1
                        radius: 6
                        color: index === seg.currentIndex ? "#3D3D3D" : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: index === seg.currentIndex ? "#F0F0F0" : "#757575"
                        font.pixelSize: 13
                        font.weight: index === seg.currentIndex ? Font.Medium : Font.Normal
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { seg.currentIndex = index; seg.selected(index) }
                    }
                }
            }
        }
    }

    // ── Signal bars ───────────────────────────────────────────
    component SignalBars: Row {
        property int signal: 0   // 0-100
        spacing: 3
        Repeater {
            model: 4
            Rectangle {
                width: 4
                height: 5 + index * 4
                anchors.bottom: parent ? parent.bottom : undefined
                radius: 1
                color: index < Math.ceil(signal / 25) ? "#005AFF" : "#3D3D3D"
            }
        }
    }

    // ── Panel ─────────────────────────────────────────────────
    Rectangle {
        id: panel
        width: parent.width; height: parent.height
        y: root.open ? 0 : parent.height
        color: "#1A1A1A"
        Behavior on y { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

        // Header
        Item {
            id: header
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 52

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: "#2D2D2D"
            }
            Text {
                anchors { left: parent.left; leftMargin: 24; verticalCenter: parent.verticalCenter }
                text: "Configurações"
                color: "#F0F0F0"; font.pixelSize: 18; font.weight: Font.Medium; font.letterSpacing: 1
            }
            MouseArea {
                id: closeBtn
                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                width: 44; height: 44
                onClicked: root.closeRequested()
                Rectangle {
                    anchors.fill: parent; radius: 8
                    color: closeBtn.pressed ? "#2D2D2D" : "transparent"
                    Text { anchors.centerIn: parent; text: "✕"; color: "#757575"; font.pixelSize: 18 }
                }
            }
        }

        // Sidebar + content
        Row {
            anchors { top: header.bottom; bottom: parent.bottom; left: parent.left; right: parent.right }

            // Sidebar
            Rectangle {
                width: 190; height: parent.height; color: "#141414"

                Column {
                    anchors { top: parent.top; topMargin: 8 }
                    width: parent.width

                    Repeater {
                        model: root.categories
                        Item {
                            width: 190; height: 54

                            Rectangle {
                                anchors.fill: parent
                                color: index === root.selectedCategory ? "#252525" : "transparent"
                            }
                            Row {
                                anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
                                spacing: 12
                                Image {
                                    source: modelData.icon
                                    width: 18; height: 18
                                    anchors.verticalCenter: parent.verticalCenter
                                    opacity: index === root.selectedCategory ? 1.0 : 0.35
                                }
                                Text {
                                    text: modelData.name
                                    color: index === root.selectedCategory ? "#F0F0F0" : "#757575"
                                    font.pixelSize: 14
                                    font.weight: index === root.selectedCategory ? Font.Medium : Font.Normal
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            MouseArea { anchors.fill: parent; onClicked: root.selectedCategory = index }
                        }
                    }
                }

                Rectangle {
                    anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
                    width: 1; color: "#2D2D2D"
                }
            }

            // Content area
            Flickable {
                id: contentFlick
                width: parent.width - 191
                height: parent.height
                contentHeight: contentCol.implicitHeight + 48
                clip: true
                flickableDirection: Flickable.VerticalFlick

                Column {
                    id: contentCol
                    width: contentFlick.width
                    topPadding: 28
                    leftPadding: 28
                    rightPadding: 28
                    spacing: 0

                    // ── Rede (WiFi) ───────────────────────────
                    Column {
                        width: parent.width - 56
                        spacing: 0
                        visible: root.selectedCategory === 0

                        // WiFi toggle row
                        Item {
                            width: parent.width; height: 60
                            Rectangle {
                                anchors.bottom: parent.bottom; width: parent.width
                                height: 1; color: "#252525"
                            }
                            Column {
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                spacing: 3
                                Text { text: "Wi-Fi"; color: "#D0D0D0"; font.pixelSize: 14 }
                                Text {
                                    text: Network.wifiEnabled
                                          ? (Network.wifiConnected ? ("Conectado · " + Network.wifiSsid) : "Ligado, desconectado")
                                          : "Desligado"
                                    color: "#606060"; font.pixelSize: 12
                                }
                            }
                            EliseSwitch {
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                checked: Network.wifiEnabled
                                onToggled: (v) => Network.setWifiEnabled(v)
                            }
                        }

                        // Current connection card
                        Item {
                            width: parent.width; height: 76
                            visible: Network.wifiConnected

                            Rectangle {
                                anchors.fill: parent; anchors.topMargin: 12
                                color: "#252525"; radius: 8
                                Row {
                                    anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                                    spacing: 16
                                    Column {
                                        spacing: 4; anchors.verticalCenter: parent.verticalCenter
                                        Text { text: Network.wifiSsid; color: "#F0F0F0"; font.pixelSize: 14; font.weight: Font.Medium }
                                        Text { text: Network.wifiIp;   color: "#757575"; font.pixelSize: 12 }
                                    }
                                }
                                SignalBars {
                                    anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                                    signal: Network.wifiSignal
                                }
                            }
                        }

                        // Spacer
                        Item { width: parent.width; height: 16; visible: Network.wifiEnabled }

                        // Scan button
                        Rectangle {
                            width: parent.width; height: 42; radius: 8
                            color: "#252525"; border.color: "#333333"; border.width: 1
                            visible: Network.wifiEnabled

                            Row {
                                anchors.centerIn: parent; spacing: 10
                                Text {
                                    text: Network.wifiScanning ? "Escaneando…" : "Escanear Redes"
                                    color: Network.wifiScanning ? "#606060" : "#005AFF"
                                    font.pixelSize: 14; font.weight: Font.Medium
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: !Network.wifiScanning
                                onClicked: Network.wifiScan()
                            }
                        }

                        Item { width: parent.width; height: 12; visible: Network.wifiEnabled }

                        // Network list
                        Column {
                            width: parent.width; spacing: 0
                            visible: Network.wifiEnabled && Network.wifiNetworks.length > 0

                            Text {
                                text: "REDES DISPONÍVEIS"; color: "#505050"
                                font.pixelSize: 11; font.letterSpacing: 2; bottomPadding: 10
                            }

                            Repeater {
                                model: Network.wifiNetworks
                                Item {
                                    width: parent.width; height: 52
                                    property var net: Network.wifiNetworks[index]

                                    Rectangle {
                                        anchors.bottom: parent.bottom; width: parent.width
                                        height: 1; color: "#252525"
                                    }

                                    Row {
                                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                        spacing: 10

                                        // Lock icon for secured networks
                                        Text {
                                            text: "🔒"
                                            font.pixelSize: 12
                                            visible: net && net.secured
                                            anchors.verticalCenter: parent.verticalCenter
                                            opacity: 0.5
                                        }
                                        Text {
                                            text: net ? net.ssid : ""
                                            color: (net && net.ssid === Network.wifiSsid) ? "#005AFF" : "#D0D0D0"
                                            font.pixelSize: 14
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    SignalBars {
                                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                        signal: net ? net.signal : 0
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            root._connectSsid    = net.ssid
                                            root._connectSecured = net.secured
                                            if (net.secured) {
                                                root._showPassDialog = true
                                            } else {
                                                Network.wifiConnect(net.ssid, "")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── Bluetooth ─────────────────────────────
                    Column {
                        width: parent.width - 56
                        spacing: 0
                        visible: root.selectedCategory === 1

                        Item {
                            width: parent.width; height: 60
                            Rectangle {
                                anchors.bottom: parent.bottom; width: parent.width
                                height: 1; color: "#252525"
                            }
                            Column {
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                spacing: 3
                                Text { text: "Bluetooth"; color: "#D0D0D0"; font.pixelSize: 14 }
                                Text {
                                    text: Network.btEnabled
                                          ? ("Visível como " + (Network.btName || "Elise"))
                                          : "Desligado"
                                    color: "#606060"; font.pixelSize: 12
                                }
                            }
                            EliseSwitch {
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                checked: Network.btEnabled
                                onToggled: (v) => Network.setBtEnabled(v)
                            }
                        }

                        // Paired devices
                        Column {
                            width: parent.width; spacing: 0
                            visible: Network.btEnabled && Network.btPaired.length > 0

                            Item { width: parent.width; height: 20 }

                            Text {
                                text: "DISPOSITIVOS PAREADOS"; color: "#505050"
                                font.pixelSize: 11; font.letterSpacing: 2; bottomPadding: 8
                            }

                            Repeater {
                                model: Network.btPaired
                                Item {
                                    width: parent.width; height: 52
                                    property var dev: Network.btPaired[index]
                                    Rectangle {
                                        anchors.bottom: parent.bottom; width: parent.width
                                        height: 1; color: "#252525"
                                    }
                                    Text {
                                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                        text: dev ? dev.name : ""
                                        color: "#D0D0D0"; font.pixelSize: 14
                                    }
                                    Text {
                                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                        text: dev ? dev.address : ""
                                        color: "#505050"; font.pixelSize: 11
                                    }
                                }
                            }
                        }

                        Item {
                            width: parent.width; height: 60
                            visible: Network.btEnabled && Network.btPaired.length === 0
                            Text {
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                text: "Nenhum dispositivo pareado"
                                color: "#505050"; font.pixelSize: 13
                            }
                        }
                    }

                    // ── Áudio ─────────────────────────────────
                    Column {
                        width: parent.width - 56
                        spacing: 24
                        visible: root.selectedCategory === 2

                        Text { text: "ÁUDIO"; color: "#505050"; font.pixelSize: 11; font.letterSpacing: 2 }

                        Column {
                            width: parent.width; spacing: 14
                            Text { text: "Volume"; color: "#D0D0D0"; font.pixelSize: 14 }
                            Item {
                                width: parent.width; height: 28
                                Text {
                                    id: volIcon; anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                    text: "♪"; color: "#606060"; font.pixelSize: 16
                                }
                                Text {
                                    id: volPct
                                    anchors { left: volIcon.right; leftMargin: 8; verticalCenter: parent.verticalCenter }
                                    text: Math.round(root.volume * 100) + "%"
                                    color: "#606060"; font.pixelSize: 13; width: 36
                                }
                                Rectangle {
                                    id: volTrack
                                    anchors { left: volPct.right; leftMargin: 10; right: parent.right; verticalCenter: parent.verticalCenter }
                                    height: 4; radius: 2; color: "#2D2D2D"
                                    Rectangle { width: parent.width * root.volume; height: parent.height; radius: 2; color: "#005AFF" }
                                    Rectangle {
                                        width: 20; height: 20; radius: 10; color: "#FFFFFF"
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: Math.max(0, Math.min(parent.width - width, parent.width * root.volume - width / 2))
                                    }
                                    MouseArea {
                                        anchors.fill: parent; anchors.topMargin: -12; anchors.bottomMargin: -12
                                        onPressed:          root.volume = Math.max(0, Math.min(1, mouseX / volTrack.width))
                                        onPositionChanged:  if (pressed) root.volume = Math.max(0, Math.min(1, mouseX / volTrack.width))
                                    }
                                }
                            }
                        }

                        Column {
                            width: parent.width; spacing: 10
                            Text { text: "Balanço"; color: "#D0D0D0"; font.pixelSize: 14 }
                            EliseSegmented {
                                width: parent.width
                                options: ["Esquerdo", "Centro", "Direito"]
                                currentIndex: root.audioBalance
                                onSelected: (i) => root.audioBalance = i
                            }
                        }
                    }

                    // ── Display ───────────────────────────────
                    Column {
                        width: parent.width - 56
                        spacing: 0
                        visible: root.selectedCategory === 3

                        // Appearance
                        Text {
                            text: "Aparência"
                            color: "#D0D0D0"; font.pixelSize: 15; font.weight: Font.Medium
                            bottomPadding: 14
                        }
                        EliseSegmented {
                            width: parent.width
                            options: ["Dia", "Noite", "Auto"]
                            currentIndex: root.displayTheme
                            onSelected: (i) => root.displayTheme = i
                        }

                        Item { width: parent.width; height: 20 }

                        // Night Shift toggle row
                        Item {
                            width: parent.width; height: 68
                            Rectangle {
                                anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#252525"
                            }
                            EliseSwitch {
                                id: nsSwitch
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                checked: root.nightShift
                                onToggled: (v) => root.nightShift = v
                            }
                            Column {
                                anchors { left: nsSwitch.right; leftMargin: 16; verticalCenter: parent.verticalCenter }
                                spacing: 4
                                Text { text: "Luz Noturna"; color: "#D0D0D0"; font.pixelSize: 14 }
                                Text {
                                    text: "Reduz automaticamente a luz azul à noite"
                                    color: "#606060"; font.pixelSize: 12
                                }
                            }
                        }

                        Item { width: parent.width; height: 20 }

                        // Brightness label
                        Text { text: "Brilho"; color: "#757575"; font.pixelSize: 12; font.letterSpacing: 1; bottomPadding: 10 }

                        // Brightness control — identical to reference
                        Row {
                            width: parent.width; spacing: 10

                            Rectangle {
                                width: parent.width - autoBtn2.width - 10
                                height: 48; radius: 8; color: "#252525"

                                Row {
                                    anchors.fill: parent

                                    // Left (dim sun)
                                    Rectangle {
                                        width: 52; height: parent.height; color: "#1E1E1E"
                                        radius: 8
                                        Image {
                                            anchors.centerIn: parent
                                            source: "qrc:/icons/sun.svg"
                                            width: 16; height: 16; opacity: 0.4
                                        }
                                    }

                                    // Percentage
                                    Text {
                                        width: 38; height: parent.height
                                        verticalAlignment: Text.AlignVCenter
                                        horizontalAlignment: Text.AlignHCenter
                                        text: Math.round(root.brightness * 100) + "%"
                                        color: "#D0D0D0"; font.pixelSize: 13
                                    }

                                    // Track
                                    Item {
                                        width: parent.width - 52 - 38 - 52; height: parent.height

                                        Rectangle {
                                            id: briTrack
                                            anchors { left: parent.left; right: parent.right; leftMargin: 8; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                            height: 4; radius: 2; color: "#3D3D3D"

                                            Rectangle {
                                                width: parent.width * root.brightness; height: parent.height; radius: 2; color: "#005AFF"
                                            }
                                            Rectangle {
                                                width: 20; height: 20; radius: 10; color: "#FFFFFF"
                                                anchors.verticalCenter: parent.verticalCenter
                                                x: Math.max(0, Math.min(parent.width - width, parent.width * root.brightness - width / 2))
                                            }
                                            MouseArea {
                                                anchors.fill: parent; anchors.topMargin: -20; anchors.bottomMargin: -20
                                                onPressed:          root.brightness = Math.max(0, Math.min(1, mouseX / briTrack.width))
                                                onPositionChanged:  if (pressed) root.brightness = Math.max(0, Math.min(1, mouseX / briTrack.width))
                                            }
                                        }
                                    }

                                    // Right (bright sun)
                                    Rectangle {
                                        width: 52; height: parent.height; color: "#1E1E1E"
                                        radius: 8
                                        Image {
                                            anchors.centerIn: parent
                                            source: "qrc:/icons/sun.svg"
                                            width: 22; height: 22
                                        }
                                    }
                                }
                            }

                            // Auto button
                            Rectangle {
                                id: autoBtn2
                                width: 72; height: 48; radius: 8
                                color: root.brightnessAuto ? "#005AFF" : "#252525"
                                border.color: root.brightnessAuto ? "#005AFF" : "#333333"; border.width: 1
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Text {
                                    anchors.centerIn: parent; text: "Auto"
                                    color: root.brightnessAuto ? "#FFFFFF" : "#757575"
                                    font.pixelSize: 13; font.weight: Font.Medium
                                }
                                MouseArea { anchors.fill: parent; onClicked: root.brightnessAuto = !root.brightnessAuto }
                            }
                        }

                        Item { width: parent.width; height: 16 }

                        // Screen Clean Mode button
                        Rectangle {
                            width: parent.width; height: 48; radius: 8; color: "#2D2D2D"
                            Text {
                                anchors.centerIn: parent; text: "Limpar Tela"
                                color: "#D0D0D0"; font.pixelSize: 14; font.weight: Font.Medium
                            }
                            MouseArea { anchors.fill: parent }
                        }

                        Item { width: parent.width; height: 24 }
                        Rectangle { width: parent.width; height: 1; color: "#252525" }
                        Item { width: parent.width; height: 24 }

                        // Language
                        Text { text: "Idioma"; color: "#D0D0D0"; font.pixelSize: 14; font.weight: Font.Medium; bottomPadding: 12 }

                        Rectangle {
                            id: langBtn
                            property bool expanded: false
                            width: parent.width; height: 42; radius: 8; color: "#252525"
                            border.color: "#333333"; border.width: 1

                            Text {
                                anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                                text: root.displayLanguage === 0 ? "Português" : "English"
                                color: "#D0D0D0"; font.pixelSize: 14
                            }
                            Text {
                                anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                                text: "▾"; color: "#757575"; font.pixelSize: 13
                            }
                            MouseArea { anchors.fill: parent; onClicked: langBtn.expanded = !langBtn.expanded }
                        }

                        Rectangle {
                            width: parent.width; height: 84; radius: 8; color: "#2D2D2D"
                            border.color: "#3D3D3D"; border.width: 1
                            visible: langBtn.expanded; z: 10

                            Column {
                                anchors.fill: parent
                                Repeater {
                                    model: ["Português", "English"]
                                    Item {
                                        width: parent.width; height: 42
                                        Text {
                                            anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                                            text: modelData
                                            color: index === root.displayLanguage ? "#F0F0F0" : "#D0D0D0"
                                            font.pixelSize: 14
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: { root.displayLanguage = index; langBtn.expanded = false }
                                        }
                                    }
                                }
                            }
                        }

                        Item { width: parent.width; height: 8 }
                    }

                    // ── Sistema ───────────────────────────────
                    Column {
                        width: parent.width - 56
                        spacing: 0
                        visible: root.selectedCategory === 4

                        Text { text: "SISTEMA"; color: "#505050"; font.pixelSize: 11; font.letterSpacing: 2; bottomPadding: 16 }

                        Repeater {
                            model: [
                                { label: "Versão do app",       value: "Elise 0.1.0-dev"   },
                                { label: "Sistema operacional", value: "Hermes OS · Buildroot" },
                                { label: "Hardware",            value: "Raspberry Pi 5"     }
                            ]
                            Item {
                                width: parent.width; height: 52
                                Rectangle {
                                    anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#252525"
                                }
                                Text {
                                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                    text: modelData.label; color: "#D0D0D0"; font.pixelSize: 14
                                }
                                Text {
                                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                    text: modelData.value; color: "#606060"; font.pixelSize: 13
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Password dialog (overlay) ──────────────────────────
        Item {
            anchors.fill: parent
            visible: root._showPassDialog
            z: 20

            Rectangle { anchors.fill: parent; color: "#80000000" }

            Rectangle {
                width: 420; height: 180
                anchors.centerIn: parent
                color: "#252525"; radius: 12

                Column {
                    anchors { fill: parent; margins: 24 }
                    spacing: 16

                    Text {
                        text: 'Conectar a "' + root._connectSsid + '"'
                        color: "#F0F0F0"; font.pixelSize: 15; font.weight: Font.Medium
                    }

                    Rectangle {
                        width: parent.width; height: 40; radius: 8
                        color: "#1A1A1A"; border.color: "#3D3D3D"; border.width: 1

                        TextInput {
                            id: passInput
                            anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                            verticalAlignment: TextInput.AlignVCenter
                            color: "#F0F0F0"; font.pixelSize: 14
                            echoMode: TextInput.Password
                            focus: root._showPassDialog
                        }
                        Text {
                            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                            text: "Senha"; color: "#505050"; font.pixelSize: 14
                            visible: passInput.text.length === 0
                        }
                    }

                    Row {
                        anchors.right: parent.right; spacing: 10

                        Rectangle {
                            width: 96; height: 36; radius: 8; color: "#333333"
                            Text { anchors.centerIn: parent; text: "Cancelar"; color: "#D0D0D0"; font.pixelSize: 13 }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: { root._showPassDialog = false; passInput.text = "" }
                            }
                        }

                        Rectangle {
                            width: 96; height: 36; radius: 8; color: "#005AFF"
                            Text { anchors.centerIn: parent; text: "Conectar"; color: "#FFFFFF"; font.pixelSize: 13; font.weight: Font.Medium }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    Network.wifiConnect(root._connectSsid, passInput.text)
                                    root._showPassDialog = false
                                    passInput.text = ""
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
