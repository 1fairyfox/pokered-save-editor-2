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
  MapPicker.qml -- ONE control in the top bar that answers "which map, drawn out of what".

  Clicking it drops a small panel with the three choices the save actually keeps, and they are three
  because the SAVE keeps them as three:

    * the MAP        (`wCurMap`)         -- which map's block data is loaded
    * the TILESET    (`gfxPtr`)          -- where the tiles are drawn FROM, and Indoor/Cave/Outdoor
                                            (which is not a place -- it is which tiles MOVE)
    * the BLOCKSET   (`blockPtr`)        -- which tileset's BLOCKS the map is built out of

  Normally the last two name the same tileset. They are two separate pointers in the save, though,
  and a console draws exactly what they say -- so they get two separate controls, and a save that
  disagrees with itself is SHOWN doing so, never quietly tidied up.

  ⚠️ Picking a map no longer COMMITS anything (leadership, 2026-07-19). It starts a PREVIEW: the
  destination is constructed for real so you see exactly what you would get, but the save is
  snapshotted first and nothing is written until you decide. The Preview box (top-right of the
  canvas) carries the decision -- ✗ drops it, ✓ asks "Normal or Manual": Normal keeps the whole
  construction (sprites, signs, warps, connections, the map's own progression), Manual restores the
  snapshot and writes ONLY the map id. So the old "Construct on change" switch is gone -- there is
  no mode to set up front; you look, then choose. @see MapModel::beginMapPreview, MapCanvas' box.
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

  /// Tileset + blockset are advanced overrides behind a disclosure link (project leadership, 2026-07-19) —
  /// the map is the thing you pick; these two are the power path, collapsed until asked for.
  property bool advancedOpen: false

  // ── A "Designated Maps" row: a label, a grouped map combo, and a one-line blurb ────────────────
  //
  // Reused for "Outside is…" (wLastMap) and "Wake up at…" (wLastBlackoutMap) — both moved off the
  // toolbar into this panel (project leadership, 2026-07-19). The combo is the SAME grouped map list the title
  // picker uses; 248 names flat is a wall, so it groups by the map's own tileset.
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

  // The map SELECTOR is the title now (MapNamePicker.qml). This ⊞ button opens the map's EXTRAS: the
  // designated maps (Outside is / Wake up at) and the tileset/blocks override. Its glyph is a
  // grid-in-a-frame — a map is a grid of blocks.
  MapBarButton {
    id: trigger
    anchors.fill: parent

    glyph: "⊞"
    open: root.openState
    onToggle: root.openState = !root.openState

    tip: qsTr("Map options — designated maps, tileset & blocks")

    // Reactive state: the map's blocks come from a different tileset than its graphics (rare, legal,
    // and worth flagging), or its stored size no longer matches the map. A little amber dot, so the
    // icon SAYS something is off without a wall of text on the bar.
    Rectangle {
      parent: trigger
      visible: !brg.map.blocksetIsTileset || !brg.map.headerMatches
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

    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

    background: Rectangle {
      color: "#ffffff"
      radius: 6
      border.width: 1
      border.color: brg.settings.dividerColor
    }

    ColumnLayout {
      anchors.fill: parent
      spacing: 8

      // ── Designated Maps — the "where the world puts you" bytes ────────────────────────────────
      //
      // (The map SELECTOR moved to the title — MapNamePicker.qml — so this panel is the extras: the
      // designated maps, and the tileset/blocks override below. Project leadership, 2026-07-19.)
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

      Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: brg.settings.dividerColor }

      // The size the save stores is a DIFFERENT set of bytes from the map id. If some earlier edit
      // left them stale, the doctrine says SHOW it and offer the fix -- never rewrite it quietly.
      //
      // But it is not an ERROR, so it is not red (project leadership, 2026-07-13: "you have red text everywhere,
      // even to indicate information, which is bad"). Red means *something is broken*. This is a
      // notice, so it reads as a notice: a muted amber line with a button that does the thing.
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

      // ── Tileset & blocks — the power path, behind a link ─────────────────────────────────────
      //
      // The map is what you pick; the tileset (graphics) and blockset (blocks) are advanced
      // overrides most people never touch, so they collapse behind a disclosure link — the same
      // "Something else…" idiom the Details panel uses (project leadership, 2026-07-19). A quiet amber dot on
      // the link surfaces when a save's graphics and blocks disagree, so the fact is never buried.
      RowLayout {
        Layout.fillWidth: true
        spacing: 6

        // "Override…" (not just "Tileset & blocks") so the link reads as MANUAL control — you are
        // overriding what the map would otherwise use — rather than "more useful options hidden in a
        // menu" (project leadership, 2026-07-19).
        Text {
          text: root.advancedOpen ? qsTr("Override tileset & blocks ▾")
                                   : qsTr("Override tileset & blocks ▸")
          font.pixelSize: 11
          color: brg.settings.accentColor
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.advancedOpen = !root.advancedOpen
          }
        }

        Rectangle {
          visible: !brg.map.blocksetIsTileset
          width: 6; height: 6; radius: 3
          color: "#e69f00"
        }

        Item { Layout.fillWidth: true }
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: 2
        spacing: 8
        visible: root.advancedOpen

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

      // What the chosen one DOES, said underneath and changing as you pick (project leadership, 2026-07-13) --
      // rather than hidden in a tooltip you have to go hunting for. This is the whole reason the
      // control exists: "Indoor" is not a place, it is *nothing animates*.
      Text {
        Layout.fillWidth: true
        text: {
          switch (brg.map.tileAnim) {
            case 0: return qsTr("Nothing animates — no water, no flowers. (Surf needs the water tile, "
                                + "so this breaks it on a water map.)");
            case 1: return qsTr("The water animates. The flowers don't.");
            case 2: return qsTr("The water and the flowers both animate.");
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

      // A fact about an unusual save, in the same muted voice as everything else here. It is not an
      // error -- a console draws it perfectly happily -- so it does not shout.
      Text {
        Layout.fillWidth: true
        visible: !brg.map.blocksetIsTileset
        text: brg.map.blocksetInd < 0
              ? qsTr("The blocks pointer is not any tileset's. The game would read whatever sits at "
                     + "that address.")
              : qsTr("The blocks come from %1 and the tiles from %2.")
                .arg(brg.map.blocksetName).arg(brg.map.tilesetName)
        font.pixelSize: 10
        color: brg.settings.textColorMid
        wrapMode: Text.WordWrap
        }
      }
    }
  }
}
