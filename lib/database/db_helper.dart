import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('medicine_reminder.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 8,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const integerType = 'INTEGER NOT NULL';
    
    // Create Users Table
    await db.execute('''
    CREATE TABLE users (
      id $idType,
      email TEXT,
      phone TEXT,
      role $textType,
      linked_patient_id INTEGER,
      caregiver_phone TEXT,
      full_name TEXT,
      age TEXT,
      condition TEXT,
      caregiver_name TEXT,
      password TEXT,
      patient_code TEXT,
      linked_patient_code TEXT
    )
    ''');

    // Create Medicines Table
    await db.execute('''
    CREATE TABLE medicines (
      id $idType,
      name $textType,
      purpose $textType,
      dosage $textType,
      schedule $textType,
      quantity INTEGER NOT NULL DEFAULT 10,
      patient_id $integerType
    )
    ''');

    // Create Logs Table
    await db.execute('''
    CREATE TABLE logs (
      id $idType,
      medicine_id $integerType,
      taken_time $textType,
      status $textType
    )
    ''');

    // Create Notifications Table
    await db.execute('''
    CREATE TABLE notifications (
      id $idType,
      patient_id $integerType,
      title $textType,
      body $textType,
      timestamp $textType
    )
    ''');

    // Create Emergency Contacts Table
    await db.execute('''
    CREATE TABLE emergency_contacts (
      id $idType,
      caregiver_id $integerType,
      name $textType,
      phone $textType,
      relationship TEXT
    )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
      CREATE TABLE IF NOT EXISTS notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        patient_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
      ''');
    }
    Future<void> tryAlter(String sql) async {
      try { await db.execute(sql); } catch (_) {}
    }
    if (oldVersion < 3) {
      await tryAlter(
        'ALTER TABLE medicines ADD COLUMN quantity INTEGER NOT NULL DEFAULT 10',
      );
    }
    if (oldVersion < 4) {
      await tryAlter('ALTER TABLE users ADD COLUMN caregiver_phone TEXT');
    }
    if (oldVersion < 5) {
      await tryAlter('ALTER TABLE users ADD COLUMN full_name TEXT');
      await tryAlter('ALTER TABLE users ADD COLUMN age TEXT');
      await tryAlter('ALTER TABLE users ADD COLUMN condition TEXT');
      await tryAlter('ALTER TABLE users ADD COLUMN caregiver_name TEXT');
    }
    if (oldVersion < 6) {
      await tryAlter('ALTER TABLE users ADD COLUMN password TEXT');
    }
    if (oldVersion < 7) {
      await tryAlter('ALTER TABLE users ADD COLUMN patient_code TEXT');
      await tryAlter('ALTER TABLE users ADD COLUMN linked_patient_code TEXT');
    }
    if (oldVersion < 8) {
      try {
        await db.execute('''
        CREATE TABLE IF NOT EXISTS emergency_contacts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          caregiver_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          phone TEXT NOT NULL,
          relationship TEXT
        )
        ''');
      } catch (_) {}
    }
  }

  // --- User CRUD ---
  Future<int> createUser(Map<String, dynamic> user) async {
    final db = await instance.database;
    return await db.insert('users', user);
  }

  Future<void> updateProfile(int userId, Map<String, dynamic> fields) async {
    final db = await instance.database;
    await db.update('users', fields, where: 'id = ?', whereArgs: [userId]);
  }

  Future<Map<String, dynamic>?> getUser(int id) async {
    final db = await instance.database;
    final maps = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return maps.first;
    } else {
      return null;
    }
  }

  Future<String?> getCaregiverPhone(int userId) async {
    final db = await instance.database;
    final maps = await db.query('users', columns: ['caregiver_phone'],
        where: 'id = ?', whereArgs: [userId]);
    if (maps.isEmpty) return null;
    return maps.first['caregiver_phone'] as String?;
  }

  Future<void> setCaregiverPhone(int userId, String phone) async {
    final db = await instance.database;
    await db.update(
      'users',
      {'caregiver_phone': phone},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<Map<String, dynamic>?> getUserByEmailOrPhone(String email, String phone) async {
    final db = await instance.database;
    final maps = await db.query('users', where: 'email = ? OR phone = ?', whereArgs: [email, phone]);
    if (maps.isNotEmpty) return maps.first;
    return null;
  }

  /// Find a patient by their unique patient_code
  Future<Map<String, dynamic>?> getUserByPatientCode(String code) async {
    final db = await instance.database;
    final maps = await db.query('users',
        where: 'patient_code = ? AND role = ?', whereArgs: [code, 'patient']);
    if (maps.isNotEmpty) return maps.first;
    return null;
  }

  /// Set the patient_code for a user (called once on patient signup)
  Future<void> setPatientCode(int userId, String code) async {
    final db = await instance.database;
    await db.update('users', {'patient_code': code},
        where: 'id = ?', whereArgs: [userId]);
  }

  /// Caregiver stores the patient code they linked to
  Future<void> setLinkedPatientCode(int caregiverId, String code) async {
    final db = await instance.database;
    await db.update('users', {'linked_patient_code': code},
        where: 'id = ?', whereArgs: [caregiverId]);
  }

  /// Get the patient code currently linked to a caregiver
  Future<String?> getLinkedPatientCode(int caregiverId) async {
    final db = await instance.database;
    final maps = await db.query('users',
        columns: ['linked_patient_code'],
        where: 'id = ?',
        whereArgs: [caregiverId]);
    if (maps.isEmpty) return null;
    return maps.first['linked_patient_code'] as String?;
  }

  // --- Medicine CRUD ---
  Future<int> createMedicine(Map<String, dynamic> medicine) async {
    final db = await instance.database;
    return await db.insert('medicines', medicine);
  }

  Future<List<Map<String, dynamic>>> getMedicinesByPatient(int patientId) async {
    final db = await instance.database;
    return await db.query('medicines', where: 'patient_id = ?', whereArgs: [patientId]);
  }

  Future<Map<String, dynamic>?> getMedicine(int id) async {
    final db = await instance.database;
    final maps = await db.query('medicines', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return maps.first;
    return null;
  }

  /// Alias used by caregiver dashboard
  Future<List<Map<String, dynamic>>> getMedicinesForPatient(int patientId) =>
      getMedicinesByPatient(patientId);

  Future<int> updateMedicine(Map<String, dynamic> medicine) async {
    final db = await instance.database;
    return db.update('medicines', medicine, where: 'id = ?', whereArgs: [medicine['id']]);
  }

  Future<int> deleteMedicine(int id) async {
    final db = await instance.database;
    return await db.delete('medicines', where: 'id = ?', whereArgs: [id]);
  }

  // --- Log CRUD ---
  Future<int> createLog(Map<String, dynamic> log) async {
    final db = await instance.database;
    return await db.insert('logs', log);
  }

  Future<List<Map<String, dynamic>>> getLogsByMedicine(int medicineId) async {
    final db = await instance.database;
    return await db.query('logs', where: 'medicine_id = ?', whereArgs: [medicineId]);
  }

  Future<List<Map<String, dynamic>>> getAllLogs() async {
    final db = await instance.database;
    return await db.query('logs', orderBy: 'taken_time DESC');
  }

  Future<int> clearAllLogs() async {
    final db = await instance.database;
    return await db.delete('logs');
  }

  Future<List<Map<String, dynamic>>> getAllMedicines() async {
    final db = await instance.database;
    return await db.query('medicines');
  }

  Future<int> decrementQuantity(int medicineId) async {
    final db = await instance.database;
    final maps = await db.query('medicines', where: 'id = ?', whereArgs: [medicineId]);
    if (maps.isEmpty) return 0;
    final current = (maps.first['quantity'] as int?) ?? 0;
    if (current <= 0) return 0;
    return await db.update(
      'medicines',
      {'quantity': current - 1},
      where: 'id = ?',
      whereArgs: [medicineId],
    );
  }

  // --- Notification CRUD ---
  Future<int> insertNotification(Map<String, dynamic> notification) async {
    final db = await instance.database;
    return await db.insert('notifications', notification);
  }

  Future<List<Map<String, dynamic>>> getNotificationsByPatient(int patientId) async {
    final db = await instance.database;
    return await db.query(
      'notifications',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'timestamp DESC',
    );
  }

  Future<int> deleteAllNotifications(int patientId) async {
    final db = await instance.database;
    return await db.delete('notifications', where: 'patient_id = ?', whereArgs: [patientId]);
  }

  Future<int> deleteNotification(int id) async {
    final db = await instance.database;
    return await db.delete('notifications', where: 'id = ?', whereArgs: [id]);
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }

  // --- Emergency Contacts CRUD ---
  Future<int> insertEmergencyContact(Map<String, dynamic> contact) async {
    final db = await instance.database;
    return await db.insert('emergency_contacts', contact);
  }

  Future<List<Map<String, dynamic>>> getEmergencyContacts(int caregiverId) async {
    final db = await instance.database;
    return await db.query(
      'emergency_contacts',
      where: 'caregiver_id = ?',
      whereArgs: [caregiverId],
      orderBy: 'name ASC',
    );
  }

  Future<int> updateEmergencyContact(int id, Map<String, dynamic> fields) async {
    final db = await instance.database;
    return await db.update('emergency_contacts', fields,
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteEmergencyContact(int id) async {
    final db = await instance.database;
    return await db.delete('emergency_contacts',
        where: 'id = ?', whereArgs: [id]);
  }

  /// Find the caregiver who has linked the given patientId.
  /// Returns the caregiver user map, or null if none linked.
  Future<Map<String, dynamic>?> getCaregiverForPatient(int patientId) async {
    final db = await instance.database;
    // First get this patient's patient_code
    final patients = await db.query('users',
        columns: ['patient_code'], where: 'id = ?', whereArgs: [patientId]);
    if (patients.isEmpty) return null;
    final code = patients.first['patient_code'] as String?;
    if (code == null || code.isEmpty) return null;
    // Then find a caregiver who linked that code
    final caregivers = await db.query('users',
        where: 'role = ? AND linked_patient_code = ?',
        whereArgs: ['caregiver', code]);
    if (caregivers.isEmpty) return null;
    return caregivers.first;
  }
}

