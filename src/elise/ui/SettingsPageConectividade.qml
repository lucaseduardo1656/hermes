import QtQuick
import Elise

// Page: Conectividade — Wi-Fi, Bluetooth, Hotspot.
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
            title: "Wi-Fi"

            SettingsToggle { label: "Wi-Fi";          checked: false }
            SettingsAction { label: "Redes salvas";   sublabel: "0 redes" }
            SettingsAction { label: "Adicionar rede" }
        }

        SettingsCard {
            title: "Bluetooth"

            SettingsToggle { label: "Bluetooth";              checked: false }
            SettingsAction { label: "Dispositivos pareados";  sublabel: "Nenhum" }
            SettingsAction { label: "Parear novo dispositivo" }
        }

        SettingsCard {
            title: "Hotspot"

            SettingsToggle { label: "Compartilhar conexão";  checked: false }
            SettingsAction { label: "Nome da rede";          sublabel: "elise-hotspot" }
            SettingsAction { label: "Senha" }
        }
    }
}
