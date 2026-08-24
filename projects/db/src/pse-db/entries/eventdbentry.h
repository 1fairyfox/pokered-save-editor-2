/*
  * Copyright 2020 Fairy Fox
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
#pragma once
#include <QObject>
#include <QJsonValue>

#include "../db_autoport.h"

struct MapDBEntry;
class QQmlEngine;
class EventsDB;

// With amazing help of Quicktype!!!
// https://app.quicktype.io

// In-Game events, there's like a million of them, not kidding lol. Every little
// thing you do changes and moves around events

/**
 * @brief One story-event definition: its name and where its flag lives in the save.
 *
 * QObject-getter style DB entry. Pinpoints the event flag (@ref byte / @ref bit)
 * the save's WorldEvents bitfield stores, and lists the maps it relates to
 * (@ref maps -> @ref toMaps in deepLink). Surfaced lists use the size + invokable
 * `...At()` accessor workaround. See db.md.
 *
 * @see EventsDB, WorldEvents (the save-side flags).
 */
struct DB_AUTOPORT EventDBEntry : public QObject {
  Q_OBJECT
  Q_PROPERTY(QString getName READ getName CONSTANT)         ///< Event name.
  Q_PROPERTY(int getInd READ getInd CONSTANT)               ///< Internal event index.
  Q_PROPERTY(int getByte READ getByte CONSTANT)             ///< Byte in the SAV holding the flag.
  Q_PROPERTY(int getBit READ getBit CONSTANT)               ///< Bit within that byte.
  Q_PROPERTY(int getMapsSize READ getMapsSize CONSTANT)     ///< Count of associated map names.
  Q_PROPERTY(int getToMapsSize READ getToMapsSize CONSTANT) ///< Count of resolved maps.
  // ── the research payload (events.json is generated from pret; see
  //    notes/reference/event-flags.md + scripts/import_events_db.py) ──────────────
  Q_PROPERTY(QString getDesc READ getDesc CONSTANT)         ///< Plain-English description.
  Q_PROPERTY(QString getGroup READ getGroup CONSTANT)       ///< Flag group ("Cerulean Gym — trainers").
  Q_PROPERTY(QString getRegion READ getRegion CONSTANT)     ///< pret's allocation block (ROM detail).
  Q_PROPERTY(QString getCaution READ getCaution CONSTANT)   ///< Softlock/progression note, or "".
  Q_PROPERTY(bool getPlaceholder READ getPlaceholder CONSTANT) ///< Unused padding bit.
  Q_PROPERTY(bool getShared READ getShared CONSTANT)        ///< Lives on more than one map.

  // ⭐ THE READ/WRITE FACTS. How many places in the shipped game SET, CHECK and CLEAR this bit.
  //
  // ⚠️ These exist so nothing has to infer it from the DESCRIPTION again. The model used to
  // answer *"is this flag ever read?"* by searching the prose for the word "reads" -- and the
  // generator writes *"Nothing ever reads it back — a leftover."* for a write-only flag, so the
  // NEGATION counted as proof of a read and every write-only flag stayed un-gated (leadership
  // found it on Pokémon Tower 7F, 2026-08-19). A sentence can be negated; a count cannot.
  //
  // `getReads() == 0` is the one that decides "useless": a flag the game writes and never looks
  // at cannot affect anything you play.
  Q_PROPERTY(int getWrites READ getWrites CONSTANT)  ///< Script sites that SET this bit.
  Q_PROPERTY(int getReads READ getReads CONSTANT)    ///< Script sites that CHECK it.
  Q_PROPERTY(int getClears READ getClears CONSTANT)  ///< Script sites that RESET it.

  /// References from DATA TABLES -- almost all `trainer EVENT_BEAT_..._TRAINER_n` in a map's
  /// trainer-header list, which the engine reads generically instead of any script reading it.
  ///
  /// ⚠️ **A SCRIPT CHECK IS NOT THE ONLY WAY A FLAG IS READ.** 335 flags are read only this way,
  /// and every one is a real edit — clearing one re-arms that trainer's battle. Judging
  /// "write-only" from @ref getReads alone would hide all of them.
  Q_PROPERTY(int getTableRefs READ getTableRefs CONSTANT)

public:
  const QString getName() const; ///< @see getName property.
  int getInd() const;            ///< @see getInd property.
  int getByte() const;           ///< @see getByte property.
  int getBit() const;            ///< @see getBit property.

  const QString getDesc() const;    ///< @see getDesc property.
  const QString getGroup() const;   ///< @see getGroup property.
  const QString getRegion() const;  ///< @see getRegion property.
  const QString getCaution() const; ///< @see getCaution property.
  bool getPlaceholder() const;      ///< @see getPlaceholder property.
  bool getShared() const;           ///< @see getShared property.
  int getWrites() const;            ///< @see getWrites property.
  int getReads() const;             ///< @see getReads property.
  int getClears() const;            ///< @see getClears property.
  int getTableRefs() const;         ///< @see getTableRefs property.

  /// Does the shipped game ever LOOK at this bit -- by script check or through a data table?
  /// The one question the "is this edit useless?" decision turns on. Unknown (a data file
  /// predating the counts) answers **true**: never hide a flag because the facts are missing.
  bool isEverRead() const;
  /// What this flag IS: used / unused / temporary / placeholder / block-swept / ...
  const QVector<QString> getClassification() const;

  const QVector<QString> getMaps() const;        ///< Associated map names.
  int getMapsSize() const;                       ///< @see getMapsSize property.
  Q_INVOKABLE const QString getMapAt(int ind) const; ///< Associated map name @p ind (for QML).

  const QVector<MapDBEntry*> getToMaps() const;  ///< Resolved associated maps.
  int getToMapsSize() const;                     ///< @see getToMapsSize property.
  Q_INVOKABLE const MapDBEntry* getToMapAt(int ind) const; ///< Resolved map @p ind (for QML).

public slots:
  void qmlProtect(const QQmlEngine* const engine) const; ///< Pin to C++ ownership.

protected:
  EventDBEntry();                ///< Empty entry (built by EventsDB).
  EventDBEntry(QJsonValue& data); ///< Build from a JSON value.

  void deepLink();          ///< Resolve the associated maps.
  void qmlRegister() const; ///< Register with QML.

  QString name = ""; // Event name
  int ind = 0; // Internal index
  int byte = 0; // Byte in SAV file
  int bit = 0; // Bit in byte
  QVector<QString> maps; // Associated Maps
  QVector<MapDBEntry*> toMaps; // To Associated Maps

  // The research payload, generated from pret. All OPTIONAL: absent -> empty/false,
  // so an older/hand-trimmed events.json still loads.
  QString desc = "";      // plain-English description
  QString group = "";     // flag group, e.g. "Cerulean Gym — trainers"
  QString region = "";    // pret's allocation block (a ROM detail, never a page)
  QString caution = "";   // softlock/progression note
  bool placeholder = false; // unused padding bit (no code presence at all)
  bool shared = false;      // lives on more than one map
  QVector<QString> classification; // used / unused / temporary / block-swept / ...

  // The read/write facts. -1 means "this events.json predates them", which is NOT the same as 0
  // ("the game never does this") -- and the difference matters, because 0 reads is what hides a
  // flag. An older file must not silently hide half the list, so unknown is treated as "in use".
  int writes = -1;
  int reads = -1;
  int clears = -1;
  int tableRefs = -1;

  friend class EventsDB; ///< Owning DB constructs/populates entries.
};
