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
 * ONE selectable, draggable SIGN on the map -- a placard.
 *
 * The door's quieter sibling, built on exactly the MapWarp / MapSprite machinery: a MouseArea (never
 * PointerHandlers), the same tile-snap-from-the-cursor drag, the same drag-off-to-delete, the same
 * ✎/✕ buttons above the thing rather than over it.
 *
 * A sign has no artwork of its own — the game draws it as whatever tile it sits on — so this is a
 * **chip**: a marked tile in the Signs layer's orange, carrying ▤ and its index, and showing the
 * one thing about a sign you cannot see by looking at the map: **what it says**. That is resolved
 * from this map's text table. See notes/reference/signs.md.
 */
import QtQuick
import QtQuick.Controls

Item {
  id: sign

  /// The canvas, for the zoom and the selection.
  required property var canvas

  /// Which sign this is -- its index in the save's sign list (0..15).
  required property int ind

  /// Map tile coords.
  required property int tileX
  required property int tileY

  /// The sign's real words, one line ("PALLET TOWN / Shades of your…"), or "(scripted text)".
  required property string preview

  /// The sign's real words with the game's own line breaks and nothing elided — what the plate
  /// shows. @see MapModel::signTextFull
  required property string previewFull

  /// ⭐ THE GAME'S OWN TEXT EXPANDER — `FontsDB::expandStr`, the same one the name editors use.
  ///
  /// Project leadership, 2026-08-18: *"Tooltips dont render names, `<PLAYER>`'s house should read as
  /// character name's house"* … then, when a hand-rolled substitution went in: *"Use pokedex friendly
  /// function to properly convert the sign text as it also converts some symbols over to utf-8."*
  ///
  /// ⚠️ AND THE HAND-ROLLED VERSION WAS WRONG, not merely duplicated. The text imported from
  /// `pret/pokered` keeps the engine's control codes verbatim (43 `<PLAYER>`s and 23 `<RIVAL>`s
  /// across `maps.json`) because the DB stores what the ROM stores — but names are only ONE kind of
  /// token in there. The game's character set is not ASCII: `<m>`/`<f>` are the gender symbols, and
  /// the font carries an accented **é** and a pile of other glyphs a regex over two names never
  /// touches. A private `.replace()` fixed the two tokens somebody had noticed and silently left
  /// every other one on screen as literal angle brackets.
  ///
  /// `expandStr` is the project's one text codec: it walks the string through the real font table,
  /// honours the dialog control codes, and substitutes the rival and player names from THIS save —
  /// so renaming your trainer renames the signs, and every symbol arrives as proper UTF-8.
  /// ⚠️ TWO VOCABULARIES MEET HERE, and they spell the same two tokens differently.
  ///
  /// `maps.json`'s sign text is imported from `pret/pokered`, which writes the name tokens in CAPS
  /// (`<PLAYER>`, `<RIVAL>` — 43 and 23 of them). `FontsDB`'s codec knows them by the app's own
  /// lowercase names (`<player>` = code 0x52, `<rival>` = 0x53). Hand `expandStr` the capitalised
  /// form and it does not recognise it at all: it falls through to plain letters and the sign reads
  /// the literal word **"RIVAL's house"** — which is precisely what the first cut of this did.
  ///
  /// Those two are the ONLY capitalised tokens in the file (checked, not assumed), so the adapter is
  /// exactly two substitutions and it lives HERE, at the boundary — not in the codec, which the name
  /// editors depend on, and not in the data, which must keep saying what pret says.
  readonly property var pretTokens: [[/<PLAYER>/g, "<player>"], [/<RIVAL>/g, "<rival>"]]

  /// ⚠️ THE CODEC IS RUN PER LINE, and the line breaks never enter it.
  ///
  /// Project leadership, 2026-08-18: *"Sign text needs to somehow display newlines instead of one big
  /// run on."* `expandStr` walks the string through the game's own font table, and a `\n` is not a
  /// character in that table — the game breaks lines with its own control codes — so every newline
  /// went in and did not come out, and a two-line placard arrived as one long sentence.
  ///
  /// Splitting first keeps the structure in OUR hands and hands the codec only what it understands:
  /// each line is expanded on its own, then the real breaks are put back. It also means a control
  /// code that ends a line (`<page>`, `<cont>`) truncates that line rather than the whole sign.
  function withNames(s) {
    if (s === "")
      return s;

    const rival  = brg.file.data.dataExpanded.rival.name;
    const player = brg.file.data.dataExpanded.player.basics.playerName;

    const lines = s.split("\n");
    for (let n = 0; n < lines.length; n++) {
      let t = lines[n];
      for (let i = 0; i < sign.pretTokens.length; i++)
        t = t.replace(sign.pretTokens[i][0], sign.pretTokens[i][1]);
      lines[n] = brg.fonts.expandStr(t, 255, rival, player);
    }

    return lines.join("\n");
  }

  /// False when the text id points past this map's text table -- the game would read whatever text
  /// comes next in the cartridge. Shown, never refused.
  required property bool textValid

  signal editRequested()

  // ── Drag state ────────────────────────────────────────────────────────────────────────────
  property int dragX: -1
  property int dragY: -1

  /// Being dragged by its TAB (the canvas proxy-drag). @see MapCanvas.proxyKind
  readonly property bool proxied: sign.canvas.proxyKind === "sign"
                                  && sign.canvas.proxyInd === sign.ind
                                  && sign.canvas.proxyX >= 0

  readonly property bool dragging: sign.dragX >= 0 || sign.proxied

  readonly property int liveX: sign.proxied ? sign.canvas.proxyX
                             : sign.dragX >= 0 ? sign.dragX : sign.tileX
  readonly property int liveY: sign.proxied ? sign.canvas.proxyY
                             : sign.dragX >= 0 ? sign.dragY : sign.tileY

  readonly property bool selected: sign.canvas.selectedSign === sign.ind

  /// True while the cursor is over the delete zone mid-drag. @see MapCanvas.overDeleteZone
  property bool overBin: false

  // A sign sits ON its tile -- no 4-pixel lift (that is an OAM fact about sprites).
  x: (sign.canvas.mapBorderPx + sign.liveX * 16) * sign.canvas.zoom
  y: (sign.canvas.mapBorderPx + sign.liveY * 16) * sign.canvas.zoom
  width: 16 * sign.canvas.zoom
  height: 16 * sign.canvas.zoom

  // ⚠️ HOVER LIFTS THE WHOLE SIGN, not just its plate. The hovered-block highlight is drawn at
  // CANVAS level with `z: 2`, and a child cannot out-stack its parent's siblings — so with the sign
  // sitting at the baseline `z: 1`, that white 2px outline painted straight over the words
  // (leadership, 2026-08-18: *"the current block white highlight paints on top of tooltip"*).
  // Selecting already lifted it to 25, which is why the bug only showed on hover.
  z: sign.dragging ? 30 : (sign.selected ? 25 : (area.containsMouse ? 20 : 1))

  // (Object stacking was removed 2026-07-15; a sign always draws, overlapping or not.)

  // ── The chip ─────────────────────────────────────────────────────────────────────────────
  //
  // The Signs layer's own orange (#e69f00, Okabe-Ito) -- the same ink the Layers panel paints its
  // swatch with, so the row IS the legend and the two can never drift apart.
  readonly property color layerInk: sign.textValid ? brg.map.ink("signs") : brg.map.ink("invalid")
  Rectangle {
    id: chip
    anchors.fill: parent

    color: "transparent"   // NO FILL -- the line carries the language (leadership, 2026-07-18)
    border.width: Math.max(2, Math.round(1.5 * sign.canvas.zoom))
    border.color: area.containsMouse && !sign.selected ? "#ffffff" : sign.layerInk
    opacity: sign.dragging ? 0.65 : 1.0

    // (No centre glyph. The ▤ was dropped -- leadership, 2026-07-18: *"remove the square dot/icon
    //  from the middle of sign boxes just have the outline"*. The outline's ink says "sign" -- the
    //  Layers panel is the legend -- and the tile art underneath stays readable.)
  }

  // 🔫 The id points past this map's text. The game reads whatever text comes next. Drawn, editable,
  // and FLAGGED -- exactly like an out-of-set sprite or a door that points nowhere.
  Text {
    visible: !sign.textValid && sign.canvas.zoom >= 1
    anchors.centerIn: parent
    text: "!"
    font.bold: true
    font.pixelSize: Math.max(9, Math.round(10 * sign.canvas.zoom))
    color: "#d55e00"
  }

  // A selection you can lose under a layer is not a selection: it draws above everything.
  Rectangle {
    visible: sign.selected
    z: 20
    anchors.fill: parent
    anchors.margins: -2
    color: "transparent"
    border.width: 2
    border.color: "#ffffff"

    Rectangle {
      anchors.fill: parent
      anchors.margins: 2
      color: "transparent"
      border.width: 1
      border.color: "#cc212121"
    }
  }

  // ── What it says, on the chip ────────────────────────────────────────────────────────────
  //
  // The one fact about a sign you cannot get by looking at the map. Shown on the selected one and on
  // hover -- not on all of them at once.
  // ⚠️ OPAQUE, AND IT WRAPS. Project leadership, 2026-08-18: *"fix the sign tooltip, the grid lines
  // cut through it and it has no multiple line support, can you clean this up and fix it."* Both
  // faults, and both were in these few lines:
  //
  //   * the plate was `#e6212121` — 90% alpha — so the block grid, the tile grid and whatever sprite
  //     sat behind it all showed straight through the words. A label you read THROUGH is not a label.
  //     It is opaque now, with a hairline border so it still separates from a dark map;
  //   * the `Text` had no `width` and no `wrapMode`, so a sign's words were one unbroken line that
  //     grew as wide as the sentence and ran off the canvas. It now wraps at a real column and gives
  //     the plate a proper multi-line height — which is the whole point, since sign text is prose.
  //
  // Sign text is also two-part in the game ("PALLET TOWN / Shades of your journey await!"), so the
  // wrap is not a nicety: the second half was simply unreadable before.
  Rectangle {
    id: plate
    visible: (sign.selected || area.containsMouse) && !sign.dragging
    z: 40

    /// How wide the words may run before they wrap. A placard, not a paragraph.
    readonly property int maxTextWidth: 190

    anchors.bottom: parent.top
    // Clear the ✎/✕ row properly (the buttons are 20px tall on a 3px margin). 32px is a real gap.
    anchors.bottomMargin: sign.selected ? 32 : 4
    anchors.horizontalCenter: parent.horizontalCenter

    width: label.width + 14
    height: label.height + 8
    radius: 3

    // Fully opaque — nothing behind it may read through. @see the note above.
    color: "#212121"
    border.width: 1
    border.color: "#4d000000"

    Text {
      id: label
      anchors.centerIn: parent

      // Wrap at the column, but never pad a short label out to it: a one-word sign gets a small
      // plate, a long one gets a wrapped block.
      width: Math.min(implicitWidth, plate.maxTextWidth)
      wrapMode: Text.Wrap
      horizontalAlignment: Text.AlignHCenter
      lineHeight: 1.15

      text: sign.textValid
            ? (sign.previewFull !== "" ? sign.withNames(sign.previewFull) : qsTr("(no text)"))
            : qsTr("id points past this map's text")
      font.pixelSize: 11
      color: sign.textValid ? "white" : "#ffb74d"
    }
  }

  // ── The delete button ────────────────────────────────────────────────────────────────────
  //
  // ABOVE the sign, never over it. No ✎ any more -- a plain CLICK opens the Details panel (see
  // onReleased), so an edit button would just be a second way to do what a click already does.
  Row {
    visible: sign.selected && !sign.dragging
    z: 45
    anchors.bottom: parent.top
    anchors.bottomMargin: 3
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: 3

    Rectangle {
      width: 20; height: 20; radius: 10
      color: delArea.containsMouse ? "#d55e00" : "#212121"
      border.width: 1
      border.color: "#ffffff"

      Text {
        anchors.centerIn: parent
        text: "✕"
        font.pixelSize: 11
        color: "white"
      }

      MouseArea {
        id: delArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: (m) => {
          m.accepted = true;
          brg.map.removeSign(sign.ind);
          sign.canvas.selectedSign = -1;
          sign.canvas.status = qsTr("Sign removed. The signs after it slid up a slot.");
        }
      }
    }
  }

  // ── The ghost ────────────────────────────────────────────────────────────────────────────
  Rectangle {
    id: ghost

    parent: sign.Window.window ? sign.Window.window.contentItem : sign
    visible: sign.dragging && sign.overBin
    z: 9999

    width: 26
    height: 26
    radius: 3
    color: "#cce69f00"
    border.width: 1
    border.color: "#e69f00"

    Text {
      anchors.centerIn: parent
      text: "▤"
      font.pixelSize: 13
      color: "#212121"
    }
  }

  // ── Input ────────────────────────────────────────────────────────────────────────────────
  MouseArea {
    id: area
    anchors.fill: parent

    enabled: !sign.canvas.panning && sign.canvas.tool !== "zoom" && !sign.canvas.placing
    hoverEnabled: true
    cursorShape: sign.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

    // A movable thing under the pointer: the cell hands its highlight over and the tabs
    // withdraw -- the same contract the sprites and doors keep. @see MapCanvas.hoverMovable
    onContainsMouseChanged: {
      const key = Math.floor((sign.canvas.mapBorderPx + sign.liveX * 16) / 32) + ","
                + Math.floor((sign.canvas.mapBorderPx + sign.liveY * 16) / 32);
      if (area.containsMouse) {
        sign.canvas.hoverMovable = key;
        sign.canvas.hoverMovableFullCell = false;
      } else if (sign.canvas.hoverMovable === key) {
        sign.canvas.hoverMovable = "";
      }
    }

    preventStealing: true

    property point press
    property bool moved: false

    onPressed: (m) => {
      area.press = Qt.point(m.x, m.y);
      area.moved = false;

      // One selection, one Details panel.
      sign.canvas.selectedSign = sign.ind;
      sign.canvas.selectedNpc = -1;
      sign.canvas.selectedWarp = -1;
      m.accepted = true;
    }

    onPositionChanged: (m) => {
      if (!area.pressed)
        return;

      if (!area.moved
          && Math.abs(m.x - area.press.x) < 4 && Math.abs(m.y - area.press.y) < 4)
        return;

      area.moved = true;

      const g = sign.mapToGlobal(m.x, m.y);
      sign.overBin = sign.canvas.overDeleteZone(g.x, g.y);
      sign.canvas.deleteHover = sign.overBin;

      if (sign.overBin) {
        const w = sign.mapToItem(ghost.parent, m.x, m.y);
        ghost.x = w.x - ghost.width / 2;
        ghost.y = w.y - ghost.height / 2;

        sign.dragX = sign.tileX;
        sign.dragY = sign.tileY;
        return;
      }

      // ⚠️ TILE-SNAPPED FROM THE CURSOR, not from an accumulated delta -- same fix as MapWarp/MapSprite.
      const p = sign.canvas.tileAtGlobal(g.x, g.y);

      sign.dragX = Math.max(0, Math.min(brg.map.blocksWide * 2 - 1, p.x));
      sign.dragY = Math.max(0, Math.min(brg.map.blocksHigh * 2 - 1, p.y));
    }

    onReleased: (m) => {
      if (!sign.dragging && !area.moved) {
        // A plain CLICK opens the Details panel on this sign; a drag does not.
        sign.editRequested();
        return;
      }

      const nx = sign.dragX;
      const ny = sign.dragY;
      const bin = sign.overBin;

      sign.dragX = -1;
      sign.dragY = -1;
      sign.overBin = false;
      sign.canvas.deleteHover = false;
      area.moved = false;

      if (bin) {
        brg.map.removeSign(sign.ind);
        sign.canvas.selectedSign = -1;
        sign.canvas.status = qsTr("Sign removed. The signs after it slid up a slot.");
        return;
      }

      if (nx < 0 || (nx === sign.tileX && ny === sign.tileY))
        return;   // put back where it started: write nothing

      // Exactly two bytes. tst_signs byte-diffs the whole save across this and demands it.
      brg.map.moveSign(sign.ind, nx, ny);
    }

    onCanceled: {
      sign.dragX = -1;
      sign.dragY = -1;
      sign.overBin = false;
      area.moved = false;
    }
  }

  // Esc, mid-drag: put it back, write NOTHING.
  Connections {
    target: sign.canvas
    function onCancelDragChanged() {
      sign.dragX = -1;
      sign.dragY = -1;
    }
  }
}
