import '../services/appwrite_service.dart';

class AuthService {
  final _appwrite = AppwriteService();

  Future<Map<String, dynamic>> signUp(
    String name,
    String email,
    String password,
  ) async {
    return await _appwrite.signUp(name: name, email: email, password: password);
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    return await _appwrite.login(email: email, password: password);
  }

  Future<bool> signInWithGoogle() async {
    // TODO: Implement OAuth with Appwrite
    return false;
  }

  Future<bool> isLoggedIn() async {
    return await _appwrite.isLoggedIn();
  }

  Future<String?> getName() async {
    final user = await _appwrite.getCurrentUser();
    return user?['name'];
  }

  Future<String?> getEmail() async {
    final user = await _appwrite.getCurrentUser();
    return user?['email'];
  }

  Future<String?> getUsername() async {
    final email = await getEmail();
    return email?.split('@')[0];
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    return await _appwrite.getCurrentUser();
  }

  Future<void> logout() async {
    await _appwrite.logout();
  }
}
