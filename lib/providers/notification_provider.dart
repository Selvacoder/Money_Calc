import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/appwrite_service.dart';
import '../services/notification_service.dart';
import 'package:appwrite/appwrite.dart';

class NotificationProvider extends ChangeNotifier {
  final AppwriteService _appwriteService = AppwriteService();
  final NotificationService _notificationService = NotificationService();

  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = false;
  Timer? _pollingTimer;
  RealtimeSubscription? _subscription;
  String? _userId;

  List<Map<String, dynamic>> get notifications => _notifications;
  bool get isLoading => _isLoading;

  Future<void> init(String userId) async {
    debugPrint('DEBUG: NotificationProvider Initializing for userId: $userId');
    _userId = userId;
    await fetchNotifications();
    _subscribeToRealtime();
  }

  Future<void> fetchNotifications({bool silent = false}) async {
    if (_userId == null) return;
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final data = await _appwriteService.getNotifications(_userId!);
      debugPrint('DEBUG: Fetched ${data.length} notifications for $_userId');
      _notifications = data;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void _subscribeToRealtime() {
    if (_userId == null || _subscription != null) return;

    final sub = _appwriteService.subscribeToNotifications(
      _userId!,
      (data) {
        // Notification received
        _handleNewNotification(data);
      },
      onError: (error) {
        debugPrint(
          'Notification Realtime Error: $error. Switching to polling.',
        );
        _subscription?.close().catchError((_) {});
        _subscription = null;
        startPolling();
      },
    );

    if (sub != null) {
      _subscription = sub;
    } else {
      debugPrint('Notification Realtime unavailable, starting polling.');
      startPolling();
    }
  }

  void _handleNewNotification(Map<String, dynamic> data) {
    // Add to list
    _notifications.insert(0, data);
    notifyListeners();

    // Show Local Notification
    _notificationService.showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: data['title'] ?? 'New Notification',
      body: data['message'] ?? '',
      payload: data['type'],
    );
  }

  void startPolling() {
    if (_pollingTimer != null) return;
    _pollingTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      _checkNewNotifications();
    });
  }

  Future<void> _checkNewNotifications() async {
    if (_userId == null) return;
    try {
      final latest = await _appwriteService.getNotifications(
        _userId!,
        limit: 5,
      );

      debugPrint(
        'DEBUG: Polling Notifications - Found ${latest.length} docs for $_userId',
      );

      // Check for new IDs not in current list
      bool hasNew = false;
      for (var n in latest) {
        final nid = n['\$id'] ?? n['id'];
        if (!_notifications.any(
          (existing) => (existing['\$id'] ?? existing['id']) == nid,
        )) {
          debugPrint('DEBUG: Triggering new notification: $nid');
          _handleNewNotification(n);
          hasNew = true;
        }
      }

      if (hasNew) {
        // Full refresh to ensure consistency
        fetchNotifications(silent: true);
      }
    } catch (e) {
      debugPrint('Error polling notifications: $e');
    }
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  @override
  void dispose() {
    stopPolling();
    _subscription?.close();
    super.dispose();
  }
}
