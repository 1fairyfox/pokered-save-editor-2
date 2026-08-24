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
 * @file tst_connections.cpp
 * @brief The map's CONNECTING ROUTES -- the four edge connections, and the offset-driven edit model.
 *
 * The domain write-up is notes/reference/map-connections.md, verified against the cartridge
 * (`scripts/emu/verify_connections.py`, 78/78). This file pins the *editing* model to it (Phase 7a).
 *
 * The load-bearing fact: a connection is neighbour + one signed offset; the other nine bytes are
 * MACRO-derived (MapEngine::connectionBytes). So the strongest oracle we have costs nothing -- the
 * fixture is a real Pallet Town save, so its stored connection bytes ARE what a console wrote, and
 * `connectionSynced()` == true proves our derive reproduces the cartridge byte-for-byte.
 *
 * Keystones:
 *  - `savedConnectionsAreInSync` -- the derive reproduces the real save's bytes exactly.
 *  - `addConnection_writesFlagBitAndItsSlotOnly` / `removeConnection_clearsOnlyTheFlagBit` /
 *    `setConnectionOffset_movesOnlyItsSlot` -- byte-diff the whole 32 KB and demand nothing outside
 *    the flag byte + the one 11-byte slot moved.
 */

#include <QtTest>

#include "../helpers/savefilefixture.h"
#include <pse-db/db.h>
#include <pse-db/mapsdb.h>
#include <pse-db/entries/mapdbentry.h>
#include <pse-db/entries/mapdbentryconnect.h>
#include <pse-savefile/savefile.h>
#include <pse-savefile/expanded/savefileexpanded.h>
#include <pse-savefile/expanded/area/area.h>
#include <pse-savefile/expanded/area/areamap.h>
#include <pse-savefile/expanded/area/areaplayer.h>
#include <pse-savefile/expanded/area/areageneral.h>
#include <pse-savefile/expanded/area/areatileset.h>
#include <pse-savefile/expanded/fragments/mapconndata.h>
#include <pse-savefile/expanded/world/world.h>
#include <pse-savefile/expanded/world/worldgeneral.h>
#include <engine/mapengine.h>
#include <mvc/mapmodel.h>

using namespace pse_test;

namespace {

// The connection save layout, straight out of notes/reference/map-connections.md.
constexpr int kConnFlags = 0x261C;  // bits 0=East 1=West 2=South 3=North
constexpr int kNorthSlot = 0x261D;  // 11 bytes each
constexpr int kSouthSlot = 0x2628;
constexpr int kWestSlot  = 0x2633;
constexpr int kEastSlot  = 0x263E;
constexpr int kSlotLen   = 11;

int slotOf(int dir)
{
  switch (dir) {
    case MapDBEntryConnect::ConnectDir::NORTH: return kNorthSlot;
    case MapDBEntryConnect::ConnectDir::SOUTH: return kSouthSlot;
    case MapDBEntryConnect::ConnectDir::WEST:  return kWestSlot;
    case MapDBEntryConnect::ConnectDir::EAST:  return kEastSlot;
    default: return -1;
  }
}

QVariantMap edge(const QVariantList& list, int dir)
{
  for (const QVariant& v : list)
    if (v.toMap().value("dir").toInt() == dir)
      return v.toMap();
  return QVariantMap();
}

QVariantMap fieldNamed(const QVariantList& fields, const QString& key)
{
  for (const QVariant& v : fields)
    if (v.toMap().value("key").toString() == key)
      return v.toMap();
  return QVariantMap();
}

} // namespace

class TestConnections : public QObject
{
  Q_OBJECT

private slots:
  void initTestCase();

  void connectionEditList_reportsAllFourEdges();
  void savedConnectionsAreInSync();                 // KEYSTONE: derive == the cartridge's bytes
  void recoveredOffsetRoundTrips();
  void desyncingAByte_isDetected();                 // negative control for the sync check

  void addConnection_writesFlagBitAndItsSlotOnly();  // KEYSTONE
  void addConnection_refusesADuplicateEdge();
  void everyConnectionHasAnInteractiveStrip();   // the live-review bug: added ones had none
  void removeConnection_clearsOnlyTheFlagBit();      // KEYSTONE
  void setConnectionOffset_movesOnlyItsSlot();       // KEYSTONE
  void rehomeConnection_movesToAnotherEdge();
  void connectionRoomLeft_countsDownFromFour();
  void connectionsEdited_isQuietUntilYouChangeSomething();

