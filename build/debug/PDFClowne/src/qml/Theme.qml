pragma Singleton
import QtQuick
import Qt.labs.settings

QtObject {
    id: root

    // 0 = light, 1 = dark
    property int mode: 0

    Component.onCompleted: {
        if (!_settings.twoModeInitialized) {
            if (_settings.mode === 2)
                mode = 1
            else if (_settings.mode === 1)
                mode = 0
            else
                mode = systemMode()

            _settings.twoModeInitialized = true
            _settings.mode = mode
        } else {
            mode = _settings.mode === 1 ? 1 : 0
        }

        applyColorScheme()
    }

    onModeChanged: {
        _settings.mode = mode
        applyColorScheme()
    }

    function applyColorScheme() {
        try {
            if (mode === 1)
                Qt.styleHints.colorScheme = Qt.ColorScheme.Dark
            else
                Qt.styleHints.colorScheme = Qt.ColorScheme.Light
        } catch(e) {}
    }

    function systemMode() {
        try {
            return Qt.styleHints.colorScheme === Qt.ColorScheme.Dark ? 1 : 0
        } catch(e) {
            return 0
        }
    }

    readonly property bool isDark: mode === 1

    function cycleMode() {
        mode = mode === 1 ? 0 : 1
    }

    readonly property string modeName: ["Light", "Dark"][mode]
    readonly property string modeIcon: ["☀", "☾"][mode]

    // Palette derived from logo color #626d90 (slate indigo)
    readonly property color background:    isDark ? "#181828" : "#F4F4F8"
    readonly property color surface:       isDark ? "#23233A" : "#FFFFFF"
    readonly property color surfaceAlt:    isDark ? "#2C2C48" : "#EEEEF4"
    readonly property color text:          isDark ? "#D8DAEA" : "#1C1C2E"
    readonly property color accent:        isDark ? "#8EA3D4" : "#5B6FA8"
    readonly property color accentText:    "#FFFFFF"
    readonly property color border:        isDark ? "#3A3A5C" : "#DCDCE8"
    readonly property color secondaryText: isDark ? "#9090B8" : "#626d90"
    readonly property color hover:         isDark ? "#2E2E50" : "#EAEAF4"
    readonly property color tabActive:     isDark ? "#2C2C48" : "#ECECfA"
    readonly property color danger:        isDark ? "#F08090" : "#C83040"

    readonly property int radius: 6
    readonly property int radiusLg: 10

    property QtObject _settings: Settings {
        category: "Theme"
        property int mode: 0
        property bool twoModeInitialized: false
    }
}
