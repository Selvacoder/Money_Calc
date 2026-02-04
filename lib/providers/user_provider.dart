import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
// Keep for now
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/appwrite_service.dart';
import 'package:appwrite/appwrite.dart';

class UserProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final AppwriteService _appwriteService = AppwriteService();

  UserProfile? _user;
  bool _isLoading =
      false; // Changed from true to false to show splash/login immediately
  bool _isAuthenticated = false;
  bool _isInitialCheckDone = false;

  UserProfile? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  bool get isInitialCheckDone => _isInitialCheckDone;

  List<String> _banks = [];
  List<String> get banks => _banks;

  Map<String, String> _primaryPaymentMethods = {};
  Map<String, String> get primaryPaymentMethods => _primaryPaymentMethods;

  late Box<UserProfile> _userBox;
  late Box _settingsBox; // New box for banks and primary methods
  bool _isHiveInitialized = false;

  UserProvider() {
    // init(); // Do not call async init in constructor without care
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
    _settingsBox = await Hive.openBox('user_settings');
    _isHiveInitialized = true;

    // Load banks and primary methods
    _banks = List<String>.from(_settingsBox.get('banks', defaultValue: []));
    _primaryPaymentMethods = Map<String, String>.from(
      _settingsBox.get('primary_payment_methods', defaultValue: {}),
    );
  }

  Future<void> checkAuthStatus({bool forceCheck = false}) async {
    _isLoading = true;
    Future.microtask(() => notifyListeners());

    debugPrint('DEBUG: checkAuthStatus started (forceCheck: $forceCheck)');
    await _initHive();

    // 1. Load from Cache
    if (_userBox.isNotEmpty) {
      _user = _userBox.get('current_user');
      if (_user != null) {
        _isAuthenticated = true;
        // Schedule for next frame to avoid build-time errors
        Future.microtask(() => notifyListeners());
      }
    }

    try {
      // 2. Check Real Auth
      final isLoggedIn = await _authService.isLoggedIn(forceCheck: forceCheck);
      debugPrint('DEBUG: checkAuthStatus - isLoggedIn: $isLoggedIn');
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
          // Sync Banks & Primary Methods from Cloud to Local
          if (userData['banks'] != null) {
            _banks = List<String>.from(userData['banks']);
            await _settingsBox.put('banks', _banks);
          }
          if (userData['primaryPaymentMethods'] != null) {
            _primaryPaymentMethods = Map<String, String>.from(
              userData['primaryPaymentMethods'],
            );
            await _settingsBox.put(
              'primary_payment_methods',
              _primaryPaymentMethods,
            );
          }

          _user = newUser;
          _isAuthenticated = true;
          debugPrint(
            'DEBUG: checkAuthStatus - Authenticated as ${newUser.email}',
          );

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
      if (e is AppwriteException && e.code == 401) {
        // Definitely not logged in
        _isAuthenticated = false;
        _user = null;
        if (_isHiveInitialized) await _userBox.clear();
      } else {
        if (e is! AppwriteException || e.code != 401) {
          print('Auth Check Error: $e');
        }
        // On other errors (offline), trust cache.
        if (_user != null) {
          _isAuthenticated = true;
        } else {
          _isAuthenticated = false;
        }
      }
    } finally {
      _isLoading = false;
      _isInitialCheckDone = true;
      Future.microtask(() => notifyListeners());
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    _isLoading = true;
    Future.microtask(() => notifyListeners()); // Wrap notifyListeners

    try {
      final result = await _authService.login(email: email, password: password);
      debugPrint('DEBUG: Login result: $result');
      if (result['success']) {
        // Essential delay for Web session propagation
        await Future.delayed(const Duration(milliseconds: 200));
        await checkAuthStatus(forceCheck: true);
      }
      return result;
    } finally {
      _isLoading = false;
      Future.microtask(() => notifyListeners());
    }
  }

  Future<Map<String, dynamic>> signUp({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) async {
    _isLoading = true;
    Future.microtask(() => notifyListeners()); // Wrap notifyListeners

    try {
      final result = await _authService.signUp(
        name: name,
        email: email,
        password: password,
        phone: phone,
      );
      if (result['success']) {
        // Essential delay for Web session propagation
        await Future.delayed(const Duration(milliseconds: 200));
        await checkAuthStatus(forceCheck: true);
      }
      return result;
    } finally {
      _isLoading = false;
      Future.microtask(() => notifyListeners());
    }
  }

  Future<void> updateProfile(UserProfile updatedProfile) async {
    _isLoading = true;
    Future.microtask(() => notifyListeners()); // Wrap notifyListeners
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
    Future.microtask(() => notifyListeners()); // Wrap notifyListeners
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
    Future.microtask(() => notifyListeners()); // Wrap notifyListeners
    try {
      if (_isHiveInitialized) {
        await _userBox.clear();
        await _settingsBox.clear();
        _banks = [];
        _primaryPaymentMethods = {};
      }
      // Check if already logged out from Appwrite to avoid unnecessary calls/errors
      if (!await _appwriteService.isLoggedIn()) {
        // Silent return, no print
        _isLoading = false;
        notifyListeners();
        return;
      }
      await _authService.logout();
      _user = null;
      _isAuthenticated = false;
    } catch (e) {
      // Log error but proceed with local logout if Appwrite logout fails
      print('Logout Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Bank Management Methods ---

  Future<void> addBank(String bankName) async {
    if (!_banks.contains(bankName)) {
      _banks.add(bankName);
      await _settingsBox.put('banks', _banks);
      notifyListeners();
      await _syncPreferences();
    }
  }

  Future<void> removeBank(String bankName) async {
    if (_banks.contains(bankName)) {
      _banks.remove(bankName);
      await _settingsBox.put('banks', _banks);

      // Also remove from primary methods if selected
      final keysToRemove = _primaryPaymentMethods.entries
          .where((entry) => entry.value == bankName)
          .map((e) => e.key)
          .toList();

      for (var key in keysToRemove) {
        _primaryPaymentMethods.remove(key);
      }

      if (keysToRemove.isNotEmpty) {
        await _settingsBox.put(
          'primary_payment_methods',
          _primaryPaymentMethods,
        );
      }
      notifyListeners();
      await _syncPreferences();
    }
  }

  Future<void> setPrimaryPaymentMethod(String method, String? bankName) async {
    if (bankName == null) {
      _primaryPaymentMethods.remove(method);
    } else {
      _primaryPaymentMethods[method] = bankName;
    }
    await _settingsBox.put('primary_payment_methods', _primaryPaymentMethods);
    notifyListeners();
    await _syncPreferences();
  }

  Future<void> _syncPreferences() async {
    if (_user != null) {
      await _appwriteService.updateUserPreferences(
        userId: _user!.userId,
        banks: _banks,
        primaryPaymentMethods: _primaryPaymentMethods,
      );
    }
  }
}
