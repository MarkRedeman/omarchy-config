import QtQuick
import qs.Commons
import qs.Ui

// Headline metric card: label, big value, one-line detail, optional meter.
// Adapted from Harshith292002/omarchy-system-monitor's StatTile (MIT).
BorderSurface {
  id: tile

  property string title: ""
  property string value: "—"
  property string detail: ""
  property real meter: -1
  property color meterColor: Color.accent
  property bool alarming: false
  property color foreground: Color.foreground
  property color muted: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.68)
  property color urgent: Color.urgent
  property string fontFamily: Style.font.family

  height: Style.space(84)
  radius: Style.cornerRadius
  color: Style.normalFillFor(foreground, Color.accent)
  borderSpec: Border.controlSpec("normal", foreground, Color.accent)

  Column {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Style.space(9)
    spacing: Style.space(2)

    Text {
      text: tile.title
      textFormat: Text.PlainText
      color: tile.muted
      font.family: tile.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      font.letterSpacing: 1.2
    }

    Text {
      text: tile.value
      textFormat: Text.PlainText
      color: tile.alarming ? tile.urgent : tile.foreground
      font.family: tile.fontFamily
      font.pixelSize: Style.font.title
      font.bold: true
    }

    Text {
      width: parent.width
      text: tile.detail
      textFormat: Text.PlainText
      color: tile.muted
      font.family: tile.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
  }

  Rectangle {
    id: track
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: Style.space(9)
    height: Style.space(3)
    radius: height / 2
    color: Qt.rgba(tile.foreground.r, tile.foreground.g, tile.foreground.b, 0.12)

    Rectangle {
      width: track.width * Math.max(0, Math.min(1, tile.meter / 100))
      height: track.height
      radius: track.radius
      color: tile.meterColor

      Behavior on width {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
      }
    }
  }
}
