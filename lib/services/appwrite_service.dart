import 'package:appwrite/appwrite.dart';
import '../config/appwrite_config.dart';

class AppwriteService {
  static final AppwriteService _instance = AppwriteService._internal();
  factory AppwriteService() => _instance;
  AppwriteService._internal();

  late Client client;
  late Account account;
  late Databases databases;

  void init() {
    client = Client()
        .setEndpoint(AppwriteConfig.endpoint)
        .setProject(AppwriteConfig.projectId)
        .setSelfSigned(status: true); // Allow self-signed certificates

    account = Account(client);
    databases = Databases(client);
  }

  // Get current user session
  Future<bool> isLoggedIn() async {
    try {
      // Add timeout to prevent long loading if server is unreachable
      await account.get().timeout(const Duration(seconds: 5));
      return true;
    } catch (e) {
      // If timeout or error, assume not logged in
      return false;
    }
  }

  // Sign up new user
  Future<Map<String, dynamic>> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      // 1. Try to create account
      try {
        await account.create(
          userId: ID.unique(),
          email: email,
          password: password,
          name: name,
        );
      } on AppwriteException catch (e) {
        // If user already exists (409), try to login
        if (e.code == 409) {
          return await login(email: email, password: password);
        }
        rethrow;
      }

      // 2. Login
      await account.createEmailPasswordSession(
        email: email,
        password: password,
      );

