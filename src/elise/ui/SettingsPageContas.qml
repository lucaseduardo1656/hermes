import QtQuick
import Elise

// Page: Contas — Conta Elise + serviços externos vinculados ao perfil.
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

        SettingsCard {
            title: "Conta Elise"

            SettingsAction { label: "Status de login"; sublabel: "Não autenticado" }
            SettingsToggle { label: "Sincronização";   checked: false }
            SettingsAction { label: "Segurança";       sublabel: "Senha, autenticação em duas etapas" }
        }

        SettingsCard {
            title: "Contas conectadas"

            SettingsAction { label: "Spotify";       sublabel: "Desconectado" }
            SettingsAction { label: "YouTube Music"; sublabel: "Desconectado" }
            SettingsAction { label: "Google";        sublabel: "Desconectado" }
        }
    }
}
