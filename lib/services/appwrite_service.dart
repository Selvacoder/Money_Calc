import 'package:appwrite/appwrite.dart';
// ignore_for_file: deprecated_member_use
import '../config/appwrite_config.dart';
import 'dart:convert'; // Added for jsonEncode

import 'package:appwrite/models.dart';

class AppwriteService {
  static final AppwriteService _instance = AppwriteService._internal();
  factory AppwriteService() => _instance;
  AppwriteService._internal() {
    init();
  }

  late Client client;
  late Account account;
  late Databases databases;
  late Realtime realtime; // Added Realtime

  void init() {
    client = Client()
        .setEndpoint(AppwriteConfig.endpoint)
        .setProject(AppwriteConfig.projectId)
        .setSelfSigned(status: true);

    account = Account(client);
    databases = Databases(client);
    realtime = Realtime(client); // Initialize Realtime
  }

  // Subscribe to Realtime Notifications
  RealtimeSubscription subscribeToNotifications(
    String userId,
    Function(Map<String, dynamic>) onNotification,
  ) {
    // Listen to changes in the 'notifications' collection
    // Filter by userId would be ideal, but Realtime channels are usually collection-level or document-level.
    // We can listen to the collection and filter client-side, OR listen to a channel query if supported.
    // Appwrite Realtime supports channels like 'databases.{id}.collections.{id}.documents'

    // We will listen to the entire collection but we need to secure it so users only see their own.
    // Since we can't easily filter Realtime *streams* by query in client SDK (it receives all events for the channel permission),
    // we rely on Row Level Security (RLS). If RLS is set up, the user only receives events for docs they can read.
    // Assuming 'notifications' collection has RLS set to 'users' or specific user permission.

    final subscription = realtime.subscribe([
      'databases.${AppwriteConfig.databaseId}.collections.${AppwriteConfig.notificationsCollectionId}.documents',
    ]);

    subscription.stream.listen((response) {
      // Check if any event is a create event
      final isCreate = response.events.any(
        (event) => event.endsWith('.create'),
      );

      if (isCreate) {
        final data = response.payload;
        if (data['userId'] == userId) {
          onNotification(data);
        }
      }
    });

    return subscription;
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
          banks: [],
          primaryPaymentMethods: {},
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

        // Parse Banks and Primary Methods
        List<String> banks = [];
        Map<String, String> primaryPaymentMethods = {};
        if (profileDocs.documents.isNotEmpty) {
          final data = profileDocs.documents.first.data;

          if (data['banks'] != null) {
            banks = List<String>.from(data['banks']);
          }

          if (data['primaryPaymentMethods'] != null) {
            try {
              final pmData = data['primaryPaymentMethods'];
              if (pmData is String && pmData.isNotEmpty) {
                primaryPaymentMethods = Map<String, String>.from(
                  jsonDecode(pmData),
                );
              }
            } catch (e) {
              print('Error parsing primary payment methods: $e');
            }
          }
        }

        return {
          'userId': user.$id,
          'name': user.name,
          'email': user.email,
          'phone': phone.isNotEmpty ? phone : '',
          'joinDate': user.registration,
          'banks': banks,
          'primaryPaymentMethods': primaryPaymentMethods,
        };
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

  // Update User Preferences (Banks & Primary Methods)
  Future<bool> updateUserPreferences({
    required String userId,
    required List<String> banks,
    required Map<String, String> primaryPaymentMethods,
  }) async {
    try {
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
          data: {
            'banks': banks,
            'primaryPaymentMethods': jsonEncode(primaryPaymentMethods),
          },
        );
        return true;
      }
      return false;
    } catch (e) {
      print('Error updating user preferences: $e');
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
        'paymentMethod': transactionData['paymentMethod'],
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
    List<String> banks = const [],
    Map<String, String> primaryPaymentMethods = const {},
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
          'banks': banks,
          'primaryPaymentMethods': jsonEncode(primaryPaymentMethods),
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
  Future<List<Map<String, dynamic>>?> getLedgerTransactions() async {
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
      return null; // Return null on error to distinguish from empty list
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

  // Batch Update Person (Name/Phone)
  Future<bool> updateLedgerPerson({
    required String oldName,
    required String oldPhone,
    required String newName,
    required String newPhone,
  }) async {
    try {
      // 1. Fetch all transactions involving this person
      // This is expensive if there are many, but Appwrite lacks "update where"
      // We rely on the fact that for a single user, it shouldn't be massive.

      // We need to match precise contact logic used in UI
      // If oldPhone is valid (not local), we query by phone.
      // Else we query by name.

      final isPhoneIdentity =
          oldPhone.isNotEmpty && !oldPhone.startsWith('local:');

      List<String> qualities = [];
      if (isPhoneIdentity) {
        qualities.add('senderPhone');
        qualities.add('receiverPhone');
      } else {
        qualities.add('senderName');
        qualities.add('receiverName');
      }

      // Appwrite doesn't support "OR" easily across fields in one query for different fields
      // But we can do multiple queries or fetch all user's transactions and filter.
      // Fetching all is safest to ensure consistency, then filter.
      // Or 2 queries: sentByPerson, receivedByPerson.

      List<Document> docsToUpdate = [];

      // Query 1: Where person is Sender
      final q1 = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.ledgerCollectionId,
        queries: [
          Query.equal(isPhoneIdentity ? 'senderPhone' : 'senderName', [
            isPhoneIdentity ? oldPhone : oldName,
          ]),
          Query.limit(100), // Pagination?
        ],
      );
      docsToUpdate.addAll(q1.documents);

      // Query 2: Where person is Receiver
      final q2 = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.ledgerCollectionId,
        queries: [
          Query.equal(isPhoneIdentity ? 'receiverPhone' : 'receiverName', [
            isPhoneIdentity ? oldPhone : oldName,
          ]),
          Query.limit(100),
        ],
      );

      // Avoid duplicates just in case (though difficult unless self-transaction)
      for (var doc in q2.documents) {
        if (!docsToUpdate.any((d) => d.$id == doc.$id)) {
          docsToUpdate.add(doc);
        }
      }

      // 2. Update each document
      for (var doc in docsToUpdate) {
        final data = doc.data;
        Map<String, dynamic> updates = {};

        // Check if Sender is the person
        bool isSender = false;
        if (isPhoneIdentity) {
          isSender = (data['senderPhone'] == oldPhone);
        } else {
          isSender =
              (data['senderName'] == oldName); // Strict name match for local
        }

        if (isSender) {
          updates['senderName'] = newName;
          updates['senderPhone'] = newPhone;
        }

        // Check if Receiver is the person
        bool isReceiver = false;
        if (isPhoneIdentity) {
          isReceiver = (data['receiverPhone'] == oldPhone);
        } else {
          isReceiver = (data['receiverName'] == oldName);
        }

        if (isReceiver) {
          updates['receiverName'] = newName;
          updates['receiverPhone'] = newPhone;
        }

        if (updates.isNotEmpty) {
          await databases.updateDocument(
            databaseId: AppwriteConfig.databaseId,
            collectionId: AppwriteConfig.ledgerCollectionId,
            documentId: doc.$id,
            data: updates,
          );
        }
      }
      return true;
    } catch (e) {
      print('Error updating ledger person: $e');
      return false;
    }
  }

