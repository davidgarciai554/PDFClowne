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

    readonly property color brandBlue: isDark ? "#6FA8DC" : "#3D7AB0"
    readonly property color brandRed: isDark ? "#FF7A73" : "#D8423C"

    readonly property color background:    isDark ? "#0F1620" : "#F7FAFC"
    readonly property color surface:       isDark ? "#18212E" : "#FFFFFF"
    readonly property color surfaceAlt:    isDark ? "#223147" : "#EDF3F9"
    readonly property color text:          isDark ? "#F5F7FA" : "#14202B"
    readonly property color accent:        brandBlue
    readonly property color accentText:    "#FFFFFF"
    readonly property color border:        isDark ? "#32465F" : "#D5E1EC"
    readonly property color secondaryText: isDark ? "#A9B6C9" : "#5A6B7E"
    readonly property color hover:         isDark ? "#2A3D57" : "#E4EEF8"
    readonly property color tabActive:     isDark ? "#27405F" : "#DCEAF7"
    readonly property color danger:        brandRed
    readonly property color viewerCanvas:  isDark ? "#0B1119" : "#DFE9F4"
    readonly property color controlFill:   surfaceAlt
    readonly property color controlFillHover: hover
    readonly property color controlFillPressed: tabActive
    readonly property color controlDisabled: isDark ? "#17202C" : "#E4ECF4"
    readonly property color focusRing:     accent
    readonly property color editSelection: accent
    readonly property color editSelectionSoft: isDark ? "#193957" : "#DCEAF7"

    readonly property int radius: 6
    readonly property int radiusLg: 10
    readonly property int controlHeight: 34
    readonly property int compactControlHeight: 28
    readonly property int iconButtonSize: 30

    property QtObject _settings: Settings {
        category: "Theme"
        property int mode: 0
        property bool twoModeInitialized: false
    }
}
