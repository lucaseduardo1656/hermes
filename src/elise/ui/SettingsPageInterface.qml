import QtQuick
import Elise

// Page: Interface — tema, cor, tipografia, densidade, animações.
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
            title: "Aparência"

            SettingsToggle {
                label: "Tema escuro"
                checked: System.darkTheme
                onToggled: (v) => System.darkTheme = v
            }
            SettingsAction { label: "Cor de destaque";    sublabel: "Dourado Elise" }
            SettingsAction { label: "Tamanho da fonte";   sublabel: "Padrão" }
            SettingsAction { label: "Densidade do layout"; sublabel: "Confortável" }
        }

        SettingsCard {
            title: "Movimento"

            SettingsToggle { label: "Animações";             checked: true }
            SettingsToggle { label: "Reduzir transparência"; checked: false }
        }
    }
}
