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
 * POINTER PICKER -- point a memory address at a square you can see.
 *
 * Project leadership, 2026-08-19, on the connection strip's three raw addresses:
 *
 * > *"i am aware of how hex addresses and memory addresses work, when i asked you for move and drag
 * > handles and stuff, i know we're talking about memory addresses but its silly to say theres no
 * > solution for this. The way i saw it when i asked the question, memory addresses point to ram this
 * > means the start of the blocks are known, i figured handles on the visual map could be relative to
 * > that address somehow either by selecting a block as the starting block for the pointer … Theres no
 * > reason at all the hex addresses just simply have to be that way because there hex addresses, and
 * > that theres no way to make it intuitive and easy."*
 *
 * They were right, and it turned out to be exact rather than approximate. **Not one of the three is a
 * free-floating address.** Each is a base plus an index into a grid this app already draws, and the
 * engine has been composing them that way all along:
 *
 *   | field | base | the grid | stride |
 *   |---|---|---|---|
 *   | Strip source      | the neighbour's blocks in ROM | the **neighbour's map**   | its width |
 *   | Strip destination | `wOverworldMap` (`$C6E8`)     | **our border ring**       | our width + 6 |
 *   | View pointer      | `wOverworldMap` (`$C6E8`)     | the **neighbour's ring**  | their width + 6 |
 *
 * So this popup is not a translation layer over something alien — it is the *same* arithmetic the
 * game does, shown forwards. Pick a square, get an address. @see MapModel::pointerPlace, and
 * notes/reference/map-connections.md (78/78 verified against the cartridge).
 *
 * ⚠️ THE TWO GRIDS ARE NOT THE SAME SHAPE. A **ring** is the map plus its 3-block border, and the
 * rendered image *is* that ring, so block (row, col) is pixel (col*32, row*32) — 1:1, no offset. A
 * **map** grid is the bare map with no border, which sits 3 blocks into the same image. Getting this
 * backwards would put every strip-source pick 3 blocks out in both axes, silently.
 *
 * ⚠️ AN OUT-OF-GRID ADDRESS IS SHOWN, NEVER REFUSED. A save can hold one, the console will read
 * whatever is there, and that is the whole reason somebody is looking at this field. The popup says
 * where it went and offers to bring it back; it does not correct anything on its own.
 *
 * @see notes/plans/map-screen.md -> Phase 5 (connections)
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
  id: picker
  objectName: "pointerPicker"

  /// Which connection (MapDBEntryConnect::ConnectDir) and which raw field we are aiming.
  property int dir: -1
  property string fieldKey: ""
  property string fieldLabel: ""

  /// Bumped by the model's own change signal so the highlight follows an edit made anywhere else.
  property int revision: 0

  Connections {
    target: brg.map
    function onChanged() { picker.revision++; }
  }

  readonly property var place: {
    picker.revision;
    return (picker.dir >= 0 && picker.fieldKey !== "")
      ? brg.map.pointerPlace(picker.dir, picker.fieldKey)
      : ({ valid: false });
  }

  /// One block, in image pixels. The provider draws at one screen pixel per Game Boy pixel.
  readonly property int blockPx: 32
  /// A ring image already includes the border; a bare-map grid starts 3 blocks in. @see the header.
  readonly property int gridOriginBlocks: (picker.place.gridKind === "ring") ? 0 : 3

  /// How much the image is shrunk to fit the popup. Never enlarged past 1:1 — this is pixel art.
  property real zoom: 1

  function openFor(d, key, label) {
    picker.dir = d;
    picker.fieldKey = key;
    picker.fieldLabel = label;
    picker.revision++;
    picker.open();
  }

  modal: true
  dim: true
  focus: true
  closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

  parent: Overlay.overlay
  anchors.centerIn: Overlay.overlay

  width: Math.min(760, Overlay.overlay ? Overlay.overlay.width - 60 : 760)
  height: Math.min(620, Overlay.overlay ? Overlay.overlay.height - 60 : 620)

  padding: 0

  background: Rectangle {
    radius: 8
    color: "#ffffff"
    border.width: 1
    border.color: brg.settings.dividerColor
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 12
    spacing: 8

    // ── What you are aiming, and at what ────────────────────────────────────────────────────
    Label {
      Layout.fillWidth: true
      text: picker.fieldLabel
      font.pixelSize: 14
      font.bold: true
    }

    Label {
      Layout.fillWidth: true
      Layout.preferredWidth: 0
      text: {
        if (!picker.place.valid)
          return "";
        return picker.place.gridKind === "ring"
          ? qsTr("Click a square of %1's border ring — the buffer the game copies through. The "
                 + "address follows.").arg(picker.place.gridName)
          : qsTr("Click a square of %1 — the map this strip is read out of. The address follows.")
              .arg(picker.place.gridName);
      }
      font.pixelSize: 10
      opacity: 0.6
      wrapMode: Text.Wrap
    }

    // ── The grid ────────────────────────────────────────────────────────────────────────────
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      color: "#1b1f24"
      radius: 4
      clip: true

      Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: Math.max(width, gridWrap.width)
        contentHeight: Math.max(height, gridWrap.height)
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }

        Item {
          id: gridWrap
          width: mapImage.width
          height: mapImage.height
          anchors.centerIn: (width < flick.width && height < flick.height) ? parent : undefined

          Image {
            id: mapImage
            source: picker.place.valid
                    ? brg.map.mapImageSource(picker.place.gridMapInd) : ""
            smooth: false
            cache: true
            // Fit the popup, but never blow pixel art up past 1:1.
            scale: 1
            width: implicitWidth * picker.zoom
            height: implicitHeight * picker.zoom
            fillMode: Image.PreserveAspectFit

            onStatusChanged: {
              if (status === Image.Ready && implicitWidth > 0 && implicitHeight > 0)
                picker.zoom = Math.min(1,
                                       (flick.width  - 8) / implicitWidth,
                                       (flick.height - 8) / implicitHeight);
            }
          }

          // The block the address currently names. Drawn even when it has left the grid — it simply
          // sits outside the image, which is the truest possible picture of what has happened.
          Rectangle {
            visible: picker.place.valid
            x: (picker.place.col + picker.gridOriginBlocks) * picker.blockPx * picker.zoom
            y: (picker.place.row + picker.gridOriginBlocks) * picker.blockPx * picker.zoom
            width: picker.blockPx * picker.zoom
            height: picker.blockPx * picker.zoom
            color: Qt.rgba(0.34, 0.71, 0.91, 0.30)
            border.width: 2
            border.color: "#56b4e9"
          }

          // Hover feedback, so it is obvious the squares are the thing you are picking.
          Rectangle {
            visible: hoverArea.containsMouse && hoverArea.hoverCol >= 0
            x: (hoverArea.hoverCol + picker.gridOriginBlocks) * picker.blockPx * picker.zoom
            y: (hoverArea.hoverRow + picker.gridOriginBlocks) * picker.blockPx * picker.zoom
            width: picker.blockPx * picker.zoom
            height: picker.blockPx * picker.zoom
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.55)
          }

          MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            property int hoverRow: -1
            property int hoverCol: -1

            function blockAt(px, py) {
              const step = picker.blockPx * picker.zoom;
              if (step <= 0)
                return null;
              const c = Math.floor(px / step) - picker.gridOriginBlocks;
              const r = Math.floor(py / step) - picker.gridOriginBlocks;
              if (!picker.place.valid)
                return null;
              if (r < 0 || c < 0 || r >= picker.place.gridH || c >= picker.place.gridW)
                return null;
              return ({ row: r, col: c });
            }

            onPositionChanged: (m) => {
              const b = blockAt(m.x, m.y);
              hoverArea.hoverRow = b ? b.row : -1;
              hoverArea.hoverCol = b ? b.col : -1;
            }
            onExited: { hoverArea.hoverRow = -1; hoverArea.hoverCol = -1; }

            onClicked: (m) => {
              const b = blockAt(m.x, m.y);
              if (b)
                brg.map.setPointerPlace(picker.dir, picker.fieldKey, b.row, b.col);
            }
          }
        }
      }
    }

    // ── The readout, and the way out ────────────────────────────────────────────────────────
    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      Label {
        Layout.fillWidth: true
        Layout.preferredWidth: 0
        text: picker.place.valid
              ? qsTr("$%1 — %2")
                  .arg(("0000" + picker.place.ptr.toString(16).toUpperCase()).slice(-4))
                  .arg(picker.place.where)
              : ""
        font.pixelSize: 11
        wrapMode: Text.Wrap
        // ⚠️ NOT `palette.text` — it resolves to #ffffff on this surface, which is white on white.
        // @see the same trap in DetailsPanel's per-field readout.
        color: picker.place.inRange ? "#000000" : "#c04a00"
      }

      // Only offered when it is actually needed, and it moves the address to the nearest square
      // rather than to some arbitrary "safe" default — the smallest edit that lands it back inside.
      Button {
        Layout.preferredHeight: 26
        visible: picker.place.valid && !picker.place.inRange
        font.pixelSize: 10
        text: qsTr("Bring it back inside")
        onClicked: brg.map.setPointerPlace(picker.dir, picker.fieldKey,
                                           picker.place.row, picker.place.col)
      }

      Button {
        Layout.preferredHeight: 26
        font.pixelSize: 10
        text: qsTr("Done")
        onClicked: picker.close()
      }
    }
  }
}
