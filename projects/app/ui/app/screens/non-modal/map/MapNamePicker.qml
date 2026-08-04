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
  MapNamePicker.qml -- the map's NAME, and it IS the map selector. Clicking it drops the MAP SELECTION
  PANEL: the grouped map list you pick from, AND the tileset & blockset the map draws from.

  project leadership, 2026-08-03: *"tileset and blockset belong in the map-selection panel, not with the
  designated maps."* So the graphics/blocks a map is drawn from live HERE, in the same dropdown you pick
  the map from — because they ARE part of choosing what map you're looking at. The designated maps
  (Outside is / Wake up at — world routing, a different concern) stay in the ⊞ panel beside this.

  The map list sits at the top so it stays directly selectable the moment the panel opens — you never
  have to open a second panel to change the map, the tileset or the blocks.
*/
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
  id: root
  objectName: "mapNamePicker"

  implicitWidth: face.implicitWidth
  implicitHeight: 26
  Layout.maximumWidth: 210

  /// Drive the drop-down open/shut by name (the DEBUG harness / screenshot review).
  property bool openState: false
  onOpenStateChanged: openState ? pop.open() : pop.close()

  // ── The face: the bold map name + a ▾ that says "I drop a menu" ────────────────────────────────
  Rectangle {
    id: face
    anchors.fill: parent
    radius: 6
    implicitWidth: faceRow.implicitWidth + 14

    color: (faceHover.hovered || root.openState) ? Qt.rgba(0, 0, 0, 0.06) : "transparent"
    Behavior on color { ColorAnimation { duration: 90 } }

    RowLayout {
      id: faceRow
      anchors.fill: parent
      anchors.leftMargin: 7
      anchors.rightMargin: 7
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
        Layout.alignment: Qt.AlignVCenter
      }
    }

    HoverHandler { id: faceHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: root.openState = !root.openState }
  }

  // ── The map-selection panel ─────────────────────────────────────────────────────────────────
  Popup {
    id: pop

    y: root.height + 4
    width: 320
    padding: 10
    margins: 8   // keep inside the window at the 750×480 minimum

    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
    onClosed: root.openState = false   // sync the button highlight on click-off/Escape @see MapPicker

    background: Rectangle {
      color: "#ffffff"
      radius: 6
      border.width: 1
      border.color: brg.settings.dividerColor
    }

    ColumnLayout {
      anchors.fill: parent
      spacing: 8

      // ── The map list — the "select box", right at the top so it's usable the instant you open ──
      Text {
        text: qsTr("Map")
        font.pixelSize: 11
        font.bold: true
        color: brg.settings.textColorMid
      }

      // A fixed-height list that scrolls internally (248 maps grouped by tileset), so the tileset /
      // blockset controls below it stay put rather than scrolling away with the list.
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 114   // ~3 rows + internal scroll — short of the window edges
        radius: 5
        border.width: 1
        border.color: brg.settings.dividerColor
        clip: true

        ListView {
          id: mapList
          anchors.fill: parent
          anchors.margins: 1
          clip: true
          model: brg.map.mapList()
          currentIndex: {
            const l = mapList.model;
            for (let i = 0; i < l.length; i++)
              if (l[i].ind === brg.map.mapInd) return i;
            return -1;
          }
          ScrollBar.vertical: ScrollBar { }

          delegate: ItemDelegate {
            required property var modelData
            required property int index
            width: mapList.width
            height: (modelData.group !== "" ? 20 : 0) + 26
            highlighted: modelData.ind === brg.map.mapInd

            // Picking a map opens the PREVIEW on the canvas (it does not commit) and closes the panel.
            // @see MapModel::beginMapPreview, the Preview card in MapCanvas.
            onClicked: {
              brg.map.beginMapPreview(modelData.ind);
              root.openState = false;
            }

            contentItem: ColumnLayout {
              spacing: 0
              Text {
                visible: modelData.group !== ""
                Layout.fillWidth: true
                text: modelData.group
                font.pixelSize: 10; font.bold: true
                color: brg.settings.textColorMid
              }
              RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text {
                  text: modelData.ind
                  font.pixelSize: 10; font.family: "monospace"
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
                Text {
                  visible: modelData.isCopy
                  text: qsTr("→ %1").arg(modelData.copyOf)
                  font.pixelSize: 10; font.italic: true
                  color: brg.settings.textColorMid
                }
              }
            }
          }
        }
      }

      Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: brg.settings.dividerColor }

      // ── Tileset (the graphics) + what animates ──────────────────────────────────────────────
      Text {
        text: qsTr("Tileset — the graphics")
        font.pixelSize: 11
        font.bold: true
        color: brg.settings.textColorMid
      }

      ComboBox {
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        font.pixelSize: 12

        model: brg.map.tilesetList()
        textRole: "name"
        valueRole: "ind"

        currentIndex: {
          const list = model;
          for (let i = 0; i < list.length; i++)
            if (list[i].ind === brg.map.tilesetInd)
              return i;
          return -1;
        }

        onActivated: brg.map.tilesetInd = currentValue
      }

      // Indoor / Cave / Outdoor — which tiles MOVE (the tileset's 0x3522 byte). Cave is not Indoor:
      // cave water animates.
      RowLayout {
        Layout.fillWidth: true
        spacing: 0

        Repeater {
          model: [
            { v: 0, name: qsTr("Indoor")  },
            { v: 1, name: qsTr("Cave")    },
            { v: 2, name: qsTr("Outdoor") }
          ]

          Rectangle {
            required property var modelData
            required property int index

            Layout.fillWidth: true
            implicitHeight: 26

            readonly property bool active: brg.map.tileAnim === modelData.v

            color: active ? brg.settings.accentColor
                 : segHover.hovered ? "#f0f0f0" : "transparent"

            border.width: 1
            border.color: brg.settings.dividerColor

            topLeftRadius: index === 0 ? 4 : 0
            bottomLeftRadius: index === 0 ? 4 : 0
            topRightRadius: index === 2 ? 4 : 0
            bottomRightRadius: index === 2 ? 4 : 0

            HoverHandler { id: segHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: brg.map.tileAnim = modelData.v }

            Text {
              anchors.centerIn: parent
              text: modelData.name
              font.pixelSize: 11
              font.bold: parent.active
              color: parent.active ? brg.settings.textColorLight : brg.settings.textColorDark
            }
          }
        }
      }

      Text {
        Layout.fillWidth: true
        text: {
          switch (brg.map.tileAnim) {
            case 0: return qsTr("Nothing animates. ⚠️ Surf needs the water tile, so Indoor breaks Surf.");
            case 1: return qsTr("Water animates, flowers don't — Surf-friendly. Tile $14 goes through a "
                                + "water distortion, typically only used for real water tiles.");
            case 2: return qsTr("Water and flowers animate — Surf-friendly. Tile $14 goes through a "
                                + "water distortion, typically only used for real water tiles.");
          }
          return (brg.map.tileAnim % 2 === 1)
                 ? qsTr("%1 — the console reads bit 0, so this behaves as water only.").arg(brg.map.tileAnim)
                 : qsTr("%1 — the console reads bit 0, so this behaves as water and flowers.").arg(brg.map.tileAnim);
        }
        font.pixelSize: 10
        color: brg.settings.textColorMid
        wrapMode: Text.WordWrap
      }

      Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: brg.settings.dividerColor }

      // ── Blockset (the blocks) ───────────────────────────────────────────────────────────────
      Text {
        text: qsTr("Blockset — what the map is built from")
        font.pixelSize: 11
        font.bold: true
        color: brg.settings.textColorMid
      }

      ComboBox {
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        font.pixelSize: 12

        model: brg.map.tilesetList()
        textRole: "name"
        valueRole: "ind"

        currentIndex: {
          const list = model;
          for (let i = 0; i < list.length; i++)
            if (list[i].ind === brg.map.blocksetInd)
              return i;
          return -1;
        }

        onActivated: brg.map.blocksetInd = currentValue
      }

      // When blocks and graphics disagree (rare, legal), say so and OFFER to sync — a button, never a
      // silent rewrite (the same muted-notice idiom the stored-size Fix uses).
      ColumnLayout {
        Layout.fillWidth: true
        visible: !brg.map.blocksetIsTileset
        spacing: 6

        Text {
          Layout.fillWidth: true
          text: brg.map.blocksetInd < 0
                ? qsTr("The blocks pointer is not any tileset's. The game would read whatever sits at "
                       + "that address.")
                : qsTr("The blocks come from %1 and the tiles from %2.")
                  .arg(brg.map.blocksetName).arg(brg.map.tilesetName)
          font.pixelSize: 10
          color: brg.settings.textColorMid
          wrapMode: Text.WordWrap
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 6

          Button {
            flat: true
            font.pixelSize: 10
            text: qsTr("Match blocks → %1").arg(brg.map.tilesetName)
            onClicked: brg.map.blocksetInd = brg.map.tilesetInd
          }

          Button {
            flat: true
            font.pixelSize: 10
            visible: brg.map.blocksetInd >= 0
            text: qsTr("Match tiles → %1").arg(brg.map.blocksetName)
            onClicked: brg.map.tilesetInd = brg.map.blocksetInd
          }

          Item { Layout.fillWidth: true }
        }
      }
    }
  }
}