  // Batch Delete Person
  Future<bool> deleteLedgerPerson({
    required String name,
    required String phone,
  }) async {
    try {
      final isPhoneIdentity = phone.isNotEmpty && !phone.startsWith('local:');

      List<Document> docsToDelete = [];

      // Query 1: Where person is Sender
      final q1 = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.ledgerCollectionId,
        queries: [
          Query.equal(isPhoneIdentity ? 'senderPhone' : 'senderName', [
            isPhoneIdentity ? phone : name,
          ]),
          Query.limit(100),
        ],
      );
      docsToDelete.addAll(q1.documents);

      // Query 2: Where person is Receiver
      final q2 = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.ledgerCollectionId,
        queries: [
          Query.equal(isPhoneIdentity ? 'receiverPhone' : 'receiverName', [
            isPhoneIdentity ? phone : name,
          ]),
          Query.limit(100),
        ],
      );

      for (var doc in q2.documents) {
        if (!docsToDelete.any((d) => d.$id == doc.$id)) {
          docsToDelete.add(doc);
        }
      }

      // Execute Deletes
      for (var doc in docsToDelete) {
        await databases.deleteDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.ledgerCollectionId,
          documentId: doc.$id,
        );
      }
      return true;
    } catch (e) {
      print('Error deleting ledger person: $e');
      return false;
    }
  }

  // Get user by phone number
  Future<Map<String, dynamic>?> getUserByPhone(String phone) async {
    try {
      // Normalize phone number (remove non-digits)
      // final normalizedPhone = phone.replaceAll(RegExp(r'\D'), ''); // Unused

      // We need to match the exact format stored in profiles.
      // Since specific format might vary, we might need a more flexible search or ensure strict formatting.
      // For now, let's assume strict match or substring match if possible.
      // Note: Appwrite queries on string attributes are exact unless full-text search is enabled.

      final result = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.profilesCollectionId,
        queries: [
          Query.equal('phone', phone), // Try exact match first
        ],
      );

      if (result.documents.isNotEmpty) {
        return result.documents.first.data;
      }

      // If exact match failed, maybe try with/without country code if needed?
      // For now, sticking to what was passed.
      return null;
    } catch (e) {
      print('Error getting user by phone: $e');
      return null;
    }
  }

  // Send in-app notification
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String message,
    required String type, // 'nudge', 'reminder', etc.
  }) async {
    try {
      await databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.notificationsCollectionId,
        documentId: ID.unique(),
        data: {
          'userId': userId,
          'title': title,
          'message': message,
          'type': type,
          'isRead': false,
          'createdAt': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      print('Error sending notification: $e');
      rethrow;
    }
  }
  // --- INVESTMENTS ---

  Future<List<Map<String, dynamic>>> getInvestments() async {
    try {
      final user = await account.get();
      final result = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.investmentsCollectionId,
        queries: [
          Query.equal('userId', [user.$id]),
        ],
      );

      return result.documents.map((doc) {
        final data = doc.data;
        data['id'] = doc.$id;
        return data;
      }).toList();
    } catch (e) {
      print('Error fetching investments: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> createInvestment(
    Map<String, dynamic> data,
  ) async {
    try {
      final user = await account.get();
      final investmentData = {
        'userId': user.$id,
        'name': data['name'],
        'type': data['type'],
        'investedAmount': data['investedAmount'] ?? 0.0,
        'currentAmount': data['currentAmount'] ?? 0.0,
        'quantity': data['quantity'] ?? 0.0,
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      final doc = await databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.investmentsCollectionId,
        documentId: ID.unique(),
        data: investmentData,
      );

      final response = doc.data;
      response['id'] = doc.$id;
      return response;
    } catch (e) {
      print('Error creating investment: $e');
      return null;
    }
  }

  Future<bool> updateInvestment(String id, Map<String, dynamic> data) async {
    try {
      // Ensure we update 'lastUpdated' if not provided
      if (!data.containsKey('lastUpdated')) {
        data['lastUpdated'] = DateTime.now().toIso8601String();
      }

      await databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.investmentsCollectionId,
        documentId: id,
        data: data,
      );
      return true;
    } catch (e) {
      print('Error updating investment: $e');
      return false;
    }
  }

  Future<bool> deleteInvestment(String id) async {
    try {
      // Should we delete all transactions associated with this investment?
      // Yes, probably. But for now simpler is better.
      await databases.deleteDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.investmentsCollectionId,
        documentId: id,
      );
      return true;
    } catch (e) {
      print('Error deleting investment: $e');
      return false;
    }
  }

  // --- INVESTMENT TRANSACTIONS ---

  Future<List<Map<String, dynamic>>> getInvestmentTransactions() async {
    try {
      final user = await account.get();
      final result = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.investmentTransactionsCollectionId,
        queries: [
          Query.equal('userId', [user.$id]),
          Query.orderDesc('dateTime'),
        ],
      );

      return result.documents.map((doc) {
        final data = doc.data;
        data['id'] = doc.$id;
        return data;
      }).toList();
    } catch (e) {
      print('Error fetching investment transactions: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> createInvestmentTransaction(
    Map<String, dynamic> data,
  ) async {
    try {
      final user = await account.get();
      final txData = {
        'userId': user.$id,
        'investmentId': data['investmentId'],
        'type': data['type'],
        'amount': data['amount'],
        'pricePerUnit': data['pricePerUnit'],
        'quantity': data['quantity'],
        'dateTime': data['dateTime'],
        'note': data['note'],
      };

      final doc = await databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.investmentTransactionsCollectionId,
        documentId: ID.unique(),
        data: txData,
      );

      final response = doc.data;
      response['id'] = doc.$id;
      return response;
    } catch (e) {
      print('Error creating investment transaction: $e');
      return null;
    }
  }

  Future<bool> deleteInvestmentTransaction(String id) async {
    try {
      await databases.deleteDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.investmentTransactionsCollectionId,
        documentId: id,
      );
      return true;
    } catch (e) {
      print('Error deleting investment transaction: $e');
      return false;
    }
  }
}
