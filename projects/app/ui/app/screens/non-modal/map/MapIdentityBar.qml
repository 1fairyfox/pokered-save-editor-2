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
  MapIdentityBar.qml -- the top bar: WHAT IS LOADED, then the things you PLAY, then THE PALETTE.

    [ Pallet Town ⌄ ] [ ⊞ ] │ [ ◧ ] ‖ [ ▶♪⌄ ] [ ▶✿ ] … [ ◧ colour ] │ [ ! ]
      map picker      opts    contrast   music   anim       palette      scratch

  * The MAP SELECTOR is the title (MapNamePicker). ⊞ (MapPicker) holds the map's config in one
    dropdown to the right of the name: designated maps, the stored-size fix, and the tileset & blocks
    the map draws from (folded back in here 2026-08-03, from a brief standalone ▩ button).
  * The PALETTE (ContrastPicker) reads as a percentage and drops a segmented slider.
  * THE THINGS YOU PLAY sit together past a divider: music (♪) and tile animation (a flower). Each is
    a MapSimButton — a ▶/⏸ play zone + a subject icon + an optional ▾. (The people-walk button was
    removed 2026-08-03; the MapSim backend stays dormant.)

  Nothing here is a menu bar and nothing here is a toolbar with separators. It is chips.
*/
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
  id: bar

  // ⚠️ THE TOOLS AND THE MAKERS ARE NOT HERE (they live on the LEFT RAIL — see Map.qml). This bar is
  // a statement of WHAT IS LOADED, plus the things you PLAY. `tool` is owned by the screen.

  /// The drop-downs, drivable by name for the DEBUG harness / the screenshot review.
  property alias mapPickerOpen: mapPicker.openState
  property alias contrastPickerOpen: contrastPicker.openState
  property alias contrastShowGlitch: contrastPicker.showGlitch
  property alias colourPickerOpen: colourPicker.openState

  implicitHeight: 36
  color: "#f7f7f7"

  Rectangle {
    anchors.bottom: parent.bottom
    width: parent.width
    height: 1
    color: brg.settings.dividerColor
  }

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: 10
    anchors.rightMargin: 10
    spacing: 7

    // ── The map's NAME — and it IS the map selector ───────────────────────────────────────────
    //
    // project leadership, 2026-07-19: *"make the map title a button with a down arrow … clicking the map name
    // directly lets you select a different map."* The tileset/blocks override and the designated maps
    // live in the ⊞ / ▩ buttons beside it.
    RowLayout {
      spacing: 6

      MapNamePicker { id: mapNamePicker }

      // A fact, not an alarm: this id has no map of its own, so the game draws the one it copies.
      Label {
        visible: brg.map.isCopy
        text: qsTr("· copy of %1").arg(brg.map.copyOfName)
        font.pixelSize: 10
        font.italic: true
        color: brg.settings.textColorMid
        elide: Text.ElideRight
        Layout.maximumWidth: 130
      }
    }

    Rectangle {
      implicitWidth: 1
      implicitHeight: 18
      color: brg.settings.dividerColor
      Layout.leftMargin: 2
      Layout.rightMargin: 2
    }

    // ── The CONFIG buttons: Map options · Contrast ───────────────────────────────────────────
    //
    // Compact icon tool-buttons, each with a ▾ that says "I drop a menu" (project leadership). Where a
    // reactive icon is natural it is one: Contrast IS its live four-shade swatch; ⊞ carries an amber
    // dot when the map's stored size is stale OR its blocks and graphics disagree. They share
    // MapBarButton, so they read as a family.

    // ── Map options (⊞): designated maps, tileset & blocks, and the stored-size fix ─────────────
    //
    // Tileset & blocks fold back in here (project leadership, 2026-08-03: *"move tileset and blockset to
    // the map-select dropdown panel"*) — they were briefly a standalone ▩ button.
    MapPicker { id: mapPicker; objectName: "mapPickerControl" }

    // ── Contrast ─────────────────────────────────────────────────────────────────────────────
    //
    // Just contrast — the COLOUR palette is its own chip on the right of the bar. Contrast is a save
    // byte; colour is a view setting.
    ContrastPicker { id: contrastPicker }

    // ══ THE THINGS YOU PLAY — music · tile animation · people walking ═════════════════════════
    //
    // project leadership, 2026-07-14: *"the music button, the tile-animation button and the walk button need to
    // all be icon buttons with an optional dropdown — a play/pause button next to a symbol, with a
    // little dropdown arrow."* They briefly MERGED into one "Simulate" button; leadership un-merged
    // them again 2026-08-03: *"have a play button next to the feet icon that defaults to tile
    // animation … break people simulation out to its own button to the right … it offers destructive
    // simulation."* So there are three, past a divider:
    //
    //   ▶♪⌄  music         — MapSimButton (MusicPicker)
    //   ▶✦⌄  tile animation — the SAFE default; ▶ plays the water/flowers, ▾ drops speed/step
    //   ▶👣• people walking — its OWN button; the amber dot marks it DESTRUCTIVE (moves sprite data)
    Rectangle {
      implicitWidth: 1
      implicitHeight: 18
      color: brg.settings.dividerColor
      Layout.leftMargin: 4
      Layout.rightMargin: 4
    }

    // ⚠️ The play buttons sit in their OWN tight RowLayout so they read as a GROUP -- close together,
    // and clearly apart from the config buttons across the divider (project leadership, 2026-07-14: *"make
    // the simulation buttons look like a proper grouping with proper spacing"*).
    RowLayout {
      id: playGroup
      spacing: 3

      // Music — ▶/⏸ ♪ ▾ (the ▾ drops the track / volume / flags).
      MusicPicker { id: musicPicker }

      // ── Tile animation — ▶/⏸ + a flower — the SAFE, default one, PLAY-ONLY ──────────────────
      //
      // The play zone toggles the map clock directly. No menu (leadership 2026-08-03: "remove the
      // tile animation dropdown, we don't need speed control"); what animates + the Surf/distortion
      // caveats live on the tileset button's Indoor/Cave/Outdoor description. The flower says "the
      // map's water and plants, alive".
      Item {
        id: animWrap
        objectName: "animGroup"
        implicitWidth: animBtn.implicitWidth
        implicitHeight: 26

        MapSimButton {
          id: animBtn
          objectName: "animChip"

          iconSource: "qrc:/assets/icons/flower.svg"
          iconSourcePlaying: "qrc:/assets/icons/flower-light.svg"

          playing: brg.mapClock.playing
          playEnabled: brg.mapClock.animates
          playTip: !brg.mapClock.animates
                     ? qsTr("This map has nothing that animates")
                     : brg.mapClock.playing ? qsTr("Stop") : qsTr("Play the tile animation")
          onToggled: brg.mapClock.playing = !brg.mapClock.playing

          // No menu — leadership 2026-08-03: "remove the tile animation dropdown, we don't need
          // speed control." What animates (and the Surf/distortion caveats) is said on the tileset
          // button's Indoor/Cave/Outdoor description instead.
          hasMenu: false
        }
      }

      // (People-walking simulation removed for now — leadership 2026-08-03: *"sprite walking, remove
      // that feature for now, I think it's not as useful now."* The MapSim backend (brg.mapSim) stays,
      // dormant and unwired, so bringing the button back later is a one-block change.)
    }

    Item { Layout.fillWidth: true }

    // ── Colour (the output palette) — its own chip, right side ──────────────────────────────────
    //
    // project leadership, 2026-07-19: *"the color picker goes in the top bar at the right."* Its face is the
    // four colours it is currently painting with. A VIEW setting — no save byte.
    ColourPicker { id: colourPicker }

    Rectangle {
      implicitWidth: 1
      implicitHeight: 18
      color: brg.settings.dividerColor
      Layout.leftMargin: 2
      Layout.rightMargin: 2
    }

    // ── The clutter switch, hard right ────────────────────────────────────────────────────────
    //
    // ⚠️ project leadership, 2026-07-13, and it is a good idea: *"Have a switch right-aligned on the top
    // toolbar that toggles on values that will be overwritten as options to change. Have it OFF by
    // default, give it a good label. When it's off, the fields that relate to things there's no
    // point in changing will not be present and add clutter."*
    //
    // Off: they simply are not there. On: they are, each wearing its yellow "!".
    //
    // ⚠️ AN ICON, NOT A LABELLED SWITCH (project leadership: *"it's way too long — don't put a long label
    // to the left of it … maybe an icon of sorts."*). It is a chip with a mark on it now, and the
    // words are in its tooltip — the bargain this toolbar makes everywhere else.
    Rectangle {
      objectName: "showScratchToggle"   // the DEBUG harness drives the panel through this

      implicitWidth: 30
      implicitHeight: 26
      radius: 13

      readonly property bool on: brg.map.showScratch

      color: on ? "#ffd54f"
           : scratchHover.hovered ? Qt.rgba(0, 0, 0, 0.10)
           : Qt.rgba(0, 0, 0, 0.05)

      border.width: 1
      border.color: on ? "#8a6d00" : brg.settings.dividerColor

      Behavior on color { ColorAnimation { duration: 90 } }

      // The same "!" that marks every one of the fields it reveals. One mark, one meaning.
      Text {
        anchors.fill: parent
        text: "!"
        font.pixelSize: 13
        font.bold: true
        color: parent.on ? "#3a2e00" : brg.settings.textColorMid
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        opacity: parent.on ? 1.0 : 0.55
      }

      HoverHandler { id: scratchHover; cursorShape: Qt.PointingHandCursor }

      // ⚠️ ReleaseWithinBounds -- it takes an EXCLUSIVE GRAB, so the press stops here. The default
      // (DragThreshold) does not grab, and Qt then goes on delivering the point to every other
      // pointer handler underneath. That is the bug that made the map's ground tap fire through the
      // panels. @see MapCanvas.overPanel
      TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: brg.map.showScratch = !brg.map.showScratch
      }

      MapToolTip {
        shown: scratchHover.hovered
        // "USELESS EDITS" -- leadership's name for this whole class (2026-07-18): everything the
        // game overwrites on load OR never reads at all. One toggle, the whole map screen.
        text: qsTr("Show useless edits — values the game overwrites when it loads your save, or "
                   + "never reads at all (reset scratch, the sprite cache, placeholder and dead "
                   + "flags).\n\nReal bytes, all editable — they just have no effect you can keep.")
      }
    }
  }
}
