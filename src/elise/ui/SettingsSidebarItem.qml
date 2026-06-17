import QtQuick
import Elise

// One card in the settings sidebar — Caelestia style: a rounded card with a
// circular icon badge, a title and a subtitle. The active card is filled with
// a soft accent tint.
//
// Usage:
//   SettingsSidebarItem {
//       icon:     "qrc:/icons/wifi.svg"
//       label:    "Network"
//       sublabel: "Wi-Fi, ethernet"
//       active:   router.activePage === "network"
//       onClicked: router.activePage = "network"
//   }
Item {
    id: root

    property url    icon
    property string label
    property string sublabel: ""
    property bool   active: false
    // Position in the (visible) list — drives the grouped rounding: only the
    // first card rounds its top, only the last rounds its bottom, the middle is
    // square. The active card is a fully-rounded pill regardless of position.
    property bool   first: false
    property bool   last:  false
    signal clicked()

    width:  parent ? parent.width : 0
    height: 64

    Rectangle {
        id: _bg
        anchors.fill: parent
        readonly property real _r: Theme.radiusL
        topLeftRadius:     root.active || root.first ? _r : 0
        topRightRadius:    root.active || root.first ? _r : 0
        bottomLeftRadius:  root.active || root.last  ? _r : 0
        bottomRightRadius: root.active || root.last  ? _r : 0
        // Smoothly morph the corners + colour when (de)activating.
        Behavior on topLeftRadius     { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
        Behavior on topRightRadius    { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
        Behavior on bottomLeftRadius  { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
        Behavior on bottomRightRadius { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
        // Active = accent-tinted pill; inactive = subtle grouped fill.
        color: root.active
                 ? Qt.rgba(System.accent.r, System.accent.g, System.accent.b, 0.18)
                 : _area.pressed ? Qt.rgba(1, 1, 1, 0.09)
                                  : Qt.rgba(1, 1, 1, 0.05)
        Behavior on color { ColorAnimation { duration: Theme.durFast } }

        // Circular icon badge
        Rectangle {
            id: _badge
            anchors { left: parent.left; leftMargin: Theme.spaceM
                      verticalCenter: parent.verticalCenter }
            width: 40; height: 40; radius: 20
            color: root.active ? Qt.rgba(System.accent.r, System.accent.g,
                                         System.accent.b, 0.28)
                               : System.surface2
            Behavior on color { ColorAnimation { duration: Theme.durFast } }
            SvgIcon {
                anchors.centerIn: parent
                source: root.icon
                color:  root.active ? System.accent : System.textSecondary
                size:   Theme.iconS
            }
        }

        Column {
            anchors {
                left: _badge.right; leftMargin: Theme.spaceM
                right: parent.right; rightMargin: Theme.spaceM
                verticalCenter: parent.verticalCenter
            }
            spacing: 1
            Text {
                width: parent.width
                text:  root.label
                color: root.active ? System.textPrimary : System.textPrimary
                font.pixelSize: Theme.fontMedium
                font.weight:    Font.Medium
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                visible: root.sublabel !== ""
                text:  root.sublabel
                color: System.textSecondary
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }
    }

    MouseArea {
        id: _area
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
