import QtQuick
import Elise

// Page: Sistema — atualizações, armazenamento, info, reiniciar.
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
            title: "Manutenção"

            SettingsAction { label: "Atualizações";    sublabel: "Sistema atualizado" }
            SettingsAction { label: "Armazenamento";   sublabel: "12.4 GB usado de 32 GB" }
        }

        SettingsCard {
            title: "Sobre"

            SettingsAction { label: "Informações do sistema"; sublabel: "Elise 0.1 · Pi 5" }
        }

        SettingsCard {
            SettingsAction { label: "Reiniciar sistema" }
            SettingsToggle { label: "Modo desenvolvedor"; checked: false }
        }
    }
}
