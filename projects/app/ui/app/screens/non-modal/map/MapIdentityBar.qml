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

    [ Pallet Town ⌄ ] [ ⊞ ] [ ▩ ] │ [ ◧ ] ‖ [ ▶♪⌄ ] [ ▶✦⌄ ] [ ▶👣• ] … [ ◧ colour ] │ [ ! ]
      map picker      opts  tiles   contrast   music   anim   walk         palette        scratch

  * The MAP SELECTOR is the title (MapNamePicker). ⊞ (MapPicker) holds the designated maps + the
    stored-size fix; ▩ (TilesetBlocksPicker) holds the tileset & blocks the map draws from — its own
    button since 2026-08-03 (leadership: "break tileset and blocks out into its own button").
  * The PALETTE (ContrastPicker) reads as a percentage and drops a segmented slider.
  * THE THINGS YOU PLAY sit together past a divider: music (♪), tile animation (✦) and people
    walking (👣). Each is a MapSimButton — a ▶/⏸ play zone + a subject icon + an optional ▾. The
    walk carries a small amber dot because its simulation is DESTRUCTIVE (it moves real sprite data).

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
  property alias tilesetPickerOpen: tilesetBlocksPicker.openState
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

    // ── The CONFIG buttons: Map options · Tileset & blocks · Contrast ─────────────────────────
    //
    // Compact icon tool-buttons, each with a ▾ that says "I drop a menu" (project leadership). Where a
    // reactive icon is natural it is one: Contrast IS its live four-shade swatch, ⊞ carries an amber
    // dot when the map's stored size is stale, ▩ carries one when its blocks and graphics disagree.
    // They share MapBarButton, so they read as a family.

    // ── Map options (⊞): designated maps (Outside is / Wake up at) + the stored-size fix ────────
    MapPicker { id: mapPicker; objectName: "mapPickerControl" }

    // ── Tileset & blocks (▩): the graphics the map draws from, and the blocks it is built out of ─
    //
    // Its own button next to ⊞ (project leadership, 2026-08-03: *"break tileset and blocks out into its own
    // button next to designated maps"*) — it used to be an "Override…" disclosure inside ⊞'s panel.
    TilesetBlocksPicker { id: tilesetBlocksPicker; objectName: "tilesetBlocksControl" }

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

      // ── Tile animation — ▶/⏸ ✦ ▾ — the SAFE, default one ────────────────────────────────────
      //
      // The play zone toggles the map clock directly (leadership: "a play button … that defaults to
      // tile animation"); the ▾ drops the speed / step / description. ✦ reads as "the map shimmering"
      // and is free of the panel glyphs (✿ is Wild Pokémon, ▦ is the Blocks & Tiles dock).
      Item {
        id: animWrap
        objectName: "animGroup"   // the screenshot review drives the panel through this
        implicitWidth: animBtn.implicitWidth
        implicitHeight: 26

        property bool menuOpen: false

        MapSimButton {
          id: animBtn
          objectName: "animChip"

          glyph: "✦"

          playing: brg.mapClock.playing
          playEnabled: brg.mapClock.animates
          playTip: !brg.mapClock.animates
                     ? qsTr("This map has nothing that animates")
                     : brg.mapClock.playing ? qsTr("Stop") : qsTr("Play the tile animation")
          onToggled: brg.mapClock.playing = !brg.mapClock.playing

          hasMenu: true
          menuOpen: animWrap.menuOpen
          menuTip: qsTr("Tile animation — the water and the flowers")
          onMenuToggled: animWrap.menuOpen = !animWrap.menuOpen
        }

        // ── The tile-animation panel: speed, step, a word on what animates ─────────────────────
        Popup {
          visible: animWrap.menuOpen
          onClosed: animWrap.menuOpen = false

          y: animWrap.height + 5
          x: -40
          width: 230
          padding: 12
          margins: 8   // keep it inside the window at the semi-fluid minimum (never clip the bottom)

          background: Rectangle {
            color: "#ffffff"; radius: 8
            border.width: 1; border.color: brg.settings.dividerColor
          }

          ColumnLayout {
            width: parent.width
            spacing: 8

            Label {
              text: qsTr("Tile animation")
              font.pixelSize: 12; font.bold: true
              color: brg.settings.textColorMid
            }

            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: brg.settings.dividerColor }

            Label {
              Layout.fillWidth: true
              wrapMode: Text.Wrap
              text: brg.mapClock.animates
                      ? qsTr("The water and the flowers, moving at the console's own pace.")
                      : qsTr("This map has nothing that animates.")
              font.pixelSize: 10
              opacity: 0.6
            }

            RowLayout {
              Layout.fillWidth: true
              visible: brg.mapClock.animates
              spacing: 4

              Label { text: qsTr("Speed"); font.pixelSize: 11; color: brg.settings.textColorMid }

              Repeater {
                model: [ { s: 0.5, label: "½×" }, { s: 1.0, label: "1×" }, { s: 2.0, label: "2×" } ]

                delegate: Rectangle {
                  required property var modelData
                  Layout.fillWidth: true
                  implicitHeight: 24
                  radius: 5

                  readonly property bool on: Math.abs(brg.mapClock.speed - modelData.s) < 0.01

                  color: on ? brg.settings.accentColor
                       : spdHover.hovered ? "#f0f0f0" : "#ffffff"
                  border.width: 1; border.color: brg.settings.dividerColor

                  Label {
                    anchors.centerIn: parent
                    text: modelData.label
                    font.pixelSize: 11; font.bold: parent.on
                    color: parent.on ? brg.settings.textColorLight : brg.settings.textColorDark
                  }

                  HoverHandler { id: spdHover; cursorShape: Qt.PointingHandCursor }
                  TapHandler { onTapped: brg.mapClock.speed = modelData.s }
                }
              }

              Rectangle {
                implicitWidth: stepRow.implicitWidth + 10
                implicitHeight: 24
                radius: 5
                color: stepHover.hovered ? "#f0f0f0" : "#ffffff"
                border.width: 1; border.color: brg.settings.dividerColor

                RowLayout {
                  id: stepRow
                  anchors.centerIn: parent
                  spacing: 2
                  Label { text: "⏭"; font.pixelSize: 11 }
                }

                HoverHandler { id: stepHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: brg.mapClock.step() }

                MapToolTip { shown: stepHover.hovered; text: qsTr("Step one frame") }
              }
            }
          }
        }
      }

      // ── People walking — ▶/⏸ 👣 — its OWN button, marked DESTRUCTIVE ─────────────────────────
      //
      // The footprints read as "people walking"; the amber dot is the app's "attention" idiom, here
      // because this simulation MOVES the real sprite data. First press asks once (SimWarningDialog);
      // after that ▶ runs it. No menu — it is a play button, and the caution lives on its face + tip.
      MapSimButton {
        id: walkBtn
        objectName: "walkChip"

        iconSource: "qrc:/assets/icons/footprints.svg"
        iconSourcePlaying: "qrc:/assets/icons/footprints-light.svg"
        marked: true

        playing: brg.mapSim.playing
        playEnabled: brg.mapSim.canSimulate
        playTip: !brg.mapSim.canSimulate
                   ? qsTr("Nobody on this map can walk — they are all set to Stay")
                   : brg.mapSim.playing ? qsTr("Stop the walk")
                   : qsTr("Let the people walk — ⚠️ this MOVES the real sprite data")
        onToggled: {
          if (brg.mapSim.playing) {
            brg.mapSim.playing = false;
            return;
          }
          if (brg.settings.mapSimWarned)
            brg.mapSim.playing = true;
          else
            simWarning.open();
        }

        hasMenu: false
      }
    }

    SimWarningDialog {
      id: simWarning
      onAccepted: brg.mapSim.playing = true
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
