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
  MapPicker.qml -- the top bar's MAP OPTIONS button (⊞): the DESIGNATED MAPS, and the map-size fix.

  The map SELECTOR is the title now (MapNamePicker.qml). This ⊞ button holds the extras:

    * "Outside is…"  (`wLastMap`)          -- where every "back outside" ($FF) door lands
    * "Wake up at…"  (`wLastBlackoutMap`)  -- where blacking out, DIG and an ESCAPE ROPE drop you
    * a Fix for a stored map SIZE that came from another map

  ⚠️ TILESET & BLOCKS ARE NOT HERE ANY MORE (project leadership, 2026-08-03): they broke out into their
  own top-bar button (TilesetBlocksPicker.qml, the ▩ next to this one). The graphics/blocks a map
  draws from is a thing people come here to change, not a power-user footnote buried in a disclosure.
  So this button's amber dot now marks only a stored-size mismatch; the blockset≠tileset disagreement
  marks the ▩ button instead.
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

  // The ⊞ button opens the map's EXTRAS: the designated maps and the size fix. Its glyph is a
  // grid-in-a-frame — a map is a grid of blocks.
  MapBarButton {
    id: trigger
    anchors.fill: parent

    glyph: "⊞"
    open: root.openState
    onToggle: root.openState = !root.openState

    tip: qsTr("Map options — designated maps, and the stored size")

    // Reactive state: the map's stored size no longer matches the map. A little amber dot, so the
    // icon SAYS something is off without a wall of text on the bar. (Tileset/blocks disagreement is
    // the ▩ button's dot now.)
    Rectangle {
      parent: trigger
      visible: !brg.map.headerMatches
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
    // size, so a menu can never fall off the edge.
    margins: 8

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

      // When the size is fine and nothing needs fixing, say the panel is complete rather than ending
      // on a bare divider.
      Text {
        Layout.fillWidth: true
        visible: brg.map.headerMatches
        text: qsTr("The stored map size matches this map.")
        font.pixelSize: 10
        color: brg.settings.textColorMid
        opacity: 0.7
        wrapMode: Text.WordWrap
      }
    }
  }
}