  // ── The inspector's raw nine (Phase 7c) ─────────────────────────────────────
  void connectionFields_nameEveryByteInEnglish();
  void setConnectionField_writesRawByte_andBreaksSync();

  // ── The three pointers, told as places (Q2) ─────────────────────────────────
  void pointerPlace_decodesEveryPointerToItsOwnGrid();   // KEYSTONE: matches the game's own macro
  void pointerPlace_isHonestAboutLeavingTheGrid();       // an out-of-buffer address is shown, not hidden
  void setPointerPlace_roundTripsAndWritesTwoBytesOnly(); // KEYSTONE

  void loadingAndResavingAnUntouchedSave_changesNothing();

private:
  QByteArray m_orig;

  struct Rig {
    SaveFile sf;
    MapModel* map = nullptr;
    AreaMap* area = nullptr;
  };

  Rig* makeRig()
  {
    auto* r = new Rig;
    loadInto(r->sf, m_orig);

    auto* area = r->sf.dataExpanded->area;
    r->area = area->map;
    r->map = new MapModel(area->map, area->player, area->tileset, area->general,
                          area->preloadedSprites, area->sprites, area->warps,
                          r->sf.dataExpanded->world->general);
    return r;
  }

  // Whichever edges the fixture map actually has (Pallet Town: North + South), and a free one.
  static QVector<int> existingDirs(MapModel* m)
  {
    QVector<int> out;
    for (int d = 0; d < 4; d++)
      if (m->connectionExists(d))
        out << d;
    return out;
  }
  static int aFreeDir(MapModel* m)
  {
    for (int d = 0; d < 4; d++)
      if (!m->connectionExists(d))
        return d;
    return -1;
  }

  static QString describeDiff(const QVector<int>& moved)
  {
    QStringList s;
    for (int i : moved)
      s << QStringLiteral("0x%1").arg(i, 4, 16, QChar('0'));
    return s.join(QStringLiteral(", "));
  }

  // Is every moved offset inside {flag byte} ∪ {the one slot}?
  static bool onlyTouched(const QVector<int>& moved, int dir, bool expectFlag)
  {
    const int base = slotOf(dir);
    bool sawFlag = false;
    for (int off : moved) {
      if (off == kConnFlags) { sawFlag = true; continue; }
      if (off >= base && off < base + kSlotLen) continue;
      return false;   // something outside the flag byte and the slot moved
    }
    return !expectFlag || sawFlag;
  }
};

void TestConnections::initTestCase()
{
  QVERIFY(DB::inst() != nullptr);
  m_orig = readSaveBytes(QStringLiteral("saves/natural-clean/BaseSAV.sav"));
  QVERIFY(!m_orig.isEmpty());
}

/// Four edges always reported; the fixture map (Pallet Town) has real connections and empty edges.
void TestConnections::connectionEditList_reportsAllFourEdges()
{
  Rig* r = makeRig();

  const QVariantList list = r->map->connectionEditList();
  QCOMPARE(list.size(), 4);

  const QVector<int> have = existingDirs(r->map);
  QVERIFY2(!have.isEmpty(), "the fixture map has no connections -- pick a different fixture");
  QVERIFY2(have.size() < 4, "the fixture map is connected on all four sides -- no empty edge to test");

  for (const QVariant& v : list) {
    const QVariantMap m = v.toMap();
    QVERIFY(m.contains("dir"));
    QVERIFY2(!m.value("dirName").toString().isEmpty(), "an edge has no name");

    if (m.value("exists").toBool()) {
      QVERIFY2(m.value("toMap").toInt() >= 0, "an existing connection names no neighbour");
      QVERIFY2(!m.value("toName").toString().isEmpty(), "an existing connection has no neighbour name");
    }
  }

  delete r;
}

/**
 * @brief THE KEYSTONE. The fixture's real connections are byte-for-byte what the macro derives.
 *
 * The fixture is a save a real console wrote, so its connection bytes are the cartridge's. If
 * `connectionSynced()` is true for every one, our `connectionBytes` (map + recovered offset -> the
 * eleven bytes) reproduces the console exactly. This is the same oracle `verify_connections.py` uses,
 * for free, from the edit side.
 */
