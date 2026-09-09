import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/stock_summary.dart';

const _dbName = 'favorites.db';
const _table = 'favorites';

Database? _db;

/// 앱 시작 시 한 번 호출해서 DB 파일을 열고(없으면 생성) 테이블을 준비합니다.
/// 이후 다른 함수들은 이 함수가 열어둔 연결을 재사용합니다.
Future<Database> initDatabase() async {
  if (_db != null) return _db!;

  // 데스크톱(macOS/Windows/Linux)에는 sqflite의 기본 구현체가 없어서,
  // ffi 기반 구현체로 교체해줘야 동작합니다. 모바일(iOS/Android)은
  // sqflite 패키지 자체에 구현체가 있어서 이 교체가 필요 없습니다.
  try {
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  } on UnsupportedError {
    // 웹처럼 dart:io를 지원하지 않는 플랫폼에서는 Platform 접근 자체가 예외를
    // 던집니다. 이 경우 sqflite 기본 구현체(모바일용)를 그대로 둡니다.
  }

  final dbDir = await getDatabasesPath();
  final dbPath = join(dbDir, _dbName);

  _db = await openDatabase(
    dbPath,
    version: 2,
    onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE $_table (
          code TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          market TEXT NOT NULL,
          added_at TEXT NOT NULL,
          reuters_code TEXT NOT NULL DEFAULT '',
          is_foreign INTEGER NOT NULL DEFAULT 0
        )
      ''');
    },
    onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        await db.execute("ALTER TABLE $_table ADD COLUMN reuters_code TEXT NOT NULL DEFAULT ''");
        await db.execute('ALTER TABLE $_table ADD COLUMN is_foreign INTEGER NOT NULL DEFAULT 0');
      }
    },
  );

  return _db!;
}

Future<void> addFavorite(StockSummary stock) async {
  final db = await initDatabase();
  await db.insert(
    _table,
    {
      'code': stock.code,
      'name': stock.name,
      'market': stock.market,
      'added_at': DateTime.now().toIso8601String(),
      'reuters_code': stock.reutersCode,
      'is_foreign': stock.isForeign ? 1 : 0,
    },
    // code가 이미 있으면(=이미 즐겨찾기된 종목) 덮어씁니다.
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

Future<void> removeFavorite(String code) async {
  final db = await initDatabase();
  await db.delete(_table, where: 'code = ?', whereArgs: [code]);
}

Future<List<StockSummary>> getFavorites() async {
  final db = await initDatabase();
  final rows = await db.query(_table, orderBy: 'added_at DESC');
  return rows
      .map((row) => StockSummary(
            code: row['code'] as String,
            name: row['name'] as String,
            market: row['market'] as String,
            reutersCode: row['reuters_code'] as String?,
            isForeign: (row['is_foreign'] as int?) == 1,
          ))
      .toList();
}

Future<bool> isFavorite(String code) async {
  final db = await initDatabase();
  final rows = await db.query(_table, where: 'code = ?', whereArgs: [code], limit: 1);
  return rows.isNotEmpty;
}
