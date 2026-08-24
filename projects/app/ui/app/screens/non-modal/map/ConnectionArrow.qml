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

/**
 * A ghostly white "add a connecting route here" arrow on ONE edge of the map.
 *
 * Shown only where that edge has NO connection (an invitation, never chrome -- project leadership: *"lightweight
 * and simple… it needs to look kind of ghostly"*). Clicking it opens a small map picker; choosing a
 * neighbour calls `brg.map.addConnection(dir, ind)`, and the arrow vanishes as the connection appears.
 * That is the click-to-add half of "both add-gestures"; the drag-a-map-onto-it half rides the same
 * `addConnection` call.
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// For `MapModel.SortConnections` — the enum, by name rather than as a bare 3. Registered uncreatable
// in bootQmlLinkage.cpp; the import is what makes its Q_ENUM reachable here.
import App.MapModel

Item {
  id: arrow

  required property var canvas
  required property int dir            // MapDBEntryConnect::ConnectDir: N 0, S 1, E 2, W 3

  /// The DEBUG harness opens a specific edge's picker through this — "connArrow0".."connArrow3".
  objectName: "connArrow" + arrow.dir

  readonly property var edge: { arrow.canvas.revision; return arrow.canvas.connEdgeFor(arrow.dir); }
  readonly property bool absent: arrow.edge !== null && arrow.edge.exists === false

  /// Every map, with the ROM's own answer for this edge marked. Built once per open (the popup binds
  /// through `pop.opened`), because it walks the whole map store.
  /// @see MapModel::connectionMapList — `{ value, name, size, group, isDefault }`.
  readonly property var connList: { pop.opened; return brg.map.connectionMapList(arrow.dir); }

  /// The map the cartridge really connects to this edge, as ONE `leadingEntries` row for the shared
  /// map selector — `{ ind, name, group, size }`. Empty when this edge has no ROM default.
  ///
  /// ⚠️ This is the part of the old bespoke ComboBox worth keeping. The shared list can sort "by
  /// connections", which clusters maps by their connection signature — genuinely useful, and what
  /// this picker now opens on — but no sort can know which single map is *supposed* to be here. That
  /// is a fact about this map's ROM header, so it rides above the sort as its own row.
  readonly property var defaultRow: {
    const l = arrow.connList;
    for (let i = 0; i < l.length; i++)
      if (l[i].isDefault === true)
        return [{ ind: l[i].value, name: l[i].name, group: l[i].group, size: l[i].size }];
    return [];
  }

  /// A map's name by id, off the same list — so nothing needs a second lookup path.
  function nameOf(ind) {
    const l = arrow.connList;
    for (let i = 0; i < l.length; i++)
      if (l[i].value === ind)
        return l[i].name;
    return qsTr("map %1").arg(ind);
  }

  visible: absent && brg.mapLayers.showConnections && brg.map.valid

  readonly property real z0: arrow.canvas.zoom
  readonly property real cell: 34 * z0

  // The map rect in buffer px (bound through revision so it tracks size/map changes), and the arrow
  // parked just outside the named edge, in the border ring.
  readonly property real mx: { arrow.canvas.revision; return brg.map.mapX * z0; }
  readonly property real my: { arrow.canvas.revision; return brg.map.mapY * z0; }
  readonly property real mw: { arrow.canvas.revision; return brg.map.mapW * z0; }
  readonly property real mh: { arrow.canvas.revision; return brg.map.mapH * z0; }

  width: cell
  height: cell
  z: 6

  x: arrow.dir === 3 ? mx - cell - 6 * z0                       // West
   : arrow.dir === 2 ? mx + mw + 6 * z0                         // East
   : mx + mw / 2 - cell / 2                                     // North / South
  y: arrow.dir === 0 ? my - cell - 6 * z0                       // North
   : arrow.dir === 1 ? my + mh + 6 * z0                         // South
   : my + mh / 2 - cell / 2                                     // East / West

  Rectangle {
    id: pill
    anchors.fill: parent
    radius: 6
    color: hov.containsMouse ? "#f0ffffff" : "#66ffffff"       // ghostly by default, solid on hover
    border.width: 1
    border.color: hov.containsMouse ? "#d55e00" : "#b0ffffff"

    Text {
      anchors.centerIn: parent
      text: arrow.dir === 0 ? "▲" : arrow.dir === 1 ? "▼" : arrow.dir === 2 ? "▶" : "◀"
      font.pixelSize: Math.max(11, Math.round(15 * arrow.z0))
      color: hov.containsMouse ? "#d55e00" : "#5a5a5a"
    }

    // A small + so it reads as "add", not as a scroll button.
    Text {
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: 2
      text: "+"
      font.bold: true
      font.pixelSize: Math.max(8, Math.round(10 * arrow.z0))
      color: hov.containsMouse ? "#d55e00" : "#7a7a7a"
    }
  }

  MouseArea {
    id: hov
    anchors.fill: parent
    hoverEnabled: true
    enabled: !arrow.canvas.panning && arrow.canvas.tool !== "zoom"
    cursorShape: Qt.PointingHandCursor
    onClicked: (m) => { m.accepted = true; pop.open(); }

    // ⭐ TELL THE CANVAS A THING IS UNDER THE POINTER, so the cell highlight stands down — the same
    // contract sprites, doors and signs keep through `hoverMovable`. An arrow lives in the border
    // ring rather than in a block, so it cannot use that key and announces itself with its own flag
    // instead. Project leadership, 2026-08-18: *"when mousing over connection icons the blocks
    // underneath highlight when its not supposed to when mousing over objects."*
    onContainsMouseChanged: arrow.canvas.hoverConnection = containsMouse

    // The flag must not be left standing if this arrow goes away while hovered (an edge that gains a
    // connection replaces its arrow), or the highlight would stay suppressed for good.
    Component.onDestruction: if (arrow.canvas) arrow.canvas.hoverConnection = false
  }

  // ⚠️ `MapToolTip`, NOT the stock `ToolTip`. This one shipped as a stock tooltip and read as dark
  // text on a near-dark background out over the canvas well — project leadership, 2026-08-18: *"the
  // connection tooltips are dark text on dark background, make it proper how it is elsewhere."*
  //
  // The rule is written at the top of MapToolTip.qml and it is absolute: **nothing on this screen may
  // use the stock ToolTip.** This file was the last holdout. `followGlobalSetting: false` because an
  // arrow is otherwise a bare chevron in the border ring — without the words it is unexplained, not
  // merely unannotated.
  MapToolTip {
    shown: hov.containsMouse && !pop.opened
    followGlobalSetting: false
    text: qsTr("Add a connecting route on the %1 edge")
          .arg(arrow.edge ? arrow.edge.dirName : "")
    delay: 400
  }

  // ── The picker ───────────────────────────────────────────────────────────────────────────
  Popup {
    id: pop
    y: arrow.height + 4
    width: 300
    padding: 10

    // ⚠️ KEEP IT INSIDE THE WINDOW. This popup used to hold a single combo and was short enough that
    // it never noticed; with the shared selector (heading · sort · search · a scrolling list) it is
    // tall, and an arrow parked near the bottom edge of the map would have opened it half off-screen.
    // A non-negative `margins` is what makes Qt reposition a Popup to fit — @see MapNamePicker, which
    // has carried the same 8 since it grew a list.
    margins: 8
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

    // While it is open the ground must not take the dismiss-press (the popup-leak bug the canvas
    // already guards). We register with the canvas the same way the docks do.
    onOpenedChanged: {
      arrow.canvas.popupsOpen += (pop.opened ? 1 : -1);
      if (arrow.canvas.popupsOpen < 0) arrow.canvas.popupsOpen = 0;

      // ⭐ THIS PICKER OPENS ON "BY CONNECTIONS" — AND ONLY THIS ONE (project leadership, 2026-08-18:
      // *"it should default there to connections sorting"*; 2026-08-19: *"it defaults to tileset for
      // map select, the connections default to connections sorting only here"*). It is the one map
      // list where that sort is the answer to the question being asked — you are choosing a
      // neighbour, so grouping by which edges a map already connects on puts the plausible ones
      // together.
      //
      // ⚠️ IT SETS THE LIST'S OWN SORT, NOT THE SHARED ONE. Writing `brg.map.mapSort` here (which is
      // what this did for a day) meant opening this dropdown once re-grouped **every map list in the
      // app** for the rest of the session — the map selector included — with nothing on screen to say
      // why. A picker may answer its own question; it may not answer everyone else's. @see
      // MapSelectList.ownSort.
      if (pop.opened)
        sel.ownSort = MapModel.SortConnections;
    }

    background: Rectangle {
      color: "#ffffff"; radius: 6
      border.width: 1; border.color: brg.settings.dividerColor
    }

    ColumnLayout {
      anchors.fill: parent
      spacing: 8

      Text {
        text: qsTr("Connect the %1 edge to…").arg(arrow.edge ? arrow.edge.dirName : "")
        font.pixelSize: 11
        font.bold: true
        color: brg.settings.textColorMid
      }

      // ⭐ THE ONE SHARED MAP SELECTOR — sort · search · grouped rows (project leadership, 2026-08-18:
      // *"the connection map select doesn't use the new shared map select, it should"*). It was the
      // last map picker on the screen still running its own bespoke ComboBox, which meant this one
      // place had no search, no sort, and a different row shape from every other map list in the app.
      //
      // What the bespoke list did better is kept, not lost: the map the ROM really connects to on this
      // edge rides at the top as a `leadingEntries` row under its own heading. @see defaultRow.
      MapSelectList {
        id: sel
        Layout.fillWidth: true
        listHeight: 150
        selectedInd: -1
        leadingEntries: arrow.defaultRow

        // Its own sort, seeded here so the list is right on its very first frame (the popup's
        // onOpenedChanged re-seeds it on every open). @see MapSelectList.ownSort — this is the ONE
        // list in the app that does not share the global sort, and the reason is written down there.
        ownSort: MapModel.SortConnections

        onPicked: (ind) => {
          if (ind < 0)
            return;
          const name = arrow.nameOf(ind);
          if (brg.map.addConnection(arrow.dir, ind)) {
            if (!brg.mapLayers.showConnections)
              brg.mapLayers.setKeyVisible("connections", true);
            arrow.canvas.selectedConnection = arrow.dir;
            arrow.canvas.status = qsTr("Connected the %1 edge to %2.")
                                    .arg(arrow.edge ? arrow.edge.dirName : "").arg(name);
          }
          pop.close();
        }
      }

      Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: qsTr("It starts corner-aligned; drag the strip along the edge to slide it, or edit the "
                   + "details to set the exact offset.")
        font.pixelSize: 11
        color: brg.settings.textColorMid
      }
    }
  }
}
