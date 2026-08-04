/*
  * Copyright 2026 Fairy Fox
  *
  * Licensed under the Apache License, Version 2.0 (the "License");
  * you may not use this file except in compliance with the License.
  * You may obtain a copy of the License at
  *
  *   http://www.apache.org/licenses/LICENSE-2.0
  *
  * Unless required by applicable law or agreed to in writing, software
  * distributed under the License is distributed on an "AS IS" BASIS,
  * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  * See the License for the specific language governing permissions and
  * limitations under the License.
*/

/*
  OptionTierRow.qml -- one TIER inside the map's "!" options panel (MapIdentityBar).

  A tier is a whole class of abnormal save values (unused/unstable, or no-effect) with one switch that
  reveals or hides that class across the entire map screen. The row is: a coloured tier light, the
  tier's name + a plain-English blurb, and a flat on/off pill on the right. The whole row is tappable.
*/
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
  id: root

  property color dotColor: "#888888"
  property string title: ""
  property string blurb: ""
  property bool checked: false
  signal toggled()

  implicitHeight: rowLay.implicitHeight

  RowLayout {
    id: rowLay
    width: parent.width
    spacing: 8

    // The tier light — same colour the "!" face shows when this tier is on.
    Rectangle {
      Layout.alignment: Qt.AlignTop
      Layout.topMargin: 3
      width: 9; height: 9; radius: 4.5
      color: root.checked ? root.dotColor : "transparent"
      border.width: 1
      border.color: root.dotColor
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 1

      Text {
        Layout.fillWidth: true
        text: root.title
        font.pixelSize: 12
        font.bold: true
        color: brg.settings.textColorDark
        wrapMode: Text.WordWrap
      }
      Text {
        Layout.fillWidth: true
        text: root.blurb
        font.pixelSize: 10
        color: brg.settings.textColorMid
        wrapMode: Text.WordWrap
      }
    }

    // A flat on/off pill — the app's language, not a system checkbox.
    Rectangle {
      Layout.alignment: Qt.AlignVCenter
      implicitWidth: 40
      implicitHeight: 22
      radius: 11
      color: root.checked ? root.dotColor : Qt.rgba(0, 0, 0, 0.08)
      border.width: 1
      border.color: root.checked ? Qt.darker(root.dotColor, 1.3) : brg.settings.dividerColor
      Behavior on color { ColorAnimation { duration: 90 } }

      Rectangle {
        width: 16; height: 16; radius: 8
        color: "#ffffff"
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - 3 : 3
        Behavior on x { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
      }
    }
  }

  HoverHandler { cursorShape: Qt.PointingHandCursor }
  TapHandler {
    gesturePolicy: TapHandler.ReleaseWithinBounds
    onTapped: root.toggled()
  }
}
