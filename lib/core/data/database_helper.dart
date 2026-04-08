import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static const _databaseName = "OfficeHealth.db";
  static const _databaseVersion = 2;

  static const tableBreakLogs = 'break_logs';
  static const tablePostureLogs = 'posture_logs';
  static const tableExerciseLogs = 'exercise_logs';
  static const tableSleepLogs = 'sleep_logs';

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableBreakLogs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        outcome TEXT NOT NULL,
        stepsCompleted INTEGER,
        sedentaryMinsBefore INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE $tablePostureLogs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        result TEXT NOT NULL,
        issueType TEXT NOT NULL,
        videoShown INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableExerciseLogs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        exerciseId TEXT NOT NULL,
        bodyPart TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        durationSeconds INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableSleepLogs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        startTimestamp INTEGER NOT NULL,
        endTimestamp INTEGER NOT NULL,
        durationSeconds INTEGER NOT NULL,
        quality INTEGER
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableSleepLogs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          startTimestamp INTEGER NOT NULL,
          endTimestamp INTEGER NOT NULL,
          durationSeconds INTEGER NOT NULL,
          quality INTEGER
        )
      ''');
    }
  }

  Future<int> insertBreakLog({
    required int timestampMillis,
    required String outcome,
    int? stepsCompleted,
    int? sedentaryMinsBefore,
  }) async {
    final db = await database;
    return db.insert(tableBreakLogs, {
      'timestamp': timestampMillis,
      'outcome': outcome,
      'stepsCompleted': stepsCompleted,
      'sedentaryMinsBefore': sedentaryMinsBefore,
    });
  }

  Future<int> insertPostureLog({
    required int timestampMillis,
    required String result,
    required String issueType,
    required bool videoShown,
  }) async {
    final db = await database;
    return db.insert(tablePostureLogs, {
      'timestamp': timestampMillis,
      'result': result,
      'issueType': issueType,
      'videoShown': videoShown ? 1 : 0,
    });
  }

  Future<int> insertExerciseLog({
    required String exerciseId,
    required String bodyPart,
    required int timestampMillis,
    required int durationSeconds,
  }) async {
    final db = await database;
    return db.insert(tableExerciseLogs, {
      'exerciseId': exerciseId,
      'bodyPart': bodyPart,
      'timestamp': timestampMillis,
      'durationSeconds': durationSeconds,
    });
  }

  Future<int> countBreakLogsSince({
    required int sinceMillis,
    String? outcome,
  }) async {
    final db = await database;
    final where = outcome == null ? 'timestamp >= ?' : 'timestamp >= ? AND outcome = ?';
    final args = outcome == null ? [sinceMillis] : [sinceMillis, outcome];
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $tableBreakLogs WHERE $where',
      args,
    );
    return (result.first['c'] as int?) ?? 0;
  }

  Future<int> countPostureLogsSince({
    required int sinceMillis,
    String? result,
  }) async {
    final db = await database;
    final where = result == null ? 'timestamp >= ?' : 'timestamp >= ? AND result = ?';
    final args = result == null ? [sinceMillis] : [sinceMillis, result];
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $tablePostureLogs WHERE $where',
      args,
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<int> sumExerciseSecondsSince({required int sinceMillis}) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(durationSeconds), 0) AS s FROM $tableExerciseLogs WHERE timestamp >= ?',
      [sinceMillis],
    );
    return (rows.first['s'] as int?) ?? 0;
  }

  Future<int> insertSleepLog({
    required int startMillis,
    required int endMillis,
    required int durationSeconds,
    int? quality,
  }) async {
    final db = await database;
    return db.insert(tableSleepLogs, {
      'startTimestamp': startMillis,
      'endTimestamp': endMillis,
      'durationSeconds': durationSeconds,
      'quality': quality,
    });
  }

  Future<int> sumSleepSecondsSince({required int sinceMillis}) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(durationSeconds), 0) AS s FROM $tableSleepLogs WHERE endTimestamp >= ?',
      [sinceMillis],
    );
    return (rows.first['s'] as int?) ?? 0;
  }

  Future<int> countSleepLogsSince({required int sinceMillis}) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $tableSleepLogs WHERE endTimestamp >= ?',
      [sinceMillis],
    );
    return (rows.first['c'] as int?) ?? 0;
  }
}
