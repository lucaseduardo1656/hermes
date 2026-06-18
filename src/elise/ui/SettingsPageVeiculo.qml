pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Elise

// Page: Veículo — preferências do carro. Placeholder content (no vehicle bus
// backend yet); toggles keep local state so they animate. Nexus-styled.
VerticalFadeFlickable {
    id: root
    clip: true
    contentWidth: width
    contentHeight: _col.implicitHeight + topMargin + bottomMargin
    topMargin: Tokens.padding.large
    bottomMargin: Tokens.padding.extraLarge

    property bool _autoHead:   true
    property bool _ambient:    false
    property bool _lockStart:  true
    property bool _unlockOff:  false
    property bool _laneWarn:   false
    property bool _autoBrake:  false
    property bool _eco:        false

    ColumnLayout {
        id: _col
        anchors { left: parent.left; right: parent.right; top: parent.top
                  leftMargin: Tokens.padding.large; rightMargin: Tokens.padding.large }
        spacing: Tokens.spacing.extraSmall / 2

        // ── Iluminação ──────────────────────────────────────────────────────
        SectionHeader { first: true; text: "Iluminação" }
        ToggleRow {
            first: true
            text: "Faróis automáticos"
            checked: root._autoHead
            onToggled: root._autoHead = checked
        }
        ToggleRow {
            text: "Luz ambiente interna"
            checked: root._ambient
            onToggled: root._ambient = checked
        }
        NavRow {
            last: true
            label: "Intensidade"
            status: "Médio"
        }

        // ── Travas ──────────────────────────────────────────────────────────
        SectionHeader { text: "Travas" }
        ToggleRow {
            first: true
            text: "Travamento ao iniciar"
            checked: root._lockStart
            onToggled: root._lockStart = checked
        }
        ToggleRow {
            last: true
            text: "Destravar ao desligar"
            checked: root._unlockOff
            onToggled: root._unlockOff = checked
        }

        // ── Assistência de direção ──────────────────────────────────────────
        SectionHeader { text: "Assistência de direção" }
        ToggleRow {
            first: true
            text: "Aviso de faixa"
            checked: root._laneWarn
            onToggled: root._laneWarn = checked
        }
        ToggleRow {
            text: "Frenagem automática"
            checked: root._autoBrake
            onToggled: root._autoBrake = checked
        }
        NavRow {
            last: true
            label: "Sensibilidade"
            status: "Padrão"
        }

        // ── Economia de energia ─────────────────────────────────────────────
        SectionHeader { text: "Economia de energia" }
        ToggleRow {
            first: true
            text: "Modo eco"
            checked: root._eco
            onToggled: root._eco = checked
        }
        NavRow {
            last: true
            label: "Limite de partida"
            status: "12.0 V"
        }
    }
}
