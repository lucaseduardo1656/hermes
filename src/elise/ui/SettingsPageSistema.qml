import QtQuick
import Elise

// Page: Sistema — atualizações, armazenamento, info, reiniciar.
//
// Bound to `Settings.sys` (SystemInfoController), which talks to the
// hermes-systemd daemon via D-Bus. When the daemon is offline the page
// renders dashes so it's obvious the bus link is down rather than showing
// stale numbers.
Flickable {
    id: root
    contentWidth:  width
    contentHeight: _col.implicitHeight + Theme.spaceXL * 2
    clip: true

    function _formatGB(bytes) {
        if (!bytes) return "—"
        return (bytes / 1073741824).toFixed(1) + " GB"
    }
    function _formatUptime(s) {
        if (!s) return "—"
        const d = Math.floor(s / 86400)
        const h = Math.floor((s % 86400) / 3600)
        const m = Math.floor((s % 3600) / 60)
        if (d > 0) return d + "d " + h + "h"
        if (h > 0) return h + "h " + m + "m"
        return m + "m"
    }

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

            SettingsAction { label: "Atualizações";  sublabel: "Sistema atualizado" }
            SettingsAction {
                label:    "Armazenamento"
                sublabel: root._formatGB(Settings.sys.storageUsedBytes)
                          + " usado de "
                          + root._formatGB(Settings.sys.storageTotalBytes)
            }
        }

        SettingsCard {
            title: "Sobre"

            SettingsAction {
                label:    "Sistema operacional"
                sublabel: Settings.sys.osVersion || "—"
            }
            SettingsAction {
                label:    "Aplicação"
                sublabel: "Elise " + (Settings.sys.appVersion || "—")
            }
            SettingsAction {
                label:    "Kernel"
                sublabel: Settings.sys.kernelVersion || "—"
            }
            SettingsAction {
                label:    "Hostname"
                sublabel: Settings.sys.hostname || "—"
            }
            SettingsAction {
                label:    "Uptime"
                sublabel: root._formatUptime(Settings.sys.uptimeSeconds)
            }
            SettingsAction {
                label:    "Daemon"
                sublabel: Settings.sys.online ? "conectado" : "desconectado"
            }
        }

        SettingsCard {
            SettingsAction {
                label: "Reiniciar sistema"
                onTriggered: Settings.sys.reboot()
            }
            SettingsAction {
                label: "Desligar sistema"
                onTriggered: Settings.sys.powerOff()
            }
            SettingsToggle { label: "Modo desenvolvedor"; checked: false }
        }
    }
}
