import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/appwrite_service.dart'; // Keep if used for mock/other calls

class UserProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  // final AppwriteService _appwriteService = AppwriteService(); // Removed unused warning

  UserProfile? _user;
  bool _isLoading = true;
  bool _isAuthenticated = false;

  UserProfile? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;

  late Box<UserProfile> _userBox;
  bool _isHiveInitialized = false;

  UserProvider() {
    init();
  }

  Future<void> init() async {
    await checkAuthStatus();
  }

  // Added loadUser as alias for checkAuthStatus to fix error in HomeScreen
  Future<void> loadUser() async {
    await checkAuthStatus();
  }

  Future<void> _initHive() async {
    if (_isHiveInitialized) return;
    _userBox = await Hive.openBox<UserProfile>('user_profile');
    _isHiveInitialized = true;
  }

  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    await _initHive();

    // 1. Load from Cache
    if (_userBox.isNotEmpty) {
      _user = _userBox.get('current_user');
      if (_user != null) {
        _isAuthenticated = true;
        notifyListeners(); // Show cached user immediately
      }
    }

    try {
      // 2. Check Real Auth
      final isLoggedIn = await _authService.isLoggedIn();
      if (isLoggedIn) {
        final userData = await _authService.getCurrentUser();
        if (userData != null) {
          final newUser = UserProfile(
            userId: userData['userId'],
            name: userData['name'],
            email: userData['email'],
            phone: userData['phone'],
            photoUrl: '', // Placeholder
            joinDate: DateTime.parse(userData['joinDate']),
          );
          _user = newUser;
          _isAuthenticated = true;

          // Update Cache
          await _userBox.put('current_user', newUser);
        } else {
          _isAuthenticated = false;
          // If server says no user, maybe clear cache?
          // Yes, consistent state.
          // But if offline, this block might throw/not happen.
          // _user = null; // Do NOT clear if just offline error.
        }
      } else {
        // Explicitly NOT logged in (e.g. session expired or never logged in)
        _isAuthenticated = false;
        _user = null;
        await _userBox.clear();
      }
    } catch (e) {
      print('Auth Check Error: $e');
      // On error (offline), trust cache.
      if (_user != null) {
        _isAuthenticated = true;
      } else {
        _isAuthenticated = false;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _authService.login(email: email, password: password);
      if (result['success']) {
        await checkAuthStatus();
      }
      return result;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> signUp({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _authService.signUp(
        name: name,
        email: email,
        password: password,
        phone: phone,
      );
      if (result['success']) {
        await checkAuthStatus();
      }
      return result;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile(UserProfile updatedProfile) async {
    _isLoading = true;
    notifyListeners();
    try {
      // Mocking the call or calling a method I need to create
      // await _authService.updateProfile(updatedProfile);

      // For now, update local state
      _user = updatedProfile;
      if (_isHiveInitialized) {
        await _userBox.put('current_user', updatedProfile);
      }

      // TODO: Persist to backend
      // await _appwriteService.updateUser(...)
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();
    try {
      final success = await _authService.signInWithGoogle();
      if (success) {
        await checkAuthStatus();
      }
      return success;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    try {
      if (_isHiveInitialized) {
        await _userBox.clear();
      }
      await _authService.logout();
      _user = null;
      _isAuthenticated = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
