import QtQuick
import Elise

// Page: Perfil — gerenciamento do usuário ativo.
Flickable {
    id: root
    contentWidth:  width
    contentHeight: _col.implicitHeight + Theme.spaceXL * 2
    clip: true

    Column {
        id: _col
        anchors {
            top: parent.top; topMargin: Theme.spaceXL
            left: parent.left; leftMargin: Theme.spaceXL
            right: parent.right; rightMargin: Theme.spaceXL
        }
        spacing: Theme.spaceXL

        // Avatar + nome
        Row {
            spacing: Theme.spaceL

            Rectangle {
                width: 72; height: 72; radius: 36
                color: System.surface2
                SvgIcon {
                    anchors.centerIn: parent
                    source: "qrc:/icons/user.svg"
                    color:  System.textSecondary
                    size:   Theme.iconL
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spaceXS

                Text {
                    text:  "Convidado"
                    color: System.textPrimary
                    font.pixelSize: Theme.fontTitle
                    font.weight:    Font.Medium
                }
                Text {
                    text:  "Toque para entrar com sua conta Elise"
                    color: System.textMuted
                    font.pixelSize: Theme.fontSmall
                }
            }
        }

        SettingsCard {
            title: "Perfil"

            SettingsAction { label: "Trocar perfil";       sublabel: "Alternar entre perfis salvos" }
            SettingsAction { label: "Preferências pessoais" }
            SettingsToggle { label: "Sincronização na nuvem"; checked: false }
        }

        SettingsCard {
            SettingsAction { label: "Sair"; sublabel: "Encerra a sessão deste perfil" }
        }
    }
}
