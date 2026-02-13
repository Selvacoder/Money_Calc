import 'package:flutter/foundation.dart';
import '../services/appwrite_service.dart';
import 'package:appwrite/appwrite.dart';

class NotificationProvider extends ChangeNotifier {
  final AppwriteService _appwriteService = AppwriteService();

  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = false;

  String? _userId;

  List<Map<String, dynamic>> get notifications => _notifications;
  bool get isLoading => _isLoading;

  Future<void> init(String userId) async {
    debugPrint('DEBUG: NotificationProvider Initializing for userId: $userId');
    _userId = userId;
    await fetchNotifications();
  }

  Future<void> fetchNotifications({bool silent = false}) async {
    if (_userId == null) return;
    if (!silent) {
      _isLoading = true;
      Future.microtask(() => notifyListeners());
    }

    try {
      final data = await _appwriteService.getNotifications(_userId!);
      debugPrint('DEBUG: Fetched ${data.length} notifications for $_userId');
      _notifications = data;
      notifyListeners();
    } catch (e) {
      if (e is! AppwriteException || e.code != 401) {
        debugPrint('Error fetching notifications: $e');
      }
    } finally {
      if (!silent) {
        _isLoading = false;
        Future.microtask(() => notifyListeners());
      }
    }
  }
}
