import 'package:appwrite/appwrite.dart';
// ignore_for_file: deprecated_member_use
import '../config/appwrite_config.dart';

class AppwriteService {
  static final AppwriteService _instance = AppwriteService._internal();
  factory AppwriteService() => _instance;
  AppwriteService._internal() {
    init();
  }

  late Client client;
  late Account account;
  late Databases databases;

  void init() {
    client = Client()
        .setEndpoint(AppwriteConfig.endpoint)
        .setProject(AppwriteConfig.projectId)
        .setSelfSigned(status: true);

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
    required String phone,
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

      // 3. Create Profile Document
      try {
        final user = await account.get();
        await createProfile(
          userId: user.$id,
          name: name,
          email: email,
          phone: phone, // Pass provided phone
        );
      } catch (e) {
        // If profile creation fails, we should maybe cleanup the account
        // or at least return an error saying profile creation failed.
        // For now, return success false.
        return {
          'success': false,
          'message': 'Account created but profile failed: $e. Check DB Schema.',
        };
      }

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

  // Get current user details from Auth and Profile Document
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final user = await account.get();
      String phone = user.phone;

      // Use try-catch for profile fetch specifically to allow fallback
      try {
        final profileDocs = await databases.listDocuments(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.profilesCollectionId,
          queries: [
            Query.equal('userId', [user.$id]),
          ],
        );

        if (profileDocs.documents.isNotEmpty) {
          final profileData = profileDocs.documents.first.data;
          // user.phone might be empty in Auth, but present in Profile doc
          if (profileData['phone'] != null &&
              profileData['phone'].toString().isNotEmpty) {
            phone = profileData['phone'].toString();
          }
        }
      } catch (e) {
        print('Error fetching profile doc: $e');
      }

      return {
        'userId': user.$id,
        'name': user.name,
        'email': user.email,
        'phone': phone.isNotEmpty ? phone : '',
        'joinDate': user.registration,
      };
    } catch (e) {
      return null;
    }
  }

  // Update user name (in Auth) and Profile (in DB)
  Future<bool> updateUserProfile({
    required String userId,
    required String name,
    required String phone,
  }) async {
    try {
      // 1. Update Auth Name
      await account.updateName(name: name);

      // 2. Update Profile Document
      final profileDocs = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.profilesCollectionId,
        queries: [
          Query.equal('userId', [userId]),
        ],
      );

      if (profileDocs.documents.isNotEmpty) {
        await databases.updateDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.profilesCollectionId,
          documentId: profileDocs.documents.first.$id,
          data: {'name': name, 'phone': phone},
        );
      } else {
        // Create if missing
        await createProfile(
          userId: userId,
          name: name,
          email: '',
          phone: phone,
        );
      }

      return true;
    } catch (e) {
      print('Error updating profile: $e');
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
        'ledgerId': transactionData['ledgerId'],
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

  Future<bool> updateCategory(
    String categoryId,
    Map<String, dynamic> data,
  ) async {
    try {
      await databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.categoriesCollectionId,
        documentId: categoryId,
        data: data,
      );
      return true;
    } catch (e) {
      print('Error updating category: $e');
      return false;
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

  // Get Quick Items (All items, manual list)
  Future<List<Map<String, dynamic>>> getQuickItems() async {
    try {
      final user = await account.get();
      final result = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.itemsCollectionId,
        queries: [
          Query.equal('userId', [user.$id]),
          Query.orderDesc('\$createdAt'), // Newest first
          Query.limit(100),
        ],
      );

      return result.documents.map((doc) {
        final data = doc.data;
        data['id'] = doc.$id;
        return data;
      }).toList();
    } catch (e) {
      print('Error fetching quick items: $e');
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
        if (data['icon'] != null) 'icon': data['icon'],
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

  Future<bool> updateItem(String itemId, Map<String, dynamic> data) async {
    try {
      await databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.itemsCollectionId,
        documentId: itemId,
        data: data,
      );
      return true;
    } catch (e) {
      print('Error updating item: $e');
      return false;
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

  // --- PROFILE ---
  Future<void> createProfile({
    required String userId,
    required String name,
    required String email,
    String? phone, // Added phone
  }) async {
    try {
      await databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.profilesCollectionId,
        documentId: ID.unique(),
        data: {
          'userId': userId,
          'name': name,
          'email': email,
          'phone': phone ?? '', // Save phone
        },
      );
    } catch (e) {
      print('Error creating profile: $e');
      rethrow; // Propagate error so signUp knows profile failed
    }
  }

  // Search contacts by name
  Future<List<Map<String, dynamic>>> searchContacts(String query) async {
    try {
      if (query.isEmpty) return [];

      final result = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.profilesCollectionId,
        queries: [
          Query.search('name', query), // Search by name
          Query.limit(5),
        ],
      );

      return result.documents.map((doc) => doc.data).toList();
    } catch (e) {
      print('Error searching contacts: $e');
      return [];
    }
  }

  // --- LEDGER ---
  Future<List<Map<String, dynamic>>> getLedgerTransactions() async {
    try {
      final user = await account.get();
      // final contact = user.phone.isNotEmpty ? user.phone : user.email; // OLD

      String contact = user.phone;
      // If auth phone is empty, try fetching from profile
      if (contact.isEmpty) {
        final profileDocs = await databases.listDocuments(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.profilesCollectionId,
          queries: [
            Query.equal('userId', [user.$id]),
          ],
        );
        if (profileDocs.documents.isNotEmpty) {
          contact = profileDocs.documents.first.data['phone'] ?? '';
        }
      }

      // If still empty, we can't fetch ledger transactions reliably by phone
      if (contact.isEmpty) return [];

      // Fetch 1: I am the sender
      final sent = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.ledgerCollectionId,
        queries: [
          Query.equal('senderPhone', [contact]),
          Query.orderDesc('date'),
        ],
      );
      // Fetch 2: I am the receiver (only if email matches)
      final received = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.ledgerCollectionId,
        queries: [
          Query.equal('receiverPhone', [contact]),
          Query.orderDesc('date'),
        ],
      );

      // Merge and Deduplicate based on $id
      final Map<String, Map<String, dynamic>> transactionMap = {};

      for (var doc in sent.documents) {
        final data = doc.data;
        data['id'] = doc.$id; // Ensure ID is part of data
        transactionMap[doc.$id] = data;
      }

      for (var doc in received.documents) {
        final data = doc.data;
        data['id'] = doc.$id; // Ensure ID is part of data
        transactionMap[doc.$id] = data;
      }

      // Convert back to list and sort by date descending
      final allTransactions = transactionMap.values.toList();
      allTransactions.sort((a, b) {
        DateTime dateA = DateTime.parse(a['date']);
        DateTime dateB = DateTime.parse(b['date']);
        return dateB.compareTo(dateA);
      });

      return allTransactions;
    } catch (e) {
      print('Error fetching ledger transactions: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> createLedgerTransaction(
    Map<String, dynamic> data,
  ) async {
    try {
      final user = await account.get();
      String contact = user.phone;

      // If auth phone is empty, try fetching from profile
      if (contact.isEmpty) {
        final profileDocs = await databases.listDocuments(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.profilesCollectionId,
          queries: [
            Query.equal('userId', [user.$id]),
          ],
        );
        if (profileDocs.documents.isNotEmpty) {
          contact = profileDocs.documents.first.data['phone'] ?? '';
        }
      }

      if (contact.isEmpty) {
        throw 'Please update your profile with a phone number to use the Ledger.';
      }

      final isReceived = data['isReceived'] == true;
      final otherName = data['name'];
      String? otherContact = data['email']; // This comes from phoneController

      // Handle optional phone for local-only entries (required schema support)
      if (otherContact == null || otherContact.toString().trim().isEmpty) {
        String safeName = (otherName ?? 'Unknown').toString().replaceAll(
          RegExp(r'[^a-zA-Z0-9]'),
          '',
        );
        if (safeName.length > 13) safeName = safeName.substring(0, 13);
        otherContact = 'local:$safeName';
      }

      // Validate otherContact length if provided
      if (otherContact.length > 20) {
        throw 'Recipient phone number must be 20 characters or less.';
      }

      final ledgerData = {
        // 'senderId': user.$id,
        'senderName': isReceived ? otherName : user.name,
        'senderPhone': isReceived ? otherContact : contact,
        'receiverName': isReceived ? user.name : otherName,
        'receiverPhone': isReceived ? contact : otherContact,
        'amount': data['amount'],
        'description': data['description'],
        'date': data['dateTime'],
      };

      final doc = await databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.ledgerCollectionId,
        documentId: ID.unique(),
        data: ledgerData,
      );

      final response = doc.data;
      response['id'] = doc.$id;
      return response;
    } catch (e) {
      print('Error creating ledger transaction: $e');
      rethrow;
    }
  }

  Future<bool> deleteLedgerTransaction(String id) async {
    try {
      await databases.deleteDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.ledgerCollectionId,
        documentId: id,
      );
      return true;
    } catch (e) {
      print('Error deleting ledger transaction: $e');
      return false;
    }
  }
}
