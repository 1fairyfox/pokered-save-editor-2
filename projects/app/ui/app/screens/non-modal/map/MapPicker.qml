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
  MapPicker.qml -- the top bar's MAP OPTIONS button (⊞): everything ABOUT the loaded map that isn't
  picking WHICH map (that is the title, MapNamePicker). One dropdown to the right of the name:

    * "Outside is…"  (`wLastMap`)          -- where every "back outside" ($FF) door lands
    * "Wake up at…"  (`wLastBlackoutMap`)  -- where blacking out, DIG and an ESCAPE ROPE drop you
    * a Fix for a stored map SIZE that came from another map
    * the TILESET (`gfxPtr`, + Indoor/Cave/Outdoor) and the BLOCKSET (`blockPtr`) the map draws from

  ⚠️ Tileset & blocks live HERE again (project leadership, 2026-08-03: *"move tileset and blockset to
  the map-select dropdown panel"*). They were briefly their own ▩ button; leadership folded them back
  into this one dropdown so the map name stays a clean direct selector and all the map's config sits in
  a single panel beside it. This button's amber dot marks EITHER a stale stored size OR a blockset that
  disagrees with the tileset.
*/
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
  id: root

  implicitWidth: trigger.implicitWidth
  implicitHeight: 26

  /// Drive the drop-down open/shut by name -- the DEBUG harness can only set properties on items,
  /// and the mandatory screenshot review has to be able to REACH the thing it is reviewing.
  /// (reference/dev-harness.md)
  property bool openState: false
  onOpenStateChanged: openState ? pop.open() : pop.close()

  // ── A "Designated Maps" row: a label, a grouped map combo, and a one-line blurb ────────────────
  //
  // Reused for "Outside is…" (wLastMap) and "Wake up at…" (wLastBlackoutMap). The combo is the SAME
  // grouped map list the title picker uses; 248 names flat is a wall, so it groups by tileset.
  component DesignatedMapRow: ColumnLayout {
    id: dmr
    property string label: ""
    property string blurb: ""
    property int value: 0
    signal picked(int v)
    spacing: 3

    Text { text: dmr.label; font.pixelSize: 10; color: brg.settings.textColorMid }

    ComboBox {
      id: dmrCombo
      Layout.fillWidth: true
      Layout.preferredHeight: 30
      font.pixelSize: 12
      model: brg.map.mapList()
      textRole: "name"
      valueRole: "ind"
      currentIndex: {
        const l = model;
        for (let i = 0; i < l.length; i++)
          if (l[i].ind === dmr.value) return i;
        return -1;
      }
      onActivated: dmr.picked(currentValue)

      delegate: ItemDelegate {
        required property var modelData
        required property int index
        width: dmrCombo.width
        height: (modelData.group !== "" ? 20 : 0) + 26
        highlighted: dmrCombo.highlightedIndex === index
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
          }
        }
      }
    }

    Text {
      Layout.fillWidth: true
      visible: dmr.blurb !== ""
      text: dmr.blurb
      font.pixelSize: 10
      color: brg.settings.textColorMid
      opacity: 0.8
      wrapMode: Text.WordWrap
    }
  }

  // The ⊞ button opens the map's config: designated maps, the size fix, and the tileset/blocks.
  MapBarButton {
    id: trigger
    anchors.fill: parent

    glyph: "⊞"
    open: root.openState
    onToggle: root.openState = !root.openState

    tip: qsTr("Map options — designated maps, tileset & blocks, the stored size")

    // Reactive state: a stale stored size, OR a blockset that disagrees with the tileset. Either is a
    // rare-but-legal thing worth flagging — a little amber dot, so the icon SAYS something is off.
    Rectangle {
      parent: trigger
      visible: !brg.map.headerMatches || !brg.map.blocksetIsTileset
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

    // ⚠️ Keep the panel inside the window at the 750×480 semi-fluid minimum: `margins` lets Qt shift
    // it up rather than clip past the bottom, and the height cap + ScrollView below let a tall panel
    // (this one now carries designated maps AND tileset/blocks) scroll rather than overflow.
    margins: 8

    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

    // ⚠️ Sync the button's open flag when the popup closes by ANY route (click-off, Escape). Without
    // this, click-off closed the popup but left openState=true — so the ⊞ button stayed highlighted
    // and the next click "closed" the already-closed popup instead of reopening it. (project leadership,
    // 2026-08-03: "panel highlighting and opening is weird if you close the panel by clicking off".)
    onClosed: root.openState = false

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

        // ── Designated Maps — the "where the world puts you" bytes ──────────────────────────────
        //
        // Both live in WorldGeneral and both re-home the player: Outside is (wLastMap) is where every
        // "back outside" ($FF) door lands — change it and every such door on the canvas re-labels at
        // once; Wake up at (wLastBlackoutMap) is where blacking out, DIG and an ESCAPE ROPE drop you.
        Text {
          text: qsTr("Designated Maps")
          font.pixelSize: 11
          font.bold: true
          color: brg.settings.textColorMid
        }

        DesignatedMapRow {
          Layout.fillWidth: true
          label: qsTr("Outside is…")
          blurb: qsTr("Designated map when a warp goes back outside.")
          value: brg.map.lastMap
          onPicked: (v) => brg.map.lastMap = v
        }

        DesignatedMapRow {
          Layout.fillWidth: true
          label: qsTr("Wake up at…")
          blurb: qsTr("Designated black out, DIG, and ESCAPE ROPE map.")
          value: brg.map.lastBlackoutMap
          onPicked: (v) => brg.map.lastBlackoutMap = v
        }

        // A stale stored size — shown only when it disagrees, with its Fix.
        Rectangle {
          Layout.fillWidth: true; implicitHeight: 1; color: brg.settings.dividerColor
          visible: !brg.map.headerMatches
        }

        RowLayout {
          Layout.fillWidth: true
          visible: !brg.map.headerMatches
          spacing: 6

          Text {
            Layout.fillWidth: true
            text: qsTr("The stored map size is from another map.")
            font.pixelSize: 10
            color: "#8a6d00"
            wrapMode: Text.WordWrap
          }

          Button {
            flat: true
            font.pixelSize: 10
            text: qsTr("Fix")
            onClicked: brg.map.fixMapHeader()
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

        // Indoor / Cave / Outdoor. NOT a place -- it is which tiles MOVE, and it lives with the
        // tileset because it IS the tileset's byte (0x3522). Cave is not Indoor: cave water animates.
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

        // What the chosen one DOES, said underneath and changing as you pick. "Indoor" is not a place,
        // it is *nothing animates*.
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
        // say so in the muted voice — and OFFER to bring them back in sync (a button, never a silent
        // rewrite; the same muted-notice idiom the stored-size Fix uses). Appears the instant a change
        // makes the two diverge.
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
}
