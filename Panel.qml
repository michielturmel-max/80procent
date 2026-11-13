import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

// Schakelaar voor de acculimiet van deze Intel-MacBook: vol laden of
// stoppen bij 80%. De limiet leeft in de Apple-SMC (sleutel BCLM) en
// overleeft herstarten; dit paneel leest en schrijft hem via het script
// bin/laadlimiet, dat weer de setuid-root helper macbook-charge-limit
// aanroept (alleen BCLM/BFCL, 20-100, uitsluitend op Apple-hardware).
//
// Linksklik schakelt direct (de echte "knop"); rechtsklik opent de
// status; midden ververst. Enter schakelt ook, r ververst, esc sluit.
Panel {
  id: root
  moduleName: "80procent"
  ipcTarget: "80procent"

  implicitWidth: button.implicitWidth
  implicitHeight: bar ? bar.barSize : 26

  readonly property string scriptPath: Quickshell.env("HOME") + "/.config/omarchy/plugins/80procent/bin/laadlimiet"

  readonly property int bodyFont: Style.font.body
  readonly property int captionFont: Style.font.caption
  readonly property int subtitleFont: Style.font.subtitle

  property string limiet: ""
  property string accu: ""
  property string laderStatus: ""
  property string stekker: ""
  property string statusFout: ""
  property bool bezig: false
  property string actNow: ""

  readonly property bool heeftTool: limiet !== ""

  // De tool-tip vat de stand samen, zodat één blik op de bar genoeg is.
  readonly property string tooltipText: {
    if (root.statusFout !== "") return "acculimiet onbekend — " + root.statusFout
    if (root.limiet === "80") return "acculimiet 80% — klik om vol te laden"
    if (root.limiet === "100") return "vol laden (100%) — klik om te stoppen bij 80%"
    return "acculimiet onbekend — klik om te schakelen"
  }

  function tip() { return root.tooltipText }

  function wissel() {
    if (root.bezig) return
    root.bezig = true
    root.actNow = "wissel"
    stProc.command = [scriptPath, "wissel"]
    stProc.running = true
  }

  function refreshStatus() {
    if (root.bezig) return
    root.bezig = true
    root.actNow = "status"
    stProc.command = [scriptPath, "status"]
    stProc.running = true
  }

  function tonen() {
    root.opened = !root.opened
    if (root.opened) root.refreshStatus()
  }

  // Bevestigpopup rechtsboven (omarchy-notificaties), dezelfde weg als de
  // nieuws-alerts.
  function toast(summary, body) {
    if (!summary) return
    toastProc.command = ["notify-send", "-t", "5000", "-a", "80procent", String(summary), String(body || "")]
    toastProc.running = true
  }

  function tik(raw) {
    var t = String(raw || "").trim()
    if (root.actNow === "status") {
      var d = null
      try { d = JSON.parse(t) } catch (e) { d = null }
      if (d) {
        root.limiet = String(d.limiet || "")
        root.accu = String(d.accu || "")
        root.laderStatus = String(d.status || "")
        root.stekker = String(d.stekker || "")
        root.statusFout = ""
      } else {
        root.limiet = ""
        root.statusFout = t !== "" ? t : "script gaf niets terug"
      }
      root.actNow = ""
      return
    }
    if (root.actNow === "wissel") {
      if (t.indexOf("ok") === 0) {
        var m = t.split(":")
        root.toast(m.length > 1 ? m[1] : "acculimiet gewijzigd", "")
        root.refreshStatus()
      } else {
        root.statusFout = t !== "" ? t : "kon niet schakelen"
        root.toast("kon niet schakelen", root.statusFout)
        root.actNow = ""
      }
    }
  }

  Process {
    id: stProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.tik(text)
    }
    onExited: root.bezig = false
  }

  Process {
    id: toastProc
    running: false
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: root.tip()
    active: root.statusFout !== "" || root.limiet === ""

    // Eigen icoon: een accu die tot 80% of helemaal vol staat. Geen glyph
    // of svg — die zijn op deze bar-hoogte onleesbaar of ontbreken in QML.
    iconComponent: Component {
      Item {
        id: bat
        // Vaste bronmaat; de balk schaalt de getekende omtrek naar zijn eigen
        // icon-size. anchors.fill werkt hier niet: de loader die dit component
        // laadt heeft zelf geen afmeting, waardoor de vlakken 0px werden.
        width: 24
        height: 24
        readonly property real s: width / 24
        readonly property real lvl: {
          if (root.limiet === "100") return 1
          if (root.limiet === "80") return 0.8
          if (root.limiet === "") return 0
          var n = parseInt(root.limiet, 10)
          return isNaN(n) ? 0 : Math.min(1, Math.max(0.2, n / 100))
        }
        readonly property color ink: (root.statusFout !== "" || root.limiet === "") && button.useActiveColor
          ? button.activeColor : button.foreground

        Rectangle {
          x: 0.6 * bat.s
          y: 7 * bat.s
          width: 18.6 * bat.s
          height: 10 * bat.s
          radius: 1.6 * bat.s
          color: "transparent"
          border.width: Math.max(1, Math.round(1.6 * bat.s))
          border.color: bat.ink
        }

        Rectangle {
          x: 19.4 * bat.s
          y: 9.2 * bat.s
          width: 2.2 * bat.s
          height: 5.6 * bat.s
          radius: 1 * bat.s
          color: bat.ink
        }

        Rectangle {
          x: 2.2 * bat.s
          y: 8.8 * bat.s
          width: Math.max(0, (18.6 * bat.s - 3.2 * bat.s)) * bat.lvl
          height: 6.6 * bat.s
          radius: 0.9 * bat.s
          color: bat.ink
        }
      }
    }

    onPressed: function(b) {
      if (b === Qt.MiddleButton) {
        root.refreshStatus()
        return
      }
      if (b === Qt.RightButton) {
        root.tonen()
        return
      }
      root.wissel()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keys
    contentWidth: Style.space(340)
    contentHeight: Style.space(250)

    PanelKeyCatcher {
      id: keys
      anchors.fill: parent

      onActivateRequested: root.wissel()
      onCloseRequested: root.opened = false
      onTextKey: function(t) {
        if (t === "r" || t === "R") root.refreshStatus()
      }
    }

    Item {
      anchors.fill: parent

      Column {
        id: kolom
        anchors.fill: parent
        anchors.margins: Style.space(14)
        spacing: Style.space(8)

        Text {
          width: parent.width
          text: "Acculimiet"
          color: root.barForeground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: root.subtitleFont
          font.bold: true
        }

        Text {
          width: parent.width
          visible: root.statusFout !== "" && root.limiet === ""
          text: root.statusFout
          color: Color.urgent
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: root.captionFont
          wrapMode: Text.WordWrap
        }

        Text {
          width: parent.width
          text: {
            if (root.limiet === "80") return "Stoppen bij 80% (bescherming aan)"
            if (root.limiet === "100") return "Vol laden (100%)"
            return "onbekend"
          }
          color: root.limiet === "80" ? Color.accent : root.barForeground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: root.bodyFont
          font.bold: true
        }

        Text {
          width: parent.width
          text: {
            if (root.accu === "") return "accu \u2014"
            var s = "accu " + root.accu + "%"
            if (root.laderStatus !== "") s += " \u00b7 " + root.laderStatus
            if (root.stekker === "1") s += " \u00b7 stekker in"
            else if (root.stekker === "0") s += " \u00b7 op accu"
            return s
          }
          color: Color.muted
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: root.captionFont
          wrapMode: Text.WordWrap
        }

        Rectangle {
          width: parent.width
          height: toggleLabel.implicitHeight + Style.space(14)
          radius: Style.cornerRadius
          color: toggleHover.containsMouse ? Color.menu.selectedBackground : Color.menu.background

          Text {
            id: toggleLabel
            anchors.centerIn: parent
            text: root.limiet === "80" ? "zonder limiet laden (vol)" : "stoppen bij 80%"
            color: root.barForeground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: root.bodyFont
            font.bold: true
          }

          MouseArea {
            id: toggleHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.wissel()
          }
        }

        Text {
          width: parent.width
          visible: root.limiet !== "100"
          text: "De limiet staat in de SMC en blijft ook na herstarten staan."
          color: Color.muted
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: root.captionFont
          wrapMode: Text.WordWrap
        }

        Text {
          width: parent.width
          text: "enter = schakelen \u00b7 r = verfrissen \u00b7 esc = sluiten"
          color: Color.muted
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: root.captionFont
        }
      }
    }
  }

  Component.onCompleted: root.refreshStatus()
}