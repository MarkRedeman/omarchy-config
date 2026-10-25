import QtQuick
import qs.Commons
import qs.Ui

// Summary card used for CPU, GPU, NPU, memory, and power.
//
// The colored dot is the same hue as the group's line in the utilization
// graph (or a neutral hue for memory/power, which are not charted). Clicking
// an interactive card toggles its full-width detail section below the
// summary rows.
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
  property bool interactive: true
  property color foreground: Color.foreground
  property color muted: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.68)
  property color urgent: Color.urgent
  property color accent: Color.accent
  property string fontFamily: Style.font.family

  signal toggled()

  radius: Style.cornerRadius
  color: expanded ? Style.hoverFillFor(foreground, seriesColor) : Style.normalFillFor(foreground, Color.accent)
  borderSpec: Border.controlSpec(expanded ? "focus" : "normal", foreground, seriesColor)
  implicitHeight: Math.max(Style.space(64), content.implicitHeight + Style.space(14))
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
      implicitHeight: Math.max(titleRow.implicitHeight, valueText.implicitHeight)

      Row {
        id: titleRow
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(6)

        Item {
          width: Style.space(7)
          height: titleText.implicitHeight

          Rectangle {
            width: Style.space(7)
            height: width
            radius: width / 2
            color: tile.seriesColor
            opacity: tile.expanded ? 1 : 0.85
            anchors.centerIn: parent
          }
        }

        Text {
          id: titleText
          text: tile.title
          textFormat: Text.PlainText
          color: tile.foreground
          font.family: tile.fontFamily
          font.pixelSize: Style.font.subtitle
          font.bold: true
          font.letterSpacing: 0.6
        }
      }

      Text {
        id: valueText
        text: tile.value
        textFormat: Text.PlainText
        color: tile.alarming ? tile.urgent : tile.foreground
        font.family: tile.fontFamily
        font.pixelSize: Style.font.title
        font.bold: true
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    Text {
      width: parent.width
      text: tile.detail
      visible: text !== ""
      textFormat: Text.PlainText
      color: tile.muted
      font.family: tile.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }

    Rectangle {
      width: parent.width
      visible: tile.meter >= 0
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
    enabled: tile.interactive
    hoverEnabled: tile.interactive
    cursorShape: tile.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: if (tile.interactive) tile.toggled()
  }
}