void TestConnections::savedConnectionsAreInSync()
{
  Rig* r = makeRig();

  const QVector<int> have = existingDirs(r->map);
  QVERIFY(!have.isEmpty());

  for (int dir : have)
    QVERIFY2(r->map->connectionSynced(dir),
             qPrintable(QStringLiteral("the derive does not reproduce the fixture's real %1 "
                                       "connection bytes")
                          .arg(edge(r->map->connectionEditList(), dir).value("dirName").toString())));

  delete r;
}

/// The offset a connection was built with is recoverable from its stored bytes, and stable.
void TestConnections::recoveredOffsetRoundTrips()
{
  Rig* r = makeRig();

  for (int dir : existingDirs(r->map)) {
    const int off = r->map->connectionOffsetOf(dir);

    // Re-deriving at that offset must leave it in sync (it was already), and re-reading it must
    // give the same number back.
    r->map->setConnectionOffset(dir, off);
    QVERIFY2(r->map->connectionSynced(dir), "re-deriving at the recovered offset broke sync");
    QCOMPARE(r->map->connectionOffsetOf(dir), off);
  }

  delete r;
}

/// Negative control: scribble one stored byte and the sync check must NOTICE.
void TestConnections::desyncingAByte_isDetected()
{
  Rig* r = makeRig();

  const QVector<int> have = existingDirs(r->map);
  QVERIFY(!have.isEmpty());
  const int dir = have.first();

  QVERIFY(r->map->connectionSynced(dir));

  // Reach in and change one derived byte behind the model's back (what break-sync raw editing does).
  MapConnData* c = r->area->connections.value((var8)dir);
  QVERIFY(c != nullptr);
  c->stripWidth = (c->stripWidth + 1) & 0xFF;

  QVERIFY2(!r->map->connectionSynced(dir),
           "a hand-edited strip width was not detected as desynced -- the sync check checks nothing");

  delete r;
}

/**
 * @brief THE KEYSTONE. Adding a connection writes the flag bit and its 11-byte slot -- nothing else.
 */
void TestConnections::addConnection_writesFlagBitAndItsSlotOnly()
{
  Rig* r = makeRig();

  const int dir = aFreeDir(r->map);
  QVERIFY(dir >= 0);

  // A real, sized neighbour so the strip actually derives.
  auto* to = MapsDB::inst()->getIndAt(QStringLiteral("1"));   // Viridian City
  QVERIFY(to != nullptr);

  r->sf.flattenData();
  const QByteArray before = snapshot(r->sf);

  QVERIFY(r->map->addConnection(dir, to->getInd()));
  QVERIFY(r->map->connectionExists(dir));

  r->sf.flattenData();
  const QByteArray after = snapshot(r->sf);

  const QVector<int> moved = diffOffsets(before, after);
  QVERIFY2(onlyTouched(moved, dir, /*expectFlag*/true),
           qPrintable(QStringLiteral("adding a connection moved bytes outside its flag + slot: %1")
                        .arg(describeDiff(moved))));

  // And what it wrote is exactly the macro's derivation (offset 0), so it comes up in sync.
  QVERIFY2(r->map->connectionSynced(dir), "a freshly derived connection is not in sync with the macro");
  QCOMPARE(r->map->connectionOffsetOf(dir), 0);

  delete r;
}

/// An edge that already has a connection cannot take a second.
void TestConnections::addConnection_refusesADuplicateEdge()
{
  Rig* r = makeRig();

  const QVector<int> have = existingDirs(r->map);
  QVERIFY(!have.isEmpty());

  QVERIFY2(!r->map->addConnection(have.first(), 1),
           "a second connection was allowed on an edge that already has one");

  delete r;
}

/**
 * @brief The live-review bug: a connection you ADD must have an interactive strip.
 *
 * `connectionList()` walks the map's *shipped* DB connections, so an added save connection had no
 * strip and nothing to grab (the "weird broken state"). The strip rect now comes from the SAVE's own
 * connection (connectionEditList's `hasStrip` + `stripX/Y/W/H`), so both the fixture's real
 * connections AND a freshly-added one report a grabbable box.
 */
