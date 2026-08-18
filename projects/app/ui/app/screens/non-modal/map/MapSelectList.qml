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
  MapSelectList.qml -- THE ONE way to pick a map (project leadership, 2026-08-04: *"anywhere else that
  references maps needs to use the built map select thing with the sort, search, and map list. All lists
  that pick from a list of maps likely need to use that one."*).

  A sort button (⇅, with a small "Sort" label naming the current mode), a search box, and the grouped,
  scrolling map list. It carries no chrome of its own beyond that — the host decides where it sits (inline
  in the map-selection panel, or inside a MapField's drop-down for the designated maps / warp targets).

  Contract:
    * `selectedInd`   — the map id to highlight as current (-1 = none).
    * `picked(ind)`   — emitted when a row is chosen. The host decides what that means (preview, commit…).
    * `leadingEntries`— optional rows prepended before the real maps (e.g. warp's "← Back outside").
                        Each is { ind, name, group, isCopy, copyOf, size } like a mapList() row.
    * `allowedIds`    — optional whitelist of map ids. EMPTY MEANS EVERY MAP (the normal case); when
                        set, the list shows only those maps. This is how a caller narrows the control
                        without forking it: the World panel picks from the maps that actually HAVE
                        persistent storage, but with the same sort, the same search and the same rows
                        as everywhere else (project leadership, 2026-08-18: *"the persistent storage
                        thing needs to have the same map selection as the others but it needs to not
                        have the maps that dont have storage — filtered but same map select thing"*).
                        ⚠️ It filters the real maps only; `leadingEntries` always ride through, since
                        they are the caller's own rows and it already decided to add them.
    * `listHeight`    — the internal list's height (it scrolls); the sort/search row sits above it.

  Sorting (`brg.map.mapSort`) is GLOBAL and shared across every instance on purpose — pick a sort once and
  every map list in the app honours it.
*/
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
  id: mapSel

  property int selectedInd: -1
  property var leadingEntries: []
  property int listHeight: 150

  /// Map ids this list may show. EMPTY = no restriction (the normal case). @see the header note.
  property var allowedIds: []

  /// Rows that are NOT maps and have NO map id: `[{ key, name }]`. They sit at the very top, above
  /// even `leadingEntries`, and choosing one emits @ref pickedExtra rather than @ref picked.
  ///
  /// ⚠️ THIS EXISTS SO NOTHING HAS TO FAKE A MAP ID (project leadership, 2026-08-18: *"General -1
  /// feels fake, dont ever do this ... it doesnt need a map id, dont ever fake a map id"*). The
  /// World panel's "Other" page — storage that belongs to no map — is reached through here. A row
  /// with no id cannot be mistaken for map -1, which is this class's genuine "no map" answer.
  property var extraRows: []

  /// Which extra row is currently the selected one ("" = none). Highlights it, the way `selectedInd`
  /// highlights a map.
  property string selectedExtra: ""

  signal picked(int ind)
  signal pickedExtra(string key)

  spacing: 8

  // ── Sort button + search ───────────────────────────────────────────────────────────────────────
  RowLayout {
    Layout.fillWidth: true
    spacing: 6

    // A compact sort button: an ⇅ icon over a small "Sort" label naming the current mode. Opens a
    // Popup of rows (the ZoomMenu idiom, no desktop-chrome Menu).
    Item {
      id: sortBtn
      Layout.preferredHeight: 30
      implicitWidth: sortFace.implicitWidth

      property bool openState: false
      readonly property string currentName: {
        const l = brg.map.mapSortModes();
        for (let i = 0; i < l.length; i++)
          if (l[i].value === brg.map.mapSort) return l[i].name;
        return qsTr("Sort");
      }

      Rectangle {
        id: sortFace
        anchors.fill: parent
        radius: 6
        implicitWidth: sortRow.implicitWidth + 16
        color: (sortHover.hovered || sortBtn.openState) ? Qt.rgba(0, 0, 0, 0.06) : "transparent"
        border.width: 1
        border.color: brg.settings.dividerColor

        RowLayout {
          id: sortRow
          anchors.fill: parent
          anchors.leftMargin: 8
          anchors.rightMargin: 8
          spacing: 6

          Text {
            text: "⇅"
            font.pixelSize: 14
            color: brg.settings.textColorMid
            Layout.alignment: Qt.AlignVCenter
          }
          ColumnLayout {
            spacing: 0
            Layout.alignment: Qt.AlignVCenter
            Text {
              text: qsTr("Sort")
              font.pixelSize: 8
              color: brg.settings.textColorMid
            }
            Text {
              text: sortBtn.currentName
              font.pixelSize: 10
              font.bold: true
              color: brg.settings.textColorDark
              elide: Text.ElideRight
              Layout.maximumWidth: 100
            }
          }
        }

        HoverHandler { id: sortHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: sortBtn.openState = !sortBtn.openState }
      }

      Popup {
        id: sortPop
        visible: sortBtn.openState
        onClosed: sortBtn.openState = false
        y: sortBtn.height + 4
        width: 172
        padding: 6
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

        background: Rectangle {
          color: "#ffffff"
          radius: 8
          border.width: 1
          border.color: brg.settings.dividerColor
        }

        ColumnLayout {
          width: parent.width
          spacing: 3

          Repeater {
            model: brg.map.mapSortModes()

            delegate: Rectangle {
              id: sortItem
              required property var modelData
              readonly property bool active: modelData.value === brg.map.mapSort

              Layout.fillWidth: true
              implicitHeight: 24
              radius: 5
              color: sortItem.active ? brg.settings.accentColor
                   : sortItemHover.hovered ? Qt.rgba(0, 0, 0, 0.06)
                   : "transparent"

              Text {
                anchors.fill: parent
                anchors.leftMargin: 9
                anchors.rightMargin: 9
                verticalAlignment: Text.AlignVCenter
                text: sortItem.modelData.name
                font.pixelSize: 11
                font.bold: sortItem.active
                color: sortItem.active ? brg.settings.textColorLight : brg.settings.textColorDark
                elide: Text.ElideRight
              }

              HoverHandler { id: sortItemHover; cursorShape: Qt.PointingHandCursor }
              TapHandler {
                onTapped: {
                  brg.map.mapSort = sortItem.modelData.value;
                  sortBtn.openState = false;
                }
              }
            }
          }
        }
      }
    }

    TextField {
      id: mapSearch
      Layout.fillWidth: true
      Layout.preferredHeight: 30
      font.pixelSize: 12
      placeholderText: qsTr("Search maps…")
    }
  }

  // ── The grouped, scrolling list ─────────────────────────────────────────────────────────────────
  Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: mapSel.listHeight
    radius: 5
    border.width: 1
    border.color: brg.settings.dividerColor
    clip: true

    ListView {
      id: mapListView
      anchors.fill: parent
      anchors.margins: 1
      clip: true

      // The shared sort (mapSort) AND the search box both feed the model. Referencing mapSort makes
      // the binding re-run when the sort changes (mapList() is otherwise a plain call). Any
      // leadingEntries ride at the very top, before the real maps.
      model: {
        brg.map.mapSort;
        brg.map.showUnused;
        const q = mapSearch.text.trim().toLowerCase();

        // The caller's own rows always ride; only the REAL maps are narrowed. @see allowedIds
        let maps = brg.map.mapList();
        if (mapSel.allowedIds.length > 0) {
          const ok = {};
          for (let k = 0; k < mapSel.allowedIds.length; k++)
            ok[mapSel.allowedIds[k]] = true;
          maps = maps.filter(function(m) { return ok[m.ind] === true; });
        }

        // Extra rows are tagged so the delegate can tell them apart — they have NO ind to show and
        // they emit a different signal. @see extraRows
        const extras = mapSel.extraRows.map(function(e) {
          return { extraKey: e.key, name: e.name, group: "", isCopy: false, copyOf: -1, size: "" };
        });

        const all = extras.concat(mapSel.leadingEntries).concat(maps);
        if (q === "")
          return all;
        return all.filter(function(m) {
          return ("" + m.name).toLowerCase().indexOf(q) >= 0
                 || (m.extraKey === undefined && ("" + m.ind).indexOf(q) >= 0);
        });
      }

      ScrollBar.vertical: ScrollBar { }

      delegate: ItemDelegate {
        required property var modelData
        required property int index
        width: mapListView.width
        // Group headings only when NOT searching (a filtered list's first-of-group headings drift).
        height: (modelData.group !== "" && mapSearch.text === "" ? 20 : 0) + 26
        highlighted: modelData.extraKey !== undefined
                     ? modelData.extraKey === mapSel.selectedExtra
                     : modelData.ind === mapSel.selectedInd

        onClicked: {
          if (modelData.extraKey !== undefined)
            mapSel.pickedExtra(modelData.extraKey);
          else
            mapSel.picked(modelData.ind);
        }

        contentItem: ColumnLayout {
          spacing: 0
          Text {
            visible: modelData.group !== "" && mapSearch.text === ""
            Layout.fillWidth: true
            text: modelData.group
            font.pixelSize: 10; font.bold: true
            color: brg.settings.textColorMid
          }
          RowLayout {
            Layout.fillWidth: true
            spacing: 6
            // ⚠️ An extra row shows NO id — it hasn't got one, and printing a placeholder here is
            // exactly the fake this mechanism exists to avoid. The column still reserves its width so
            // the names stay aligned with the maps below.
            Text {
              text: modelData.extraKey !== undefined ? "" : modelData.ind
              font.pixelSize: 10; font.family: "monospace"
              color: brg.settings.textColorMid
              Layout.minimumWidth: 22
            }
            Text {
              Layout.fillWidth: true
              text: modelData.name
              font.pixelSize: 12
              color: brg.settings.textColorDark
              elide: Text.ElideRight
            }
            Text {
              visible: modelData.isCopy
              text: qsTr("→ %1").arg(modelData.copyOf)
              font.pixelSize: 10; font.italic: true
              color: brg.settings.textColorMid
            }
            // The map size (WxH blocks), right-aligned — uniform with the app's other lists.
            Text {
              text: modelData.size !== undefined ? modelData.size : ""
              font.pixelSize: 10; font.family: "monospace"
              color: brg.settings.textColorMid
            }
          }
        }
      }
    }
  }
}
