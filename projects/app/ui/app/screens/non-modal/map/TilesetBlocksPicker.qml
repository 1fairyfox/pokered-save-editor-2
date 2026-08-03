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
  TilesetBlocksPicker.qml -- the top bar's TILESET & BLOCKS button (▩), its own control next to the
  Map-options (⊞) button.

  project leadership, 2026-08-03: *"break tileset and blocks out into its own button next to designated
  maps."* It used to be an "Override tileset & blocks" disclosure buried inside MapPicker's panel; it
  is a first-class button now, because the graphics/blocks a map draws from is a thing people come to
  the Map screen to change, not a power-user footnote.

  Two pointers, two controls, because the SAVE keeps them as two:

    * the TILESET  (`gfxPtr`)   -- where the tiles are drawn FROM, and Indoor/Cave/Outdoor (which is
                                   not a place -- it is which tiles MOVE)
    * the BLOCKSET (`blockPtr`) -- which tileset's BLOCKS the map is built out of

  Normally the two name the same tileset. They are separate pointers, though, and a console draws
  exactly what they say -- so a save that disagrees with itself is SHOWN doing so (the amber dot on
  the button, and the line under the blockset), never quietly tidied up.
*/
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
  id: root

  implicitWidth: trigger.implicitWidth
  implicitHeight: 26

  /// Drive the drop-down open/shut by name -- the DEBUG harness can only set properties on items,
  /// and the mandatory screenshot review has to be able to REACH the thing it reviews.
  property bool openState: false
  onOpenStateChanged: openState ? pop.open() : pop.close()

  MapBarButton {
    id: trigger
    anchors.fill: parent

    glyph: "▩"
    open: root.openState
    onToggle: root.openState = !root.openState

    tip: qsTr("Tileset & blocks — the graphics the map draws from, and the blocks it is built out of")

    // The map's blocks come from a different tileset than its graphics: rare, legal, worth flagging.
    // A little amber dot, the same "attention" idiom the ⊞ button and the "!" scratch mark use.
    Rectangle {
      parent: trigger
      visible: !brg.map.blocksetIsTileset
      width: 7; height: 7; radius: 3.5
      color: "#e69f00"
      border.width: 1
      border.color: "#8a6d00"
      x: 3; y: 3
      z: 5
    }
  }

  // ── The drop-down ───────────────────────────────────────────────────────────────────────────
  Popup {
    id: pop

    y: root.height + 4
    width: 300
    padding: 10

    // ⚠️ Keep the panel inside the window (project leadership, 2026-08-03): `margins` lets Qt shift a
    // drop-down UP when it would otherwise clip past the window bottom at the semi-fluid minimum
    // size, so a menu can never fall off the edge. The content also scrolls if it can't fit at all.
    margins: 8

    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

    // Cap the height to what the window can show, and scroll the rest -- a semi-fluid surface never
    // clips its own menus.
    readonly property real maxH: (root.Window.height > 0 ? root.Window.height : 480) - 70
    height: Math.min(implicitHeight, maxH)

    background: Rectangle {
      color: "#ffffff"
      radius: 6
      border.width: 1
      border.color: brg.settings.dividerColor
    }

    contentItem: ScrollView {
      clip: true
      ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

      ColumnLayout {
        width: pop.availableWidth
        spacing: 8

        // ── Tileset (the graphics) + what animates ────────────────────────────────────────────
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

        // Indoor / Cave / Outdoor. NOT a place -- it is which tiles MOVE, and it lives with the
        // tileset because it IS the tileset's byte (0x3522). Cave is not Indoor: cave water animates.
        RowLayout {
          Layout.fillWidth: true
          spacing: 0

          Repeater {
            model: [
              { v: 0, name: qsTr("Indoor"),  does: qsTr("Nothing animates.") },
              { v: 1, name: qsTr("Cave"),    does: qsTr("Water animates. Flowers don't.") },
              { v: 2, name: qsTr("Outdoor"), does: qsTr("Water and flowers animate.") }
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

        // What the chosen one DOES, said underneath and changing as you pick (project leadership,
        // 2026-07-13) -- rather than hidden in a tooltip. "Indoor" is not a place, it is *nothing
        // animates*.
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
            // Every value the save can hold, including the ones no real game ships: the console tests
            // bit 0 and nothing else.
            return (brg.map.tileAnim % 2 === 1)
                   ? qsTr("%1 — the console reads bit 0, so this behaves as water only.")
                       .arg(brg.map.tileAnim)
                   : qsTr("%1 — the console reads bit 0, so this behaves as water and flowers.")
                       .arg(brg.map.tileAnim);
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
            return -1;   // a blockPtr that is nobody's blockset. Shown, not "corrected".
          }

          onActivated: brg.map.blocksetInd = currentValue
        }

        // Blocks and graphics are two pointers; normally they name the same tileset. When they don't,
        // say so in the muted voice — and OFFER to bring them back in sync (project leadership, 2026-08-03:
        // *"for tileset, blockset make sure you offer to switch the other in sync when changing"*).
        // Not automatic — a console draws a disagreeing save perfectly happily, so the offer is a
        // button, never a silent rewrite. This is the same muted-notice-with-a-button idiom the
        // stored-size Fix uses. The offer appears the instant a change makes the two diverge.
        ColumnLayout {
          Layout.fillWidth: true
          visible: !brg.map.blocksetIsTileset
          spacing: 6

          Text {
            Layout.fillWidth: true
            text: brg.map.blocksetInd < 0
                  ? qsTr("The blocks pointer is not any tileset's. The game would read whatever sits "
                         + "at that address.")
                  : qsTr("The blocks come from %1 and the tiles from %2.")
                    .arg(brg.map.blocksetName).arg(brg.map.tilesetName)
            font.pixelSize: 10
            color: brg.settings.textColorMid
            wrapMode: Text.WordWrap
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 6

            // Bring the blocks to the graphics' tileset (the common "I just changed the tileset, match
            // the blocks too" case).
            Button {
              flat: true
              font.pixelSize: 10
              text: qsTr("Match blocks → %1").arg(brg.map.tilesetName)
              onClicked: brg.map.blocksetInd = brg.map.tilesetInd
            }

            // Or the other way: bring the graphics to the blocks' tileset. Only when the blocks name a
            // real tileset (a raw, nobody's-tileset pointer has no name to match to).
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
}
