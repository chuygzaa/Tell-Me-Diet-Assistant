import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DiaryDatabase {
  static final DiaryDatabase instance = DiaryDatabase._init();
  static Database? _database;

  DiaryDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('diary_ledger.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }
  static const List<String> scalableColumns = [
    'calories', 'protein', 'carbs', 'fat', 'sugar_g', 'fiber_g',
    'vita_mcg', 'vitb6_mg', 'vitb12_mcg', 'vitc_mg', 'vite_mg', 'folate_mcg',
    'niacin_mg', 'riboflavin_mg', 'thiamin_mg', 'calcium_mg', 'copper_mcg',
    'iron_mg', 'magnesium_mg', 'manganese_mg', 'phosphorus_mg', 'selenium_mcg',
    'zinc_mg',
  ];
  static const String _favoritesDDL = '''
    CREATE TABLE favorites (
      fav_id         INTEGER PRIMARY KEY AUTOINCREMENT,
      label          TEXT NOT NULL,
      food_id        INTEGER NOT NULL DEFAULT 0,
      food_name_full TEXT NOT NULL,
      consumed_g     REAL NOT NULL,
      calories       REAL NOT NULL,
      protein        REAL NOT NULL,
      carbs          REAL NOT NULL,
      fat            REAL NOT NULL,
      sugar_g        REAL DEFAULT 0,
      fiber_g        REAL DEFAULT 0,
      vita_mcg       REAL DEFAULT 0,
      vitb6_mg       REAL DEFAULT 0,
      vitb12_mcg     REAL DEFAULT 0,
      vitc_mg        REAL DEFAULT 0,
      vite_mg        REAL DEFAULT 0,
      folate_mcg     REAL DEFAULT 0,
      niacin_mg      REAL DEFAULT 0,
      riboflavin_mg  REAL DEFAULT 0,
      thiamin_mg     REAL DEFAULT 0,
      calcium_mg     REAL DEFAULT 0,
      copper_mcg     REAL DEFAULT 0,
      iron_mg        REAL DEFAULT 0,
      magnesium_mg   REAL DEFAULT 0,
      manganese_mg   REAL DEFAULT 0,
      phosphorus_mg  REAL DEFAULT 0,
      selenium_mcg   REAL DEFAULT 0,
      zinc_mg        REAL DEFAULT 0,
      created_at     TEXT NOT NULL
    )
  ''';
  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE diary_log (
        log_id        INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp     TEXT NOT NULL,
        meal_type     TEXT NOT NULL,
        food_id       INTEGER NOT NULL,
        user_food_name TEXT NOT NULL,
        food_name_full TEXT NOT NULL,
        consumed_g    REAL NOT NULL,
        calories      REAL NOT NULL,
        protein       REAL NOT NULL,
        carbs         REAL NOT NULL,
        fat           REAL NOT NULL,
        sugar_g       REAL DEFAULT 0,
        fiber_g       REAL DEFAULT 0,
        vita_mcg      REAL DEFAULT 0,
        vitb6_mg      REAL DEFAULT 0,
        vitb12_mcg    REAL DEFAULT 0,
        vitc_mg       REAL DEFAULT 0,
        vite_mg       REAL DEFAULT 0,
        folate_mcg    REAL DEFAULT 0,
        niacin_mg     REAL DEFAULT 0,
        riboflavin_mg REAL DEFAULT 0,
        thiamin_mg    REAL DEFAULT 0,
        calcium_mg    REAL DEFAULT 0,
        copper_mcg    REAL DEFAULT 0,
        iron_mg       REAL DEFAULT 0,
        magnesium_mg  REAL DEFAULT 0,
        manganese_mg  REAL DEFAULT 0,
        phosphorus_mg REAL DEFAULT 0,
        selenium_mcg  REAL DEFAULT 0,
        zinc_mg       REAL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE weight_log (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        date       TEXT NOT NULL UNIQUE,
        weight_lbs REAL NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_log_date ON diary_log (timestamp);');
    await db.execute(_favoritesDDL);
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE weight_log (
          id         INTEGER PRIMARY KEY AUTOINCREMENT,
          date       TEXT NOT NULL UNIQUE,
          weight_lbs REAL NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      for (final col in [
        'sugar_g', 'fiber_g', 'vita_mcg', 'vitb6_mg', 'vitb12_mcg',
        'vitc_mg', 'vite_mg', 'folate_mcg', 'niacin_mg', 'riboflavin_mg',
        'thiamin_mg', 'calcium_mg', 'copper_mcg', 'iron_mg', 'magnesium_mg',
        'manganese_mg', 'phosphorus_mg', 'selenium_mcg', 'zinc_mg',
      ]) {
        await db.execute(
            'ALTER TABLE diary_log ADD COLUMN $col REAL DEFAULT 0');
      }
    }
    if (oldVersion < 4) {
      await db.execute(_favoritesDDL);
}
  }

  // --- Diary Log CRUD ---

  Future<int> insertMeal(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('diary_log', row);
  }

  Future<List<Map<String, dynamic>>> getMealsByDate(String dateYMD) async {
    final db = await instance.database;
    return await db.query(
      'diary_log',
      where: 'timestamp LIKE ?',
      whereArgs: ['$dateYMD%'],
      orderBy: 'timestamp ASC',
    );
  }

  Future<Map<String, double>> getDailyTotals(String dateYMD) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT
        SUM(calories) as total_cals,
        SUM(protein)  as total_protein,
        SUM(carbs)    as total_carbs,
        SUM(fat)      as total_fat
      FROM diary_log
      WHERE timestamp LIKE ?
    ''', ['$dateYMD%']);
    if (result.first['total_cals'] == null) {
      return {'calories': 0.0, 'protein': 0.0, 'carbs': 0.0, 'fat': 0.0};
    }
    return {
      'calories': (result.first['total_cals']    as num).toDouble(),
      'protein':  (result.first['total_protein'] as num).toDouble(),
      'carbs':    (result.first['total_carbs']   as num).toDouble(),
      'fat':      (result.first['total_fat']     as num).toDouble(),
    };
  }

  Future<int> deleteMeal(int id) async {
    final db = await instance.database;
    return await db.delete('diary_log', where: 'log_id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAllDates() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT
        substr(timestamp, 1, 10) as date,
        SUM(calories) as total_cals,
        SUM(protein)  as total_protein,
        SUM(carbs)    as total_carbs,
        SUM(fat)      as total_fat,
        COUNT(*)      as item_count
      FROM diary_log
      GROUP BY substr(timestamp, 1, 10)
      ORDER BY date DESC
    ''');
  }

  Future<Map<String, double>> getLast7DaysMicronutrientAverages() async {
    final db = await instance.database;
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final cutoffStr =
        '${cutoff.year}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.day.toString().padLeft(2, '0')}';

    final dayCount = await db.rawQuery('''
      SELECT COUNT(DISTINCT substr(timestamp, 1, 10)) as days
      FROM diary_log WHERE substr(timestamp, 1, 10) >= ?
    ''', [cutoffStr]);
    final days = ((dayCount.first['days'] as int?) ?? 0).toDouble();
    if (days == 0) return {};

    final r = (await db.rawQuery('''
      SELECT
        SUM(calories)      as c,  SUM(protein)       as p,
        SUM(carbs)         as cb, SUM(fat)            as f,
        SUM(sugar_g)       as sg, SUM(fiber_g)        as fg,
        SUM(vita_mcg)      as va, SUM(vitb6_mg)       as vb6,
        SUM(vitb12_mcg)    as vb12, SUM(vitc_mg)      as vc,
        SUM(vite_mg)       as ve, SUM(folate_mcg)     as fo,
        SUM(niacin_mg)     as ni, SUM(riboflavin_mg)  as ri,
        SUM(thiamin_mg)    as th, SUM(calcium_mg)     as ca,
        SUM(copper_mcg)    as cu, SUM(iron_mg)        as ir,
        SUM(magnesium_mg)  as mg, SUM(manganese_mg)   as mn,
        SUM(phosphorus_mg) as ph, SUM(selenium_mcg)   as se,
        SUM(zinc_mg)       as zn
      FROM diary_log WHERE substr(timestamp, 1, 10) >= ?
    ''', [cutoffStr])).first;

    double avg(String k) => ((r[k] as num?) ?? 0).toDouble() / days;

    return {
      'calories': avg('c'),       'protein': avg('p'),
      'carbs': avg('cb'),         'fat': avg('f'),
      'sugar_g': avg('sg'),       'fiber_g': avg('fg'),
      'vita_mcg': avg('va'),      'vitb6_mg': avg('vb6'),
      'vitb12_mcg': avg('vb12'),  'vitc_mg': avg('vc'),
      'vite_mg': avg('ve'),       'folate_mcg': avg('fo'),
      'niacin_mg': avg('ni'),     'riboflavin_mg': avg('ri'),
      'thiamin_mg': avg('th'),    'calcium_mg': avg('ca'),
      'copper_mcg': avg('cu'),    'iron_mg': avg('ir'),
      'magnesium_mg': avg('mg'),  'manganese_mg': avg('mn'),
      'phosphorus_mg': avg('ph'), 'selenium_mcg': avg('se'),
      'zinc_mg': avg('zn'),
    };
  }

  // --- Weight Log CRUD ---

  Future<int> upsertWeight(String dateYMD, double weightLbs) async {
    final db = await instance.database;
    return await db.rawInsert('''
      INSERT INTO weight_log (date, weight_lbs)
      VALUES (?, ?)
      ON CONFLICT(date) DO UPDATE SET weight_lbs = excluded.weight_lbs
    ''', [dateYMD, weightLbs]);
  }

  Future<List<Map<String, dynamic>>> getWeightHistory() async {
    final db = await instance.database;
    return await db.query('weight_log', orderBy: 'date ASC');
  }

  Future<Map<String, dynamic>?> getLatestWeight() async {
    final db = await instance.database;
    final result =
        await db.query('weight_log', orderBy: 'date DESC', limit: 1);
    return result.isNotEmpty ? result.first : null;
  }

  // --- Lifecycle ---

  Future<Map<String, dynamic>> getDataForTDEE() async {
  final db = await instance.database;

  final cals = await db.rawQuery('''
    SELECT
      substr(timestamp, 1, 10) as date,
      SUM(calories) as calories,
      SUM(protein)  as protein_g,
      SUM(carbs)    as carbs_g,
      SUM(fat)      as fat_g
    FROM diary_log
    GROUP BY substr(timestamp, 1, 10)
    ORDER BY date ASC
  ''');

  final weights = await db.query('weight_log', orderBy: 'date ASC');

  return {
    'daily_entries': cals.map((r) => {
      'date':       r['date'] as String,
      'calories':   (r['calories']  as num? ?? 0).toDouble(),
      'protein_g':  (r['protein_g'] as num? ?? 0).toDouble(),
      'carbs_g':    (r['carbs_g']   as num? ?? 0).toDouble(),
      'fat_g':      (r['fat_g']     as num? ?? 0).toDouble(),
    }).toList(),
    'weight_entries': weights.map((r) => {
      'date':       r['date'] as String,
      'weight_lbs': (r['weight_lbs'] as num).toDouble(),
    }).toList(),
    'latest_weight': weights.isNotEmpty
        ? (weights.last['weight_lbs'] as num).toDouble()
        : null,
  };
}

Future<int> updateMeal(int logId, Map<String, dynamic> fields) async {
  final db = await instance.database;
  return await db.update('diary_log', fields,
      where: 'log_id = ?', whereArgs: [logId]);
}

Future<int> copyDayToToday(String sourceDateYMD) async {
  final db = await instance.database;
  final meals = await getMealsByDate(sourceDateYMD);
  final todayTs = DateTime.now().toIso8601String();
  int copied = 0;
  for (final meal in meals) {
    final row = Map<String, dynamic>.from(meal);
    row.remove('log_id');          // let it auto-increment a fresh id
    row['timestamp'] = todayTs;    // re-stamp to today
    await db.insert('diary_log', row);
    copied++;
  }
  return copied;
}
Future<int> addFavorite(Map<String, dynamic> row) async {
  final db = await instance.database;
  return await db.insert('favorites', row);
}

Future<List<Map<String, dynamic>>> getFavorites() async {
  final db = await instance.database;
  return await db.query('favorites', orderBy: 'created_at DESC');
}

Future<int> deleteFavorite(int favId) async {
  final db = await instance.database;
  return await db.delete('favorites', where: 'fav_id = ?', whereArgs: [favId]);
}
  Future close() async {
    final db = _database;
    if (db != null) await db.close();
  }
}