void TestConnections::everyConnectionHasAnInteractiveStrip()
{
  Rig* r = makeRig();

  // The fixture's real connections have strips.
  for (int dir : existingDirs(r->map)) {
    const QVariantMap e = edge(r->map->connectionEditList(), dir);
    QVERIFY2(e.value("hasStrip").toBool(), "a shipped connection lost its interactive strip");
    QVERIFY(e.value("stripW").toInt() > 0 && e.value("stripH").toInt() > 0);
  }

  // An ADDED one does too -- this is the bug.
  const int free = aFreeDir(r->map);
  QVERIFY(free >= 0);
  auto* to = MapsDB::inst()->getIndAt(QStringLiteral("1"));   // Viridian City, a real sized map
  QVERIFY(to != nullptr);
  QVERIFY(r->map->addConnection(free, to->getInd()));

  const QVariantMap e = edge(r->map->connectionEditList(), free);
  QVERIFY2(e.value("hasStrip").toBool(),
           "an ADDED connection has no interactive strip -- the review bug is back");
  QVERIFY(e.value("stripW").toInt() > 0 && e.value("stripH").toInt() > 0);

  delete r;
}

/**
 * @brief THE KEYSTONE. Deleting a connection clears ONLY the flag bit.
 *
 * Byte fidelity: the 11 stale bytes of the slot are left exactly as they lie (the game reads the
 * slot only when the flag bit says to), so a delete is a single-bit edit.
 */
void TestConnections::removeConnection_clearsOnlyTheFlagBit()
{
  Rig* r = makeRig();

  const QVector<int> have = existingDirs(r->map);
  QVERIFY(!have.isEmpty());
  const int dir = have.first();

  r->sf.flattenData();
  const QByteArray before = snapshot(r->sf);

  r->map->removeConnection(dir);
  QVERIFY(!r->map->connectionExists(dir));

  r->sf.flattenData();
  const QByteArray after = snapshot(r->sf);

  const QVector<int> moved = diffOffsets(before, after);
  QVERIFY2(moved == QVector<int>{ kConnFlags },
           qPrintable(QStringLiteral("deleting a connection moved more than the flag byte: %1")
                        .arg(describeDiff(moved))));

  delete r;
}

/**
 * @brief THE KEYSTONE. Sliding the offset rewrites only its own slot -- the flag byte and every
 *        other connection stay put.
 */
void TestConnections::setConnectionOffset_movesOnlyItsSlot()
{
  Rig* r = makeRig();

  const QVector<int> have = existingDirs(r->map);
  QVERIFY(!have.isEmpty());
  const int dir = have.first();

  const int from = r->map->connectionOffsetOf(dir);
  const int to = from + 2;

  r->sf.flattenData();
  const QByteArray before = snapshot(r->sf);

  r->map->setConnectionOffset(dir, to);

  r->sf.flattenData();
  const QByteArray after = snapshot(r->sf);

  const QVector<int> moved = diffOffsets(before, after);
  QVERIFY2(onlyTouched(moved, dir, /*expectFlag*/false),
           qPrintable(QStringLiteral("sliding the offset moved bytes outside its slot: %1")
                        .arg(describeDiff(moved))));
  QVERIFY2(!moved.contains(kConnFlags), "sliding the offset touched the enable flags byte");

  // The new offset is what we asked for, and it is in sync.
  QCOMPARE(r->map->connectionOffsetOf(dir), to);
  QVERIFY(r->map->connectionSynced(dir));

  delete r;
}

/// Re-homing moves a connection to a free edge, keeping its neighbour and offset -- and the old edge
/// is emptied. (No rotation exists in the save; this is the representable "attach to another side".)
void TestConnections::rehomeConnection_movesToAnotherEdge()
{
  Rig* r = makeRig();

  const QVector<int> have = existingDirs(r->map);
  QVERIFY(!have.isEmpty());
  const int from = have.first();
  const int to = aFreeDir(r->map);
  QVERIFY(to >= 0);

  const QVariantMap wasEdge = edge(r->map->connectionEditList(), from);
  const int neighbour = wasEdge.value("toMap").toInt();
  const int offset = wasEdge.value("offset").toInt();

  r->map->rehomeConnection(from, to);

  QVERIFY2(!r->map->connectionExists(from), "the old edge still has a connection after re-homing");
  QVERIFY2(r->map->connectionExists(to), "the new edge has no connection after re-homing");

  const QVariantMap now = edge(r->map->connectionEditList(), to);
  QCOMPARE(now.value("toMap").toInt(), neighbour);
  QCOMPARE(now.value("offset").toInt(), offset);
  QVERIFY2(r->map->connectionSynced(to), "the re-homed connection is not in sync for its new edge");

  delete r;
}

