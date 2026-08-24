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
 * ONE selectable edge CONNECTION on the map -- the strip where a neighbouring map bleeds into the ring.
 *
 * The sibling of MapWarp.qml / MapSign.qml, and built on the same idea: a MouseArea, a select, a ✕, a
 * click-to-edit. What is different is the DRAG. A connection has no free X/Y -- it has one signed
 * OFFSET, and sliding it along the shared edge IS setting that offset (the nine derived bytes follow;
 * see notes/reference/map-connections.md). So the drag is constrained to the edge's one axis, snaps to
 * whole blocks, and magnetises to the landmark positions (corner-aligned / centred / flush).
 *
 * ⚠️ NOT a Repeater delegate. An offset edit re-derives the strip and bumps `canvas.revision`, which
 * would rebuild a delegate mid-drag and drop the gesture. There are only ever four connections, so the
 * canvas places four fixed MapConnection items (one per direction) that bind to the model in place.
 */
import QtQuick

Item {
  id: conn

  /// The canvas, for the zoom and the selection.
  required property var canvas

  /// Which edge this is -- MapDBEntryConnect::ConnectDir (N 0, S 1, E 2, W 3).
  required property int dir

  /// Reachable by name from the DEBUG harness, like every other model-built control on this screen
  /// (`dockBtn_<id>`, `missableSwitch_<n>`). Without it a connection could only be dragged by
  /// guessing screen coordinates — which is exactly how the drag bug below went unverified.
  objectName: "mapConn" + conn.dir

  /// The edit info AND the strip geometry, both from the SAVE's live connection (connectionEditList
  /// now carries `stripX/Y/W/H` + `hasStrip`, computed from the save's map + offset via the macro).
  /// ⚠️ NOT connectionList() / connStripFor — that walks the map's *shipped* DB connections, so an
  /// ADDED connection had no strip and nothing to grab (the "weird broken state"). Bound to
  /// `canvas.revision` so it updates in place when the offset changes.
  readonly property var edge:  { conn.canvas.revision; return conn.canvas.connEdgeFor(conn.dir); }

  readonly property bool present: conn.edge !== null && conn.edge.exists === true
                                  && conn.edge.hasStrip === true

  readonly property bool horizontal: conn.dir === 0 || conn.dir === 1   // N / S slide along X; E / W along Y
  readonly property bool selected: conn.canvas.selectedConnection === conn.dir

  signal editRequested()

  visible: present && brg.mapLayers.showConnections

  // Geometry straight from the model, in buffer px * zoom -- QML does no arithmetic of its own.
  x: present ? conn.edge.stripX * conn.canvas.zoom : 0
  y: present ? conn.edge.stripY * conn.canvas.zoom : 0
  width: present ? conn.edge.stripW * conn.canvas.zoom : 0
  height: present ? conn.edge.stripH * conn.canvas.zoom : 0

  z: conn.dragging ? 30 : (conn.selected ? 25 : 2)

  // ── Drag state ────────────────────────────────────────────────────────────────────────────
  property bool dragging: false
  property real pressPos: 0        // where along the axis the press landed (item px)
  property int  baseOffset: 0      // the offset when the drag began
  property string snapName: ""     // the landmark we are currently magnetised to, "" for none

  readonly property real blockPx: 32 * conn.canvas.zoom

  /// The last whole-block step this drag committed. The rounding is HYSTERETIC around it, so a few
  /// pixels of pointer jitter can never push the offset back and forth. @see the note below.
  property int  lastStep: 0

  /// Snap @p off to the nearest landmark; sets snapName. Returns the (possibly snapped) offset,
  /// clamped to the legal range.
  ///
  /// ⚠️ THE GRAB RADIUS AND THE RELEASE RADIUS ARE DIFFERENT ON PURPOSE (2026-08-19). A magnet that
  /// lets go at exactly the distance it grabs at CHATTERS: sit one block from a landmark and the
  /// smallest movement snaps in, un-snaps, snaps in again. That is half of project leadership's
  /// *"the handle drags now occasionally an extra step still making it somewhat unusable"* — the
  /// "extra step" is the magnet pulling you a block you didn't ask for and then dropping you.
  /// Grab within 1 block; hold until you are clearly 2 blocks away.
  function withSnap(off) {
    const lo = conn.edge.offsetMin, hi = conn.edge.offsetMax;
    off = Math.max(lo, Math.min(hi, off));

    const snaps = conn.edge.snaps || [];

    // Already magnetised? Stay until we have properly left.
    if (conn.snapName !== "") {
      for (let h = 0; h < snaps.length; h++)
        if (snaps[h].name === conn.snapName && Math.abs(off - snaps[h].offset) <= 2)
          return snaps[h].offset;
    }

    conn.snapName = "";
    for (let i = 0; i < snaps.length; i++) {
      if (Math.abs(off - snaps[i].offset) <= 1) {
        conn.snapName = snaps[i].name;
        return snaps[i].offset;
      }
    }
    return off;
  }

  // ── The outline ──────────────────────────────────────────────────────────────────────────
  //
  // No fill (project leadership, 2026-07-13): an outline shows you the strip, a wash hides the map under it. The
  // ring's own vermillion (#d55e00, Okabe-Ito) when idle; the selection purple when picked.
  Rectangle {
    anchors.fill: parent
    color: "transparent"
    border.width: Math.max(2, Math.round(conn.canvas.zoom))
    border.color: conn.selected ? "#cc79a7" : "#d55e00"
    opacity: conn.dragging ? 0.8 : 1.0

    // A dashed inner edge when the connection has been RAW-edited (desynced): the offset no longer
    // describes it, so the slider/handle can't, and we say so quietly rather than lie.
    Rectangle {
      visible: conn.present && conn.edge.synced === false
      anchors.fill: parent
      anchors.margins: 3
      color: "transparent"
      border.width: 1
      border.color: "#ffd54f"
    }
  }

  // The grab handle -- a small disc in the middle of the strip, so there is an obvious thing to slide.
  //
  // ⚠️ WHOLE-PIXEL PLACEMENT, NOT `anchors.centerIn` (project leadership, 2026-08-19: *"the anchor
  // drag icon is offcenter slightly looks further below"*). The strip's height is
  // `blocks × 32 × zoom`, so at most zooms it is FRACTIONAL — 67.2 px at 0.7 — and centring an
  // 18 px disc in it puts the disc at 24.6, which the renderer resolves downward and softens with
  // antialiasing. Small, but it reads as "not quite centred", and it is worse at some zooms than
  // others, which is why it looks like a mistake rather than a rounding artefact. Rounding both the
  // position and the size to whole pixels makes it land the same way at every zoom.
  Rectangle {
    visible: conn.canvas.zoom >= 0.6
    width: 18; height: 18; radius: 9
    x: Math.round((conn.width  - width)  / 2)
    y: Math.round((conn.height - height) / 2)
    color: drag.containsMouse || conn.dragging ? "#d55e00" : "#e6212121"
    border.width: 1
    border.color: "#ffffff"

    Text {
      anchors.centerIn: parent
      // ⚠️ The arrow glyphs carry more descent than cap-height, so a box-centred one sits visibly
      // low inside an 18 px disc. One pixel up puts the STROKE on the centre line, which is what
      // the eye actually measures.
      anchors.verticalCenterOffset: -1
      text: conn.horizontal ? "↔" : "↕"
      font.pixelSize: 12
      color: "white"
    }
  }

  // The selection ring, above everything, like the door's.
  Rectangle {
    visible: conn.selected
    z: 20
    anchors.fill: parent
    anchors.margins: -2
    color: "transparent"
    border.width: 2
    border.color: "#cc79a7"
  }

  // ── The label ──────────────────────────────────────────────────────────────────────────────
  //
  // Which neighbour, which way, and -- while dragging -- the live offset and the landmark it has
  // snapped to. Shown on the selected one, on hover, and during a drag.
  Rectangle {
    visible: conn.present && (conn.selected || drag.containsMouse || conn.dragging)
    z: 40
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.top
    anchors.bottomMargin: conn.selected ? 30 : 4

    width: lbl.implicitWidth + 12
    height: lbl.implicitHeight + 6
    radius: 3
    color: "#e6212121"

    Text {
      id: lbl
      anchors.centerIn: parent
      text: {
        if (!conn.present) return "";
        let s = conn.edge.dirName + " · " + conn.edge.toName;
        if (conn.dragging || conn.selected)
          s += "  (offset " + conn.edge.offset
             + (conn.snapName !== "" ? " · " + conn.snapName : "") + ")";
        return s;
      }
      font.pixelSize: 11
      color: "white"
    }
  }

  // ── The delete button ────────────────────────────────────────────────────────────────────
  //
  // Above the strip, never over it (the door's rule). Removing a connection clears one flag bit.
  Rectangle {
    visible: conn.selected && !conn.dragging
    z: 45
    anchors.bottom: parent.top
    anchors.bottomMargin: 3
    anchors.horizontalCenter: parent.horizontalCenter
    width: 20; height: 20; radius: 10
    color: delArea.containsMouse ? "#d55e00" : "#212121"
    border.width: 1
    border.color: "#ffffff"

    Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 11; color: "white" }

    MouseArea {
      id: delArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: (m) => {
        m.accepted = true;
        brg.map.removeConnection(conn.dir);
        conn.canvas.selectedConnection = -1;
        conn.canvas.status = qsTr("Connection removed from the %1 edge.").arg(conn.edge.dirName);
      }
    }
  }

  // ── Input ────────────────────────────────────────────────────────────────────────────────
  MouseArea {
    id: drag
    anchors.fill: parent
    enabled: conn.present && !conn.canvas.panning && conn.canvas.tool !== "zoom" && !conn.canvas.placing
    hoverEnabled: true
    cursorShape: conn.dragging ? (conn.horizontal ? Qt.SizeHorCursor : Qt.SizeVerCursor)
                               : Qt.PointingHandCursor
    preventStealing: true

    property bool moved: false

    // ⭐ TELL THE CANVAS WE ARE UNDER THE POINTER (project leadership, 2026-08-19: *"the connection
    // icon on the map firstly shows map block squares underneath being highlighted as you try to
    // click the anchor drag icon"* … *"map blocks arent supposed to highlight at all on connections.
    // Thats only for the main map and its out of bounds area."*).
    //
    // `canvas.hoverConnection` already existed and the cell highlight already consulted it — but
    // **nothing ever set it**. It was added for the ADD arrows and the strip was never wired, so the
    // white block outline kept lighting up under the very handle you were reaching for. A declared
    // signal with no sender is worse than none: everything downstream looks correct and does nothing.
    onContainsMouseChanged: conn.canvas.hoverConnection = containsMouse
    Component.onDestruction: conn.canvas.hoverConnection = false

    // ⚠️ MEASURE IN A FRAME THAT DOES NOT MOVE (fixed 2026-08-19). project leadership:
    // *"connections move around super glitchy and choppy, clicking and dragging just jerks it all
    // over the place its almost impossible to use without manually working with the numbers in
    // details."* — and that is a feedback loop, not a smoothness problem.
    //
    // `m.x`/`m.y` are LOCAL to this MouseArea, which fills `conn` — and `conn.x/y` are the strip's
    // own position, so **the item slides out from under the cursor the moment the offset changes**.
    // Drag right: offset goes up, the item moves right, the pointer's LOCAL x therefore goes DOWN,
    // the computed delta shrinks, the offset is written back smaller, the item moves left... every
    // frame, in both directions. The jerking IS the oscillation.
    //
    // So the press point and every sample are taken in the PARENT's space, which is fixed while the
    // strip moves inside it. `blockPx` is already zoom-scaled, so the arithmetic is unchanged.
    // MapSprite has always done this (`mapToItem(ghost.parent, …)`); this one was the odd file out.
    function axisIn(m) {
      const p = drag.mapToItem(conn.parent, m.x, m.y);
      return conn.horizontal ? p.x : p.y;
    }

    onPressed: (m) => {
      conn.canvas.selectedConnection = conn.dir;
      conn.baseOffset = conn.edge.offset;
      conn.pressPos = drag.axisIn(m);
      conn.lastStep = 0;
      conn.snapName = "";
      drag.moved = false;
      m.accepted = true;
    }

    onPositionChanged: (m) => {
      if (!drag.pressed) return;

      const cur = drag.axisIn(m);
      const dpx = cur - conn.pressPos;
      if (!drag.moved && Math.abs(dpx) < 4) return;
      drag.moved = true;

      // Slide along the edge -> a whole-block change in offset. A desynced connection can't be driven
      // by the offset knob (its bytes no longer match it), so a drag first re-syncs it to its own
      // recovered offset and then moves from there.
      //
      // ⚠️ HYSTERESIS, NOT `Math.round` (2026-08-19). Plain rounding flips at exactly half a block,
      // so a pointer resting near that boundary — which is where it spends a lot of its time, since
      // you stop moving when you are nearly there — steps back and forth on a pixel of jitter. That
      // is the other half of *"the handle drags now occasionally an extra step"*. You have to travel
      // 60% of a block past the CURRENT step to advance, and the step never falls back on noise.
      const raw = dpx / conn.blockPx;
      if (raw > conn.lastStep + 0.6)
        conn.lastStep = Math.floor(raw + 0.4);
      else if (raw < conn.lastStep - 0.6)
        conn.lastStep = Math.ceil(raw - 0.4);

      const want = conn.withSnap(conn.baseOffset + conn.lastStep);

      if (want !== conn.edge.offset)
        brg.map.setConnectionOffset(conn.dir, want);
      conn.dragging = true;
    }

    onReleased: () => {
      if (!drag.moved) {
        conn.editRequested();   // a plain click opens the Details panel on this connection
        return;
      }
      conn.dragging = false;
      conn.snapName = "";
      drag.moved = false;
    }

    onCanceled: { conn.dragging = false; conn.snapName = ""; drag.moved = false; }
  }

  // Esc mid-drag: put the offset back where it began, write nothing further.
  Connections {
    target: conn.canvas
    function onCancelDragChanged() {
      if (conn.dragging) {
        brg.map.setConnectionOffset(conn.dir, conn.baseOffset);
        conn.dragging = false;
        conn.snapName = "";
      }
    }
  }
}
