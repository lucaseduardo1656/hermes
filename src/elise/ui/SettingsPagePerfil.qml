pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Elise

// Page: Perfil — gerenciamento do usuário ativo. Placeholder content (no profile
// backend yet); laid out in the Caelestia nexus style for visual consistency.
VerticalFadeFlickable {
    id: root
    clip: true
    contentWidth: width
    contentHeight: _col.implicitHeight + topMargin + bottomMargin
    topMargin: Tokens.padding.large
    bottomMargin: Tokens.padding.extraLarge

    property bool _cloudSync: false

    ColumnLayout {
        id: _col
        anchors { left: parent.left; right: parent.right; top: parent.top
                  leftMargin: Tokens.padding.large; rightMargin: Tokens.padding.large }
        spacing: Tokens.spacing.extraSmall / 2

        // ── Hero: avatar + nome ─────────────────────────────────────────────
        ConnectedRect {
            Layout.fillWidth: true
            first: true; last: true
            implicitHeight: hero.implicitHeight + Tokens.padding.extraLarge * 2

            RowLayout {
                id: hero
                anchors.fill: parent
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.large

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    width: 72; height: 72; radius: width / 2
                    color: Colours.palette.m3surfaceContainerHighest
                    SvgIcon {
                        anchors.centerIn: parent
                        source: "qrc:/icons/user.svg"
                        color: Colours.palette.m3onSurfaceVariant; size: Theme.iconL
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall
                    StyledText {
                        Layout.fillWidth: true
                        text: "Convidado"
                        font: Tokens.font.title.medium
                        elide: Text.ElideRight
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: "Toque para entrar com sua conta Elise"
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.medium
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        // ── Perfil ──────────────────────────────────────────────────────────
        SectionHeader { first: true; text: "Perfil" }
        NavRow {
            first: true
            label: "Trocar perfil"
            status: "Alternar entre perfis salvos"
        }
        NavRow {
            label: "Preferências pessoais"
        }
        ToggleRow {
            last: true
            text: "Sincronização na nuvem"
            checked: root._cloudSync
            onToggled: root._cloudSync = checked
        }

        // ── Sessão ──────────────────────────────────────────────────────────
        SectionHeader { text: "Sessão" }
        NavRow {
            first: true; last: true
            label: "Sair"
            status: "Encerra a sessão deste perfil"
        }
    }
}
