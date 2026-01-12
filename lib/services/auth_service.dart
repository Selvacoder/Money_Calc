import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AuthService {
  static const String _isLoggedInKey = 'isLoggedIn';
  static const String _currentUserKey = 'currentUser';
  static const String _usersKey = 'registeredUsers';

  // User data structure
  Map<String, dynamic> _createUser(String name, String email, String password) {
    return {
      'name': name,
      'email': email,
      'password': password, // In production, this should be hashed!
      'username': email.split('@')[0],
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  // Get all registered users
  Future<Map<String, dynamic>> _getRegisteredUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString(_usersKey);
    if (usersJson == null) return {};
    return Map<String, dynamic>.from(json.decode(usersJson));
  }

  // Save registered users
  Future<void> _saveRegisteredUsers(Map<String, dynamic> users) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usersKey, json.encode(users));
  }

  // Check if email already exists
  Future<bool> emailExists(String email) async {
    final users = await _getRegisteredUsers();
    return users.containsKey(email.toLowerCase());
  }

  // Sign up new user
  Future<Map<String, dynamic>> signUp(
    String name,
    String email,
    String password,
  ) async {
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      return {'success': false, 'message': 'All fields are required'};
    }

    final emailLower = email.toLowerCase();

    // Check if email already registered
    if (await emailExists(emailLower)) {
      return {
        'success': false,
        'message': 'Email already registered. Please login.',
      };
    }

    // Create and save new user
    final users = await _getRegisteredUsers();
    users[emailLower] = _createUser(name, emailLower, password);
    await _saveRegisteredUsers(users);

    // Log user in
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, true);
    await prefs.setString(_currentUserKey, json.encode(users[emailLower]));

    return {'success': true, 'message': 'Account created successfully'};
  }

  // Login with email and password
  Future<Map<String, dynamic>> login(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      return {'success': false, 'message': 'Email and password are required'};
    }

    final emailLower = email.toLowerCase();
    final users = await _getRegisteredUsers();

    // Check if email exists
    if (!users.containsKey(emailLower)) {
      return {
        'success': false,
        'message': 'Email not registered. Please sign up first.',
      };
    }

    // Verify password
    final user = users[emailLower];
    if (user['password'] != password) {
      return {'success': false, 'message': 'Incorrect password'};
    }

    // Log user in
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, true);
    await prefs.setString(_currentUserKey, json.encode(user));

    return {'success': true, 'message': 'Login successful'};
  }

  // Google Sign In (placeholder for future Google Auth integration)
  Future<bool> signInWithGoogle() async {
    // This would integrate with google_sign_in package
    // For now, it's a placeholder that simulates Google login
    final prefs = await SharedPreferences.getInstance();

    // Create a Google user if not exists
    final googleEmail = 'user@gmail.com';
    final users = await _getRegisteredUsers();

    if (!users.containsKey(googleEmail)) {
      users[googleEmail] = _createUser(
        'Google User',
        googleEmail,
        'google_auth',
      );
      await _saveRegisteredUsers(users);
    }

    await prefs.setBool(_isLoggedInKey, true);
    await prefs.setString(_currentUserKey, json.encode(users[googleEmail]));
    return true;
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_currentUserKey);
    if (userJson == null) return null;
    final user = json.decode(userJson);
    return user['username'];
  }

  Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_currentUserKey);
    if (userJson == null) return null;
    final user = json.decode(userJson);
    return user['email'];
  }

  Future<String?> getName() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_currentUserKey);
    if (userJson == null) return null;
    final user = json.decode(userJson);
    return user['name'];
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    // Only clear current session, keep registered users
    await prefs.remove(_isLoggedInKey);
    await prefs.remove(_currentUserKey);
    // Also clear transactions and other user data
    final keys = prefs.getKeys();
    for (var key in keys) {
      if (key != _usersKey) {
        await prefs.remove(key);
      }
    }
  }
}
