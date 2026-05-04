import QtQuick
import Elise

// Page: Veículo — preferências do carro vinculadas ao perfil ativo.
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
            title: "Iluminação"

            SettingsToggle { label: "Faróis automáticos";  checked: true  }
            SettingsToggle { label: "Luz ambiente interna"; checked: false }
            SettingsAction { label: "Intensidade";         sublabel: "Médio" }
        }

        SettingsCard {
            title: "Travas"

            SettingsToggle { label: "Travamento ao iniciar"; checked: true  }
            SettingsToggle { label: "Destravar ao desligar"; checked: false }
        }

        SettingsCard {
            title: "Assistência de direção"

            SettingsToggle { label: "Aviso de faixa";        checked: false }
            SettingsToggle { label: "Frenagem automática";   checked: false }
            SettingsAction { label: "Sensibilidade";         sublabel: "Padrão" }
        }

        SettingsCard {
            title: "Economia de energia"

            SettingsToggle { label: "Modo eco";              checked: false }
            SettingsAction { label: "Limite de partida";     sublabel: "12.0 V" }
        }
    }
}
