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
 * ☺ **CHARACTER STATE** -- the nine map-global flags that govern how ALL the map's characters behave.
 *
 * NOT per-NPC (that is a sprite you click on the canvas, edited in Details). These belong to the MAP,
 * which is why they are a **right-dock panel**, beside the other things you edit about the map itself.
 * v1 shipped them as its "NPC" page with three wrong labels; every field here carries the name of what
 * it actually does and a sentence saying what that means.
 *
 * ## Useless edits hide behind the toolbar "!" (project leadership, 2026-07-18 -- supersedes 2026-07-15)
 *
 * The four flags the game rewrites on load are USELESS EDITS (*"character state is still littered
 * with useless fields"*): they hide unless the toolbar's "!" gate is on, and when shown they wear
 * the ⚠ mark saying why. The five durable flags show always. (The earlier "no hidden fields, mark
 * them instead" ruling of 2026-07-15 is superseded by the one-gate-for-the-whole-screen standard.)
 *
 * ## Persistence, verified on a real cartridge
 *
 * `scripts/emu/probe_npc_character_state.py` stamped all nine and booted the ROM. Four are rewritten on
 * load (⚠ -- an edit is momentary): the two Sprites bits are zeroed with the whole status byte, and
 * "Ignore player input" / "Scripted-movement active" are cleared to hand you back the controls. The
 * other five keep the value you write. @see notes/reference/npc-character-state.md
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
  id: panel
  objectName: "mapCharacterState"

  /// The panel's one title-bar "?" (MapDock renders it).
  readonly property string panelInfo: qsTr(
    "Flags that govern how ALL the characters on this map behave — whether NPCs turn to face you, "
    + "whether a scripted cutscene has the controls, whether a trainer battle is queued.\n\n"
    + "They belong to the map you're standing on, not to any one person — which is why they're here "
    + "and not in a character's own panel. Click a character on the map to edit that one.\n\n"
    + "A ⚠ means the game rewrites this the moment it loads your save (verified on a real Game Boy). "
    + "It's still yours to set — nothing here is hidden, refused, or changed behind your back.")

  /// Harness-visible: the panel resolved its data.
  readonly property bool diagReady: panel.npc !== null

  // BINDINGS, not an imperative refresh -- the panel is built by a Loader and `npc` must re-resolve
  // when a different map is loaded. `revision` is the dependency a plain property access would miss.
  property int revision: 0
  Connections {
    target: brg.map
    function onChanged() { panel.revision++; }
  }

  readonly property var npc: {
    panel.revision;   // a dependency, deliberately
    return brg.file.data.dataExpanded.area.npc;
  }

  // ── one toggle row: name, its ⚠ (if the game rewrites it), the switch, the "?" for the words ──
  //
  // ⚠️ A REWRITTEN-ON-LOAD row is a USELESS EDIT (leadership's word, 2026-07-18: *"character
  // state is still littered with useless fields"*) and hides behind the toolbar's "!" — the one
  // gate for the whole screen. This SUPERSEDES the earlier "no hidden fields, mark them instead"
  // ruling (2026-07-15): the mark stays, and the row only appears when the gate is on.
  // The per-row blurb moved behind a "?" -- one-line rows, panel-wide standard.
  // ⭐ ONE GATE PER ROW, AND ONLY ONE (project leadership, 2026-08-18): *"An option is ONLY gated by 1
  // box. An option NEVER requires 2 or more gates to be enabled for it to show, just like an option will
  // never BELONG to any more than 1 gate only."* Hence a single `gate` STRING rather than a set of
  // booleans — the type makes the rule unbreakable, because there is nowhere to put a second one.
  //
  //   ""          — always shown
  //   "scratch"   — no-effect: the game rewrites or never reads it            → the "!" panel
  //   "tinkerer"  — real, but a finicky mid-motion state to resume into       → the 🔧 panel
  //   "debug"     — the game's own development leftovers                      → the 🔧 panel
  //
  // ⚠️ When a row is BOTH rewritten-on-load and finicky, "scratch" wins. Not a tie-break for its own
  // sake: "the game will throw this away" is the fact that decides whether editing it is worth anyone's
  // time, and it must not be reachable from a gate that doesn't say so.
  readonly property var gateOn: ({
    "":         true,
    "scratch":  brg.map.showScratch,
    "tinkerer": brg.map.showTinkerer,
    "debug":    brg.map.showDebug
  })

  component FlagRow: RowLayout {
    id: row
    property string title: ""
    property string blurb: ""
    property bool rewritten: false          // the game zeroes/clears this on load
    property string rewrittenWhy: ""
    property string gate: ""                // "" | "scratch" | "tinkerer" | "debug" — exactly one
    property bool value: false
    signal toggle()

    Layout.fillWidth: true
    spacing: 6
    visible: panel.gateOn[row.gate === "" && row.rewritten ? "scratch" : row.gate]

    MapWarnIcon {
      visible: row.rewritten
      text: row.rewrittenWhy
    }

    Label {
      text: row.title
      font.pixelSize: 12
      color: brg.settings.textColorDark
      Layout.fillWidth: true
      elide: Text.ElideRight
    }

    MapInfoIcon {
      visible: row.blurb !== ""
      text: row.blurb
    }

    MapSwitch {
      checked: row.value
      onToggled: row.toggle()
    }
  }

  component GroupHeading: Label {
    Layout.fillWidth: true
    Layout.topMargin: 10
    font.pixelSize: 11
    font.bold: true
    opacity: 0.55
  }

  readonly property string zeroedWhy: qsTr("The game zeroes this whole status byte every time it "
    + "loads a save — so this can't survive. Verified on a real cartridge.")
  readonly property string clearedWhy: qsTr("The game clears this when it loads your save, to hand "
    + "the controls back to you. Verified on a real cartridge.")

  ScrollView {
    id: scroller
    anchors.fill: parent
    clip: true
    contentWidth: availableWidth
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

    // Reserve the 16px scrollbar lane (ui-patterns.md rule 2) so the right-anchored switches and ⚠
    // marks never end up under the overlay bar.
    ColumnLayout {
      width: scroller.availableWidth - 22
      spacing: 6

      ColumnLayout {
        Layout.fillWidth: true
        Layout.margins: 10
        spacing: 4

        Label {
          Layout.fillWidth: true
          text: qsTr("How the characters on this map behave")
          wrapMode: Text.Wrap
          opacity: 0.6
          font.pixelSize: 11
        }

        // ── Sprites — both zeroed on load ──────────────────────────────────────────────────────
        GroupHeading {
          text: qsTr("Sprites")
          visible: brg.map.showScratch   // both of its rows are useless edits
        }

        FlagRow {
          title: qsTr("Don't face the player when talked to")
          blurb: qsTr("Normally an NPC turns to look at you when you talk to it. Set this and they "
                      + "won't — used mid-cutscene.")
          rewritten: true; rewrittenWhy: panel.zeroedWhy
          value: panel.npc.npcsDoNotFacePlayer
          onToggle: panel.npc.npcsDoNotFacePlayer = !panel.npc.npcsDoNotFacePlayer
        }

        FlagRow {
          title: qsTr("Trade-center sprites have faced")
          blurb: qsTr("Link Trade Center only: the two trading sprites have turned to face each "
                      + "other. It means nothing in a single-player save.")
          rewritten: true; rewrittenWhy: panel.zeroedWhy
          value: panel.npc.initTradeCenterFacing
          onToggle: panel.npc.initTradeCenterFacing = !panel.npc.initTradeCenterFacing
        }

        // ── Controls — two kept, two cleared ───────────────────────────────────────────────────
        // A heading with nothing under it is worse than no heading, so each one carries the OR of its
        // own rows' gates. @see `gatesAnyRow` for why the panel itself follows the same rule.
        GroupHeading {
          text: qsTr("Controls")
          visible: brg.map.showTinkerer || brg.map.showScratch
        }

        // Both survive a save (console-verified — reference/npc-character-state.md), so they are NOT
        // no-effect edits; they are simply a state a save should never be sitting in. That is the
        // Tinkerer gate exactly (project leadership, 2026-08-18, naming "scripted walk" among its
        // contents).
        FlagRow {
          gate: "tinkerer"
          title: qsTr("Scripted walk — starting")
          blurb: qsTr("A scripted walk is about to begin this frame. Cutscene machinery — 0 in any "
                      + "normal save.")
          value: panel.npc.initScriptedMovement
          onToggle: panel.npc.initScriptedMovement = !panel.npc.initScriptedMovement
        }

        FlagRow {
          gate: "tinkerer"
          title: qsTr("Scripted walk — running")
          blurb: qsTr("A sprite is currently being walked by a script. Cutscene machinery — 0 in any "
                      + "normal save.")
          value: panel.npc.scriptedNpcMoving
          onToggle: panel.npc.scriptedNpcMoving = !panel.npc.scriptedNpcMoving
        }

        FlagRow {
          title: qsTr("Ignore player input")
          blurb: qsTr("Your buttons are ignored while a cutscene has the controls.")
          rewritten: true; rewrittenWhy: panel.clearedWhy
          value: panel.npc.disableJoypad
          onToggle: panel.npc.disableJoypad = !panel.npc.disableJoypad
        }

        FlagRow {
          title: qsTr("Scripted walk — active")
          blurb: qsTr("The game is in the middle of running a scripted-movement sequence.")
          rewritten: true; rewrittenWhy: panel.clearedWhy
          value: panel.npc.scriptedMovementActive
          onToggle: panel.npc.scriptedMovementActive = !panel.npc.scriptedMovementActive
        }

        // ── Battle — two kept, plus the pointer ────────────────────────────────────────────────
        GroupHeading {
          text: qsTr("Battle")
          visible: brg.map.showTinkerer || brg.map.showDebug || brg.map.showScratch
        }

        FlagRow {
          gate: "tinkerer"
          title: qsTr("Trainer battle queued")
          blurb: qsTr("The battle about to start is a trainer's (not a wild encounter).")
          value: panel.npc.trainerBattle
          onToggle: panel.npc.trainerBattle = !panel.npc.trainerBattle
        }

        // ⭐ THE DEBUG GATE'S FOUNDING MEMBER (project leadership, 2026-08-18): *"Unused and unstable
        // should no longer include debug or developer stuff, that is moved to its own gate out of
        // unused and unstable."* It was the one row that made "unused & unstable" have to describe
        // itself as covering "developer leftovers" too — now that tier is a single clean idea again.
        FlagRow {
          gate: "debug"
          title: qsTr("Test battle (debug)")
          blurb: qsTr("A leftover debug flag the retail game never sets. Included because every byte "
                      + "is yours to edit.")
          value: panel.npc.testBattle
          onToggle: panel.npc.testBattle = !panel.npc.testBattle
        }

        // The trainer-header pointer. Researched (reference/npc-character-state.md §4a): it is
        // TRANSIENT scratch the game sets only during a trainer engagement and never reads back from a
        // save, so a "resolve to a named trainer" picker would be false precision over a leftover value
        // (and would need per-map ROM header addresses we don't carry). The honest treatment: explain
        // it, keep the full-range hex (nothing refused), and offer a one-click Clear for the leftover.
        //
        // ⭐ AND IT IS GATED. Project leadership, 2026-08-18: *"Trainer pointer should be in useless
        // options"* — and by the panel's own research it plainly is one: the game writes it while a
        // trainer battle starts and never reads it back out of a save, which is the definition of a
        // no-effect edit. It was explaining that in prose while sitting in the open; now it explains
        // it behind the "!", with the rest of its kind.
        ColumnLayout {
          Layout.fillWidth: true
          Layout.topMargin: 6
          spacing: 2
          visible: brg.map.showScratch

          RowLayout {
            Layout.fillWidth: true
            Label {
              text: qsTr("Trainer pointer")
              font.pixelSize: 12
              color: brg.settings.textColorDark
              Layout.fillWidth: true
            }
            // Tidy the leftover -- only offered when there's something to clear.
            Text {
              visible: panel.npc.trainerHeaderPtr !== 0
              text: qsTr("Clear")
              font.pixelSize: 10
              font.underline: clearArea.containsMouse
              color: brg.settings.accentColor
              MouseArea {
                id: clearArea
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: panel.npc.trainerHeaderPtr = 0
              }
            }
          }
          Label {
            Layout.fillWidth: true
            text: qsTr("A ROM pointer the game sets only while a trainer battle starts, and never reads "
                       + "back from a save — so it's a harmless leftover here, not a setting. Editable "
                       + "anyway (full range). Real trainer editing lives on the map's trainer sprites.")
            wrapMode: Text.Wrap
            font.pixelSize: 10
            opacity: 0.55
          }

          TextField {
            id: ptrField
            Layout.fillWidth: true
            Layout.topMargin: 2
            font.pixelSize: 12
            inputMask: "\\0\\xHHHH"
            text: "0x" + Number(panel.npc.trainerHeaderPtr).toString(16).toUpperCase().padStart(4, "0")
            onEditingFinished: {
              const v = parseInt(text, 16);
              if (!isNaN(v))
                panel.npc.trainerHeaderPtr = v & 0xFFFF;
            }
          }
        }

        Item { Layout.preferredHeight: 12 }   // breathing room at the bottom of the scroll
      }
    }
  }
}
