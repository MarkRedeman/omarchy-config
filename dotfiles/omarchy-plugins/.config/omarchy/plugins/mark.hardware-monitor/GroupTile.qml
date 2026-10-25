import QtQuick
import qs.Commons
import qs.Ui

// Summary card in the hardware panel's three-column row.
//
// The colored dot is the same hue as the group's line in the utilization
// graph, so the graph no longer needs a separate legend. Clicking the card
// toggles its full-width detail section below the row.
BorderSurface {
  id: tile

  property string title: ""
  property string value: "—"
  property string detail: ""
  property real meter: -1
  property color meterColor: Color.accent
  property color seriesColor: Color.accent
  property bool alarming: false
  property bool expanded: false
  property color foreground: Color.foreground
  property color muted: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.68)
  property color urgent: Color.urgent
  property color accent: Color.accent
  property string fontFamily: Style.font.family

  signal toggled()

  radius: Style.cornerRadius
  color: expanded ? Style.hoverFillFor(foreground, seriesColor) : Style.normalFillFor(foreground, Color.accent)
  borderSpec: Border.controlSpec(expanded ? "focus" : "normal", foreground, seriesColor)
  implicitHeight: Math.max(Style.space(84), content.implicitHeight + Style.space(16))
  height: implicitHeight

  Column {
    id: content
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Style.space(8)
    spacing: Style.space(2)

    Item {
      width: parent.width
      implicitHeight: Math.max(titleRow.implicitHeight, chevron.implicitHeight)

      Row {
        id: titleRow
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(5)

        Rectangle {
          width: Style.space(6)
          height: width
          radius: width / 2
          color: tile.seriesColor
          opacity: tile.expanded ? 1 : 0.85
        }

        Text {
          text: tile.title
          textFormat: Text.PlainText
          color: tile.muted
          font.family: tile.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 1.2
        }
      }

      Text {
        id: chevron
        text: tile.expanded ? "▴" : "▾"
        textFormat: Text.PlainText
        color: tile.muted
        font.family: tile.fontFamily
        font.pixelSize: Style.font.bodySmall
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
      }
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

    Rectangle {
      width: parent.width
      height: Style.space(3)
      radius: height / 2
      color: Qt.rgba(tile.foreground.r, tile.foreground.g, tile.foreground.b, 0.12)

      Rectangle {
        width: parent.width * Math.max(0, Math.min(1, tile.meter / 100))
        height: parent.height
        radius: parent.radius
        color: tile.meterColor

        Behavior on width {
          NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: tile.toggled()
  }
}