/// Four is the cap; the room counts down, and a fifth is refused.
void TestConnections::connectionRoomLeft_countsDownFromFour()
{
  Rig* r = makeRig();

  const int used = existingDirs(r->map).size();
  QCOMPARE(r->map->connectionRoomLeft(), 4 - used);

  // Fill every free edge.
  for (int d = 0; d < 4; d++)
    if (!r->map->connectionExists(d))
      QVERIFY(r->map->addConnection(d, 1));

  QCOMPARE(r->map->connectionRoomLeft(), 0);
  QVERIFY2(!r->map->addConnection(0, 1), "a fifth connection was allowed on a four-sided map");

  delete r;
}

/// Quiet until you actually change something -- merely looking must not trip the warning.
void TestConnections::connectionsEdited_isQuietUntilYouChangeSomething()
{
  Rig* r = makeRig();

  QVERIFY2(!r->map->connectionsEdited(), "the panel is warning about an edit nobody made");

  (void)r->map->connectionEditList();
  for (int d = 0; d < 4; d++) {
    (void)r->map->connectionExists(d);
    (void)r->map->connectionSynced(d);
    (void)r->map->connectionOffsetOf(d);
  }
  QVERIFY(!r->map->connectionsEdited());

  const int dir = existingDirs(r->map).first();
  r->map->setConnectionOffset(dir, r->map->connectionOffsetOf(dir) + 1);
  QVERIFY2(r->map->connectionsEdited(), "an offset change did not trip the warning");

  delete r;
}

/// The inspector's advanced section names all eight struct fields, in English, with their values.
void TestConnections::connectionFields_nameEveryByteInEnglish()
{
  Rig* r = makeRig();
  const int dir = existingDirs(r->map).first();

  const QVariantList f = r->map->connectionFields(dir);
  QCOMPARE(f.size(), 8);

  const QStringList keys = { "mapPtr", "stripSrc", "stripDst", "stripWidth",
                             "width", "yAlign", "xAlign", "viewPtr" };
  for (const QString& key : keys) {
    const QVariantMap m = fieldNamed(f, key);
    QVERIFY2(!m.isEmpty(), qPrintable(QStringLiteral("no field for '%1'").arg(key)));
    QVERIFY2(!m.value("label").toString().isEmpty(),
             qPrintable(QStringLiteral("'%1' has no human name").arg(key)));
    QVERIFY2(!m.value("blurb").toString().isEmpty(),
             qPrintable(QStringLiteral("'%1' has no explanation").arg(key)));
  }

  // The values are the bytes actually stored.
  MapConnData* c = r->area->connections.value((var8)dir);
  QCOMPARE(fieldNamed(f, "stripSrc").value("value").toInt(), c->stripSrc);
  QCOMPARE(fieldNamed(f, "viewPtr").value("value").toInt(), c->viewPtr);
  QCOMPARE(fieldNamed(f, "mapPtr").value("value").toInt(), c->mapPtr);

  delete r;
}

/// A raw-field write is a BREAK-SYNC edit: exactly its own byte(s) move, and the connection is no
/// longer in sync (the offset no longer describes it).
void TestConnections::setConnectionField_writesRawByte_andBreaksSync()
{
  Rig* r = makeRig();
  const int dir = existingDirs(r->map).first();

  QVERIFY2(r->map->connectionSynced(dir), "the fixture connection did not start in sync");

  MapConnData* c = r->area->connections.value((var8)dir);
  const int want = (c->stripWidth + 5) & 0xFF;

  r->sf.flattenData();
  const QByteArray before = snapshot(r->sf);

  r->map->setConnectionField(dir, QStringLiteral("stripWidth"), want);

  r->sf.flattenData();
  const QByteArray after = snapshot(r->sf);

  // stripWidth sits at slot + 5 (mapPtr 1 + stripSrc 2 + stripDst 2).
  const int at = slotOf(dir) + 5;
  const QVector<int> moved = diffOffsets(before, after);
  QVERIFY2(moved == QVector<int>{ at },
           qPrintable(QStringLiteral("a raw stripWidth write moved: %1").arg(describeDiff(moved))));
  QCOMPARE(static_cast<int>(static_cast<quint8>(after.at(at))), want);

  QVERIFY2(!r->map->connectionSynced(dir),
           "a raw byte edit did not break sync -- the offset should no longer describe it");

  delete r;
}

/**
 * @brief Load an untouched save, re-save it, and not one bit moves. The connection blocks included.
 */
