import QtQuick
import Elise

// Page: Som — volume, equalização, saída, fonte padrão.
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
            title: "Volume"

            SettingsAction { label: "Volume geral";    sublabel: "65%" }
            SettingsAction { label: "Equalizador";     sublabel: "Plano" }
        }

        SettingsCard {
            title: "Saída de áudio"

            SettingsAction { label: "Dispositivo";     sublabel: "Alto-falantes do veículo" }
            SettingsToggle { label: "Áudio espacial";  checked: false }
        }

        SettingsCard {
            title: "Fonte padrão"

            SettingsAction { label: "Serviço de música"; sublabel: "Spotify" }
            SettingsToggle { label: "Retomar ao iniciar"; checked: true }
        }
    }
}
