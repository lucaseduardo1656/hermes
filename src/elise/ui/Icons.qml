pragma Singleton
import QtQuick

// Subset of Caelestia's utils/Icons.qml — maps runtime state to Material Symbols
// glyph names. Only the helpers Elise needs (network / bluetooth / volume).
QtObject {
    function getNetworkIcon(strength, isSecure) {
        if (isSecure) {
            if (strength >= 80) return "network_wifi_locked";
            if (strength >= 60) return "network_wifi_3_bar_locked";
            if (strength >= 40) return "network_wifi_2_bar_locked";
            if (strength >= 20) return "network_wifi_1_bar_locked";
            return "signal_wifi_0_bar";
        }
        if (strength >= 80) return "network_wifi";
        if (strength >= 60) return "network_wifi_3_bar";
        if (strength >= 40) return "network_wifi_2_bar";
        if (strength >= 20) return "network_wifi_1_bar";
        return "signal_wifi_0_bar";
    }

    function getBluetoothIcon(icon) {
        const s = icon || "";
        if (s.includes("headset") || s.includes("headphones")) return "headphones";
        if (s.includes("audio"))    return "speaker";
        if (s.includes("phone"))    return "smartphone";
        if (s.includes("mouse"))    return "mouse";
        if (s.includes("keyboard")) return "keyboard";
        return "bluetooth";
    }

    function getVolumeIcon(volume, isMuted) {
        if (isMuted || volume <= 0) return "no_sound";
        return "volume_up";
    }

    // Map a notification summary + urgency to a Material glyph (Caelestia parity).
    // urgency: 2 = critical.
    function getNotifIcon(summary, urgency) {
        const s = (summary || "").toLowerCase();
        if (s.includes("reboot") || s.includes("reinic")) return "restart_alt";
        if (s.includes("battery") || s.includes("bateria")) return "power";
        if (s.includes("welcome") || s.includes("bem-vindo")) return "waving_hand";
        if (s.includes("update") || s.includes("atualiza")) return "update";
        if (s.includes("install") || s.includes("instal")) return "download";
        if (s.includes("unable") || s.includes("falha") || s.includes("erro")) return "deployed_code_alert";
        if (s.includes("wi-fi") || s.includes("wifi") || s.includes("rede")) return "wifi";
        if (s.includes("bluetooth")) return "bluetooth";
        if (s.includes("rota") || s.includes("route") || s.includes("navega")) return "navigation";
        if (s.includes("file") || s.includes("arquivo")) return "folder_copy";
        if (urgency >= 2) return "release_alert";
        return "chat";
    }
}
