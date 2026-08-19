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
  MapNamePicker.qml -- the map's NAME, and it IS the map selector. Clicking it drops the MAP SELECTION
  PANEL: the grouped map list you pick from, AND the tileset & blockset the map draws from.

  project leadership, 2026-08-03: *"tileset and blockset belong in the map-selection panel, not with the
  designated maps."* So the graphics/blocks a map is drawn from live HERE, in the same dropdown you pick
  the map from — because they ARE part of choosing what map you're looking at. The designated maps
  (Outside is / Wake up at — world routing, a different concern) stay in the ⊞ panel beside this.

  The map list sits at the top so it stays directly selectable the moment the panel opens — you never
  have to open a second panel to change the map, the tileset or the blocks.
*/
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
  id: root
  objectName: "mapNamePicker"

  implicitWidth: face.implicitWidth
  implicitHeight: 26
  Layout.maximumWidth: 210

  /// Drive the drop-down open/shut by name (the DEBUG harness / screenshot review).
  property bool openState: false
  onOpenStateChanged: openState ? pop.open() : pop.close()

  /// The tileset & blocks controls live behind a "More settings" disclosure — collapsed by default so
  /// the panel is just the map picker until you ask for more (project leadership, 2026-08-03).
  property bool advancedOpen: false

  /// Tileset & blocks: ONE combined selector by default, or two separate ones. The user chooses with
  /// explicit "Separate" / "Merge" buttons (project leadership, 2026-08-03). We always show the split
  /// view when the save's tileset and blocks genuinely differ — one combo can't represent two values.
  property bool blocksSeparated: false
  readonly property bool blocksSplitShown: blocksSeparated || !brg.map.blocksetIsTileset

  /// Tile-animation explanation, as organised bullet points (project leadership, 2026-08-04). The save
  /// byte (tileset 0x3522) is tri-state 0/1/2 = Indoor/Cave/Outdoor; a hack value >2 is read by the
  /// console on bit 0 alone, so it collapses onto water-only (odd) or water+flower (even). @see
  /// notes/reference/map-animation.md. `animEff` is that collapsed 0/1/2; `animBullets` is the list.
  /// New in a structure meant to GROW — add a fact by pushing another line.
  readonly property int animEff: {
    const v = brg.map.tileAnim;
    if (v === 0) return 0;
    return (v % 2 === 1) ? 1 : 2;   // odd → water-only, even → water+flower
  }
  /// Does THIS tileset's tile $14 really hold water, and tile $03 really hold a flower? `hasWater`
  /// is a real tile trait; `hasFlower` is exact too — the flower is native only to the tileset whose
  /// canonical animation includes it (default == Outdoor/2, i.e. OVERWORLD). @see map-animation.md.
  readonly property bool tsHasWater: brg.map.tilesetHasWater
  readonly property bool tsHasFlower: brg.map.tileAnimDefault === 2

  // ⚠️ NO "this is the tileset's own setting" BULLET, and no name for the default here.
  //
  // One was added and struck out the same day (leadership, 2026-08-18): *"Dont have tilesets own
  // setting — its not a pro or con, its just a map default option, its what the green dot is for."*
  // Right on both counts: the bullets are a list of what WORKS and what DOESN'T, and "this is the
  // default" is neither. The segment strip's green dot already says it, in the one place where it is
  // actually useful — on the segment you would click.

  /// Each entry is { text, pos, warn } — pos true → a green "+" (working), false → a red "−" (not);
  /// { text, note: true } → an amber "⚠" for a glitch value; and a non-empty `warn` adds a hoverable
  /// yellow "!" at the end whose tooltip explains a real gotcha.
  ///
  /// ⚠️ **PLAIN ENGLISH. NO TECHNICAL BREAKDOWN.** Project leadership, 2026-08-18, after a pass that
  /// went the other way: *"I dont want technical info dumps like 21 frames bytes rotated — this isnt
  /// plain english, this is technical jargon and its not nesesarily more useful for any group of
  /// people. Before i worded it better ... just describing it as distorting the wave tile."*
  ///
  /// The rule this section is written to: **say what you will SEE, not how the console does it.** The
  /// frame cadence, the byte rotation and the flower's frame order are all true and all documented in
  /// `notes/reference/map-animation.md` — which is where they belong. A person choosing between
  /// Indoor, Cave and Outdoor wants to know what changes on their map.
  ///
  /// What each bullet does carry is the ASSERTION, because we can check it: this tileset's $14 either
  /// is water or is not, and saying which is more useful than hedging "usually". "Usually" is the
  /// fallback for when we genuinely cannot tell.
  readonly property var animBullets: {
    const eff = root.animEff;
    const raw = brg.map.tileAnim;
    const water = root.tsHasWater;
    const flower = root.tsHasFlower;
    const b = [];

    // ── Surf ─────────────────────────────────────────────────────────────────────────────────
    //
    // ⚠️ NOT conditioned on whether they are surfing RIGHT NOW. Project leadership: *"Dont determine
    // surfing by if the player is actively surfing — most of the time they may not be, just because
    // there not doesnt mean the map is ok to make non-surfable."* Exactly right: this is a property of
    // the SETTING, and a save sitting on dry land today is one step away from needing it.
    //
    // It stays a plain "+"/"−" with no "!" — the earlier version warned whenever a map merely had
    // water, which is what made it shout about Silph Co's ornamental pond.
    b.push(eff === 0
      ? { text: qsTr("Surf can't be used on this setting"), pos: false, warn: "" }
      : { text: qsTr("Surf works on this setting"), pos: true, warn: "" });

    // ── Water, tile $14 ──────────────────────────────────────────────────────────────────────
    //
    // The conflict cuts both ways: a tileset with no water at $14 still gets the distortion, and it
    // lands on whatever graphic is sitting there instead.
    b.push(eff === 0
      ? { text: water
                ? qsTr("This tileset's water tile ($14) won't get wave distortions")
                : qsTr("Tile $14 won't get wave distortions"),
          pos: false, warn: "" }
      : { text: water
                ? qsTr("This tileset's water tile ($14) gets wave distortions")
                : qsTr("Tile $14 gets wave distortions — it isn't water on this tileset"),
          pos: !!water,
          warn: water ? "" : qsTr("This tileset's tile $14 isn't water. The wave distortion still "
                                  + "runs, and it distorts whatever graphic is sitting there.") });

    // ── The flower, tile $03 ─────────────────────────────────────────────────────────────────
    //
    // Same shape, and "replaced" is the important word — the flower is copied over $03 rather than
    // animating it, so on a tileset whose $03 is something else, that graphic is gone while this
    // setting is on.
    b.push(eff === 2
      ? { text: flower
                ? qsTr("This tileset's flower tile ($03) will be replaced by flower animation frames")
                : qsTr("This tileset's tile $03 isn't a flower, and will be replaced by flower "
                       + "animation frames"),
          pos: !!flower,
          warn: flower ? "" : qsTr("This tileset's tile $03 isn't a flower. It will be replaced "
                                   + "entirely by the flower animation frames.") }
      : { text: flower
                ? qsTr("This tileset's flower tile ($03) will not be replaced by flower animation "
                       + "frames")
                : qsTr("Tile $03 will not be replaced by flower animation frames"),
          pos: !flower, warn: "" });

    // ── A byte the game itself could never have written ──────────────────────────────────────
    //
    // Not garbage and not a crash — the console only looks at whether it is zero and then at its
    // lowest bit, so anything above 2 lands on one of the two real settings. Say WHICH, because
    // "glitch value" on its own tells you nothing about what you will see.
    if (raw > 2)
      b.push({ text: (raw % 2 === 1)
                     ? qsTr("Value %1 is a glitch value — it behaves like Cave").arg(raw)
                     : qsTr("Value %1 is a glitch value — it behaves like Outdoor").arg(raw),
               note: true, warn: "" });

    return b;
  }

  /// ⚠️ RETIRED — always false. Project leadership, 2026-08-18: *"Forgo the exclamation mark, just
  /// keep the green dot on the default."*
  ///
  /// The segment used to wear a yellow "!" whenever the current setting raised any caution
  /// (2026-08-04). It was one mark too many: the three bullets underneath already say, in words, what
  /// is and is not working — the badge repeated them without adding anything, and two competing marks
  /// on one small control read as noise. The **green default dot stays** (it answers a question the
  /// bullets cannot: which of these is this tileset's own).
  ///
  /// The per-bullet "!" is untouched — that one hangs off the specific sentence it qualifies, which
  /// is the whole difference.
  readonly property bool animHasWarning: false

  // ── The face: the bold map name + a ▾ that says "I drop a menu" ────────────────────────────────
  Rectangle {
    id: face
    anchors.fill: parent
    radius: 6
    implicitWidth: faceRow.implicitWidth + 14

    color: (faceHover.hovered || root.openState) ? Qt.rgba(0, 0, 0, 0.06) : "transparent"
    Behavior on color { ColorAnimation { duration: 90 } }

    RowLayout {
      id: faceRow
      anchors.fill: parent
      anchors.leftMargin: 7
      anchors.rightMargin: 7
      spacing: 5

      Label {
        Layout.fillWidth: true
        text: brg.map.valid ? brg.map.mapName : qsTr("No map")
        font.pixelSize: 14
        font.bold: true
        color: brg.settings.textColorDark
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
      }

      Text {
        text: "⌄"
        font.pixelSize: 11
        color: brg.settings.textColorMid
        opacity: 0.85
        Layout.alignment: Qt.AlignVCenter
      }
    }

    HoverHandler { id: faceHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: root.openState = !root.openState }
  }

  // ── The map-selection panel ─────────────────────────────────────────────────────────────────
  Popup {
    id: pop

    y: root.height + 4
    width: 320
    padding: 10
    margins: 8   // keep inside the window at the 750×480 minimum

    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
    onClosed: root.openState = false   // sync the button highlight on click-off/Escape @see MapPicker

    background: Rectangle {
      color: "#ffffff"
      radius: 6
      border.width: 1
      border.color: brg.settings.dividerColor
    }

    ColumnLayout {
      anchors.fill: parent
      spacing: 8

      // ── The map list — the ONE shared map selector (sort · search · list) ──────────────────────
      // Extracted to MapSelectList so every place that picks a map uses the same control (project
      // leadership, 2026-08-04). Picking previews on the canvas (doesn't commit) and closes the panel.
      // @see MapModel::beginMapPreview, the Preview card in MapCanvas.
      MapSelectList {
        Layout.fillWidth: true
        listHeight: 114   // ~3 rows + internal scroll — short of the window edges
        selectedInd: brg.map.mapInd
        onPicked: (ind) => { brg.map.beginMapPreview(ind); root.openState = false; }
      }

      Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: brg.settings.dividerColor }

      // ── "Tileset & blocks" — collapsed behind a disclosure so the panel stays a clean map picker ──
      // project leadership, 2026-08-03: hide the graphics/blocks behind a more-settings link.
      // The Separate/Merge switch lives on the RIGHT of this header (project leadership, 2026-08-04) —
      // out of the "Tileset" control row, where as a full Button it inflated the row and left a gap.
      RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Text {
          text: (root.advancedOpen ? "▾  " : "▸  ") + qsTr("Tileset & blocks")
          font.pixelSize: 11
          font.bold: true
          color: moreHover.hovered ? brg.settings.textColorDark : brg.settings.textColorMid
          HoverHandler { id: moreHover; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: root.advancedOpen = !root.advancedOpen }
        }

        Item { Layout.fillWidth: true }

        // One switch, both directions: "Separate" when combined, "Merge" when split. Merge writes
        // blocks := tileset (the existing behaviour); Separate just reveals the second control.
        Text {
          visible: root.advancedOpen
          text: root.blocksSplitShown ? qsTr("Merge") : qsTr("Separate")
          font.pixelSize: 10
          font.bold: true
          color: mergeHover.hovered ? brg.settings.textColorDark : brg.settings.accentColor
          HoverHandler { id: mergeHover; cursorShape: Qt.PointingHandCursor }
          TapHandler {
            onTapped: {
              if (root.blocksSplitShown) {
                brg.map.blocksetInd = brg.map.tilesetInd;
                root.blocksSeparated = false;
              } else {
                root.blocksSeparated = true;
              }
            }
          }
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        visible: root.advancedOpen
        spacing: 8

        // ONE combined selector by default; the "Separate" / "Merge" buttons switch between one control
        // (tiles & blocks move together) and two (each set on its own). The split view also shows
        // whenever the save's two values genuinely differ. (project leadership, 2026-08-03.)

        // ── Combined selector (one control, moves both) ──
        RowLayout {
          Layout.fillWidth: true
          visible: !root.blocksSplitShown
          spacing: 6

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
            // The combined selector moves BOTH — the whole point of combining them.
            onActivated: { brg.map.tilesetInd = currentValue; brg.map.blocksetInd = currentValue; }
          }

          FieldButtons {
            Layout.alignment: Qt.AlignVCenter
            showRevert: true
            onRandomize: { brg.map.randomizeTileset(); brg.map.blocksetInd = brg.map.tilesetInd; }
            onRevert: { brg.map.revertTileset(); brg.map.revertBlockset(); }
          }
        }

        // ── Split selectors (two controls) ──
        ColumnLayout {
          Layout.fillWidth: true
          visible: root.blocksSplitShown
          spacing: 6

          Text {
            Layout.fillWidth: true
            text: qsTr("Tileset")
            font.pixelSize: 10
            color: brg.settings.textColorMid
          }
          RowLayout {
            Layout.fillWidth: true
            spacing: 6
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
            FieldButtons {
              Layout.alignment: Qt.AlignVCenter
              showRevert: true
              onRandomize: brg.map.randomizeTileset()
              onRevert: brg.map.revertTileset()
            }
          }

          Text {
            Layout.fillWidth: true
            text: qsTr("Blocks")
            font.pixelSize: 10
            color: brg.settings.textColorMid
          }
          RowLayout {
            Layout.fillWidth: true
            spacing: 6
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
                return -1;
              }
              onActivated: brg.map.blocksetInd = currentValue
            }
            FieldButtons {
              Layout.alignment: Qt.AlignVCenter
              showRevert: true
              onRandomize: brg.map.randomizeBlockset()
              onRevert: brg.map.revertBlockset()
            }
          }

          // If the two genuinely differ, say what the game would draw (a fact, not an alarm).
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

        // ── Tile Animation ──────────────────────────────────────────────────────────────────────
        // Its own titled group now (project leadership, 2026-08-04). Indoor / Cave / Outdoor picks which
        // tiles MOVE (the tileset's 0x3522 byte). Cave is not Indoor: cave water animates.
        // Same label weight as "Tileset" / "Blocks" — it's a peer control, not a bigger heading.
        // Only shown in the SPLIT view, where those two labels exist for it to sit beside; in the
        // merged view (one unlabelled combo) it would be an orphaned heading (project leadership,
        // 2026-08-04).
        Text {
          Layout.fillWidth: true
          Layout.topMargin: 2
          visible: root.blocksSplitShown
          text: qsTr("Tile Animation")
          font.pixelSize: 10
          color: brg.settings.textColorMid
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 0

          Repeater {
            model: [
              { v: 0, name: qsTr("Indoor")  },
              { v: 1, name: qsTr("Cave")    },
              { v: 2, name: qsTr("Outdoor") }
            ]

            Rectangle {
              id: seg
              required property var modelData
              required property int index
              objectName: "animSeg" + index   // the DEBUG harness taps segments by this

              Layout.fillWidth: true
              implicitHeight: 26

              readonly property bool active: brg.map.tileAnim === modelData.v
              readonly property bool isDefault: modelData.v === brg.map.tileAnimDefault

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

              // The label, plus the yellow "!" when THIS is the selected setting and it raises a
              // warning (project leadership, 2026-08-04). MapWarnIcon carries its own hover tooltip.
              RowLayout {
                anchors.centerIn: parent
                spacing: 4

                Text {
                  Layout.alignment: Qt.AlignVCenter
                  text: seg.modelData.name
                  font.pixelSize: 11
                  font.bold: seg.active
                  color: seg.active ? brg.settings.textColorLight : brg.settings.textColorDark
                }

                MapWarnIcon {
                  Layout.alignment: Qt.AlignVCenter
                  visible: seg.active && root.animHasWarning
                  implicitWidth: 13
                  implicitHeight: 13
                  radius: 6.5
                  text: qsTr("This setting raises a warning — see the notes below.")
                }
              }

              // A small green dot marks the tileset's DEFAULT animation (project leadership,
              // 2026-08-04) — "the green default button", shown on whichever segment is native to
              // this map's tileset, active or not.
              Rectangle {
                visible: seg.isDefault
                width: 6; height: 6; radius: 3
                color: "#009e73"
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 3
                anchors.rightMargin: 3

                HoverHandler { id: defHover; cursorShape: Qt.PointingHandCursor }
                MapToolTip {
                  shown: defHover.hovered
                  delay: 300
                  text: qsTr("This is this map's default animation — what its tileset uses on a real cartridge.")
                }
              }
            }
          }
        }

        // The plain-English facts, as bullets (project leadership, 2026-08-04) — one line per fact, so it
        // reads at a glance instead of as a paragraph. Driven by `animBullets` (top of file), which is
        // built to GROW: add a fact by pushing another line there.
        ColumnLayout {
          Layout.fillWidth: true
          Layout.topMargin: 2
          spacing: 3

          Repeater {
            model: root.animBullets

            RowLayout {
              id: bulletRow
              required property var modelData
              Layout.fillWidth: true
              spacing: 6

              // A green "+" when the feature works, a red "−" when it doesn't, an amber "⚠" for a
              // glitch value. Okabe-Ito palette (colourblind-safe) — the app's existing warn colour
              // for the minus, its green for the plus.
              Text {
                text: bulletRow.modelData.note ? "⚠" : (bulletRow.modelData.pos ? "+" : "−")
                font.pixelSize: 11
                font.bold: true
                color: bulletRow.modelData.note ? "#e69f00"
                     : bulletRow.modelData.pos  ? "#009e73"
                                                : "#d55e00"
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 10
                horizontalAlignment: Text.AlignHCenter
              }
              Text {
                Layout.fillWidth: true
                text: bulletRow.modelData.text
                font.pixelSize: 10
                color: brg.settings.textColorMid
                wrapMode: Text.WordWrap
              }

              // A hoverable yellow "!" for a real gotcha (project leadership, 2026-08-04) — the icon IS
              // the affordance (no separate "?"), tooltip on hover. Only when this bullet warns.
              MapWarnIcon {
                Layout.alignment: Qt.AlignTop
                visible: bulletRow.modelData.warn !== undefined && bulletRow.modelData.warn !== ""
                text: bulletRow.modelData.warn !== undefined ? bulletRow.modelData.warn : ""
                tipWidth: 240
              }
            }
          }
        }
      }
    }
  }
}