      return {'success': true, 'message': 'Account created successfully'};
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Login with email and password
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      await account.createEmailPasswordSession(
        email: email,
        password: password,
      );
      return {'success': true, 'message': 'Login successful'};
    } on AppwriteException catch (e) {
      if (e.code == 401) {
        return {'success': false, 'message': 'Invalid email or password'};
      }
      return {'success': false, 'message': e.message ?? 'Login failed'};
    } catch (e) {
      return {'success': false, 'message': 'An error occurred: $e'};
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await account.deleteSession(sessionId: 'current');
    } catch (e) {
      // Ignore errors on logout
    }
  }

  // Get current user details from Auth (No Database needed)
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final user = await account.get();

      // Return data directly from Auth Account
      return {
        'userId': user.$id,
        'name': user.name,
        'email': user.email,
        'phone': user.phone.isNotEmpty ? user.phone : '',
        'joinDate': user.registration,
      };
    } catch (e) {
      return null;
    }
  }

  // Update user name (in Auth)
  Future<bool> updateUserProfile({
    required String userId,
    required String name,
    required String phone,
  }) async {
    try {
      await account.updateName(name: name);
      // Phone update requires password/verification in strict mode, skipping for now
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- TRANSACTIONS ---

  Future<List<Map<String, dynamic>>> getTransactions() async {
    try {
      final user = await account.get();
      final result = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.transactionsCollectionId,
        queries: [
          Query.equal('userId', [user.$id]),
          Query.orderDesc('dateTime'),
        ],
      );

      return result.documents.map((doc) {
        final data = doc.data;
        data['id'] = doc.$id; // Ensure ID is mapped
        return data;
      }).toList();
    } catch (e) {
      print('Error fetching transactions: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> createTransaction(
    Map<String, dynamic> transactionData,
  ) async {
    try {
      final user = await account.get();

      // Prepare data for Appwrite
      final data = {
        'userId': user.$id,
        'title': transactionData['title'],
        'amount': transactionData['amount'],
        'isExpense': transactionData['isExpense'],
        'dateTime': transactionData['dateTime'],
        'categoryId': transactionData['categoryId'],
        'itemId': transactionData['itemId'],
      };

      final doc = await databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.transactionsCollectionId,
        documentId: ID.unique(),
        data: data,
      );

      // Increment Usage Counts
      if (transactionData['categoryId'] != null) {
        incrementCategoryUsage(transactionData['categoryId']);
      }
      if (transactionData['itemId'] != null) {
        incrementItemUsage(transactionData['itemId']);
      }

      final responseData = doc.data;
      responseData['id'] = doc.$id;
      return responseData;
    } catch (e) {
      print('Error creating transaction: $e');
      return null;
    }
  }

  Future<bool> deleteTransaction(String transactionId) async {
    try {
      // 1. Fetch transaction details before deleting
      final doc = await databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.transactionsCollectionId,
        documentId: transactionId,
      );

      final categoryId = doc.data['categoryId'];
      final itemId = doc.data['itemId'];

      // 2. Decrement Usage
      if (categoryId != null) {
        await decrementCategoryUsage(categoryId);
      }
      if (itemId != null) {
        await decrementItemUsage(itemId);
      }

      // 3. Delete Document
      await databases.deleteDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.transactionsCollectionId,
        documentId: transactionId,
      );
      return true;
    } catch (e) {
      print('Error deleting transaction: $e');
      return false;
    }
  }

  // ... (Other methods)

  // Usage Counters
  Future<void> incrementCategoryUsage(String categoryId) async {
    try {
      final doc = await databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.categoriesCollectionId,
        documentId: categoryId,
      );
      final currentUsage = doc.data['usageCount'] ?? 0;
      await databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.categoriesCollectionId,
        documentId: categoryId,
        data: {'usageCount': currentUsage + 1},
      );
    } catch (e) {
      print('Error incrementing category usage: $e');
    }
  }

  Future<void> incrementItemUsage(String itemId) async {
    try {
      final doc = await databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.itemsCollectionId,
        documentId: itemId,
      );
      final currentUsage = doc.data['usageCount'] ?? 0;
      await databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.itemsCollectionId,
        documentId: itemId,
        data: {'usageCount': currentUsage + 1},
      );
    } catch (e) {
      print('Error incrementing item usage: $e');
    }
  }

  Future<void> decrementCategoryUsage(String categoryId) async {
    try {
      final doc = await databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.categoriesCollectionId,
        documentId: categoryId,
      );
      final currentUsage = doc.data['usageCount'] ?? 0;
      if (currentUsage > 0) {
        await databases.updateDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.categoriesCollectionId,
          documentId: categoryId,
          data: {'usageCount': currentUsage - 1},
        );
      }
    } catch (e) {
      print('Error decrementing category usage: $e');
    }
  }

  Future<void> decrementItemUsage(String itemId) async {
    try {
      final doc = await databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.itemsCollectionId,
        documentId: itemId,
      );
      final currentUsage = doc.data['usageCount'] ?? 0;
      if (currentUsage > 0) {
        await databases.updateDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.itemsCollectionId,
          documentId: itemId,
          data: {'usageCount': currentUsage - 1},
        );
      }
    } catch (e) {
      print('Error decrementing item usage: $e');
    }
  }

  // --- CATEGORIES & ITEMS ---

  // Get Categories (Sorted by usage)
  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final user = await account.get();
      final result = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.categoriesCollectionId,
        queries: [
          Query.equal('userId', [user.$id]),
          Query.orderDesc('usageCount'),
        ],
      );

      return result.documents.map((doc) {
        final data = doc.data;
        data['id'] = doc.$id;
        return data;
      }).toList();
    } catch (e) {
      print('Error fetching categories: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> createCategory(
    Map<String, dynamic> data,
  ) async {
    try {
      final user = await account.get();
      final categoryData = {
        'userId': user.$id,
        'name': data['name'],
        'type': data['type'],
        'icon': data['icon'],
        'usageCount': 0,
      };

      final doc = await databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.categoriesCollectionId,
        documentId: ID.unique(),
        data: categoryData,
      );

      final response = doc.data;
      response['id'] = doc.$id;
      return response;
    } catch (e) {
      print('Error creating category: $e');
      return null;
    }
  }

  Future<bool> deleteCategory(String categoryId) async {
    try {
      // 1. Delete associated items first
      final items = await getItems(categoryId);
      for (var item in items) {
        if (item['id'] != null) {
          await deleteItem(item['id']);
        }
      }

      // 2. Delete the category
      await databases.deleteDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.categoriesCollectionId,
        documentId: categoryId,
      );
      return true;
    } catch (e) {
      print('Error deleting category: $e');
      return false;
    }
  }

  // Get Top Items (Sorted by usage, limited)
  Future<List<Map<String, dynamic>>> getTopItems({int limit = 8}) async {
    try {
      final user = await account.get();
      final result = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.itemsCollectionId,
        queries: [
          Query.equal('userId', [user.$id]),
          Query.orderDesc('usageCount'),
          Query.limit(limit),
        ],
      );

      return result.documents.map((doc) {
        final data = doc.data;
        data['id'] = doc.$id;
        return data;
      }).toList();
    } catch (e) {
      print('Error fetching top items: $e');
      return [];
    }
  }

  // Get Items for a Category (Sorted by usage)
  Future<List<Map<String, dynamic>>> getItems(String categoryId) async {
    try {
      final user = await account.get();
      final result = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.itemsCollectionId,
        queries: [
          Query.equal('userId', [user.$id]),
          Query.equal('categoryId', [categoryId]),
          Query.orderDesc('usageCount'),
        ],
      );

      return result.documents.map((doc) {
        final data = doc.data;
        data['id'] = doc.$id;
        return data;
      }).toList();
    } catch (e) {
      print('Error fetching items: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> createItem(Map<String, dynamic> data) async {
    try {
      final user = await account.get();
      final itemData = {
        'userId': user.$id,
        'title': data['title'],
        'amount': data['amount'],
        'isExpense': data['isExpense'],
        'categoryId': data['categoryId'],
        'usageCount': 0,
        'frequency': data['frequency'] ?? 'daily',
      };

      final doc = await databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.itemsCollectionId,
        documentId: ID.unique(),
        data: itemData,
      );

      final response = doc.data;
      response['id'] = doc.$id;
      return response;
    } catch (e) {
      print('Error creating item: $e');
      rethrow; // Rethrow to let UI handle the error
    }
  }

  Future<bool> deleteItem(String itemId) async {
    try {
      await databases.deleteDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.itemsCollectionId,
        documentId: itemId,
      );
      return true;
    } catch (e) {
      print('Error deleting item: $e');
      return false;
    }
  }
}
