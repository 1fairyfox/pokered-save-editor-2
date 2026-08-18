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
  MapField.qml -- a compact "which map?" field. Shows the currently-chosen map's name and, when clicked,
  drops the ONE shared map selector (MapSelectList: sort · search · list). Use it wherever a single map
  value is picked from the whole list -- the designated maps, a warp's destination, and so on (project
  leadership, 2026-08-04: everything that picks a map uses the same control).

  Contract:
    * `value`         — the currently-selected map id (shown on the face).
    * `picked(ind)`   — emitted when a new map is chosen from the drop-down.
    * `leadingEntries`— optional rows prepended in the list (e.g. warp's "← Back outside"). When the
                        current `value` matches one of these, its name is shown on the face too.
    * `allowedIds`    — optional whitelist of map ids, passed straight through to the list. EMPTY =
                        every map. @see MapSelectList.allowedIds
*/
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
  id: mf

  property int value: 0
  property var leadingEntries: []

  /// Map ids the drop-down may offer. EMPTY = every map. @see MapSelectList.allowedIds
  property var allowedIds: []

  /// Non-map rows `[{ key, name }]`. @see MapSelectList.extraRows — this is how the World panel's
  /// "Other" page is offered without inventing a map id for it.
  property var extraRows: []

  /// The extra row that is currently chosen ("" = a real map is chosen). When set, the face shows
  /// that row's name instead of a map name.
  property string currentExtra: ""

  signal picked(int ind)
  signal pickedExtra(string key)

  implicitHeight: 30
  implicitWidth: 160

  property bool openState: false

  /// The name to show on the face — from the leading entries first, then the real map list.
  readonly property string currentName: {
    if (mf.currentExtra !== "") {
      for (let e = 0; e < mf.extraRows.length; e++)
        if (mf.extraRows[e].key === mf.currentExtra) return mf.extraRows[e].name;
    }
    for (let j = 0; j < mf.leadingEntries.length; j++)
      if (mf.leadingEntries[j].ind === mf.value) return mf.leadingEntries[j].name;
    const l = brg.map.mapList();
    for (let i = 0; i < l.length; i++)
      if (l[i].ind === mf.value) return l[i].name;
    return qsTr("Map %1").arg(mf.value);
  }

  Rectangle {
    id: face
    anchors.fill: parent
    radius: 6
    color: (faceHover.hovered || mf.openState) ? Qt.rgba(0, 0, 0, 0.06) : "#ffffff"
    border.width: 1
    border.color: brg.settings.dividerColor

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 9
      anchors.rightMargin: 8
      spacing: 6

      Text {
        Layout.fillWidth: true
        text: mf.currentName
        font.pixelSize: 12
        color: brg.settings.textColorDark
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
      }
      Text {
        text: "⌄"
        font.pixelSize: 11
        color: brg.settings.textColorMid
        Layout.alignment: Qt.AlignVCenter
      }
    }

    HoverHandler { id: faceHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: mf.openState = !mf.openState }
  }

  Popup {
    id: pop
    visible: mf.openState
    onClosed: mf.openState = false
    y: mf.height + 4
    width: 292
    padding: 10
    margins: 8
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

    background: Rectangle {
      color: "#ffffff"
      radius: 6
      border.width: 1
      border.color: brg.settings.dividerColor
    }

    MapSelectList {
      anchors.fill: parent
      listHeight: 150
      selectedInd: mf.currentExtra === "" ? mf.value : -1
      selectedExtra: mf.currentExtra
      leadingEntries: mf.leadingEntries
      allowedIds: mf.allowedIds
      extraRows: mf.extraRows
      onPicked: (ind) => { mf.picked(ind); mf.openState = false; }
      onPickedExtra: (key) => { mf.pickedExtra(key); mf.openState = false; }
    }
  }
}
