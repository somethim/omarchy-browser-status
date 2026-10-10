import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "somethim.browser-status"

  readonly property string helper: Qt.resolvedUrl("bin/browser-status").toString().replace(/^file:\/\//, "")
  property bool popupOpen: false
  property var browserState: ({ browser: null, running: false, processCount: 0, memoryMb: 0, cpu: 0, windows: [], windowsKnown: false, groups: [], keeperSupported: false, keeperEnabled: false, keeperActive: false })
  property string actionError: ""
  readonly property bool running: browserState.running === true
  readonly property int windowCount: (browserState.windows || []).length
  readonly property bool background: running && browserState.windowsKnown && windowCount === 0
  readonly property bool keeperEnabled: browserState.keeperEnabled === true
  readonly property string browserName: browserState.browser ? browserState.browser.name : "Browser"
  readonly property string browserIcon: browserState.browser && browserState.browser.icon ? "file://" + browserState.browser.icon : ""
  readonly property string modeText: background ? (browserState.keeperActive ? "In background for notifications" : "Running in background (no windows)")
    : windowCount === 1 ? "1 window open" : windowCount + " windows open"
  readonly property string summary: root.browserName + " · " + (background ? "background" : modeText) + " · "
    + browserState.processCount + " processes · " + formatMemory(browserState.memoryMb) + " · " + formatCpu(browserState.cpu)

  visible: running
  implicitWidth: running ? button.implicitWidth : 0
  implicitHeight: button.implicitHeight

  function close() { popupOpen = false }
  function refresh() {
    if (!probe.running) probe.running = true
  }
  function act(kind, option) {
    if (action.running) return
    actionError = ""
    action.command = option ? [helper, kind, option] : [helper, kind]
    action.running = true
  }
  function formatMemory(mb) {
    return mb >= 1024 ? (mb / 1024).toFixed(2) + " GB" : Math.round(mb) + " MB"
  }
  function formatCpu(cpu) {
    return (cpu >= 10 ? Math.round(cpu) : Number(cpu).toFixed(1)) + "% CPU"
  }
  function formatUptime(seconds) {
    if (seconds === null || seconds === undefined) return ""
    var hours = Math.floor(seconds / 3600)
    var minutes = Math.floor((seconds % 3600) / 60)
    return hours > 0 ? hours + "h " + minutes + "m" : minutes + "m"
  }

  // With the keeper on, the helper keeps the default browser running in the
  // background: at login, after the default changes, and after it closes or
  // crashes. A browser stopped with Quit stays stopped until reopened.
  Component.onCompleted: act("keeper-ensure")
  onPopupOpenChanged: if (popupOpen) refresh()

  Timer {
    interval: root.popupOpen ? 3000 : 10000
    repeat: true
    running: true
    onTriggered: root.refresh()
  }

  Process {
    id: probe
    command: [root.helper, "status"]
    stdout: StdioCollector { id: probeOut; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) return
      try { root.browserState = JSON.parse(String(probeOut.text || "{}")) }
      catch (error) { root.actionError = "Could not read browser status" }
      if (!root.running) root.popupOpen = false
      // Not running, or opened without the keeper: let the helper start it in
      // the background or add the keeper, so closing every visible window
      // leaves it running for notifications.
      if (root.keeperEnabled && (!root.running || root.browserState.keeperActive === false)) root.act("keeper-ensure")
    }
  }

  Process {
    id: action
    stderr: StdioCollector { id: actionErr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.actionError = String(actionErr.text || "Action failed").trim()
      refreshSoon.restart()
    }
  }

  // The browser needs a moment to open or close; probing at once reports the old state.
  Timer {
    id: refreshSoon
    interval: 1500
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: root.summary
    onTooltipHoveredChanged: if (tooltipHovered) root.refresh()
    iconComponent: Component {
      Item {
        Image {
          id: appIcon
          visible: root.browserIcon !== ""
          anchors.centerIn: parent
          width: Style.space(15)
          height: width
          fillMode: Image.PreserveAspectFit
          sourceSize.width: Math.round(width * Screen.devicePixelRatio)
          sourceSize.height: Math.round(height * Screen.devicePixelRatio)
          // The helper resolves the desktop entry's icon to a file; the icon
          // theme lookup misses hicolor-only app icons.
          source: root.browserIcon
        }
        Text {
          visible: root.browserIcon === ""
          anchors.centerIn: parent
          text: "󰖟"
          color: root.bar.barForeground
          font { family: root.bar.fontFamily; pixelSize: Style.font.body }
        }
        // Marks a windowless (background) browser.
        Rectangle {
          visible: root.background
          width: Style.space(5)
          height: width
          radius: width / 2
          color: Commons.Color.accent
          anchors.right: appIcon.right
          anchors.bottom: appIcon.bottom
          anchors.rightMargin: -Style.space(2)
          anchors.bottomMargin: -Style.space(2)
        }
      }
    }
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.LeftButton) root.popupOpen = !root.popupOpen
      else if (mouseButton === Qt.RightButton) root.act("open")
    }
  }

  PopupCard {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(340))
    contentHeight: popup.fittedContentHeight(content.implicitHeight)

    Column {
      id: content
      anchors.left: parent.left
      anchors.right: parent.right
      spacing: Style.space(8)

      Text {
        text: root.browserName
        color: root.bar.foreground
        font { family: root.bar.fontFamily; pixelSize: Style.font.subtitle; bold: true }
      }

      Text {
        width: parent.width
        text: root.modeText + (root.browserState.uptimeSeconds !== null && root.browserState.uptimeSeconds !== undefined
          ? " · up " + root.formatUptime(root.browserState.uptimeSeconds) : "")
        color: root.background ? Commons.Color.accent : root.bar.foreground
        wrapMode: Text.WordWrap
        font { family: root.bar.fontFamily; pixelSize: Style.font.caption }
      }

      UsageRow {
        title: "Total · " + root.browserState.processCount + " processes"
        memory: root.formatMemory(root.browserState.memoryMb)
        cpu: root.formatCpu(root.browserState.cpu)
        strong: true
      }

      Rectangle {
        width: parent.width
        height: 1
        color: Util.alpha(root.bar.foreground, 0.15)
      }

      Repeater {
        model: root.browserState.groups || []
        UsageRow {
          required property var modelData
          title: modelData.label + (modelData.count > 1 ? " ×" + modelData.count : "")
          memory: root.formatMemory(modelData.memoryMb)
          cpu: root.formatCpu(modelData.cpu)
        }
      }

      Text {
        visible: root.windowCount > 0
        text: "Windows"
        color: root.bar.foreground
        font { family: root.bar.fontFamily; pixelSize: Style.font.caption; bold: true }
      }

      Repeater {
        model: (root.browserState.windows || []).slice(0, 6)
        Text {
          required property var modelData
          width: content.width
          text: "• " + (modelData.title || modelData.class) + (modelData.workspace ? "  [" + modelData.workspace + "]" : "")
          elide: Text.ElideRight
          color: root.bar.foreground
          opacity: 0.8
          font { family: root.bar.fontFamily; pixelSize: Style.font.caption }
        }
      }

      Toggle {
        visible: root.browserState.keeperSupported === true
        width: parent.width
        label: "Background notifications"
        description: "A hidden window keeps the browser open after you close it"
        checked: root.keeperEnabled
        enabled: !action.running
        onClicked: root.act(root.keeperEnabled ? "keeper-off" : "keeper-on")
      }

      Row {
        spacing: Style.space(8)
        Button {
          text: "Open window"
          bordered: true
          fontFamily: root.bar.fontFamily
          fontSize: Style.font.caption
          enabled: !action.running
          onClicked: root.act("open")
        }
        Button {
          text: "Quit " + root.browserName
          bordered: true
          fontFamily: root.bar.fontFamily
          fontSize: Style.font.caption
          enabled: !action.running
          onClicked: root.act("quit")
        }
      }

      Text {
        visible: root.actionError !== ""
        text: root.actionError
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        width: parent.width
        color: root.bar.urgent
        font { family: root.bar.fontFamily; pixelSize: Style.font.caption }
      }
    }
  }

  component UsageRow: Item {
    id: row
    property string title: ""
    property string memory: ""
    property string cpu: ""
    property bool strong: false
    width: content.width
    implicitHeight: titleLabel.implicitHeight
    Text {
      id: titleLabel
      anchors.left: parent.left
      width: parent.width - memoryLabel.width - cpuLabel.width - Style.space(16)
      text: row.title
      elide: Text.ElideRight
      color: root.bar.foreground
      font { family: root.bar.fontFamily; pixelSize: Style.font.caption; bold: row.strong }
    }
    Text {
      id: memoryLabel
      anchors.right: cpuLabel.left
      anchors.rightMargin: Style.space(8)
      width: Style.space(72)
      horizontalAlignment: Text.AlignRight
      text: row.memory
      color: row.strong ? Commons.Color.accent : root.bar.foreground
      font { family: root.bar.fontFamily; pixelSize: Style.font.caption; bold: row.strong }
    }
    Text {
      id: cpuLabel
      anchors.right: parent.right
      width: Style.space(72)
      horizontalAlignment: Text.AlignRight
      text: row.cpu
      color: row.strong ? Commons.Color.accent : root.bar.foreground
      font { family: root.bar.fontFamily; pixelSize: Style.font.caption; bold: row.strong }
    }
  }
}
