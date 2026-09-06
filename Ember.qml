// Ember.qml — Omarchy service plugin entry point.
// Puts a warm, always-on presence in the corner of every screen and reacts
// to whatever the agents are doing. State arrives through a tiny file that the
// `ember` CLI writes, so ANY tool — Claude Code, a shell script, a hook — can
// make Ember stir with one line.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Item {
    id: root

    // ---- config (edit + save; the shell hot-reloads) ----
    property int  boxSize:  260   // width & height of Ember's little window
    property int  marginX:  26    // gap from screen edge
    property int  marginY:  26
    property bool everyScreen: true   // false = primary screen only

    // ---- state plumbing ----
    readonly property string runtimeDir: String(Quickshell.env("XDG_RUNTIME_DIR") || "/tmp")
    readonly property string statePath: runtimeDir + "/ember/state"
    property string presence: "idle"
    readonly property var valid: ["idle", "listening", "thinking", "speaking", "alert"]

    function applyState(raw) {
        var s = String(raw || "").trim().toLowerCase()
        if (s === "" || root.valid.indexOf(s) < 0) return
        root.presence = s
        if (s === "alert") alertTimer.restart()   // notifications settle back to idle
    }

    FileView {
        id: stateFile
        path: root.statePath
        watchChanges: true
        onFileChanged: stateFile.reload()
        onLoaded: root.applyState(stateFile.text())
    }

    Timer {
        id: alertTimer
        interval: 4200
        onTriggered: if (root.presence === "alert") root.presence = "idle"
    }

    // one small overlay window per screen
    Variants {
        model: root.everyScreen ? Quickshell.screens
                                 : (Quickshell.screens.length ? [Quickshell.screens[0]] : [])

        PanelWindow {
            required property var modelData
            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "ember"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            anchors { right: true; bottom: true }
            margins { right: root.marginX; bottom: root.marginY }
            implicitWidth: root.boxSize
            implicitHeight: root.boxSize
            mask: Region {}   // empty input region => fully click-through

            EmberScene {
                anchors.fill: parent
                presence: root.presence
            }
        }
    }
}
