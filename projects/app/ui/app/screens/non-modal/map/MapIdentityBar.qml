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

    Rectangle {
      implicitWidth: 1
      implicitHeight: 18
      color: brg.settings.dividerColor
      Layout.leftMargin: 2
      Layout.rightMargin: 2
    }

    // ── Colour (the output palette) — grouped with the options panel past the divider ────────────
    //
    // project leadership, 2026-07-19: *"the color picker goes in the top bar at the right."* Moved to the
    // RIGHT of the divider 2026-08-03 so it groups with the "!" options panel. A VIEW setting — no
    // save byte; its face is the four colours it is currently painting with.
    ColourPicker { id: colourPicker }

    // ── The abnormal-values options panel (!) — hard right ───────────────────────────────────────
    //
    // Was a single "show useless edits" toggle; now a dropdown panel of TIERS of abnormal options
    // (project leadership, 2026-08-03). The face's little light says which tier is currently revealed:
    //   • grey  — nothing abnormal shown
    //   • blue  — Tier 2 only (no-effect edits: overwritten on load, read-only, or never read)
    //   • amber — Tier 1 (unused / unstable: the game DOES act on them, with unintended effects)
    //
    // The tiers are two independent switches, each turning its whole class on across the map screen.
    // Tier 1 also governs the unused/glitch MAPS in the selection list (brg.map.showUnused).
    Item {
      id: optionsButton
      objectName: "mapOptionsButton"   // the DEBUG harness drives the panel through this
      implicitWidth: 30
      implicitHeight: 26

      /// Open/shut by name for the harness / screenshot review.
      property bool openState: false
      onOpenStateChanged: openState ? optionsPop.open() : optionsPop.close()

      readonly property bool t1: brg.map.showUnused    // unused / unstable (dangerous)
      readonly property bool t2: brg.map.showScratch   // no-effect (harmless)

      Rectangle {
        id: optionsFace
        anchors.fill: parent
        radius: 13

        color: (optHover.hovered || optionsButton.openState) ? Qt.rgba(0, 0, 0, 0.10)
             : Qt.rgba(0, 0, 0, 0.05)
        border.width: 1
        border.color: optionsButton.t1 ? "#b3261e"
                    : optionsButton.t2 ? "#3a6ea5"
                    : brg.settings.dividerColor
        Behavior on color { ColorAnimation { duration: 90 } }

        Text {
          anchors.centerIn: parent
          text: "!"
          font.pixelSize: 13
          font.bold: true
          color: optionsButton.t1 ? "#b3261e"
               : optionsButton.t2 ? "#3a6ea5"
               : brg.settings.textColorMid
          opacity: (optionsButton.t1 || optionsButton.t2) ? 1.0 : 0.55
        }

        // The "level" light — a small dot, top-right, coloured by the highest tier currently shown.
        Rectangle {
          width: 7; height: 7; radius: 3.5
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: 2
          visible: optionsButton.t1 || optionsButton.t2
          color: optionsButton.t1 ? "#e53935" : "#42a5f5"
          border.width: 1
          border.color: "#ffffff"
        }
      }

      HoverHandler { id: optHover; cursorShape: Qt.PointingHandCursor }
      TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: optionsButton.openState = !optionsButton.openState
      }

      MapToolTip {
        shown: optHover.hovered && !optionsButton.openState
        text: qsTr("Uncommon options — reveal abnormal values the app normally hides: unused/unstable "
                   + "ones the game acts on with unintended effects, and no-effect ones it overwrites "
                   + "or never reads.")
      }

      Popup {
        id: optionsPop
        y: optionsButton.height + 6
        x: optionsButton.width - width   // right-aligned under the chip, stays inside the window
        width: 288
        padding: 10
        margins: 8
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
        onClosed: optionsButton.openState = false

        background: Rectangle {
          color: "#ffffff"
          radius: 6
          border.width: 1
          border.color: brg.settings.dividerColor
        }

        ColumnLayout {
          anchors.fill: parent
          spacing: 8

          Text {
            Layout.fillWidth: true
            text: qsTr("Uncommon options")
            font.pixelSize: 11
            font.bold: true
            color: brg.settings.textColorMid
          }

          // ── Tier 1: Unused / unstable — the game acts on them, with unintended effects ──────────
          OptionTierRow {
            Layout.fillWidth: true
            dotColor: "#e53935"
            title: qsTr("Unused & unstable")
            blurb: qsTr("Values the game does read and act on, but that are unused, unfinished, or "
                        + "developer leftovers — editing them has real, often unintended effects "
                        + "(glitches, even crashes). Also shows the unused/glitch maps in the list.")
            checked: brg.map.showUnused
            onToggled: brg.map.showUnused = !brg.map.showUnused
          }

          Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: brg.settings.dividerColor }

          // ── Tier 2: No-effect — overwritten on load, read-only, or never read ──────────────────
          OptionTierRow {
            Layout.fillWidth: true
            dotColor: "#42a5f5"
            title: qsTr("No-effect edits")
            blurb: qsTr("Values the game overwrites when it loads your save, or never reads at all — "
                        + "reset scratch, the sprite cache, placeholder and dead flags. Real bytes, "
                        + "all editable — they just have no effect you can keep.")
            checked: brg.map.showScratch
            onToggled: brg.map.showScratch = !brg.map.showScratch
          }
        }
      }
    }
  }
}
