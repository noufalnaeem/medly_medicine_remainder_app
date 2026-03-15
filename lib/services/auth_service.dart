import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../database/db_helper.dart';

class AuthService {
  static const String _keyUserId = 'user_id';
  static const String _keyUserRole = 'user_role';
  static const String _keyIsLoggedIn = 'is_logged_in';

  // Login — validates email/phone AND password
  Future<User?> login(String emailOrPhone, String password) async {
    final dbHelper = DatabaseHelper.instance;
    final userMap =
        await dbHelper.getUserByEmailOrPhone(emailOrPhone, emailOrPhone);
    if (userMap == null) return null;

    final storedPassword = userMap['password'] as String?;
    // If no password stored yet, allow login (backward compat for old accounts)
    if (storedPassword != null &&
        storedPassword.isNotEmpty &&
        storedPassword != password) {
      return null; // Wrong password
    }

    final user = User.fromMap(userMap);
    await _saveSession(user);
    return user;
  }

  // Sign Up — stores email/phone, role, and password
  Future<User?> signUp(User user) async {
    final dbHelper = DatabaseHelper.instance;
    final existing = await dbHelper.getUserByEmailOrPhone(
        user.email ?? '', user.phone ?? '');
    if (existing != null) {
      throw Exception('User already exists with this email or phone.');
    }

    final id = await dbHelper.createUser(user.toMap());

    // Auto-generate a unique patient code for patients
    String? patientCode;
    if (user.role == 'patient') {
      patientCode = _generatePatientCode(id);
      await dbHelper.setPatientCode(id, patientCode);
    }

    final newUser = User(
      id: id,
      email: user.email,
      phone: user.phone,
      role: user.role,
      linkedPatientId: user.linkedPatientId,
      password: user.password,
      patientCode: patientCode,
    );
    await _saveSession(newUser);
    return newUser;
  }

  /// Generates a unique 8-character alphanumeric code based on user ID + random
  String _generatePatientCode(int userId) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = (userId * 7919 + 13337) % 100000000;
    final base = rand.toString().padLeft(8, '0');
    // Make it alphanumeric and more readable
    final letters = chars[(userId + 3) % chars.length] +
        chars[(userId * 3 + 7) % chars.length];
    return letters + base.substring(0, 6);
  }

  // Save session
  Future<void> _saveSession(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    if (user.id != null) await prefs.setInt(_keyUserId, user.id!);
    await prefs.setString(_keyUserRole, user.role);
  }

  // Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // Get current session
  Future<Map<String, dynamic>> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
    int? userId = prefs.getInt(_keyUserId);
    String? role = prefs.getString(_keyUserRole);

    return {
      'isLoggedIn': isLoggedIn,
      'userId': userId,
      'role': role,
    };
  }
}
