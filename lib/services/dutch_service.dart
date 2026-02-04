import 'package:appwrite/appwrite.dart';
import 'package:nanoid/nanoid.dart';
import '../config/appwrite_config.dart';
import '../services/appwrite_service.dart';
import 'dart:convert'; // For jsonEncode

class DutchService {
  // Use the shared AppwriteService instance to ensure we share the same Client/Session
  final Databases databases = AppwriteService().databases;
  final Account account = AppwriteService().account;
  final Functions functions = AppwriteService().functions;

  DutchService();

  // --- GROUPS ---

  Future<Map<String, dynamic>?> createGroup({
    required String name,
    required String type,
    required List<String> members, // User IDs
    required String createdBy,
    required String currency,
  }) async {
    try {
      // Use Cloud Function to create group with strict permissions (Secure)
      final execution = await functions.createExecution(
        functionId: AppwriteConfig.createGroupFunctionId,
        body: jsonEncode({
          'databaseId': AppwriteConfig.databaseId,
          'collectionId': AppwriteConfig.dutchGroupsCollectionId,
          'name': name,
          'type': type,
          'members': members,
          'createdBy': createdBy,
          'currency': currency == '₹' ? 'INR' : currency,
          'inviteCode': customAlphabet(
            '1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ',
            6,
          ),
        }),
        xasync: false, // Wait for result
      );

      print('DEBUG: Function Status: ${execution.status}');

      // Try to parse the response regardless of status check
      try {
        final dynamic decoded = jsonDecode(execution.responseBody);
        if (decoded is Map && decoded.containsKey('\$id')) {
          final data = Map<String, dynamic>.from(decoded);
          data['id'] = data['\$id'];
          return data;
        }
      } catch (_) {
        // ignore parse error if we are going to throw anyway
      }

      if (execution.status.toString().contains('completed')) {
        // Fallback if parsing matched but we didn't return above (unlikely)
        final dynamic decoded = jsonDecode(execution.responseBody);
        final data = Map<String, dynamic>.from(decoded);
        data['id'] = data['\$id'];
        return data;
      } else {
        throw 'Function execution failed. Status: ${execution.status}, Body: ${execution.responseBody}';
      }
    } catch (e) {
      print('CRITICAL: Cloud Function Failed. Error: $e');
      if (e is AppwriteException) {
        print(
          'Appwrite Code: ${e.code}, Message: ${e.message}, Response: ${e.response}',
        );
      }

      // FALLBACK (If function not deployed): Create locally with creator-only permission?
      // Or just fail. Given strict security requirement, we should fail or warn.
      if (e.toString().contains('function_not_found') ||
          e.toString().contains('404')) {
        print(
          'Function not found. Trying local creation (Limited features)...',
        );
        return _createGroupLocally(
          name: name,
          type: type,
          members: members,
          createdBy: createdBy,
          currency: currency,
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _createGroupLocally({
    required String name,
    required String type,
    required List<String> members,
    required String createdBy,
    required String currency,
  }) async {
    try {
      final doc = await databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.dutchGroupsCollectionId,
        documentId: ID.unique(),
        data: {
          'name': name,
          'type': type,
          'members': members,
          'createdBy': createdBy,
          'currency': currency == '₹' ? 'INR' : currency,
          'inviteCode': customAlphabet(
            '1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ',
            6,
          ),
        },
        permissions: [
          Permission.read(Role.user(createdBy)),
          Permission.write(Role.user(createdBy)),
          // We can't add other members here securely via Client SDK if strict
        ],
      );
      final data = doc.data;
      data['id'] = doc.$id;
      return data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getGroupById(String groupId) async {
    try {
      final doc = await databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.dutchGroupsCollectionId,
        documentId: groupId,
      );
      final data = doc.data;
      data['id'] = doc.$id;
      return data;
    } catch (e) {
      print('Error fetching group by ID: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getMyGroups({
    int limit = 100,
    String? lastId,
  }) async {
    try {
      final List<String> queries = [
        Query.orderDesc('\$createdAt'),
        Query.limit(limit),
      ];
      if (lastId != null && lastId.isNotEmpty) {
        queries.add(Query.cursorAfter(lastId));
      }

      final result = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.dutchGroupsCollectionId,
        queries: queries,
      );
      final docs = result.documents.map((d) {
        final data = d.data;
        data['id'] = d.$id;
        data['\$createdAt'] = d.$createdAt;
        return data;
      }).toList();

      // Sort client-side
      docs.sort((a, b) {
        final dateA = DateTime.parse(a['\$createdAt']);
        final dateB = DateTime.parse(b['\$createdAt']);
        return dateB.compareTo(dateA);
      });

      return docs;
    } catch (e) {
      print('Error fetching groups: $e');
      rethrow;
    }
  }

  // --- EXPENSES ---

  Future<Map<String, dynamic>?> addExpense({
    required String groupId,
    required String description,
    required double amount,
    required String category,
    required String paidBy,
    required String splitType,
    required String splitData, // JSON
    required List<String> groupMembers, // Needed for permissions
  }) async {
    try {
      final execution = await functions.createExecution(
        functionId: AppwriteConfig.createExpenseFunctionId,
        body: jsonEncode({
          'databaseId': AppwriteConfig.databaseId,
          'collectionId': AppwriteConfig.dutchExpensesCollectionId,
          'groupId': groupId,
          'payerId': paidBy,
          'description': description,
          'amount': amount,
          'category': category,
          'splitType': splitType,
          'splitData': splitData,
          'groupMembers': groupMembers,
          'status': 'pending',
        }),
        xasync: false,
      );

      print('DEBUG: addExpense Status: ${execution.status}');

      try {
        final dynamic decoded = jsonDecode(execution.responseBody);
        if (decoded is Map && decoded.containsKey('\$id')) {
          final data = Map<String, dynamic>.from(decoded);
          data['id'] = data['\$id'];
          return data;
        }
      } catch (_) {}

      if (execution.status.toString().contains('completed')) {
        final dynamic decoded = jsonDecode(execution.responseBody);
        final data = Map<String, dynamic>.from(decoded);
        data['id'] = data['\$id'];
        return data;
      } else {
        throw 'Function execution failed. Status: ${execution.status}, Body: ${execution.responseBody}';
      }
    } catch (e) {
      print('CRITICAL: Cloud Function Failed (addExpense). Error: $e');
      if (e is AppwriteException) {
        print('Appwrite Code: ${e.code}, Message: ${e.message}');
      }
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getGroupExpenses(
    String groupId, {
    int limit = 100,
    String? lastId,
  }) async {
    try {
      List<String> queries = [
        Query.equal('groupId', groupId),
        Query.orderDesc('\$createdAt'),
        Query.limit(limit),
      ];
      if (lastId != null && lastId.isNotEmpty) {
        queries.add(Query.cursorAfter(lastId));
      }

      final result = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.dutchExpensesCollectionId,
        queries: queries,
      );
      print(
        'DEBUG: Appwrite response documents count: ${result.documents.length}',
      );
      final docs = result.documents.map((d) {
        final data = d.data;
        data['id'] = d.$id;
        data['\$createdAt'] = d.$createdAt;
        return data;
      }).toList();

      // Client-side filter and sort
      final filtered = docs; // Filtered by server-side query now
      filtered.sort((a, b) {
        final dateA =
            DateTime.tryParse(a['dateTime'] ?? '') ??
            DateTime.tryParse(a['\$createdAt'] ?? '') ??
            DateTime(1970);
        final dateB =
            DateTime.tryParse(b['dateTime'] ?? '') ??
            DateTime.tryParse(b['\$createdAt'] ?? '') ??
            DateTime(1970);
        return dateB.compareTo(dateA);
      });
      return filtered;
    } catch (e) {
      print('Error fetching expenses: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAllExpenses({
    int limit = 25,
    String? lastId,
  }) async {
    try {
      final List<String> queries = [
        Query.orderDesc('\$createdAt'),
        Query.limit(limit),
      ];
      if (lastId != null && lastId.isNotEmpty) {
        queries.add(Query.cursorAfter(lastId));
      }

      final result = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.dutchExpensesCollectionId,
        queries: queries,
      );
      final docs = result.documents.map((d) {
        final data = d.data;
        data['id'] = d.$id;
        data['\$createdAt'] = d.$createdAt;
        return data;
      }).toList();

      // Sort client-side
      docs.sort((a, b) {
        final dateA = DateTime.parse(a['dateTime']);
        final dateB = DateTime.parse(b['dateTime']);
        return dateB.compareTo(dateA);
      });

      return docs;
    } catch (e) {
      print('Error fetching all expenses: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAllSettlements({
    int limit = 25,
    String? lastId,
  }) async {
    try {
      final List<String> queries = [
        Query.orderDesc('\$createdAt'),
        Query.limit(limit),
      ];
      if (lastId != null && lastId.isNotEmpty) {
        queries.add(Query.cursorAfter(lastId));
      }

      final result = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.dutchSettlementsCollectionId,
        queries: queries,
      );
      final docs = result.documents.map((d) {
        final data = d.data;
        data['id'] = d.$id;
        data['\$createdAt'] = d.$createdAt;
        return data;
      }).toList();

      // Sort client-side
      docs.sort((a, b) {
        final dateA = DateTime.parse(a['dateTime']);
        final dateB = DateTime.parse(b['dateTime']);
        return dateB.compareTo(dateA);
      });

      return docs;
    } catch (e) {
      print('Error fetching all settlements: $e');
      rethrow;
    }
  }

  // --- SETTLEMENTS ---

  Future<bool> settleDebt({
    required String groupId,
    required String payerId,
    required String receiverId,
    required double amount,
    required List<String> groupMembers,
    String? expenseId,
  }) async {
    try {
      final execution = await functions.createExecution(
        functionId: AppwriteConfig.createSettlementFunctionId,
        body: jsonEncode({
          'databaseId': AppwriteConfig.databaseId,
          'collectionId': AppwriteConfig.dutchSettlementsCollectionId,
          'groupId': groupId,
          'payerId': payerId,
          'receiverId': receiverId,
          'amount': amount,
          'groupMembers': groupMembers,
          'status': 'pending',
          'expenseId': expenseId,
        }),
        xasync: false,
      );

      print('DEBUG: settleDebt Status: ${execution.status}');

      if (execution.status.toString().contains('completed')) {
        return true;
      } else {
        throw 'Function execution failed. Status: ${execution.status}, Body: ${execution.responseBody}';
      }
    } catch (e) {
      print('CRITICAL: Cloud Function Failed (settleDebt). Error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getGroupSettlements(
    String groupId, {
    int limit = 100,
    String? lastId,
  }) async {
    try {
      List<String> queries = [
        Query.equal('groupId', groupId),
        Query.orderDesc('\$createdAt'),
        Query.limit(limit),
      ];
      if (lastId != null && lastId.isNotEmpty) {
        queries.add(Query.cursorAfter(lastId));
      }

      final result = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.dutchSettlementsCollectionId,
        queries: queries,
      );
      print('DEBUG: Appwrite Settlements count: ${result.documents.length}');
      final docs = result.documents.map((d) {
        final data = d.data;
        data['id'] = d.$id;
        return data;
      }).toList();

      final filtered = docs; // Server-side filtered
      filtered.sort((a, b) {
        final dateA = DateTime.tryParse(a['dateTime'] ?? '') ?? DateTime(1970);
        final dateB = DateTime.tryParse(b['dateTime'] ?? '') ?? DateTime(1970);
        return dateB.compareTo(dateA);
      });
      return filtered;
    } catch (e) {
      print('Error fetching settlements: $e');
      rethrow;
    }
  }

  // --- STATUS UPDATES ---

  Future<bool> updateExpenseStatus(String expenseId, String status) async {
    try {
      await databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.dutchExpensesCollectionId,
        documentId: expenseId,
        data: {'status': status},
      );
      return true;
    } catch (e) {
      print('Error updating expense status: $e');
      return false;
    }
  }

  Future<bool> updateSettlementStatus(
    String settlementId,
    String status,
  ) async {
    try {
      await databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.dutchSettlementsCollectionId,
        documentId: settlementId,
        data: {'status': status},
      );
      return true;
    } catch (e) {
      print('Error updating settlement status: $e');
      return false;
    }
  }
}
