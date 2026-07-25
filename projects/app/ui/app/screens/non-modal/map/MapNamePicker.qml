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
  MapNamePicker.qml -- the map's NAME, and it IS the map selector.

  Project leadership, 2026-07-19: *"why dont we make the map title a button with a down arrow indicating its a
  dropdown … clicking the map name directly lets you select a different map, no panel opening
  needed."* So the bold title is a flat dropdown button: click it, pick a map, and it opens the
  PREVIEW (MapModel::beginMapPreview) exactly as the old picker combo did. The tileset/blockset
  overrides and the designated maps live in their own little panel (MapPicker.qml) beside it.
*/
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ComboBox {
  id: root
  objectName: "mapNamePicker"

  model: brg.map.mapList()
  textRole: "name"
  valueRole: "ind"

  Layout.preferredHeight: 26
  Layout.maximumWidth: 210

  currentIndex: {
    const list = model;
    for (let i = 0; i < list.length; i++)
      if (list[i].ind === brg.map.mapInd)
        return i;
    return -1;
  }

  // Picking a map opens the PREVIEW on the canvas (it does not commit) — the same flow the old
  // picker combo used. @see MapModel::beginMapPreview, the Preview card in MapCanvas.
  onActivated: brg.map.beginMapPreview(currentValue)

  // The face: the bold map name + a ▾ that says "I drop a menu". Flat — no combo chrome; it reads as
  // the title it replaced, just clickable.
  contentItem: RowLayout {
    spacing: 5

    Label {
      Layout.fillWidth: true
      text: brg.map.valid ? brg.map.mapName : qsTr("No map")
      font.pixelSize: 14
      font.bold: true
      color: brg.settings.textColorDark
      elide: Text.ElideRight
      verticalAlignment: Text.AlignVCenter
    }

    Text {
      text: "⌄"
      font.pixelSize: 11
      color: brg.settings.textColorMid
      opacity: 0.85
    }
  }

  indicator: null   // the ▾ lives in the content row above, tight against the name

  background: Rectangle {
    radius: 6
    color: root.down || root.hovered ? Qt.rgba(0, 0, 0, 0.06) : "transparent"
    Behavior on color { ColorAnimation { duration: 90 } }
  }

  // A wider dropdown than the tiny title — 248 names in a flat list is a wall, so it is GROUPED by
  // the map's own tileset, exactly like the old picker.
  popup: Popup {
    y: root.height + 4
    width: 300
    implicitHeight: Math.min(420, contentItem.implicitHeight + 2)
    padding: 4

    background: Rectangle {
      color: "#ffffff"
      radius: 6
      border.width: 1
      border.color: brg.settings.dividerColor
    }

    contentItem: ListView {
      clip: true
      implicitHeight: contentHeight
      model: root.delegateModel
      currentIndex: root.highlightedIndex
      ScrollBar.vertical: ScrollBar { }
    }
  }

  delegate: ItemDelegate {
    required property var modelData
    required property int index

    width: 300 - 8
    height: (modelData.group !== "" ? 20 : 0) + 26
    highlighted: root.highlightedIndex === index

    contentItem: ColumnLayout {
      spacing: 0

      Text {
        visible: modelData.group !== ""
        Layout.fillWidth: true
        text: modelData.group
        font.pixelSize: 10
        font.bold: true
        color: brg.settings.textColorMid
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Text {
          text: modelData.ind
          font.pixelSize: 10
          font.family: "monospace"
          color: brg.settings.textColorMid
          Layout.minimumWidth: 22
        }

        Text {
          Layout.fillWidth: true
          text: modelData.name
          font.pixelSize: 12
          color: brg.settings.textColorDark
          elide: Text.ElideRight
        }

        // A fact, not an alarm: this id has no map of its own, so the game draws the one it copies.
        Text {
          visible: modelData.isCopy
          text: qsTr("→ %1").arg(modelData.copyOf)
          font.pixelSize: 10
          font.italic: true
          color: brg.settings.textColorMid
        }
      }
    }
  }
}