/**
 * @brief KEYSTONE. Each of the three pointers decodes to a square of the grid it actually indexes —
 *        and the arithmetic is the game's own, run backwards.
 *
 * Project leadership, 2026-08-19: *"its silly to say theres no solution for this … memory addresses
 * point to ram this means the start of the blocks are known."* They were right, and this is why the
 * handles and the picker are honest rather than approximate: **none of the three is a free-floating
 * address.** Each is a base plus an index, and the engine already composes them that way.
 *
 * Checked against the `map_connection` macro as documented in notes/reference/map-connections.md
 * (78/78 verified against the cartridge), for the NORTH edge with offset 0:
 *
 *     stripSrc  ->  W * (H - 3) + _src        the neighbour's LAST THREE ROWS
 *     stripDst  ->  _tgt = offset + 3         our ring, top row
 *     viewPtr   ->  (W + 6) * H + 1           the neighbour's ring, after you cross
 *
 * If the decode is ever wrong, a drag or a picker click writes a plausible address to the wrong
 * square — the worst kind of failure here, because the number still looks like an address.
 */
void TestConnections::pointerPlace_decodesEveryPointerToItsOwnGrid()
{
  Rig* r = makeRig();

  bool checkedNorth = false;

  for (int dir : existingDirs(r->map)) {
    for (const QString& key : { QStringLiteral("stripSrc"),
                                QStringLiteral("stripDst"),
                                QStringLiteral("viewPtr") }) {
      const QVariantMap p = r->map->pointerPlace(dir, key);
      QVERIFY2(p.value("valid").toBool(),
               qPrintable(QStringLiteral("dir %1 / %2 did not decode at all").arg(dir).arg(key)));

      // The decode must be self-consistent: base + row*stride + col has to be the pointer itself.
      const int rebuilt = p.value("base").toInt()
                        + p.value("row").toInt() * p.value("gridW").toInt()
                        + p.value("col").toInt();
      QCOMPARE(rebuilt, p.value("ptr").toInt());

      QVERIFY2(!p.value("where").toString().isEmpty(), "a decoded pointer had no English readout");
      QVERIFY(p.value("gridW").toInt() > 0 && p.value("gridH").toInt() > 0);
    }

    if (dir != MapDBEntryConnect::ConnectDir::NORTH)
      continue;

    // ── The macro itself, for the one edge we can state in closed form ──────────────────────
    MapConnData* c = r->area->connections.value((var8)dir);
    MapDBEntry* to = MapsDB::inst()->getStoreAt(c->mapPtr);
    QVERIFY(to != nullptr);

    const int W = to->getWidth();
    const int H = to->getHeight();

    const QVariantMap src = r->map->pointerPlace(dir, QStringLiteral("stripSrc"));
    QCOMPARE(src.value("gridKind").toString(), QStringLiteral("map"));     // ROM blocks: no border
    QCOMPARE(src.value("gridW").toInt(), W);
    QCOMPARE(src.value("row").toInt() * W + src.value("col").toInt(), W * (H - 3));

    const QVariantMap dst = r->map->pointerPlace(dir, QStringLiteral("stripDst"));
    QCOMPARE(dst.value("gridKind").toString(), QStringLiteral("ring"));    // WRAM buffer: + border
    QCOMPARE(dst.value("row").toInt(), 0);                                 // the ring's top row
    QCOMPARE(dst.value("col").toInt(), 3);                                 // offset 0 -> _tgt = 3

    const QVariantMap vp = r->map->pointerPlace(dir, QStringLiteral("viewPtr"));
    QCOMPARE(vp.value("gridKind").toString(), QStringLiteral("ring"));
    QCOMPARE(vp.value("gridW").toInt(), W + 6);
    QCOMPARE(vp.value("row").toInt() * (W + 6) + vp.value("col").toInt(), (W + 6) * H + 1);

    checkedNorth = true;
  }

  QVERIFY2(checkedNorth, "the fixture map has no NORTH connection -- the macro check never ran");

  delete r;
}

