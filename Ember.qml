// Ember.qml — Omarchy service plugin entry point.
// One warm presence that FOLLOWS you to whatever screen you're working on,
// reacts to agent activity, and can be dragged to any corner (its spot is
// remembered). Drive it from any tool via $XDG_RUNTIME_DIR/ember/state.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io

Item {
    id: root

    // ---- config ----
    property int  boxSize:  320    // Ember's window (transparent; glow needs room)
    property int  handle:   150    // central grab area you can drag; rest click-through
    property bool draggable: true
    // offset (logical px) of Ember from the bottom-right corner; drag updates these
    property int  mRight:  26
    property int  mBottom: 26

    // ---- state plumbing ----
    readonly property string runtimeDir: String(Quickshell.env("XDG_RUNTIME_DIR") || "/tmp")
    readonly property string statePath: runtimeDir + "/ember/state"
    readonly property string cfgPath: String(Quickshell.env("HOME") || "") + "/.config/ember/pos"
    property string presence: "idle"
    property real   targetLevel: 0
    readonly property var valid: ["idle", "listening", "thinking", "speaking", "alert"]

    // follow the focused monitor
    readonly property var focusMon: Hyprland.focusedMonitor
    readonly property real monScale: (focusMon && focusMon.scale > 0) ? focusMon.scale : 1
    readonly property real swLogical: focusMon ? focusMon.width / monScale : 1920
    readonly property real shLogical: focusMon ? focusMon.height / monScale : 1080
    readonly property var focusedScreen: {
        var name = focusMon ? String(focusMon.name || "") : ""
        var screens = Quickshell.screens || []
        for (var i = 0; i < screens.length; i++)
            if (String(screens[i].name || "") === name) return screens[i]
        return screens.length ? screens[0] : null
    }

    function applyState(raw) {
        var parts = String(raw || "").trim().toLowerCase().split(/\s+/)
        var s = parts[0]
        if (s === "" || root.valid.indexOf(s) < 0) return
        root.presence = s
        var lv = parts.length > 1 ? parseFloat(parts[1]) : 0
        if (isNaN(lv)) lv = 0
        root.targetLevel = Math.max(0, Math.min(1, lv))
        if (parts.length > 1) levelDecay.restart()
        if (s === "alert") alertTimer.restart()
    }

    FileView {
        id: stateFile
        path: root.statePath
        watchChanges: true
        onFileChanged: stateFile.reload()
        onLoaded: root.applyState(stateFile.text())
    }
    FileView {
        id: posFile
        path: root.cfgPath
        onLoaded: {
            var p = String(posFile.text() || "").trim().split(/\s+/)
            var a = parseInt(p[0]), b = parseInt(p[1])
            if (!isNaN(a) && !isNaN(b)) { root.mRight = a; root.mBottom = b }
        }
    }
    function savePos() { posFile.setText(root.mRight + " " + root.mBottom + "\n") }

    Timer { id: alertTimer; interval: 4200; onTriggered: if (root.presence === "alert") root.presence = "idle" }
    Timer { id: levelDecay; interval: 350;  onTriggered: root.targetLevel = 0 }

    PanelWindow {
        id: win
        visible: root.focusedScreen !== null
        screen: root.focusedScreen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "ember"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors { right: true; bottom: true }
        margins { right: root.mRight; bottom: root.mBottom }
        implicitWidth: root.boxSize
        implicitHeight: root.boxSize

        // only the central handle takes the mouse; the transparent rest is click-through
        mask: Region {
            x: (root.boxSize - root.handle) / 2
            y: (root.boxSize - root.handle) / 2
            width: root.handle
            height: root.handle
        }

        EmberScene {
            anchors.fill: parent
            presence: root.presence
            inLevel: root.targetLevel
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.draggable
            cursorShape: Qt.SizeAllCursor
            preventStealing: true
            property real gx: 0
            property real gy: 0
            onPressed: function (mouse) { gx = mouse.x; gy = mouse.y }
            onPositionChanged: function (mouse) {
                var maxR = Math.max(0, root.swLogical - root.boxSize)
                var maxB = Math.max(0, root.shLogical - root.boxSize)
                root.mRight  = Math.round(Math.max(0, Math.min(maxR, root.mRight  - (mouse.x - gx))))
                root.mBottom = Math.round(Math.max(0, Math.min(maxB, root.mBottom - (mouse.y - gy))))
            }
            onReleased: root.savePos()
        }
    }
}
