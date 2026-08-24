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
 * The DETAILS panel -- it edits whatever is selected, and it is never blank.
 *
 * With **nothing selected** it shows the MAP's own details. With a **sprite selected** it shows
 * every byte that sprite has, grouped and explained, each one editable across its **full range** --
 * hack and glitch values included, flagged in words, never refused and never quietly corrected.
 *
 * Right now sprites are the only selectable thing on the map (the ground is deliberately not
 * clickable); warps, signs and connections join them later, on the same machinery.
 *
 * ⚠️ **REBUILT 2026-07-13.** The first cut was a list of raw byte boxes under headings called Who,
 * Where and When, and project leadership took it apart -- rightly. What changed, and why, is written up in
 * MapModel::npcFields (the schema) and SpriteField.qml (the controls). The short version:
 *
 *   * every field declares a **kind**, and the kind picks the control -- a picture is a grid of
 *     ARTWORK, an X/Y pair is ONE control, a countdown is drawn as a countdown;
 *   * the raw number box appears **only when the combo cannot say the value**;
 *   * the "Talking to it" group **changes shape with the sprite**: the item picker exists for an
 *     item ball and the trainer roster for a trainer, because the save's own bits say which it is;
 *   * a byte the console recomputes on load wears a yellow **!**;
 *   * the panel's paragraph is a **?** in the title bar, and the ✕ is a **Delete** button that says
 *     Delete.
 *
 * @see notes/plans/map-screen.md -> Phase 4d
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
  id: details
  objectName: "mapDetails"   // the DEBUG harness reads the two diag properties below

  /// The map canvas, so we know what is selected. Handed over by MapDock (a Loader's content
  /// cannot see the ids around it), so it is briefly null before that happens.
  property var canvas: null

  /// Harness-visible: how many field rows the panel THINKS it has, and for whom. A panel that is
  /// empty when it shouldn't be is otherwise very hard to tell apart from one that is correct.
  readonly property int diagFieldCount: (details.fields || []).length
  readonly property int diagSlot: details.slot

  /// Harness-visible: scroll the panel to a pixel offset, and report how far it can go.
  ///
  /// ⚠️ THIS EXISTS BECAUSE THE GENERIC SCROLL COULD NOT REACH IT. `app_scroll` walks the tree for a
  /// Flickable, and a `ScrollView`'s scrollable is its *contentItem*, not the ScrollView -- so the
  /// walk kept finding some other Flickable, reported a plausible contentY, and moved nothing. That
  /// is a silent failure: the numbers come back fine and the panel does not budge, which is exactly
  /// how a screenshot review ends up looking at the wrong thing. @see notes/reference/dev-harness.md
  function diagScrollTo(y) {
    if (scroller.contentItem === null)
      return -1;
    const maxY = Math.max(0, scroller.contentItem.contentHeight - scroller.availableHeight);
    scroller.contentItem.contentY = Math.max(0, Math.min(maxY, y));
    return scroller.contentItem.contentY;
  }

  readonly property real diagScrollMax: (scroller.contentItem === null) ? 0
      : Math.max(0, scroller.contentItem.contentHeight - scroller.availableHeight)

  readonly property int slot: canvas ? canvas.selectedNpc : -1
  readonly property bool hasSprite: slot > 0

  /// The selected DOOR, or -1. One selection at a time -- the canvas enforces it, so `hasDoor` and
  /// `hasSprite` can never both be true.
  readonly property int door: canvas ? canvas.selectedWarp : -1
  readonly property bool hasDoor: door >= 0

  readonly property var doorData: {
    details.revision;
    return details.hasDoor ? brg.map.warpAt(details.door) : ({});
  }

  readonly property var doorFields: {
    details.revision;
    return details.hasDoor ? brg.map.warpFields(details.door) : [];
  }

  /// The selected SIGN, or -1. One selection at a time -- the canvas enforces it, so `hasSign` can
  /// never be true alongside `hasDoor` or `hasSprite`.
  readonly property int sign: canvas ? canvas.selectedSign : -1
  readonly property bool hasSign: sign >= 0

  readonly property var signData: {
    details.revision;
    return details.hasSign ? brg.map.signAt(details.sign) : ({});
  }

  readonly property var signFieldsData: {
    details.revision;
    return details.hasSign ? brg.map.signFields(details.sign) : [];
  }

  /// The selected edge CONNECTION's direction (0-3), or -1. One selection at a time, canvas-enforced.
  readonly property int connection: canvas ? canvas.selectedConnection : -1
  readonly property bool hasConnection: connection >= 0

  readonly property var connEdge: {
    details.revision;
    if (!details.hasConnection) return ({});
    const l = brg.map.connectionEditList();
    for (let i = 0; i < l.length; i++)
      if (l[i].dir === details.connection) return l[i];
    return ({});
  }

  readonly property var connFieldsData: {
    details.revision;
    return details.hasConnection ? brg.map.connectionFields(details.connection) : [];
  }

  /// Which connections the person has put on MANUAL CONTROL, by direction. A connection not in here
  /// is on auto: its raw fields follow the offset and stay read-only.
  ///
  /// ⭐ NOTHING BUT THEM MAY TURN IT OFF (project leadership, 2026-08-19: *"Never auto turn off
  /// manual sync i moved the number down and it suddenly greyed out and switched to sync."*).
  ///
  /// Two things did that, and both are gone:
  ///
  ///   * it was a single `bool` reset by `onConnectionChanged` — and `connection` reads through
  ///     `canvas.selectedConnection`, so anything that so much as re-touched the selection while you
  ///     were typing dropped you back to auto. Per-direction state means selecting away and back
  ///     keeps your choice, and nothing else can clear it.
  ///   * the switch was `enabled: connSynced`, so the FIRST raw edit — which by definition desyncs
  ///     the connection — greyed the switch out. It looked exactly like the app had changed its
  ///     mind for you, which is what they described.
  ///
  /// Manual is a state you chose. It ends when you say so.
  property var connManualDirs: ({})

  readonly property bool connBreakSync: details.hasConnection
                                        && details.connManualDirs[details.connection] === true

  function setConnManual(on) {
    if (!details.hasConnection)
      return;
    // A new object, not a mutation — QML only re-evaluates a var binding when the reference changes.
    let next = {};
    for (let k in details.connManualDirs)
      next[k] = details.connManualDirs[k];
    next[details.connection] = on;
    details.connManualDirs = next;

    // The canvas shows the resize grips off this, so the panel's choice and the map agree. Two
    // copies of one state, and the panel is the owner — @see MapCanvas.connManual.
    if (details.canvas)
      details.canvas.connManual = next;
  }

  readonly property bool connRawEditable: details.connBreakSync
                                        || (details.hasConnection && details.connEdge.synced === false)

  /// The selected SCRIPT TRIGGER's storage-spot index, or -1. One selection at a time (canvas-
  /// enforced), so it can never be true alongside a sprite / door / sign / connection.
  readonly property int scriptSpot: canvas ? canvas.selectedScript : -1
  readonly property bool hasScript: scriptSpot >= 0

  readonly property var scriptData: {
    details.revision;
    return details.hasScript ? brg.map.scriptSpotAt(details.scriptSpot) : ({});
  }

  // ── The BLOCK inspector — every spot on a clicked block, editable inline ──────────────────────
  //
  // Clicking a block on the map selects it; this panel then lists everything filed there (the same
  // spots the canvas tabs draw, uncapped) and lets you change the simple ones — event flags, filter
  // flags, hidden pickups — right here, with an "open"/"edit" for the ones that have their own
  // editor. Project leadership, 2026-07-19. @see MapCanvas.selectedBlockSpots
  readonly property bool hasBlock: canvas ? canvas.hasSelectedBlock : false
  readonly property var blockSpots: {
    details.revision; details.worldTick;
    return details.hasBlock && canvas ? canvas.selectedBlockSpots : [];
  }

  // The world's flag stores, reached the same way the World panel reaches them. `worldTick` re-reads
  // a toggle's live value after WE flip it (external edits refresh on the next revision bump).
  property int worldTick: 0
  readonly property var worldEvents: (brg.file && brg.file.data && brg.file.data.dataExpanded
                                      && brg.file.data.dataExpanded.world)
                                     ? brg.file.data.dataExpanded.world.events : null
  readonly property var worldMissables: (brg.file && brg.file.data && brg.file.data.dataExpanded
                                         && brg.file.data.dataExpanded.world)
                                        ? brg.file.data.dataExpanded.world.missables : null
  readonly property var worldHidden: (brg.file && brg.file.data && brg.file.data.dataExpanded
                                      && brg.file.data.dataExpanded.world)
                                     ? brg.file.data.dataExpanded.world.hidden : null

  /// A small two-state chip for the block inspector's inline flag edits — tap to flip.
  component FlagChip: Rectangle {
    id: chip
    property bool on: false
    property string onText: "ON"
    property string offText: "OFF"
    property color onColor: "#33a866"
    signal toggled()

    implicitWidth: chipText.implicitWidth + 16
    implicitHeight: 20
    radius: 4
    color: chip.on ? chip.onColor : "#9aa0a6"

    Text {
      id: chipText
      anchors.centerIn: parent
      text: chip.on ? chip.onText : chip.offText
      font.pixelSize: 9
      font.bold: true
      color: "#ffffff"
    }

    HoverHandler { cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: chip.toggled() }
  }

  // ── The block inspector's layer grouping (project leadership, 2026-07-19) ───────────────────────────────
  //
  // Spots are grouped by their LAYER, in layer order; ENABLED layers show, HIDDEN layers tuck behind
  // a "more" link. Each spot's layer + on-state comes from brg.mapLayers (the Layers panel's truth).

  function spotLayerOn(s) {
    switch (s.kind) {
      case "player":     return brg.mapLayers.showPlayer;
      case "sprite":     return brg.mapLayers.showNpcs;
      case "warp":       return brg.mapLayers.showWarps;
      case "sign":       return brg.mapLayers.showSigns;
      case "filterFlag": return brg.mapLayers.showFlagBoxes;
      case "eventFlag":  return brg.mapLayers.showEventFlags;
      case "script":
      case "cardKeyDoor":return brg.mapLayers.showScripts;
      case "hiddenItem":
      case "hiddenCoin": return brg.mapLayers.showHiddenPickups;
      case "tileTrait":  return (brg.map.layers & s.ind) !== 0;
    }
    return true;
  }

  function spotLayerName(s) {
    switch (s.kind) {
      case "player":     return qsTr("Player");
      case "sprite":     return qsTr("People");
      case "warp":       return qsTr("Warps");
      case "sign":       return qsTr("Signs");
      case "filterFlag": return qsTr("Filter flags");
      case "eventFlag":  return qsTr("Event flags");
      case "script":
      case "cardKeyDoor":return qsTr("Scripts");
      case "hiddenItem":
      case "hiddenCoin": return qsTr("Hidden pickups");
      case "tileTrait":  return s.section === "wild" ? qsTr("Wild Pokémon") : qsTr("Tiles");
    }
    return qsTr("Other");
  }

  // The Layers panel's order (Objects, then the Meaning family, then Tiles).
  function spotLayerOrder(s) {
    const order = { "player": 0, "sprite": 1, "warp": 2, "sign": 3,
                    "filterFlag": 4, "eventFlag": 5, "script": 6, "cardKeyDoor": 6,
                    "hiddenItem": 7, "hiddenCoin": 7, "tileTrait": 8 };
    return order[s.kind] !== undefined ? order[s.kind] : 9;
  }

  /// The selected block's spots, grouped by layer name, each group carrying its on-state + order.
  readonly property var blockGroups: {
    details.worldTick;
    const spots = details.blockSpots || [];
    const by = {};
    for (let i = 0; i < spots.length; i++) {
      const s = spots[i];
      const name = details.spotLayerName(s);
      if (by[name] === undefined)
        by[name] = { name: name, on: details.spotLayerOn(s), order: details.spotLayerOrder(s), spots: [] };
      by[name].spots.push(s);
    }
    const arr = [];
    for (const k in by)
      arr.push(by[k]);
    arr.sort((a, b) => a.order - b.order);
    return arr;
  }
  readonly property var blockGroupsShown: (details.blockGroups || []).filter(g => g.on);
  readonly property var blockGroupsHidden: (details.blockGroups || []).filter(g => !g.on);
  readonly property int blockHiddenCount: {
    let n = 0;
    const g = details.blockGroupsHidden || [];
    for (let i = 0; i < g.length; i++) n += g[i].spots.length;
    return n;
  }

  /// Whether the hidden-layer groups are expanded (the "more" link). Reset per block.
  property bool blockShowHidden: false
  onHasBlockChanged: details.blockShowHidden = false

  /// One row of the block inspector — a spot with its inline flag chip / Open button.
  component BlockSpotRow: RowLayout {
    id: bsr
    property var spot: ({})
    Layout.fillWidth: true
    Layout.topMargin: 1
    spacing: 6

    Rectangle {
      Layout.preferredWidth: 9
      Layout.preferredHeight: 9
      radius: 4.5
      color: bsr.spot.ink !== undefined ? bsr.spot.ink : brg.settings.dividerColor
    }

    Label {
      Layout.fillWidth: true
      text: bsr.spot.name !== undefined ? bsr.spot.name : qsTr("(spot)")
      font.pixelSize: 11
      color: brg.settings.textColorDark
      wrapMode: Text.Wrap
    }

    FlagChip {
      visible: bsr.spot.kind === "eventFlag" && details.worldEvents !== null
      on: { details.worldTick; return details.worldEvents ? details.worldEvents.eventsAt(bsr.spot.ind) : false }
      onText: qsTr("ON"); offText: qsTr("OFF")
      onToggled: {
        if (!details.worldEvents) return;
        details.worldEvents.eventsSet(bsr.spot.ind, !details.worldEvents.eventsAt(bsr.spot.ind));
        details.worldTick++;
      }
    }

    FlagChip {
      visible: bsr.spot.kind === "filterFlag" && details.worldMissables !== null
      on: { details.worldTick; return details.worldMissables ? !details.worldMissables.missablesAt(bsr.spot.ind) : false }
      onText: qsTr("SHOWN"); offText: qsTr("HIDDEN"); onColor: "#0072b2"
      // ⚠️ `setMissableShown`, NOT `missablesSet` — the bit alone leaves the sprite slot's picture
      // id at 0 and the object never comes back. @see MapModel::setMissableShown
      onToggled: {
        if (!details.worldMissables) return;
        brg.map.setMissableShown(bsr.spot.ind, details.worldMissables.missablesAt(bsr.spot.ind));
        details.worldTick++;
      }
    }

    FlagChip {
      visible: bsr.spot.kind === "hiddenItem" && details.worldHidden !== null
      on: { details.worldTick; return details.worldHidden ? details.worldHidden.hItemsAt(bsr.spot.ind) : false }
      onText: qsTr("GOT"); offText: qsTr("THERE"); onColor: "#9aa0a6"
      onToggled: {
        if (!details.worldHidden) return;
        details.worldHidden.hItemsSet(bsr.spot.ind, !details.worldHidden.hItemsAt(bsr.spot.ind));
        details.worldTick++;
      }
    }

    FlagChip {
      visible: bsr.spot.kind === "hiddenCoin" && details.worldHidden !== null
      on: { details.worldTick; return details.worldHidden ? details.worldHidden.hCoinsAt(bsr.spot.ind) : false }
      onText: qsTr("GOT"); offText: qsTr("THERE"); onColor: "#9aa0a6"
      onToggled: {
        if (!details.worldHidden) return;
        details.worldHidden.hCoinsSet(bsr.spot.ind, !details.worldHidden.hCoinsAt(bsr.spot.ind));
        details.worldTick++;
      }
    }

    Button {
      visible: bsr.spot.kind === "sprite" || bsr.spot.kind === "player"
               || bsr.spot.kind === "warp" || bsr.spot.kind === "sign"
               || bsr.spot.kind === "script" || bsr.spot.kind === "cardKeyDoor"
      flat: true
      font.pixelSize: 10
      text: qsTr("Open")
      onClicked: {
        if (!details.canvas) return;
        if (bsr.spot.kind === "script" || bsr.spot.kind === "cardKeyDoor")
          details.canvas.selectedScript = bsr.spot.ind;
        else
          details.canvas.selectSpot(bsr.spot.kind, bsr.spot.ind);
      }
    }

    Label {
      visible: bsr.spot.kind === "tileTrait"
      text: bsr.spot.section === "wild" ? qsTr("wild") : qsTr("tile")
      font.pixelSize: 9
      opacity: 0.5
    }
  }

  // (The map's warp STATE lives in its own right-dock panel -- @see WarpStatePanel.qml.)

  /// The player is slot 0. He is selectable and draggable like anybody else (project leadership, 2026-07-13),
  /// but he has no NPC record -- his bytes live in the save's player block, not the sprite table --
  /// so he gets his own short list rather than an empty one.
  readonly property bool hasPlayer: slot === 0

  /// The panel's "?". MapDock puts it in the title bar; it is the one tooltip icon this panel gets.
  readonly property string panelInfo: qsTr(
    "Everything the save holds about whoever is selected — and it is genuinely everything, including "
    + "the values no real game would ever write. Nothing here is refused and nothing is quietly "
    + "corrected.\n\n"
    + "A yellow ! means the game works that value out again when it loads your save: real bytes, "
    + "yours to set, but they won't survive Continue.\n\n"
    + "Nothing selected? Then this is the map itself.")

  // ⚠️ BINDINGS, not an imperative refresh().
  //
  // The first version called a refresh() from `onSlotChanged` + `Component.onCompleted`, and it
  // silently never ran: the panel is created by a Loader with `canvas` still null (so slot is -1),
  // and MapDock hands the canvas over in `onLoaded` -- AFTER completion. The panel came up
  // permanently blank while every C++ test passed, because the C++ was fine and the QML never
  // asked it anything. Bind it and the question gets asked whenever the answer could have changed.
  //
  // `revision` is what makes an EDIT re-ask: the model's own values change under us, and a binding
  // on npcAt(slot) alone would not know that.
  property int revision: 0

  Connections {
    target: brg.map
    function onChanged() { details.revision++; }

    // A door moving / being re-aimed does NOT emit changed() (that would re-render the whole map
    // image). It gets its own signal, and the panel has to listen to it or it goes stale mid-drag.
    function onWarpsChanged() { details.revision++; }

    // Signs, same story -- their own signal, or the panel goes stale mid-drag.
    function onSignsChanged() { details.revision++; }
  }

  readonly property var sprite: {
    details.revision;   // a dependency, deliberately
    return details.hasSprite ? brg.map.npcAt(details.slot) : ({});
  }

  readonly property var fields: {
    details.revision;
    return details.hasSprite ? brg.map.npcFields(details.slot) : [];
  }

  // ⚠️ These strings must match MapModel::npcFields' group names EXACTLY -- they are what the rows
  // are filtered by. (Was Who / Where / When, which project leadership called "really really dumb", and she is
  // right: they told you nothing about what was under them.)
  readonly property var groupOrder: ["Character", "Where", "Movement", "Talking to it",
                                     "Right now", "The drawing"]

  // The PLAYER's 26-byte map-state block (@see MapModel::playerFields). Bound on `revision` so an
  // edit re-asks -- the same reason the sprite fields are. The durable groups show always; the ten
  // the game rewrites on load and the three it never reads are in the last group, filtered out by
  // the model unless the toolbar's "Useless edits" toggle (the "!") is on.
  readonly property var playerFields: {
    details.revision;
    return details.hasPlayer ? brg.map.playerFields() : [];
  }

  // ⚠️ Must match MapModel::playerFields' group names EXACTLY.
  readonly property var playerGroupOrder: ["Facing & movement", "Fine position",
                                           "What they can do here", "Battle", "Standing on",
                                           "Rewritten on load, or never read"]

  ScrollView {
    id: scroller
    objectName: "detailsScroller"   // the DEBUG harness scrolls the panel by this
    anchors.fill: parent
    clip: true
    contentWidth: availableWidth          // never scroll sideways; the rows wrap instead
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

    // ⚠️ RESERVE THE SCROLLBAR'S LANE -- 16px. The bar is an overlay, so full-width content ends up
    // underneath it. Here that put the yellow "!" icons (right-anchored on each field's label row)
    // behind the scrollbar. See ui-patterns.md; it is a recurring gotcha and this is the fix.
    ColumnLayout {
      objectName: "detailsContent"   // the DEBUG harness full-length-shots the panel via this
      width: scroller.availableWidth - 22
      spacing: 8

      // ── Nothing selected: the MAP's own details ───────────────────────────────────────────
      //
      // The panel is never blank. Editing "what this map is" has one home, and this is it.
      ColumnLayout {
        Layout.fillWidth: true
        Layout.margins: 10
        spacing: 6
        visible: !details.hasSprite && !details.hasPlayer && !details.hasDoor && !details.hasSign
                 && !details.hasConnection && !details.hasScript && !details.hasBlock

        Label {
          text: brg.map.mapName
          font.bold: true
          font.pixelSize: 15
          Layout.fillWidth: true
          elide: Text.ElideRight
        }

        Label {
          Layout.fillWidth: true
          text: qsTr("Nothing selected — click somebody, a warp or a sign to edit them.")
          wrapMode: Text.Wrap
          opacity: 0.6
          font.pixelSize: 11
        }

        MapDetailRow { label: qsTr("Map id");     value: String(brg.map.mapInd) }
        MapDetailRow { label: qsTr("Size");       value: qsTr("%1 × %2 blocks").arg(brg.map.blocksWide).arg(brg.map.blocksHigh) }
        MapDetailRow { label: qsTr("Tileset");    value: brg.map.tilesetName }
        MapDetailRow { label: qsTr("Palette");    value: brg.map.contrastName }
        MapDetailRow { label: qsTr("Player at");  value: qsTr("%1, %2").arg(brg.map.playerX).arg(brg.map.playerY) }
        MapDetailRow { label: qsTr("People");     value: qsTr("%1 of 15").arg(15 - brg.map.npcRoomLeft()) }
        MapDetailRow { label: qsTr("Warps");      value: qsTr("%1 of 32").arg(32 - brg.map.warpRoomLeft()) }
        MapDetailRow { label: qsTr("Signs");      value: qsTr("%1 of 16").arg(16 - brg.map.signRoomLeft()) }

        // ⚠️ THE 3-STEP WILD-ENCOUNTER COOLDOWN HAS MOVED to the top of the Wild Pokémon panel
        // (project leadership, 2026-08-18: *"Wild pokemon, the 3 step option needs to be there
        // instead of details"*). It is an ENCOUNTER control, and it belongs with the encounter
        // tables — it only sat here because this page was where the briefed odds and ends landed.
        // @see WildPokemonPanel.qml · notes/reference/wild-encounter-cooldown.md

        // ══ MAP STATE — v1's "Map" page (the AreaMap leftover bytes) ═══════════════════════════
        //
        // ⚠️ notes/reference/area-map-state.md. Two durable levers (script step + run-on-load, always
        // on bike), one derived value kept in sync by default (the camera), and two reset-on-load
        // scratch fields behind the "Useless edits" toggle. Every value full-range, hack included.
        // ⚠️ A GATED-EMPTY SECTION TAKES ITS HEADING AND ITS DIVIDER WITH IT (§11b, at section
        // scale). Everything under "This map, right now" is now behind a gate — the live step and
        // its override behind Tinkerer, the reset-on-load scratch behind "!" — so with both shut
        // this would otherwise be a title, a rule, and nothing at all.
        Rectangle {
          Layout.fillWidth: true
          Layout.topMargin: 6
          height: 1
          color: brg.settings.dividerColor
          visible: areaState.hasAnything
        }

        ColumnLayout {
          id: areaState
          Layout.fillWidth: true
          Layout.topMargin: 4
          spacing: 6

          property bool rawScript: false   // the script "Something else…" disclosure

          /// Is there a single row to show? The OR of the gates its own contents sit behind.
          readonly property bool hasAnything: brg.map.showTinkerer || brg.map.showScratch

          Label {
            text: qsTr("This map, right now")
            font.bold: true
            font.pixelSize: 12
            Layout.fillWidth: true
            visible: areaState.hasAnything
          }

          // ⚠️ THE PROGRESSION STATE PICKER IS NOT HERE. It lives in World / Persistent Storage.
          //
          // Project leadership, 2026-08-18: *"Map state should not be in map details, but current
          // step only belongs in map details with reference to the World/Persistent Storage."*
          //
          // The split is the persistence rule they set earlier the same day: a **progression stage**
          // is a whole save block -- event flags, this map's filter flags, badges, and the map's
          // STORED script byte -- all of which survive a map change and a reload, so it is persistent
          // storage and belongs on that page. What is left here is the one byte that is genuinely
          // about the map you are standing on right now.
          //
          // Two controls named "Current state step" in two panels reading two DIFFERENT bytes is what
          // sent them looking in the first place ("the world says pallet town is daisy current step
          // but the map details panel says default"), so the two are now named apart and each says
          // which byte it is.
          //
          // ══ THE LIVE STEP + ITS OVERRIDE — ONE GROUP, BEHIND THE TINKERER GATE ═══════════════
          //
          // ⭐ CONSOLE-VERIFIED BEFORE BUILDING (project leadership, 2026-08-19: *"If you are 100%
          // sure and confident that the use_cur_map_script is the only way to use curMapScript and
          // your 100% sure otherwise that even if the user sets that value it would be overwritten
          // on load if useCurMapScript is still not set … Make sure this is correct before doing
          // it."*). It is correct, and the cartridge said so — `scripts/emu/probe_cur_map_script.py`,
          // Route 12, two mirror-image runs:
          //
          //   override CLEAR → we wrote live 0x00 / stored 0x03 and read live **0x03**
          //                    (the stored byte overwrote the live one; editing it keeps NOTHING)
          //   override SET   → we wrote live 0x00 / stored 0x03 and read stored **0x00**
          //                    (the live byte won, and propagated INTO the stored byte)
          //
          // The mechanism is `ExecuteCurMapScriptInTable` (home/trainers.asm): every scripted map's
          // wrapper hands it the map's STORED byte, and it uses that unless BIT_USE_CUR_MAP_SCRIPT
          // is set — a one-shot bit `res`'d the instant it is read, and set in exactly ONE place in
          // the whole game (TalkToTrainer, mid trainer-engagement).
          //
          // So these two are ONE value with the game's own switch between them, and a save resting
          // on a desync is a state the console erases on the first tick. That is why they live
          // together, here (not in World, which holds the durable per-map byte), behind **Tinkerer**
          // — real, honoured, and unnatural to rest in. @see plans/map-screen.md §11b.
          ColumnLayout {
            id: liveStep
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 6

            // The whole group rides ONE gate — no row inside it carries a second one (§11b).
            visible: brg.map.showTinkerer

            Label {
              Layout.fillWidth: true
              text: qsTr("The step running right now")
              font.pixelSize: 11
              font.bold: true
              color: brg.settings.textColorMid
            }

            Label {
              Layout.fillWidth: true
              wrapMode: Text.Wrap
              font.pixelSize: 10
              opacity: 0.6
              text: qsTr("The map keeps its own progress in World; this is the working copy the game "
                         + "makes of it while you stand here. Normally the game copies the World "
                         + "value over this one the moment the map runs, so changing it on its own "
                         + "changes nothing — unless you also turn on the switch below, which makes "
                         + "the game use this value once and write it back to World.")
            }
          }

          // (No second heading here — the group above already says what this is. It used to read
          //  "Current state step — the loaded map's live byte", which was a byte-name apology for
          //  two controls that looked identical; naming the group properly retires it.)

          // Descriptive picker when this map has named steps…
          //
          // ⚠️ AND A PLAIN NUMBER BOX WHEN IT DOESN'T, which is what leadership saw and read as a
          // removal (*"why did you remove the selection picker originally there for the map state
          // step"* … *"maybe the current map state doesn't always have options is why i saw a map
          // without it"* — exactly right). Only 97 maps have a script at all; the rest have no named
          // steps to offer, so the control degrades to the raw byte rather than showing an empty
          // dropdown. @see mapHasScriptList.
          ComboBox {
            id: curScriptCombo
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            font.pixelSize: 12
            visible: liveStep.visible && brg.map.mapHasScriptList && !areaState.rawScript
            model: { details.revision; return brg.map.mapScriptList(); }
            textRole: "name"
            valueRole: "value"
            currentIndex: {
              details.revision;
              const l = model;
              for (let i = 0; i < l.length; i++)
                if (l[i].value === brg.map.mapScript) return i;
              return -1;
            }
            onActivated: brg.map.mapScript = currentValue

            delegate: ItemDelegate {
              required property var modelData
              width: parent ? parent.width : 0
              contentItem: RowLayout {
                spacing: 6
                Text {
                  Layout.fillWidth: true
                  text: modelData.name
                  font.pixelSize: 12
                  color: brg.settings.textColorDark
                  elide: Text.ElideRight
                }
                Text {
                  visible: modelData.hack === true
                  text: qsTr("raw")
                  font.pixelSize: 9
                  color: "#d55e00"
                }
              }
            }
          }

          // What the selected step MEANS -- the progression description (same words as the
          // Map Storage panel's per-map script dropdown; from maps.json scriptEntries desc).
          Label {
            Layout.fillWidth: true
            visible: curScriptCombo.visible && text !== ""
            wrapMode: Text.Wrap
            font.pixelSize: 10
            opacity: 0.55
            text: {
              details.revision;
              const l = brg.map.mapScriptList();
              for (let i = 0; i < l.length; i++)
                if (l[i].value === brg.map.mapScript)
                  return l[i].desc !== undefined ? l[i].desc : "";
              return "";
            }
          }

          // …a raw index otherwise, or behind "Something else…".
          RowLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: liveStep.visible && (!brg.map.mapHasScriptList || areaState.rawScript)
            Label { text: qsTr("Step"); font.pixelSize: 10; opacity: 0.6 }
            SpinBox {
              Layout.fillWidth: true
              Layout.preferredHeight: 28
              font.pixelSize: 11
              editable: true
              from: 0
              to: 255
              value: brg.map.mapScript
              onValueModified: brg.map.mapScript = value
            }
          }

          // The "Something else…" link only when there IS a named list to step out of.
          Label {
            visible: liveStep.visible && brg.map.mapHasScriptList
            text: areaState.rawScript ? qsTr("Pick from the list") : qsTr("Something else…")
            font.pixelSize: 10
            color: brg.settings.accentColor
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: areaState.rawScript = !areaState.rawScript
            }
          }

          // ⭐ THE SWITCH THAT MAKES THE STEP ABOVE MEAN ANYTHING. Same group, same gate — it is
          // half of one idea, not a neighbouring setting. (BIT_USE_CUR_MAP_SCRIPT.)
          RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: liveStep.visible
            Label {
              Layout.fillWidth: true
              text: qsTr("Use this step instead, once")
              font.pixelSize: 12
              wrapMode: Text.Wrap
            }
            MapSwitch {
              checked: brg.map.runScriptOnLoad
              onToggled: brg.map.runScriptOnLoad = !brg.map.runScriptOnLoad
            }
          }
          // ⚠️ NO "Open World" BUTTON. It was added on 2026-08-18 and struck out the same day —
          // *"The open world button on the map details panel needs to be removed i dont like it."*
          //
          // Worth keeping the reason: a button that only navigates somewhere else is not editing
          // anything, and this panel is for editing. The rail already has a World button one click
          // away, permanently, in a fixed place. One short line of context is enough.
          // ONE closing line for the pair. The old two ("The stage that sets this lives in World." +
          // a second paragraph about the switch) said the same thing twice and split one idea across
          // two footnotes; the group's own blurb carries it now.
          Label {
            Layout.fillWidth: true
            Layout.topMargin: 2
            visible: liveStep.visible
            text: qsTr("Checked on the console: with the switch off the game replaces this with "
                       + "World's value the moment the map runs; with it on, this value is used "
                       + "once and becomes World's value.")
            wrapMode: Text.Wrap
            font.pixelSize: 10
            opacity: 0.55
          }

          // ⚠️ "ALWAYS ON BIKE" AND THE CAMERA HAVE MOVED TO THE PLAYER.
          //
          // Project leadership, 2026-08-18: *"Move Camera — follows the player to player details.
          // Always on bike also in character details."* Both are about the person, not the place: one
          // is what he is riding, the other is where the screen sits relative to him. They only ever
          // lived here because this group was the drawer everything map-shaped fell into. @see the
          // Player section further down this file.

          // ── Reset-on-load scratch, behind the "Useless edits" toggle ────────────────────────
          ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 6
            spacing: 4
            visible: brg.map.showScratch

            Rectangle {
              Layout.fillWidth: true
              radius: 6
              color: Qt.rgba(0, 0, 0, 0.03)
              border.width: 1
              border.color: brg.settings.dividerColor
              implicitHeight: asHdr.implicitHeight + 14
              RowLayout {
                id: asHdr
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6
                MapWarnIcon {
                  text: qsTr("The game works this value out again — or clears it — the moment it loads "
                             + "your save. Verified on a real cartridge.")
                }
                Label {
                  Layout.fillWidth: true
                  text: qsTr("Rewritten on load — the game resets these every time")
                  wrapMode: Text.Wrap
                  font.pixelSize: 10
                  opacity: 0.7
                }
              }
            }

            // Screen VRAM pointer → $9800
            RowLayout {
              Layout.fillWidth: true
              spacing: 6
              Label { Layout.preferredWidth: 110; text: qsTr("Screen VRAM ptr"); font.pixelSize: 10; opacity: 0.7; elide: Text.ElideRight }
              SpinBox {
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                font.pixelSize: 10
                editable: true
                from: 0
                to: 65535
                value: brg.map.vramViewPtr
                onValueModified: brg.map.vramViewPtr = value
              }
            }
            Label { Layout.fillWidth: true; text: qsTr("Reset to $9800 on load."); font.pixelSize: 9; opacity: 0.5 }

            // Card-Key door X / Y → 0
            RowLayout {
              Layout.fillWidth: true
              spacing: 6
              Label { Layout.preferredWidth: 110; text: qsTr("Card-Key door X"); font.pixelSize: 10; opacity: 0.7; elide: Text.ElideRight }
              SpinBox {
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                font.pixelSize: 10
                editable: true
                from: 0
                to: 255
                value: brg.map.cardKeyDoorX
                onValueModified: brg.map.cardKeyDoorX = value
              }
            }
            RowLayout {
              Layout.fillWidth: true
              spacing: 6
              Label { Layout.preferredWidth: 110; text: qsTr("Card-Key door Y"); font.pixelSize: 10; opacity: 0.7; elide: Text.ElideRight }
              SpinBox {
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                font.pixelSize: 10
                editable: true
                from: 0
                to: 255
                value: brg.map.cardKeyDoorY
                onValueModified: brg.map.cardKeyDoorY = value
              }
            }
            Label { Layout.fillWidth: true; text: qsTr("Zeroed on load (Silph Co. door scratch)."); font.pixelSize: 9; opacity: 0.5 }
          }

          // ⚠️ NO "three more bytes are hidden, turn on the ! to see them" notice here, and none
          // anywhere else either (project leadership, 2026-08-18: *"Dont show small text telling
          // theres more useless options — leave that to when the user clicks the useless options and
          // discovers it themselves."*). Advertising what is hidden is the clutter the gate exists to
          // remove: it costs a paragraph on every panel to tell you about values that, by definition,
          // do nothing. The "!" in the toolbar is the discovery path.
        }

        // The view pointer the GAME itself computed and left in the save. If an edit has made it
        // stale we say so plainly and offer the one-click fix -- we never quietly rewrite it.
        Rectangle {
          Layout.fillWidth: true
          Layout.topMargin: 6
          visible: !brg.map.headerMatches
          radius: 6
          color: Qt.rgba(1, 0.84, 0.31, 0.15)
          border.width: 1
          border.color: "#ffd54f"
          implicitHeight: fixCol.implicitHeight + 16

          ColumnLayout {
            id: fixCol
            anchors.fill: parent
            anchors.margins: 8
            spacing: 6

            Label {
              Layout.fillWidth: true
              text: qsTr("This map's header no longer matches what the game would compute.")
              wrapMode: Text.Wrap
              font.pixelSize: 11
            }

            Button {
              text: qsTr("Fix it")
              onClicked: brg.map.fixMapHeader()
            }
          }
        }

        // (⇄ WARP STATE used to be appended here, at the bottom of the map's own details. It is now
        //  its OWN PANEL, in the RIGHT dock -- which is where project leadership asked for it (2026-07-14: "I
        //  will place them in the right panel as warp state") and which is simply better: down here
        //  it sat below the fold, behind a scroll past six rows of map facts. The right dock is
        //  where the things you edit ABOUT THE MAP live; the Details panel is for what is SELECTED.
        //  @see WarpStatePanel.qml)
      }

      // ══ ▦ A BLOCK SELECTED — the block inspector ═══════════════════════════════════════════
      //
      // Everything filed on the clicked block, in one list, editable inline where it is a simple
      // value (project leadership, 2026-07-19: *"clicking a block automatically brings up all the details …
      // instead of taking you to event flags why not offer to still take you there but change it
      // directly there"*). Flags flip right here; objects and scripts get an Edit/Open that selects
      // them into their own editor above.
      ColumnLayout {
        Layout.fillWidth: true
        Layout.margins: 10
        spacing: 8
        visible: details.hasBlock

        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          Rectangle {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            radius: 4
            color: "transparent"
            border.width: 2
            border.color: brg.settings.dividerColor
            Text { anchors.centerIn: parent; text: "▦"; font.pixelSize: 15; color: brg.settings.textColorMid }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Label {
              Layout.fillWidth: true
              text: qsTr("Block")
              font.bold: true
              font.pixelSize: 14
              elide: Text.ElideRight
            }
            Label {
              Layout.fillWidth: true
              text: (details.canvas && details.canvas.selectedBlockMapX >= 0
                     && details.canvas.selectedBlockMapY >= 0)
                    ? qsTr("at %1, %2").arg(details.canvas.selectedBlockMapX).arg(details.canvas.selectedBlockMapY)
                    : qsTr("in the border ring")
              font.pixelSize: 10
              opacity: 0.6
            }
          }
        }

        Label {
          Layout.fillWidth: true
          visible: (details.blockSpots || []).length === 0
          text: qsTr("Nothing is filed on this block.")
          wrapMode: Text.Wrap
          font.pixelSize: 11
          color: brg.settings.textColorMid
        }

        Label {
          Layout.fillWidth: true
          visible: (details.blockGroupsShown || []).length > 0
          text: qsTr("Flip a flag right here, or open the rest in its own editor.")
          wrapMode: Text.Wrap
          font.pixelSize: 10
          opacity: 0.55
        }

        // ── The ENABLED-layer groups, in layer order ───────────────────────────────────────
        Repeater {
          model: details.blockGroupsShown

          delegate: ColumnLayout {
            required property var modelData
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 2

            Label {
              text: modelData.name
              font.pixelSize: 11
              font.bold: true
              opacity: 0.55
              Layout.fillWidth: true
            }

            Repeater {
              model: modelData.spots
              delegate: BlockSpotRow {
                required property var modelData
                Layout.fillWidth: true
                spot: modelData
              }
            }
          }
        }

        // ── The HIDDEN-layer groups, behind a "more" link ──────────────────────────────────
        Label {
          Layout.fillWidth: true
          Layout.topMargin: 6
          visible: details.blockHiddenCount > 0
          text: details.blockShowHidden
                ? qsTr("Hide layers that are off")
                : qsTr("%n more on hidden layers…", "", details.blockHiddenCount)
          font.pixelSize: 10
          color: brg.settings.accentColor
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: details.blockShowHidden = !details.blockShowHidden
          }
        }

        Repeater {
          model: details.blockShowHidden ? details.blockGroupsHidden : []

          delegate: ColumnLayout {
            required property var modelData
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 2

            RowLayout {
              Layout.fillWidth: true
              spacing: 5
              Label {
                text: modelData.name
                font.pixelSize: 11
                font.bold: true
                opacity: 0.45
              }
              // A quiet marker that this layer is currently OFF on the map.
              Label {
                text: qsTr("· layer off")
                font.pixelSize: 9
                font.italic: true
                opacity: 0.4
              }
              Item { Layout.fillWidth: true }
            }

            Repeater {
              model: modelData.spots
              delegate: BlockSpotRow {
                required property var modelData
                Layout.fillWidth: true
                spot: modelData
                opacity: 0.85
              }
            }
          }
        }
      }

      // ══ ⇄ A DOOR SELECTED ══════════════════════════════════════════════════════════════════
      //
      // ⚠️ **An edited door is genuinely LIVE.** `LoadMainData` sets BIT_NO_PREVIOUS_MAP on the saved
      // tileset byte, so the next `LoadMapHeader` bails out before it rebuilds the warp list from
      // ROM. Verified on the cartridge -- including a 4th door invented in a 3-door town.
      //
      // And the game puts the map's original doors back the moment the player leaves and walks in
      // again. That is the cartridge's behaviour, not our gap, and the panel SAYS it -- once the user
      // has actually made an edit it applies to. (Same rule as the cast: we track the EDIT, never a
      // diff against the ROM.) See notes/reference/warps.md §1.
      ColumnLayout {
        Layout.fillWidth: true
        Layout.margins: 10
        spacing: 8
        visible: details.hasDoor

        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          Rectangle {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            radius: 4
            color: "#66f0e442"
            border.width: 1
            border.color: "#f0e442"

            Text {
              anchors.centerIn: parent
              text: "⇄"
              font.pixelSize: 15
              color: "#212121"
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Label {
              Layout.fillWidth: true
              text: qsTr("Warp %1").arg(details.door)
              font.bold: true
              font.pixelSize: 14
              elide: Text.ElideRight
            }

            Label {
              Layout.fillWidth: true
              text: details.doorData.destName || ""
              font.pixelSize: 10
              opacity: 0.6
              elide: Text.ElideRight
            }
          }
        }

        // Where it goes, resolved — the one thing about a door that matters, said in full.
        Label {
          Layout.fillWidth: true
          visible: (details.doorData.destLabel || "") !== ""
          text: details.doorData.destLabel || ""
          wrapMode: Text.Wrap
          font.pixelSize: 11
          color: brg.settings.textColorMid
        }

        // 🔫 It points at an arrival point the target map does not have. The console would copy four
        // arbitrary ROM bytes into the view pointer and the player's coordinates. Shown, explained,
        // never refused.
        Rectangle {
          Layout.fillWidth: true
          visible: details.hasDoor && !details.doorData.destValid
          radius: 6
          color: Qt.rgba(0.84, 0.37, 0, 0.12)
          border.width: 1
          border.color: "#d55e00"
          implicitHeight: badDest.implicitHeight + 14

          Label {
            id: badDest
            anchors.fill: parent
            anchors.margins: 7
            wrapMode: Text.Wrap
            font.pixelSize: 10
            text: qsTr("This warp leads to arrival point %1 of %2 — but that map only has %3.\n\n"
                       + "The game doesn't check. It will read whatever cartridge bytes happen to "
                       + "come after the list and drop the player somewhere undefined.")
                  .arg(details.doorData.destWarp || 0)
                  .arg(details.doorData.destName || "")
                  .arg(details.doorData.arrivalCount || 0)
          }
        }

        Button {
          Layout.fillWidth: true
          Layout.topMargin: 2
          Layout.preferredHeight: 28
          font.pixelSize: 11

          text: qsTr("Delete this warp")

          contentItem: Label {
            text: parent.text
            font: parent.font
            color: parent.hovered ? "#ffffff" : "#d55e00"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }

          background: Rectangle {
            radius: 4
            color: parent.hovered ? "#d55e00" : "transparent"
            border.width: 1
            border.color: "#d55e00"

            Behavior on color { ColorAnimation { duration: 90 } }
          }

          onClicked: {
            brg.map.removeWarp(details.door);
            if (details.canvas)
              details.canvas.selectedWarp = -1;
          }
        }

        Repeater {
          model: details.doorFields

          delegate: WarpField {
            required property var modelData
            Layout.fillWidth: true

            fieldData: modelData
            ind: details.door
          }
        }

        // ⚠️ NO "THESE WARPS ARE LIVE" NOTICE. Removed 2026-08-19 — project leadership: *"remove
        // these connections are live whole block, please its dumb to announce messages talking
        // about this is live this isnt live, you scatter these in different places and its silly
        // and takes up space."* It was one of three identical panels (warps, signs, connections)
        // and the standing rule now is: **do not announce liveness anywhere.** An editor's edits
        // being real is the assumption, not news; the restore-on-re-entry behaviour belongs in
        // notes/reference/warps.md, where somebody who wants it is already looking.
      }

      // ══ ▤ A SIGN SELECTED ══════════════════════════════════════════════════════════════════
      //
      // ⚠️ **An edited sign is genuinely LIVE**, on the same linchpin as a door (`.loadSignData` sits
      // inside `LoadMapHeader`, behind BIT_NO_PREVIOUS_MAP). The game puts the map's original signs
      // back the moment the player leaves and walks in again -- said in words below, once the user has
      // actually made an edit. See notes/reference/signs.md.
      ColumnLayout {
        Layout.fillWidth: true
        Layout.margins: 10
        spacing: 8
        visible: details.hasSign

        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          Rectangle {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            radius: 4
            color: "#66e69f00"
            border.width: 1
            border.color: "#e69f00"

            Text {
              anchors.centerIn: parent
              text: "▤"
              font.pixelSize: 15
              color: "#212121"
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Label {
              Layout.fillWidth: true
              text: qsTr("Sign %1").arg(details.sign)
              font.bold: true
              font.pixelSize: 14
              elide: Text.ElideRight
            }

            Label {
              Layout.fillWidth: true
              text: qsTr("at %1, %2").arg(details.signData.x || 0).arg(details.signData.y || 0)
              font.pixelSize: 10
              opacity: 0.6
              elide: Text.ElideRight
            }
          }
        }

        // What it says, resolved — the whole point of a sign, shown in full (several lines allowed).
        Label {
          Layout.fillWidth: true
          visible: (details.signData.preview || "") !== "" && (details.signData.textValid === true)
          text: qsTr("“%1”").arg(details.signData.preview || "")
          wrapMode: Text.Wrap
          font.pixelSize: 11
          color: brg.settings.textColorMid
        }

        // 🔫 The text id points past this map's text table. The game reads whatever comes next.
        // Shown, explained, never refused.
        Rectangle {
          Layout.fillWidth: true
          visible: details.hasSign && (details.signData.textValid === false)
          radius: 6
          color: Qt.rgba(0.84, 0.37, 0, 0.12)
          border.width: 1
          border.color: "#d55e00"
          implicitHeight: badText.implicitHeight + 14

          Label {
            id: badText
            anchors.fill: parent
            anchors.margins: 7
            wrapMode: Text.Wrap
            font.pixelSize: 10
            text: qsTr("This sign's text id isn't one this map has — the game will read whatever text "
                       + "comes next in the cartridge.\n\nIt's still yours to set: pick from the map's "
                       + "text below, or keep the raw id.")
          }
        }

        Button {
          Layout.fillWidth: true
          Layout.topMargin: 2
          Layout.preferredHeight: 28
          font.pixelSize: 11

          text: qsTr("Delete this sign")

          contentItem: Label {
            text: parent.text
            font: parent.font
            color: parent.hovered ? "#ffffff" : "#d55e00"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }

          background: Rectangle {
            radius: 4
            color: parent.hovered ? "#d55e00" : "transparent"
            border.width: 1
            border.color: "#d55e00"

            Behavior on color { ColorAnimation { duration: 90 } }
          }

          onClicked: {
            brg.map.removeSign(details.sign);
            if (details.canvas)
              details.canvas.selectedSign = -1;
          }
        }

        Repeater {
          model: details.signFieldsData

          delegate: SignField {
            required property var modelData
            Layout.fillWidth: true

            fieldData: modelData
            ind: details.sign
          }
        }

        // ⚠️ NO LIVENESS NOTICE — see the warps section for the ruling (2026-08-19).
      }

      // ══ 🔗 A CONNECTION SELECTED ═══════════════════════════════════════════════════════════
      //
      // A connection is neighbour + one signed OFFSET; the other nine bytes are macro-derived. So the
      // top of the panel is those two real inputs, and the raw nine live below, read-only while synced
      // and unlocked by the break-sync switch (the power path). See notes/reference/map-connections.md.
      ColumnLayout {
        Layout.fillWidth: true
        Layout.margins: 10
        spacing: 8
        visible: details.hasConnection

        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          Rectangle {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            radius: 4
            color: "#66d55e00"
            border.width: 1
            border.color: "#d55e00"
            Text { anchors.centerIn: parent; text: "🔗"; font.pixelSize: 14 }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Label {
              Layout.fillWidth: true
              text: qsTr("%1 connection").arg(details.connEdge.dirName || "")
              font.bold: true
              font.pixelSize: 14
              elide: Text.ElideRight
            }
            Label {
              Layout.fillWidth: true
              text: (details.connEdge.synced === false)
                    ? qsTr("Raw-edited — the offset no longer describes it")
                    : qsTr("to %1 · offset %2").arg(details.connEdge.toName || "").arg(details.connEdge.offset || 0)
              font.pixelSize: 10
              opacity: 0.6
              elide: Text.ElideRight
            }
          }
        }

        // ── Neighbour ──────────────────────────────────────────────────────────────────────
        //
        // ⭐ THE SHARED MAP SELECTOR (project leadership, 2026-08-19: *"the neighbour map id should
        // use the shared MapSelectList"* — the arrow's ADD picker already did; this editor was the
        // last bespoke map list on the screen). So it gains sort, search and the same grouped rows
        // as every other map list in the app, instead of a one-off ComboBox with its own delegate.
        //
        // What the bespoke list did better is kept, not lost: the map the cartridge really connects
        // to this edge rides at the top as a `leadingEntries` row, because no sort can know that.
        Label { text: qsTr("Connects to"); font.pixelSize: 11; color: brg.settings.textColorMid }
        MapField {
          Layout.fillWidth: true
          Layout.preferredHeight: 30

          value: details.connEdge.toMap !== undefined ? details.connEdge.toMap : 0

          leadingEntries: {
            details.revision;
            if (!details.hasConnection) return [];
            const l = brg.map.connectionMapList(details.connection);
            for (let i = 0; i < l.length; i++)
              if (l[i].isDefault === true)
                return [{ ind: l[i].value, name: l[i].name, group: l[i].group, size: l[i].size }];
            return [];
          }

          onPicked: (ind) => brg.map.setConnectionMap(details.connection, ind)
        }

        // ── Offset (the one real knob) ───────────────────────────────────────────────────────
        RowLayout {
          Layout.fillWidth: true
          spacing: 6
          Label { text: qsTr("Offset"); font.pixelSize: 11; color: brg.settings.textColorMid }
          SpinBox {
            id: offsetSpin
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            font.pixelSize: 11
            editable: true
            from: details.connEdge.offsetMin !== undefined ? details.connEdge.offsetMin : -32
            to: details.connEdge.offsetMax !== undefined ? details.connEdge.offsetMax : 32
            value: details.connEdge.offset || 0
            onValueModified: brg.map.setConnectionOffset(details.connection, value)
          }
        }

        // The snap landmarks, as one-tap buttons.
        Flow {
          Layout.fillWidth: true
          spacing: 6
          Repeater {
            model: details.connEdge.snaps || []
            delegate: Button {
              required property var modelData
              height: 24
              font.pixelSize: 10
              text: modelData.name + " (" + modelData.offset + ")"
              onClicked: brg.map.setConnectionOffset(details.connection, modelData.offset)
            }
          }
        }

        // ── Attach to another edge (re-home; never a rotation) ───────────────────────────────
        Label {
          Layout.fillWidth: true
          Layout.topMargin: 4
          text: qsTr("Attached edge")
          font.pixelSize: 11
          color: brg.settings.textColorMid
        }
        RowLayout {
          Layout.fillWidth: true
          spacing: 4
          Repeater {
            model: [{ d: 0, n: qsTr("North") }, { d: 1, n: qsTr("South") },
                    { d: 2, n: qsTr("East") },  { d: 3, n: qsTr("West") }]
            delegate: Button {
              required property var modelData
              Layout.fillWidth: true
              Layout.preferredHeight: 26
              font.pixelSize: 10
              text: modelData.n
              // The current edge is highlighted; a free edge is a re-home target; an occupied one is off.
              enabled: modelData.d === details.connection
                       || !brg.map.connectionExists(modelData.d)
              highlighted: modelData.d === details.connection
              onClicked: {
                if (modelData.d === details.connection) return;
                brg.map.rehomeConnection(details.connection, modelData.d);
                if (details.canvas) details.canvas.selectedConnection = modelData.d;
              }
            }
          }
        }

        // ── The raw nine (read-only while synced; break sync to edit) ────────────────────────
        //
        // ⭐ BEHIND THE 🔧 **MANUAL** GATE (project leadership, 2026-08-18): *"It includes the manual
        // controls like viewbox and connection — it doesn't switch them to manual, it just shows them,
        // allowing to break auto sync."* Read that carefully, because it is the whole design: the gate
        // **reveals** this section and changes nothing. Sync is still on, the bytes are still derived,
        // the spin boxes are still read-only until you throw "Break sync" yourself. Opening a gate must
        // never be an edit.
        //
        // ⚠️ `connSynced === false` is the escape hatch, and it is not a second gate — it is the same
        // question the contrast strip answers with `contrastIsGlitch`. A connection that is ALREADY
        // desynced has to show its raw bytes whether or not the gate is open, or the panel would be
        // hiding the only explanation for what the map is doing.
        ColumnLayout {
          id: connRaw
          Layout.fillWidth: true
          spacing: 6

          readonly property bool connSynced: details.connEdge.synced !== false
          visible: brg.map.showManual || !connRaw.connSynced

          RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 6
            spacing: 6
            Label {
              Layout.fillWidth: true
              text: qsTr("Raw bytes")
              font.pixelSize: 11
              font.bold: true
              opacity: 0.55
            }
            // ⭐ "MANUAL CONTROL", NOT "BREAK SYNC" (project leadership, 2026-08-19: *"break sync
            // becomes manual control"*). "Break" names the damage rather than the capability, and
            // reads like something you'd be warned against; what the switch actually gives you is
            // the wheel. It is also the word the 🔧 gate that reveals this section already uses, so
            // the two now say the same thing.
            // ⚠️ ALWAYS ENABLED. It used to disable itself the moment the connection desynced —
            // which is the moment you make your first raw edit — so turning it on and typing a
            // number greyed the switch out under your hand. @see details.connManualDirs.
            Switch {
              text: qsTr("Manual control")
              font.pixelSize: 10
              checked: details.connBreakSync
              onToggled: details.setConnManual(checked)
            }
          }

          Label {
            Layout.fillWidth: true
            text: details.connRawEditable
                  ? qsTr("You are setting these by hand — the offset above no longer describes the "
                         + "connection until you pick a neighbour or an offset again. The map "
                         + "redraws as you change them.")
                  : qsTr("These follow the offset above. Turn on “Manual control” to set them "
                         + "yourself.")
            wrapMode: Text.Wrap
            font.pixelSize: 10
            opacity: 0.55
          }

          Repeater {
            model: details.connFieldsData
            delegate: ColumnLayout {
              id: connFieldRow
              required property var modelData
              spacing: 1

              // ⚠️ `Layout.fillWidth` ALONE WAS NOT ENOUGH once this delegate became a ColumnLayout.
              // As a RowLayout it stretched because it held a `fillWidth` child that wanted the room;
              // wrapped in a column it settled at its implicit 198px while the row inside it drew at
              // the full 330 — overflowing its own parent, which is why the rows LOOKED right and the
              // readout underneath them silently had 98px to wrap 44 characters into. Pinning the
              // preferred width to the section makes it deterministic instead of emergent.
              Layout.fillWidth: true
              Layout.preferredWidth: connRaw.width

              // So the harness (and a human) can reach one row by name. @see dev-harness.md
              objectName: "connField_" + connFieldRow.modelData.key

              // ⭐ A POINTER IS A PLACE, AND THE PLACE IS SHOWN (project leadership, 2026-08-19:
              // *"i am aware of how hex addresses and memory addresses work … but its silly to say
              // theres no solution for this … the start of the blocks are known"*).
              //
              // They are right, and it is exact: none of the three is a free-floating address —
              // each is a base plus an index into a grid this app already draws. @see
              // MapModel::pointerPlace, which is the same arithmetic the engine uses to COMPOSE
              // them, run backwards. Verified against all three of Pallet Town's north pointers
              // and the macro in notes/reference/map-connections.md.
              readonly property var place: {
                details.revision;
                return connFieldRow.modelData.kind === "pointer" && details.hasConnection
                  ? brg.map.pointerPlace(details.connection, connFieldRow.modelData.key)
                  : ({ valid: false });
              }

              RowLayout {
                Layout.fillWidth: true
                spacing: 6

              Label {
                Layout.preferredWidth: 92
                text: connFieldRow.modelData.label
                font.pixelSize: 10
                opacity: 0.7
                elide: Text.ElideRight
              }

              // ⭐ THE NEIGHBOUR ID IS A MAP, SO IT GETS THE MAP LIST (project leadership,
              // 2026-08-19: *"neighbor map id should be the map list"*). It is still the raw byte —
              // the shared selector offers all 248 including the glitch ids, so nothing is refused;
              // it just stops asking anybody to know that Route 1 is 12.
              MapField {
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                visible: connFieldRow.modelData.key === "mapPtr"
                enabled: details.connRawEditable
                value: connFieldRow.modelData.value
                onPicked: (ind) => brg.map.setConnectionField(details.connection,
                                                              connFieldRow.modelData.key, ind)
              }

              // ⭐ AN ADDRESS IS NOT A QUANTITY (project leadership: *"strip src/dst and the view
              // pointer shown as hex pointers"*). Three of these eight are memory addresses, and
              // showing "50923" where the game means `$C6EB` is a small lie about what the value
              // is — you cannot match it against anything, and the digits carry no structure.
              // Typing is hex too, so what you read is what you write.
              TextField {
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                font.pixelSize: 10
                font.family: "monospace"
                visible: connFieldRow.modelData.kind === "pointer"
                enabled: details.connRawEditable
                text: "$" + ("0000" + connFieldRow.modelData.value.toString(16).toUpperCase()).slice(-4)
                onEditingFinished: {
                  const v = parseInt(text.replace(/^[$#]|^0x/i, ""), 16);
                  if (!isNaN(v))
                    brg.map.setConnectionField(details.connection, connFieldRow.modelData.key,
                                               Math.max(0, Math.min(0xFFFF, v)));
                }
              }

              // Pick the square instead of typing the address. Opens the grid the pointer indexes
              // — the neighbour's own map, or a border ring — with the current target lit up.
              Rectangle {
                id: pickBtn
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                visible: connFieldRow.modelData.kind === "pointer"
                radius: 4
                border.width: 1
                border.color: brg.settings.dividerColor
                readonly property bool armed: details.connRawEditable && connFieldRow.place.valid
                opacity: armed ? 1 : 0.4
                color: !armed ? "transparent"
                     : pickArea.pressed  ? Qt.rgba(0, 0, 0, 0.16)
                     : pickArea.containsMouse ? Qt.rgba(0, 0, 0, 0.08) : "transparent"

                Label {
                  anchors.centerIn: parent
                  text: "⊞"
                  font.pixelSize: 13
                  opacity: 0.75
                }

                MouseArea {
                  id: pickArea
                  anchors.fill: parent
                  hoverEnabled: true
                  enabled: pickBtn.armed
                  cursorShape: Qt.PointingHandCursor
                  onClicked: pointerPicker.openFor(details.connection,
                                                   connFieldRow.modelData.key,
                                                   connFieldRow.modelData.label)
                }

                ToolTip.visible: pickArea.containsMouse
                ToolTip.text: qsTr("Point at a square instead")
                ToolTip.delay: 400
              }

              SpinBox {
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                font.pixelSize: 10
                editable: true
                visible: connFieldRow.modelData.kind !== "pointer"
                         && connFieldRow.modelData.key !== "mapPtr"
                enabled: details.connRawEditable
                from: connFieldRow.modelData.min
                to: connFieldRow.modelData.max
                value: connFieldRow.modelData.value
                onValueModified: brg.map.setConnectionField(details.connection,
                                                            connFieldRow.modelData.key, value)
              }
              }

              // ⭐ THE ADDRESS, IN WORDS. "row 2, column 3 of Pallet Town's border ring" — the same
              // decode the picker and the on-canvas handle drive, sitting under the hex so the two
              // readings are always visibly the same number.
              //
              // It says so plainly when the address has left its grid. That is ALLOWED — a save can
              // hold it, the game will read whatever is there, and refusing to show it would be the
              // opposite of what this screen is for.
              // ⚠️ `fillWidth` ALONE, and NO `Layout.preferredWidth: 0` here. That pairing is the
              // right fix for a wrapping Label whose implicitWidth would otherwise blow its column
              // out — but combined with a `leftMargin` inside a Repeater delegate it resolved to a
              // zero-width item, and a zero-width wrapping Label is not invisible: it reserves its
              // height and draws nothing. On screen that is a blank gap under every pointer field,
              // which looks like a layout bug rather than missing text. Caught in the screenshot
              // pass; the model was right the whole time.
              Label {
                objectName: "connWhere_" + connFieldRow.modelData.key
                // ⚠️ NO INDENT. It was set to 98 to line up under the field column, which is right on
                // a wide panel and wrong on this one: the dock is **240 logical px**, the label column
                // is 92 of it, and indenting by 98 left 98px to wrap 44 characters into. Measured, not
                // guessed — the panel reported its own width when the readout came out blank.
                Layout.fillWidth: true
                Layout.leftMargin: 2
                Layout.rightMargin: 2
                Layout.topMargin: 1
                Layout.bottomMargin: 4
                visible: connFieldRow.modelData.kind === "pointer" && connFieldRow.place.valid
                text: connFieldRow.place.where || ""
                font.pixelSize: 9
                wrapMode: Text.Wrap
                opacity: connFieldRow.place.inRange ? 0.55 : 0.9

                // ⚠️ NOT `palette.text` — IT IS WHITE HERE. Every other quiet label on this panel
                // just leaves `color` alone and dims with `opacity`; this one asked the palette and
                // got #ffffff, so it drew white text on a white panel: present, correct, measurable
                // (194 × 12 px, right string) and completely invisible. The only reason it was caught
                // is that the screenshot showed a gap where words should be and the harness could be
                // asked what colour it had ended up. @see notes/reference/ui-patterns.md
                color: connFieldRow.place.inRange ? "#000000" : "#c04a00"
              }
            }
          }
        }

        // ── Delete ───────────────────────────────────────────────────────────────────────────
        Button {
          Layout.fillWidth: true
          Layout.topMargin: 6
          Layout.preferredHeight: 28
          font.pixelSize: 11
          text: qsTr("Delete this connection")
          contentItem: Label {
            text: parent.text
            font: parent.font
            color: parent.hovered ? "#ffffff" : "#d55e00"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }
          background: Rectangle {
            radius: 4
            color: parent.hovered ? "#d55e00" : "transparent"
            border.width: 1
            border.color: "#d55e00"
            Behavior on color { ColorAnimation { duration: 90 } }
          }
          onClicked: {
            brg.map.removeConnection(details.connection);
            if (details.canvas) details.canvas.selectedConnection = -1;
          }
        }

        // ⚠️ NO LIVENESS NOTICE — see the warps section for the ruling (2026-08-19).
      }

      // ══ ⟐ A SCRIPT TRIGGER SELECTED ════════════════════════════════════════════════════════
      //
      // A dashed script box on the canvas. It has NO editable bytes of its own — it is a place where
      // the map's script runs — so this is a READING: what sets it off, what it changes (the event
      // and filter flags it writes, each with direction + phase), and where the sequence goes next.
      // The data is the extracted storage spot (MapModel::scriptSpotAt). It shows what the script
      // *changes*; what it *reads* to decide is not tracked.
      ColumnLayout {
        Layout.fillWidth: true
        Layout.margins: 10
        spacing: 8
        visible: details.hasScript

        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          Rectangle {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            radius: 4
            color: "transparent"
            border.width: 2
            border.color: brg.map.ink("script")
            Text {
              anchors.centerIn: parent
              text: details.scriptData.isCardKey ? "▤" : "⟐"
              font.pixelSize: 14
              color: brg.map.ink("script")
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Label {
              Layout.fillWidth: true
              text: details.scriptData.title || qsTr("Script trigger")
              font.bold: true
              font.pixelSize: 14
              elide: Text.ElideRight
            }
            Label {
              Layout.fillWidth: true
              // Shape-aware: a row/column trigger has no single (x, y). (A scriptRow carries x = −1.)
              text: details.scriptData.shape === "scriptRow" ? qsTr("row %1").arg(details.scriptData.y || 0)
                  : details.scriptData.shape === "scriptCol" ? qsTr("column %1").arg(details.scriptData.x || 0)
                  : qsTr("at %1, %2").arg(details.scriptData.x || 0).arg(details.scriptData.y || 0)
              font.pixelSize: 10
              opacity: 0.6
            }
          }
        }

        // What sets it off.
        Label {
          Layout.fillWidth: true
          visible: (details.scriptData.trigger || "") !== ""
          text: details.scriptData.trigger || ""
          wrapMode: Text.Wrap
          font.pixelSize: 11
          color: brg.settings.textColorMid
        }

        // The pret routine that owns it — the exact thing, for anyone who wants it.
        RowLayout {
          Layout.fillWidth: true
          spacing: 6
          visible: (details.scriptData.routine || "") !== ""
          Label { text: qsTr("Routine"); font.pixelSize: 10; opacity: 0.6 }
          Label {
            Layout.fillWidth: true
            text: details.scriptData.routine || ""
            font.pixelSize: 10
            font.family: "monospace"
            color: brg.settings.textColorMid
            elide: Text.ElideMiddle
          }
        }

        Rectangle { Layout.fillWidth: true; Layout.topMargin: 2; implicitHeight: 1; color: brg.settings.dividerColor }

        // ── Event flags it changes ─────────────────────────────────────────────────────────
        Label {
          Layout.fillWidth: true
          visible: (details.scriptData.events || []).length > 0
          text: qsTr("Event flags it changes")
          font.pixelSize: 11
          font.bold: true
          opacity: 0.6
        }
        Repeater {
          model: details.scriptData.events || []
          delegate: ColumnLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: 1

            RowLayout {
              Layout.fillWidth: true
              spacing: 6
              // Direction chip: set = turns ON (green), reset = turns OFF (grey).
              Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 16
                radius: 3
                color: modelData.action === "set" ? "#33a866" : "#9aa0a6"
                Text {
                  anchors.centerIn: parent
                  text: modelData.action === "set" ? qsTr("ON") : qsTr("OFF")
                  font.pixelSize: 9
                  font.bold: true
                  color: "#ffffff"
                }
              }
              Label {
                Layout.fillWidth: true
                text: modelData.name
                font.pixelSize: 11
                color: brg.settings.textColorDark
                wrapMode: Text.Wrap
              }
            }
            // The phase that does it, and whether it fires later in the sequence.
            Label {
              Layout.fillWidth: true
              Layout.leftMargin: 36
              visible: (modelData.stepName || "") !== "" || modelData.viaChain === true
              text: (modelData.viaChain === true ? qsTr("later in the sequence") : qsTr("here"))
                    + ((modelData.stepName || "") !== "" ? " · " + modelData.stepName : "")
              font.pixelSize: 9
              opacity: 0.5
              wrapMode: Text.Wrap
            }
          }
        }

        // ── Filter flags (people/objects it shows or hides) ────────────────────────────────
        Label {
          Layout.fillWidth: true
          Layout.topMargin: 2
          visible: (details.scriptData.filters || []).length > 0
          text: qsTr("People & objects it shows or hides")
          font.pixelSize: 11
          font.bold: true
          opacity: 0.6
        }
        Repeater {
          model: details.scriptData.filters || []
          delegate: ColumnLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: 1

            RowLayout {
              Layout.fillWidth: true
              spacing: 6
              Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 16
                radius: 3
                color: modelData.action === "show" ? "#0072b2" : "#9aa0a6"
                Text {
                  anchors.centerIn: parent
                  text: modelData.action === "show" ? qsTr("SHOW") : qsTr("HIDE")
                  font.pixelSize: 9
                  font.bold: true
                  color: "#ffffff"
                }
              }
              Label {
                Layout.fillWidth: true
                text: modelData.name
                font.pixelSize: 11
                color: brg.settings.textColorDark
                wrapMode: Text.Wrap
              }
            }
            Label {
              Layout.fillWidth: true
              Layout.leftMargin: 44
              visible: (modelData.stepName || "") !== "" || modelData.viaChain === true
              text: (modelData.viaChain === true ? qsTr("later in the sequence") : qsTr("here"))
                    + ((modelData.stepName || "") !== "" ? " · " + modelData.stepName : "")
              font.pixelSize: 9
              opacity: 0.5
              wrapMode: Text.Wrap
            }
          }
        }

        // Where the sequence goes next.
        Label {
          Layout.fillWidth: true
          Layout.topMargin: 2
          visible: (details.scriptData.chain || []).length > 0
          text: qsTr("Continues into: %1").arg((details.scriptData.chain || []).join(", "))
          wrapMode: Text.Wrap
          font.pixelSize: 10
          opacity: 0.55
        }

        // Nothing tracked to change.
        Label {
          Layout.fillWidth: true
          visible: (details.scriptData.events || []).length === 0
                   && (details.scriptData.filters || []).length === 0
          text: qsTr("This trigger doesn't change any event or filter flag we track — it runs the "
                     + "map's own script for its current step.")
          wrapMode: Text.Wrap
          font.pixelSize: 10
          opacity: 0.55
        }

        // The honest boundary of what we know.
        Label {
          Layout.fillWidth: true
          Layout.topMargin: 6
          text: qsTr("This shows what the script changes. Whether it also reads a flag to decide "
                     + "isn't tracked.")
          wrapMode: Text.Wrap
          font.pixelSize: 9
          opacity: 0.45
        }
      }

      // ── The PLAYER selected ──────────────────────────────────────────────────────────────
      //
      // He is slot 0, he is selectable and draggable like anybody else -- and he does not live in
      // the sprite table, so `npcFields` has nothing for him. His position is the one thing about
      // him that is genuinely a map fact, and the canvas already edits it by dragging; the rest of
      // him (name, badges, money, the lot) is the Trainer Card's job, not the map's.
      ColumnLayout {
        Layout.fillWidth: true
        Layout.margins: 10
        spacing: 8
        visible: details.hasPlayer

        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          Image {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            source: "image://player/npc/1/0/" + brg.map.contrast
            smooth: false
            fillMode: Image.PreserveAspectFit
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Label {
              Layout.fillWidth: true
              text: qsTr("The player")
              font.bold: true
              font.pixelSize: 14
              elide: Text.ElideRight
            }

            Label {
              text: qsTr("Slot 0 — the game requires them")
              font.pixelSize: 10
              opacity: 0.6
            }
          }
        }

        Label {
          Layout.fillWidth: true
          Layout.topMargin: 2
          text: qsTr("Where they are standing")
          font.pixelSize: 11
          color: brg.settings.textColorMid
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 6

          Label { text: qsTr("X"); font.pixelSize: 10; opacity: 0.6 }

          SpinBox {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredHeight: 28
            font.pixelSize: 11
            editable: true
            from: 0
            to: 255
            value: brg.map.playerX
            onValueModified: brg.map.movePlayer(value, brg.map.playerY)
          }

          Label { text: qsTr("Y"); font.pixelSize: 10; opacity: 0.6 }

          SpinBox {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredHeight: 28
            font.pixelSize: 11
            editable: true
            from: 0
            to: 255
            value: brg.map.playerY
            onValueModified: brg.map.movePlayer(brg.map.playerX, value)
          }
        }

        // Moving him invalidates the view pointer the GAME computed. We say so and offer the fix --
        // we never quietly rewrite it. (The derived-byte doctrine; map-screen.md.)
        Rectangle {
          Layout.fillWidth: true
          Layout.topMargin: 6
          visible: !brg.map.headerMatches
          radius: 6
          color: Qt.rgba(1, 0.84, 0.31, 0.15)
          border.width: 1
          border.color: "#ffd54f"
          implicitHeight: pFixCol.implicitHeight + 16

          ColumnLayout {
            id: pFixCol
            anchors.fill: parent
            anchors.margins: 8
            spacing: 6

            Label {
              Layout.fillWidth: true
              text: qsTr("The map view pointer the game computed no longer matches where they are.")
              wrapMode: Text.Wrap
              font.pixelSize: 11
            }

            Button {
              text: qsTr("Fix it")
              onClicked: brg.map.fixMapHeader()
            }
          }
        }

        // ── ⭐ HIS BIKE, AND HIS CAMERA ─────────────────────────────────────────────────────
        //
        // Project leadership, 2026-08-18: *"Move Camera — follows the player to player details.
        // Always on bike also in character details."* Both were in the map-state group, which was
        // simply the drawer that everything map-shaped fell into. They are about the PERSON: one is
        // what he is riding, the other is where the screen sits relative to him.

        Rectangle { Layout.fillWidth: true; Layout.topMargin: 6; height: 1; color: brg.settings.dividerColor }

        RowLayout {
          Layout.fillWidth: true
          Layout.topMargin: 4
          spacing: 8
          Label {
            Layout.fillWidth: true
            text: qsTr("Always on bike (Cycling Road)")
            font.pixelSize: 12
            wrapMode: Text.Wrap
          }
          MapSwitch {
            checked: brg.map.alwaysOnBike
            onToggled: brg.map.alwaysOnBike = !brg.map.alwaysOnBike
          }
        }

        // ── The camera / view box, behind the 🔧 MANUAL gate ─────────────────────────────────
        //
        // ⭐ Same rule as the connection bytes (project leadership, 2026-08-18): the gate **shows**
        // this, it does not set it loose. The camera keeps following the player exactly as before
        // while the gate is shut; all the gate does is put the switch on screen.
        //
        // ⚠️ `!viewSynced` is the escape hatch, not a second gate: a camera that is ALREADY loose must
        // show its controls whatever the gate says, or there would be no way to see why the screen is
        // drawn where it is — or to put it back. (You can also break it loose by dragging the box on
        // the canvas, which is a gesture no gate mediates.)
        ColumnLayout {
          id: viewBox
          Layout.fillWidth: true
          spacing: 3
          visible: brg.map.showManual || !brg.map.viewSynced

          RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 8
            Label {
              Layout.fillWidth: true
              text: brg.map.viewSynced ? qsTr("Camera — follows the player")
                                       : qsTr("Camera — set loose")
              font.pixelSize: 12
              wrapMode: Text.Wrap
            }
            MapSwitch {
              // On = broken loose. Flipping it toggles sync; re-attaching snaps the box to the player.
              checked: !brg.map.viewSynced
              onToggled: brg.map.setViewBreakSync(brg.map.viewSynced)
            }
          }

          // The raw pointer, only on the power path.
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            visible: !brg.map.viewSynced
            RowLayout {
              Layout.fillWidth: true
              spacing: 6
              Label { text: qsTr("Address"); font.pixelSize: 10; opacity: 0.6 }
              SpinBox {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                font.pixelSize: 11
                editable: true
                from: 0
                to: 65535
                value: brg.map.viewPtr
                onValueModified: brg.map.setViewPtr(value)
              }
            }
            Label {
              Layout.fillWidth: true
              text: qsTr("The game trusts this pointer and draws the screen from it — an off-map value "
                         + "shows garbage. You can also drag the view box around on the canvas.")
              wrapMode: Text.Wrap
              font.pixelSize: 10
              opacity: 0.55
            }
          }
          Label {
            Layout.fillWidth: true
            visible: brg.map.viewSynced
            text: qsTr("The view box tracks the player automatically. Break it loose to place it by "
                       + "hand.")
            wrapMode: Text.Wrap
            font.pixelSize: 10
            opacity: 0.55
          }
        }

        // ── Every other byte of his map state, grouped ──────────────────────────────────────
        //
        // ⚠️ Read notes/reference/player-state.md. Ten of these the game rewrites the instant it
        // loads the save, three it never reads -- all gathered in the last group, behind the
        // toolbar's "Useless edits" toggle (filtered in the MODEL, so no view can leak one). The
        // durable ones show here always. Everything full-range, hack values included, never refused.
        Repeater {
          model: details.playerGroupOrder

          delegate: ColumnLayout {
            id: playerGroup
            required property string modelData

            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 3

            readonly property var members: (details.playerFields || []).filter(function(f) {
              return f.group === playerGroup.modelData;
            })

            readonly property bool isRewriteGroup:
              playerGroup.modelData === "Rewritten on load, or never read"

            visible: playerGroup.members.length > 0

            // The durable groups get a plain heading.
            Label {
              visible: !playerGroup.isRewriteGroup
              text: playerGroup.modelData
              font.pixelSize: 11
              font.bold: true
              opacity: 0.55
              Layout.fillWidth: true
              Layout.topMargin: 4
            }

            // ⚠️ THE REWRITE GROUP IS A DIFFERENT KIND OF GROUP, so it says so rather than being a
            // plain heading -- exactly like the warp panel's "Fields that do nothing". Project leadership,
            // 2026-07-14: *"which ones were regenerated or rewritten on save load with little
            // exclamation points grouped below and hidden behind a switch."*
            Rectangle {
              visible: playerGroup.isRewriteGroup
              Layout.fillWidth: true
              Layout.topMargin: 10
              radius: 6
              color: Qt.rgba(0, 0, 0, 0.03)
              border.width: 1
              border.color: brg.settings.dividerColor
              implicitHeight: rewriteHdr.implicitHeight + 16

              ColumnLayout {
                id: rewriteHdr
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                Label {
                  Layout.fillWidth: true
                  text: qsTr("Rewritten on load, or never read")
                  font.pixelSize: 11
                  font.bold: true
                  opacity: 0.75
                }

                RowLayout {
                  Layout.fillWidth: true
                  spacing: 6

                  MapWarnIcon {
                    text: qsTr("The game works this value out again the moment it loads your save. "
                               + "Verified on a real cartridge.")
                  }

                  Label {
                    Layout.fillWidth: true
                    text: qsTr("the game rewrites it every time it loads your save")
                    wrapMode: Text.Wrap
                    font.pixelSize: 10
                    opacity: 0.6
                  }
                }

                RowLayout {
                  Layout.fillWidth: true
                  spacing: 6

                  Label {
                    Layout.preferredWidth: 14
                    text: "💀"
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                  }

                  Label {
                    Layout.fillWidth: true
                    text: qsTr("it survives perfectly — and nothing in the game ever reads it")
                    wrapMode: Text.Wrap
                    font.pixelSize: 10
                    opacity: 0.6
                  }
                }
              }
            }

            Repeater {
              model: playerGroup.members

              delegate: PlayerField {
                required property var modelData
                Layout.fillWidth: true

                fieldData: modelData
              }
            }
          }
        }

        // ⚠️ NO "thirteen more of his bytes are hidden" notice. @see the note in the Map-state
        // group above (leadership, 2026-08-18) — the "!" is the discovery path, not a paragraph.

        Label {
          Layout.fillWidth: true
          Layout.topMargin: 8
          text: qsTr("Their name, their badges and everything else about them live on the Trainer Card.")
          wrapMode: Text.Wrap
          font.pixelSize: 10
          opacity: 0.55
        }
      }

      // ── A sprite selected ────────────────────────────────────────────────────────────────
      ColumnLayout {
        Layout.fillWidth: true
        Layout.margins: 10
        spacing: 8
        visible: details.hasSprite

        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          Image {
            width: 32
            height: 32
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            source: details.sprite.source || ""
            smooth: false
            fillMode: Image.PreserveAspectFit
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Label {
              text: details.sprite.name || ""
              font.bold: true
              font.pixelSize: 14
              Layout.fillWidth: true
              elide: Text.ElideRight
            }

            Label {
              text: qsTr("Slot %1").arg(details.slot)
              font.pixelSize: 10
              opacity: 0.6
            }
          }
        }

        // ⚠️ A DELETE BUTTON THAT SAYS DELETE.
        //
        // It was a "✕" ToolButton with a tooltip. Project leadership: *"The x button deletes — it's not
        // self-explanatory, should be delete button."* A destructive action gets a word, not a glyph
        // you have to hover to identify.
        Button {
          Layout.fillWidth: true
          Layout.topMargin: 2
          Layout.preferredHeight: 28
          font.pixelSize: 11

          text: qsTr("Delete this character")

          contentItem: Label {
            text: parent.text
            font: parent.font
            color: parent.hovered ? "#ffffff" : "#d55e00"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }

          background: Rectangle {
            radius: 4
            color: parent.hovered ? "#d55e00" : "transparent"
            border.width: 1
            border.color: "#d55e00"

            Behavior on color { ColorAnimation { duration: 90 } }
          }

          onClicked: {
            brg.map.removeNpc(details.slot);
            if (details.canvas)
              details.canvas.selectedNpc = -1;
          }
        }

        // (A big yellow BLOCK saying "this map hasn't loaded this character's picture" sat here.
        //  REMOVED 2026-07-13 -- project leadership: *"don't have it also as a big yellow block on the details
        //  page."* And she is right: the picture picker two rows below already carries the yellow "!"
        //  on exactly that character, with the sentence in its tooltip. Saying it a second time, in a
        //  paragraph, in a coloured box, above the fields you came to edit, is the panel shouting.)

        // (A blue "this map's cast no longer matches the game's" notice sat here. REMOVED 2026-07-13
        // -- project leadership: "do not have notice on cast no longer matches". It fired on every edit, said
        // the same thing every time, and pushed the fields you were editing down the panel. The fact
        // it carried -- the game rebuilds a map's cast from ROM when you walk back in -- is still
        // true, and it is written down where a fact belongs: notes/reference/sprites.md, Part 6.)

        // ── Every byte, grouped ──────────────────────────────────────────────────────────────
        Repeater {
          model: details.groupOrder

          delegate: ColumnLayout {
            id: fieldGroup
            required property string modelData

            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 3

            readonly property var members: (details.fields || []).filter(function(f) {
              return f.group === fieldGroup.modelData;
            })

            visible: fieldGroup.members.length > 0

            Label {
              text: fieldGroup.modelData
              font.pixelSize: 11
              font.bold: true
              opacity: 0.55
              Layout.fillWidth: true
              Layout.topMargin: 4
            }

            Repeater {
              model: fieldGroup.members

              delegate: SpriteField {
                required property var modelData
                Layout.fillWidth: true

                fieldData: modelData
                slot: details.slot
                canvas: details.canvas   // so the picture picker can mute the ground while it is up
              }
            }
          }
        }
      }
    }
  }

  // Aims one of the connection's three raw addresses at a square you can see. One instance for the
  // whole panel -- the ⊞ beside each pointer field opens it with that field's key.
  PointerPicker {
    id: pointerPicker
  }
}