/// An address that has left its buffer is a real thing a save can hold, and it is exactly what
/// somebody poking at these wants to see. It must be reported, with its (possibly negative) square,
/// and flagged — never quietly clamped into something that looks fine.
///
/// ⚠️ The negative row is the point: C's integer division truncates toward zero, so a naive
/// `index / stride` reports row 0 for an address a whole row ABOVE the buffer. That is the
/// difference between "just off the top" and "fine".
void TestConnections::pointerPlace_isHonestAboutLeavingTheGrid()
{
  Rig* r = makeRig();
  const int dir = existingDirs(r->map).first();

  const QVariantMap base = r->map->pointerPlace(dir, QStringLiteral("stripDst"));
  QVERIFY(base.value("valid").toBool());
  QVERIFY2(base.value("inRange").toBool(), "the fixture's own pointer was already out of range");

  // One whole row ABOVE the buffer's start.
  const int stride = base.value("gridW").toInt();
  r->map->setConnectionField(dir, QStringLiteral("stripDst"),
                             base.value("base").toInt() - stride + 2);

  const QVariantMap out = r->map->pointerPlace(dir, QStringLiteral("stripDst"));
  QVERIFY2(out.value("valid").toBool(), "an out-of-grid address stopped decoding entirely");
  QVERIFY2(!out.value("inRange").toBool(), "an address above the buffer was reported as in range");
  QCOMPARE(out.value("row").toInt(), -1);      // floor, not truncation
  QCOMPARE(out.value("col").toInt(), 2);
  QVERIFY2(out.value("where").toString().contains(QStringLiteral("outside")),
           "the readout did not say the address had left its grid");

  delete r;
}

/**
 * @brief KEYSTONE. Picking a square writes that square's address — and moves TWO BYTES, nothing else.
 *
 * This is the write path behind both the picker click and the on-canvas drag, so it carries the
 * project's byte-fidelity rule directly: a pointer edit is a two-byte edit.
 */
void TestConnections::setPointerPlace_roundTripsAndWritesTwoBytesOnly()
{
  Rig* r = makeRig();
  const int dir = existingDirs(r->map).first();

  r->sf.flattenData();
  const QByteArray before = snapshot(r->sf);

  const QVariantMap p0 = r->map->pointerPlace(dir, QStringLiteral("stripDst"));
  QVERIFY(p0.value("valid").toBool());

  const int wantRow = p0.value("row").toInt() + 2;
  const int wantCol = p0.value("col").toInt() + 1;
  r->map->setPointerPlace(dir, QStringLiteral("stripDst"), wantRow, wantCol);

  const QVariantMap p1 = r->map->pointerPlace(dir, QStringLiteral("stripDst"));
  QCOMPARE(p1.value("row").toInt(), wantRow);
  QCOMPARE(p1.value("col").toInt(), wantCol);

  r->sf.flattenData();
  const QByteArray after = snapshot(r->sf);

  // stripDst is the two bytes at slot + 3 (mapPtr 1 + stripSrc 2).
  const int at = slotOf(dir) + 3;
  const QVector<int> moved = diffOffsets(before, after);
  for (int off : moved)
    QVERIFY2(off == at || off == at + 1,
             qPrintable(QStringLiteral("aiming a pointer moved a byte it had no business touching: %1")
                          .arg(describeDiff(moved))));
  QVERIFY2(!moved.isEmpty(), "aiming a pointer at a different square wrote nothing at all");

  // Off the grid entirely -> clamped to the grid, never refused and never written out of bounds.
  r->map->setPointerPlace(dir, QStringLiteral("stripDst"), 9999, 9999);
  const QVariantMap p2 = r->map->pointerPlace(dir, QStringLiteral("stripDst"));
  QCOMPARE(p2.value("row").toInt(), p2.value("gridH").toInt() - 1);
  QCOMPARE(p2.value("col").toInt(), p2.value("gridW").toInt() - 1);
  QVERIFY2(p2.value("inRange").toBool(), "a clamped pick did not land inside the grid");

  delete r;
}

void TestConnections::loadingAndResavingAnUntouchedSave_changesNothing()
{
  Rig* r = makeRig();

  r->sf.flattenData();
  const QByteArray once = snapshot(r->sf);

  r->sf.expandData();
  r->sf.flattenData();
  const QByteArray twice = snapshot(r->sf);

  const QVector<int> moved = diffOffsets(once, twice);
  QVERIFY2(moved.isEmpty(),
           qPrintable(QStringLiteral("a load/save round trip of an UNTOUCHED save moved %1 bytes: %2")
                        .arg(moved.size()).arg(describeDiff(moved))));

  delete r;
}

QTEST_MAIN(TestConnections)
#include "tst_connections.moc"
