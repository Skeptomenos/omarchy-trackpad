import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// Trackpad settings overlay: draggable sliders for scroll speed and pointer
// speed plus a natural-scrolling switch. Values apply live while dragging
// (hyprctl keyword) and persist on release via trackpad-settings, which
// writes ~/.config/hypr/trackpad-ui.lua and reloads Hyprland.
//
// Summon with: omarchy-shell shell summon david.trackpad
Item {
  id: root

  property var shell: null
  property var manifest: null

  property bool opened: false
  property string settingsBin: Quickshell.env("HOME") + "/.local/bin/trackpad-settings"

  property bool naturalScroll: true
  property real scrollFactor: 1.0
  property real sensitivity: 0.0
  property bool gesturesOn: true
  property real swipeSpeed: 1.0

  function open(payloadJson) {
    opened = true
    readProc.running = true
    Qt.callLater(function() {
      if (root.opened) keyCatcher.forceActiveFocus()
    })
  }

  function close() {
    opened = false
  }

  function dismiss() {
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "david.trackpad")
    else close()
  }

  function snap(v) {
    return Math.round(v * 20) / 20 // 0.05 steps
  }

  // Live preview while dragging: throttle hyprctl keyword calls so a drag
  // doesn't spawn a process per mouse move. The persisted write happens once,
  // on release.
  property var pendingLive: ({})
  function liveApply(option, value) {
    pendingLive[option] = value
    if (!liveTimer.running) liveTimer.start()
  }

  Timer {
    id: liveTimer
    interval: 80
    onTriggered: {
      for (var opt in root.pendingLive)
        Quickshell.execDetached(["hyprctl", "keyword", opt, String(root.pendingLive[opt])])
      root.pendingLive = {}
    }
  }

  function persist(key, value) {
    Quickshell.execDetached([root.settingsBin, "set", key, String(value)])
  }

  Process {
    id: readProc
    command: ["bash", "-c",
      root.settingsBin + " get natural_scroll; " +
      root.settingsBin + " get scroll_factor; " +
      root.settingsBin + " get sensitivity; " +
      root.settingsBin + " get gestures; " +
      root.settingsBin + " get swipe_speed"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var lines = String(text || "").trim().split("\n")
        if (lines.length < 5) return
        root.naturalScroll = lines[0].trim() === "on"
        var sf = parseFloat(lines[1])
        var sens = parseFloat(lines[2])
        root.gesturesOn = lines[3].trim() === "on"
        var swipe = parseFloat(lines[4])
        if (isFinite(sf)) root.scrollFactor = sf
        if (isFinite(sens)) root.sensitivity = sens
        if (isFinite(swipe)) root.swipeSpeed = swipe
      }
    }
  }

  PanelWindow {
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "david-trackpad"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, 0.45)

      MouseArea {
        anchors.fill: parent
        onClicked: root.dismiss()
      }
    }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true

      Keys.onEscapePressed: root.dismiss()

      Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(Style.space(420), keyCatcher.width - Style.space(32))
        height: content.implicitHeight + Style.space(48)
        radius: Style.cornerRadius
        color: Color.background
        border.width: Math.max(1, Style.space(2))
        border.color: Color.popups.border

        // Swallow clicks so only the scrim outside the card dismisses.
        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
          id: content
          anchors.fill: parent
          anchors.margins: Style.space(24)
          spacing: Style.space(16)

          Text {
            text: "TRACKPAD"
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 2
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(12)

            Text {
              text: "Natural scrolling"
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              Layout.fillWidth: true
            }

            ToggleSwitch {
              checked: root.naturalScroll
              onToggled: {
                root.naturalScroll = !root.naturalScroll
                Quickshell.execDetached([root.settingsBin, "toggle", "natural_scroll"])
              }
            }
          }

          RowLayout {
            Layout.fillWidth: true

            Text {
              text: "Scroll speed"
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              Layout.fillWidth: true
            }

            Text {
              text: root.scrollFactor.toFixed(2)
              color: Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }
          }

          PanelSlider {
            Layout.fillWidth: true
            minimum: 0.1
            maximum: 3.0
            step: 0.05
            value: root.scrollFactor
            onMoved: function(v) {
              var s = root.snap(v)
              root.scrollFactor = s
              root.liveApply("input:touchpad:scroll_factor", s.toFixed(2))
            }
            onReleased: function(v) {
              var s = root.snap(v)
              root.scrollFactor = s
              root.persist("scroll_factor", s.toFixed(2))
            }
          }

          RowLayout {
            Layout.fillWidth: true

            Text {
              text: "Pointer speed"
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              Layout.fillWidth: true
            }

            Text {
              text: (root.sensitivity >= 0 ? "+" : "") + root.sensitivity.toFixed(2)
              color: Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }
          }

          PanelSlider {
            Layout.fillWidth: true
            minimum: -1.0
            maximum: 1.0
            step: 0.05
            tickCount: 3
            value: root.sensitivity
            onMoved: function(v) {
              var s = root.snap(v)
              root.sensitivity = s
              root.liveApply("input:sensitivity", s.toFixed(2))
            }
            onReleased: function(v) {
              var s = root.snap(v)
              root.sensitivity = s
              root.persist("sensitivity", s.toFixed(2))
            }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(12)

            Text {
              text: "Workspace gestures (4-finger)"
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              Layout.fillWidth: true
            }

            ToggleSwitch {
              checked: root.gesturesOn
              onToggled: {
                root.gesturesOn = !root.gesturesOn
                Quickshell.execDetached([root.settingsBin, "toggle", "gestures"])
              }
            }
          }

          RowLayout {
            Layout.fillWidth: true
            visible: root.gesturesOn

            Text {
              text: "Swipe speed"
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              Layout.fillWidth: true
            }

            Text {
              text: root.swipeSpeed.toFixed(2)
              color: Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }
          }

          // Gestures aren't hyprctl keywords, so this one applies on release
          // (via a config rewrite + reload) rather than live during the drag.
          PanelSlider {
            Layout.fillWidth: true
            visible: root.gesturesOn
            minimum: 0.5
            maximum: 3.0
            step: 0.05
            value: root.swipeSpeed
            onMoved: function(v) {
              root.swipeSpeed = root.snap(v)
            }
            onReleased: function(v) {
              var s = root.snap(v)
              root.swipeSpeed = s
              root.persist("swipe_speed", s.toFixed(2))
            }
          }

          Text {
            text: "Esc or click outside to close"
            color: Qt.darker(Color.foreground, 1.6)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            Layout.alignment: Qt.AlignHCenter
          }
        }
      }
    }
  }
}
