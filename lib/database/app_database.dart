import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/measurement_record_model.dart';
import '../models/measurement_session_model.dart';
import '../models/operation_model.dart';
import '../models/template_model.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'taktflow.db');
    return openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE templates (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  createdAt TEXT NOT NULL
);
''');
        await db.execute('''
CREATE TABLE operations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  templateId INTEGER NOT NULL,
  name TEXT NOT NULL,
  orderIndex INTEGER NOT NULL,
  FOREIGN KEY (templateId) REFERENCES templates (id) ON DELETE CASCADE
);
''');
        await db.execute('''
CREATE TABLE measurement_sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  templateId INTEGER NOT NULL,
  startedAt TEXT NOT NULL,
  endedAt TEXT,
  comment TEXT,
  FOREIGN KEY (templateId) REFERENCES templates (id) ON DELETE CASCADE
);
''');
        await db.execute('''
CREATE TABLE measurement_records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sessionId INTEGER NOT NULL,
  templateId INTEGER NOT NULL,
  operationId INTEGER NOT NULL,
  operationName TEXT NOT NULL,
  cycleNumber INTEGER NOT NULL,
  startedAt TEXT NOT NULL,
  endedAt TEXT NOT NULL,
  durationMs INTEGER NOT NULL,
  comment TEXT,
  FOREIGN KEY (sessionId) REFERENCES measurement_sessions (id) ON DELETE CASCADE,
  FOREIGN KEY (templateId) REFERENCES templates (id) ON DELETE CASCADE
);
''');
        await db.execute(
          'CREATE INDEX idx_operations_template ON operations (templateId, orderIndex)',
        );
        await db.execute(
          'CREATE INDEX idx_records_session ON measurement_records (sessionId, id)',
        );
      },
    );
  }

  Future<List<TemplateModel>> getTemplates() async {
    final db = await database;
    final rows = await db.query('templates', orderBy: 'createdAt DESC');
    return rows.map(TemplateModel.fromMap).toList();
  }

  Future<TemplateModel?> getTemplate(int id) async {
    final db = await database;
    final rows = await db.query('templates', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return TemplateModel.fromMap(rows.first);
  }

  Future<int> insertTemplate(String name, DateTime createdAt) async {
    final db = await database;
    return db.insert('templates', {
      'name': name,
      'createdAt': createdAt.toIso8601String(),
    });
  }

  Future<void> updateTemplate(int id, String name) async {
    final db = await database;
    await db.update(
      'templates',
      {'name': name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteTemplate(int id) async {
    final db = await database;
    await db.delete('templates', where: 'id = ?', whereArgs: [id]);
  }

  /// Создаёт копию шаблона вместе с операциями.
  Future<int> duplicateTemplate(int sourceTemplateId, {String? newName}) async {
    final db = await database;
    return db.transaction<int>((txn) async {
      final rows = await txn.query(
        'templates',
        where: 'id = ?',
        whereArgs: [sourceTemplateId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Template not found: $sourceTemplateId');
      }
      final source = TemplateModel.fromMap(rows.first);
      final createdAt = DateTime.now();
      final name = (newName == null || newName.trim().isEmpty)
          ? '${source.name} (копия)'
          : newName.trim();

      final newTemplateId = await txn.insert('templates', {
        'name': name,
        'createdAt': createdAt.toIso8601String(),
      });

      final sourceOps = await txn.query(
        'operations',
        where: 'templateId = ?',
        whereArgs: [sourceTemplateId],
        orderBy: 'orderIndex ASC',
      );

      for (final op in sourceOps) {
        await txn.insert('operations', {
          'templateId': newTemplateId,
          'name': op['name'],
          'orderIndex': op['orderIndex'],
        });
      }
      return newTemplateId;
    });
  }

  Future<List<OperationModel>> getOperations(int templateId) async {
    final db = await database;
    final rows = await db.query(
      'operations',
      where: 'templateId = ?',
      whereArgs: [templateId],
      orderBy: 'orderIndex ASC',
    );
    return rows.map(OperationModel.fromMap).toList();
  }

  /// Полная перезапись операций шаблона (проще, чем дифф по MVP).
  Future<void> replaceOperations(int templateId, List<String> names) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'operations',
        where: 'templateId = ?',
        whereArgs: [templateId],
      );
      for (var i = 0; i < names.length; i++) {
        await txn.insert('operations', {
          'templateId': templateId,
          'name': names[i],
          'orderIndex': i,
        });
      }
    });
  }

  Future<int> countOperations(int templateId) async {
    final db = await database;
    final r = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM operations WHERE templateId = ?',
      [templateId],
    );
    return Sqflite.firstIntValue(r) ?? 0;
  }

  Future<int> insertSession({
    required int templateId,
    required DateTime startedAt,
  }) async {
    final db = await database;
    return db.insert('measurement_sessions', {
      'templateId': templateId,
      'startedAt': startedAt.toIso8601String(),
    });
  }

  Future<void> updateSessionEnded(int sessionId, DateTime endedAt) async {
    final db = await database;
    await db.update(
      'measurement_sessions',
      {'endedAt': endedAt.toIso8601String()},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> updateSessionComment(int sessionId, String? comment) async {
    final db = await database;
    await db.update(
      'measurement_sessions',
      {'comment': comment},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<List<MeasurementSessionModel>> getAllSessions() async {
    final db = await database;
    final rows = await db.query('measurement_sessions', orderBy: 'startedAt DESC');
    return rows.map(MeasurementSessionModel.fromMap).toList();
  }

  Future<MeasurementSessionModel?> getSession(int id) async {
    final db = await database;
    final rows =
        await db.query('measurement_sessions', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return MeasurementSessionModel.fromMap(rows.first);
  }

  /// Удаляет сессию замера; отсечки удаляются каскадом (ON DELETE CASCADE).
  Future<void> deleteSession(int sessionId) async {
    final db = await database;
    await db.delete('measurement_sessions', where: 'id = ?', whereArgs: [sessionId]);
  }

  Future<int> insertRecord({
    required int sessionId,
    required int templateId,
    required int operationId,
    required String operationName,
    required int cycleNumber,
    required DateTime startedAt,
    required DateTime endedAt,
    required int durationMs,
    String? comment,
  }) async {
    final db = await database;
    return db.insert('measurement_records', {
      'sessionId': sessionId,
      'templateId': templateId,
      'operationId': operationId,
      'operationName': operationName,
      'cycleNumber': cycleNumber,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt.toIso8601String(),
      'durationMs': durationMs,
      'comment': comment,
    });
  }

  Future<List<MeasurementRecordModel>> getRecordsForSession(int sessionId) async {
    final db = await database;
    final rows = await db.query(
      'measurement_records',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
      orderBy: 'id ASC',
    );
    return rows.map(MeasurementRecordModel.fromMap).toList();
  }

  Future<List<MeasurementRecordModel>> getLastRecordsForSession(
    int sessionId,
    int limit,
  ) async {
    final db = await database;
    final rows = await db.query(
      'measurement_records',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
      orderBy: 'id DESC',
      limit: limit,
    );
    final list = rows.map(MeasurementRecordModel.fromMap).toList();
    return list.reversed.toList();
  }

  Future<MeasurementRecordModel?> getLastRecordForSession(int sessionId) async {
    final db = await database;
    final rows = await db.query(
      'measurement_records',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MeasurementRecordModel.fromMap(rows.first);
  }

  Future<void> deleteRecord(int recordId) async {
    final db = await database;
    await db.delete('measurement_records', where: 'id = ?', whereArgs: [recordId]);
  }

  Future<int> countRecordsForSession(int sessionId) async {
    final db = await database;
    final r = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM measurement_records WHERE sessionId = ?',
      [sessionId],
    );
    return Sqflite.firstIntValue(r) ?? 0;
  }

  Future<int?> maxCycleForSession(int sessionId) async {
    final db = await database;
    final r = await db.rawQuery(
      'SELECT MAX(cycleNumber) AS m FROM measurement_records WHERE sessionId = ?',
      [sessionId],
    );
    final v = r.first['m'];
    if (v == null) return null;
    return v as int?;
  }

  /// Агрегаты по сессиям: число отсечек и максимальный номер цикла.
  Future<Map<int, ({int count, int maxCycle})>> getSessionAggregates() async {
    final db = await database;
    final rows = await db.rawQuery('''
SELECT sessionId,
       COUNT(*) AS cnt,
       COALESCE(MAX(cycleNumber), 0) AS mx
FROM measurement_records
GROUP BY sessionId
''');
    final out = <int, ({int count, int maxCycle})>{};
    for (final row in rows) {
      final sid = row['sessionId']! as int;
      out[sid] = (
        count: row['cnt']! as int,
        maxCycle: row['mx']! as int,
      );
    }
    return out;
  }
}
