import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('parts.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE parts (
      id TEXT PRIMARY KEY NOT NULL,
      serial_no TEXT,
      part_name TEXT,
      category TEXT,
      total_parts INTEGER,
      current_count INTEGER,
      box_no INTEGER,
      availability INTEGER,
      image_path TEXT,
      last_updated TEXT,
      sync_status INTEGER DEFAULT 0
    )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute(
          "ALTER TABLE parts ADD COLUMN availability INTEGER DEFAULT 0",
        );
      } catch (_) {}

      try {
        await db.execute(
          "ALTER TABLE parts ADD COLUMN sync_status INTEGER DEFAULT 0",
        );
      } catch (_) {}

      try {
        await db.execute("ALTER TABLE parts ADD COLUMN image_path TEXT");
      } catch (_) {}

      try {
        await db.execute("ALTER TABLE parts ADD COLUMN last_updated TEXT");
      } catch (_) {}
    }
  }
}
