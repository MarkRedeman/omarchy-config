import QtQuick
import qs.Commons
import qs.Ui

// Full-width detail section shown below the three summary cards. The colored
// dot matches the card and the utilization graph; clicking the header
// collapses the section again.
BorderSurface {
  id: detail

  property string title: ""
  property color seriesColor: Color.accent
  property color foreground: Color.foreground
  property color muted: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.68)
  property color accent: Color.accent
  property string fontFamily: Style.font.family

  default property alias body: bodyColumn.children
  signal toggled()

  radius: Style.cornerRadius
  color: Style.normalFillFor(foreground, Color.accent)
  borderSpec: Border.controlSpec("normal", foreground, seriesColor)
  implicitHeight: content.implicitHeight + Style.space(18)
  height: implicitHeight

  Column {
    id: content
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Style.space(9)
    spacing: Style.space(6)

    Item {
      width: parent.width
      implicitHeight: Math.max(headerRow.implicitHeight, chevron.implicitHeight)

      Row {
        id: headerRow
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(5)

        Rectangle {
          width: Style.space(6)
          height: width
          radius: width / 2
          color: detail.seriesColor
        }

        Text {
          text: detail.title
          textFormat: Text.PlainText
          color: detail.muted
          font.family: detail.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 1.2
        }
      }

      Text {
        id: chevron
        text: "▴"
        textFormat: Text.PlainText
        color: detail.muted
        font.family: detail.fontFamily
        font.pixelSize: Style.font.bodySmall
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: detail.toggled()
      }
    }

    Column {
      id: bodyColumn
      width: parent.width
      spacing: Style.space(6)
    }
  }
}
