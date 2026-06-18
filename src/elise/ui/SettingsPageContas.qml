pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Elise

// Page: Contas — Conta Elise + serviços externos vinculados ao perfil.
// Placeholder content (no auth backend yet), nexus-styled.
VerticalFadeFlickable {
    id: root
    clip: true
    contentWidth: width
    contentHeight: _col.implicitHeight + topMargin + bottomMargin
    topMargin: Tokens.padding.large
    bottomMargin: Tokens.padding.extraLarge

    property bool _sync: false

    ColumnLayout {
        id: _col
        anchors { left: parent.left; right: parent.right; top: parent.top
                  leftMargin: Tokens.padding.large; rightMargin: Tokens.padding.large }
        spacing: Tokens.spacing.extraSmall / 2

        // ── Conta Elise ─────────────────────────────────────────────────────
        SectionHeader { first: true; text: "Conta Elise" }
        NavRow {
            first: true
            label: "Status de login"
            status: "Não autenticado"
        }
        ToggleRow {
            text: "Sincronização"
            checked: root._sync
            onToggled: root._sync = checked
        }
        NavRow {
            last: true
            label: "Segurança"
            status: "Senha, autenticação em duas etapas"
        }

        // ── Contas conectadas ───────────────────────────────────────────────
        SectionHeader { text: "Contas conectadas" }
        NavRow {
            first: true
            label: "Spotify"
            status: "Desconectado"
        }
        NavRow {
            label: "YouTube Music"
            status: "Desconectado"
        }
        NavRow {
            last: true
            label: "Google"
            status: "Desconectado"
        }
    }
}
