import 'package:appwrite/appwrite.dart';
// ignore_for_file: deprecated_member_use
import '../config/appwrite_config.dart';
import 'dart:convert'; // Added for jsonEncode

import 'package:appwrite/models.dart' as models;
import 'package:flutter/foundation.dart';
// Conditional import for web to avoid compilation errors on mobile
import 'html_stub.dart' if (dart.library.html) 'dart:html' as html;

class AppwriteService {
  static final AppwriteService _instance = AppwriteService._internal();
  factory AppwriteService() => _instance;
  AppwriteService._internal() {
    init();
  }

  late Client client;
  late Account account;
  late Databases databases;
  late Storage storage;

  void init() {
    client = Client()
        .setEndpoint(AppwriteConfig.endpoint)
        .setProject(AppwriteConfig.projectId);
    // .setSelfSigned(status: true); // Removed for production domain

    account = Account(client);
    databases = Databases(client);
    storage = Storage(client);

    functions = Functions(client);
  }

  late Functions functions;
  bool _skipInvestmentFetch = false;

  // Subscribe to Realtime Notifications

  // Get current user session
  Future<bool> isLoggedIn({bool forceCheck = false}) async {
    try {
      if (kIsWeb && !forceCheck) {
        // PREVENTIVE: check localStorage before making the network call that triggers a Red 401 log
        // Scanning for any key starting with 'a_session_' to catch all variations
        bool hasSession = false;
        try {
          for (var key in html.window.localStorage.keys) {
            if (key.startsWith('a_session_')) {
              hasSession = true;
              break;
            }
          }
        } catch (e) {
          debugPrint('Error accessing localStorage: $e');
        }

        if (!hasSession) {
          debugPrint(
            'DEBUG: isLoggedIn - No session keys found in localStorage. Keys: ${html.window.localStorage.keys.toList()}',
          );
          return false;
        }

        // Give the browser a tiny moment to ensure storage is settled
        await Future.delayed(const Duration(milliseconds: 50));
      }

      // Add timeout to prevent long loading if server is unreachable
      await account.get().timeout(const Duration(seconds: 5));
      return true;
    } catch (e) {
      // 401 means not logged in, other errors mean network/server issues
      // Silence 401 to avoid console noise for unauthenticated users
      if (e is! AppwriteException || e.code != 401) {
        debugPrint('isLoggedIn error: $e');
      }
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
          customPaymentMethods: [],
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
      String msg = e.message ?? 'Login failed';
      if (msg.contains('password') && msg.contains('between 8 and 256')) {
        msg = 'Incorrect email or password.';
      } else if (msg.contains('Invalid `email` param')) {
        msg = 'Please enter a valid email address.';
      }
      return {'success': false, 'message': msg};
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

        Map<String, String> primaryPaymentMethods = {};
        List<String> banks = [];
        List<String> customPaymentMethods = [];
        String photoUrl = '';

        if (profileDocs.documents.isNotEmpty) {
          final data = profileDocs.documents.first.data;

          if (data['phone'] != null && data['phone'].toString().isNotEmpty) {
            phone = data['phone'].toString();
          }

          if (data['photoUrl'] != null) {
            photoUrl = data['photoUrl'].toString();
          }

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

          if (data['customPaymentMethods'] != null) {
            try {
              final cpmData = data['customPaymentMethods'];
              if (cpmData is String && cpmData.isNotEmpty) {
                customPaymentMethods = List<String>.from(jsonDecode(cpmData));
              }
            } catch (e) {
              print('Error parsing custom payment methods: $e');
            }
          }
        }

        return {
          'userId': user.$id,
          'name': user.name,
          'email': user.email,
          'phone': phone.isNotEmpty ? phone : '',
          'photoUrl': photoUrl,
          'joinDate': user.registration,
          'banks': banks,
          'primaryPaymentMethods': primaryPaymentMethods,
          'customPaymentMethods': customPaymentMethods,
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

  // Update user profile and photo
  Future<bool> updateUserProfile({
    required String userId,
    required String name,
    required String phone,
    String? photoUrl,
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

      final Map<String, dynamic> updateData = {'name': name, 'phone': phone};
      if (photoUrl != null) {
        updateData['photoUrl'] = photoUrl;
      }

      if (profileDocs.documents.isNotEmpty) {
        await databases.updateDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.profilesCollectionId,
          documentId: profileDocs.documents.first.$id,
          data: updateData,
        );
      } else {
        // Create if missing
        await createProfile(
          userId: userId,
          name: name,
          email: '',
          phone: phone,
          photoUrl: photoUrl,
        );
      }

      return true;
    } catch (e) {
      print('Error updating profile: $e');
      return false;
    }
  }

  // Upload Profile Photo
  Future<String?> uploadProfilePhoto(String userId, String filePath) async {
    try {
      final file = await storage.createFile(
        bucketId: AppwriteConfig.profilePhotosBucketId,
        fileId: userId,
        file: InputFile.fromPath(
          path: filePath,
          filename: 'profile_$userId.jpg',
        ),
        permissions: [
          Permission.read(Role.any()),
          Permission.write(Role.user(userId)),
        ],
      );

      // Return the preview URL
      final url =
          '${AppwriteConfig.endpoint}/storage/buckets/${AppwriteConfig.profilePhotosBucketId}/files/${file.$id}/view?project=${AppwriteConfig.projectId}';
      return url;
    } catch (e) {
      // If file already exists, we might need to delete it first or use unique ID
      if (e is AppwriteException && e.code == 409) {
        try {
          await storage.deleteFile(
            bucketId: AppwriteConfig.profilePhotosBucketId,
            fileId: userId,
          );
          return await uploadProfilePhoto(userId, filePath);
        } catch (e2) {
          print('Error deleting old photo: $e2');
        }
      }
      print('Error uploading photo: $e');
      return null;
    }
  }

  // Update User Preferences (Banks & Primary Methods)
  Future<bool> updateUserPreferences({
    required String userId,
    required List<String> banks,
    required Map<String, String> primaryPaymentMethods,
    List<String>? customPaymentMethods,
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
            if (customPaymentMethods != null)
              'customPaymentMethods': jsonEncode(customPaymentMethods),
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

  Future<List<Map<String, dynamic>>> getTransactions({
    int limit = 25,
    String? lastId,
  }) async {
    try {
      final user = await account.get();
      final List<String> queries = [
        Query.equal('userId', [user.$id]),
        Query.orderDesc('dateTime'),
        Query.limit(limit),
      ];

      if (lastId != null && lastId.isNotEmpty) {
        queries.add(Query.cursorAfter(lastId));
      }

      final result = await databases
          .listDocuments(
            databaseId: AppwriteConfig.databaseId,
            collectionId: AppwriteConfig.transactionsCollectionId,
            queries: queries,
          )
          .timeout(const Duration(seconds: 10));

      return result.documents.map((doc) {
        final data = doc.data;
        data['id'] = doc.$id; // Ensure ID is mapped
        return data;
      }).toList();
    } catch (e) {
      if (e is! AppwriteException || e.code != 401) {
        print('Error fetching transactions: $e');
      }
      return [];
    }
  }

  Future<Map<String, dynamic>?> createTransaction(
    Map<String, dynamic> data,
  ) async {
    try {
      final user = await account.get();
      final txData = {
        'userId': user.$id,
        'amount': data['amount'],
        'categoryId': data['categoryId'],
        'itemId': data['itemId'],
        'title': data['title'] ?? data['description'] ?? '',
        'dateTime': data['dateTime'],
        'isExpense': data['isExpense'],
        'ledgerId': data['ledgerId'],
        'paymentMethod': data['paymentMethod'],
      };

      // Handle Usage logic
      if (data['categoryId'] != null) {
        await incrementCategoryUsage(data['categoryId']);
      }
      if (data['itemId'] != null) {
        await incrementItemUsage(data['itemId']);
      }

      final doc = await databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.transactionsCollectionId,
        documentId: ID.unique(),
        data: txData,
        permissions: [
          Permission.read(Role.user(user.$id)),
          Permission.write(Role.user(user.$id)),
        ],
      );

      final response = doc.data;
      response['id'] = doc.$id;
      return response;
    } catch (e) {
      print('Error creating transaction: $e');
      return null;
    }
  }

  // Create Ledger Transaction
  Future<Map<String, dynamic>?> createLedgerTransaction(
    Map<String, dynamic> transactionData,
  ) async {
    try {
      final user = await account.get();
      final myId = user.$id;

      String senderId = transactionData['senderId'] ?? '';
      String receiverId = transactionData['receiverId'] ?? '';
      final senderPhone = transactionData['senderPhone'] ?? '';
      final receiverPhone = transactionData['receiverPhone'] ?? '';

      print(
        'DEBUG: Init - Sender: $senderId ($senderPhone), Receiver: $receiverId ($receiverPhone)',
      );

      // Universal ID Resolution: Check both parties
      try {
        if (senderId.isEmpty &&
            senderPhone.isNotEmpty &&
            !senderPhone.toString().startsWith('local:')) {
          final sUser = await getUserByPhone(senderPhone);
          if (sUser != null) {
            senderId = sUser['userId'];
            print('DEBUG: Resolved Sender ID: $senderId');
          } else {
            print('DEBUG: Failed to resolve Sender: $senderPhone');
          }
        }

        if (receiverId.isEmpty &&
            receiverPhone.isNotEmpty &&
            !receiverPhone.toString().startsWith('local:')) {
          final rUser = await getUserByPhone(receiverPhone);
          if (rUser != null) {
            receiverId = rUser['userId'];
            print('DEBUG: Resolved Receiver ID: $receiverId');
          } else {
            print('DEBUG: Failed to resolve Receiver: $receiverPhone');
          }
        }
      } catch (e) {
        print('DEBUG: ID Resolution Failed (Non-fatal): $e');
      }

      // Determine Status & Permissions
      String status = transactionData['status'] ?? 'confirmed';
      final perms = <String>{
        Permission.read(Role.user(myId)),
        Permission.write(Role.user(myId)),
      };

      if (senderId.isNotEmpty) {
        perms.add(Permission.read(Role.user(senderId)));
        perms.add(Permission.write(Role.user(senderId)));
      }
      if (receiverId.isNotEmpty) {
        perms.add(Permission.read(Role.user(receiverId)));
        perms.add(Permission.write(Role.user(receiverId)));
      }

      // If both parties are identified and distinct, it's a shared transaction (Pending)
      if (senderId.isNotEmpty &&
          receiverId.isNotEmpty &&
          senderId != receiverId) {
        status = 'pending';
      } else if (status == 'pending') {
        // If we expected it to be pending (based on input) but failed to resolve IDs
        if (senderId.isEmpty) {
          throw 'Cannot request money: Sender not registered';
        }
        if (receiverId.isEmpty) {
          throw 'Cannot request money: Receiver not registered';
        }
      }
      print(
        'DEBUG: Final decision - Sender: $senderId, Receiver: $receiverId, Status: $status',
      );

      final data = {
        'senderId': senderId,
        'senderName': transactionData['senderName'] ?? '',
        'senderPhone': senderPhone,
        'receiverName': transactionData['receiverName'] ?? '',
        'receiverPhone': receiverPhone,
        'receiverId': receiverId,
        'creatorId': myId, // Track who created it
        'amount': transactionData['amount'],
        'description': transactionData['description'] ?? '',
        'date': transactionData['dateTime'],
        'dateTime': transactionData['dateTime'],
        'status': status,
      };
      try {
        print(
          'DEBUG: Creating Document. Data: $data, Perms: ${perms.toList()}',
        );
        final doc = await databases.createDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.ledgerCollectionId,
          documentId: ID.unique(),
          data: data,
          permissions: perms.toList(),
        );

        final response = doc.data;
        response['id'] = doc.$id;
        return response;
      } on AppwriteException catch (e) {
        if (e.code == 401) {
          print(
            'DEBUG: Permission Error (401). Retrying with MINIMAL permissions (Me Only)...',
          );
          // Retry with ONLY my permissions
          final minPerms = [
            Permission.read(Role.user(myId)),
            Permission.write(Role.user(myId)),
          ];
          final doc = await databases.createDocument(
            databaseId: AppwriteConfig.databaseId,
            collectionId: AppwriteConfig.ledgerCollectionId,
            documentId: ID.unique(),
            data: data,
            permissions: minPerms,
          );
          final response = doc.data;
          response['id'] = doc.$id;

          // Attempt to share via Cloud Function
          // Determine who to share with (The OTHER person)
          String? targetId;
          if (myId == senderId) {
            targetId = receiverId;
          } else if (myId == receiverId) {
            targetId = senderId;
          }

          if (targetId != null && targetId.isNotEmpty) {
            shareLedgerTransaction(doc.$id, targetId)
                .then((_) {
                  print('DEBUG: Triggered share function for ${doc.$id}');
                })
                .catchError((e) {
                  print('DEBUG: Share function failed: $e');
                });
          }
          return response;
        }
        rethrow;
      } catch (e) {
        print('DEBUG: Generic Error in createDocument: $e');
        rethrow;
      }
    } catch (e) {
      print('Error creating ledger transaction: $e');
      rethrow;
    }
  }

  // Call Appwrite Cloud Function
  Future<void> shareLedgerTransaction(
    String transactionId,
    String receiverId,
  ) async {
    print(
      'DEBUG: shareLedgerTransaction called. TxID: $transactionId, Receiver: $receiverId',
    );
    try {
      final execution = await functions.createExecution(
        functionId: AppwriteConfig.shareTransactionFunctionId,
        body: jsonEncode({
          'transactionId': transactionId,
          'receiverId': receiverId,
          'databaseId': AppwriteConfig.databaseId,
          'collectionId': AppwriteConfig.ledgerCollectionId,
        }),
      );
      print(
        'DEBUG: Function Execution Triggered. Status: ${execution.status}, ID: ${execution.$id}',
      );
      print('DEBUG: Function Response Body: ${execution.responseBody}');
    } catch (e) {
      print('DEBUG: Error calling share function: $e');
    }
  }

  Future<bool> updateLedgerTransactionStatus(String id, String status) async {
    try {
      await databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.ledgerCollectionId,
        documentId: id,
        data: {'status': status},
      );
      return true;
    } catch (e) {
      print('Error updating ledger status: $e');
      return false;
    }
  }

  // Get multiple profiles by their userIds
  Future<List<Map<String, dynamic>>> getProfilesByIds(
    List<String> userIds,
  ) async {
    try {
      if (userIds.isEmpty) return [];

      final result = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.profilesCollectionId,
        queries: [Query.equal('userId', userIds), Query.limit(userIds.length)],
      );

      return result.documents.map((doc) {
        final data = doc.data;
        data['id'] = doc.$id;
        return data;
      }).toList();
    } catch (e) {
      print('Error fetching profiles by IDs: $e');
      return [];
    }
  }

  // Get User by Phone (for Ledger linking)
  Future<Map<String, dynamic>?> getUserByPhone(String phone) async {
    try {
      // Normalize phone if key
      final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
      // Basic check, might need specific format depending on how it's stored

      final result = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.profilesCollectionId,
        queries: [
          Query.equal('phone', [
            phone,
            '+$cleanPhone',
            cleanPhone,
          ]), // Try all formats
          Query.limit(1),
        ],
      );

      if (result.documents.isNotEmpty) {
        final doc = result.documents.first;
        final data = doc.data;
        data['\$id'] = doc.$id; // Inject ID
        return data;
      }
      return null;
    } catch (e) {
      print('Error finding user by phone: $e');
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

  // Join Group via Invite Code
  Future<bool> joinGroup(String inviteCode, String userId) async {
    try {
      print('DEBUG: Attempting to join group with code: "$inviteCode"');

      // Use Cloud Function for secure join
      if (AppwriteConfig.joinGroupFunctionId.isNotEmpty) {
        final execution = await functions.createExecution(
          functionId: AppwriteConfig.joinGroupFunctionId,
          body: jsonEncode({
            'databaseId': AppwriteConfig.databaseId,
            'collectionId': AppwriteConfig.dutchGroupsCollectionId,
            'inviteCode': inviteCode,
            'userId': userId,
          }),
          xasync: false,
        );

        print('DEBUG: Function Execution Status: ${execution.status}');
        print('DEBUG: Function Response: ${execution.responseBody}');

        if (execution.status.toString().contains('completed')) {
          final response = jsonDecode(execution.responseBody);
          if (response['success'] == true) {
            return true;
          } else {
            throw response['message'] ?? 'Failed to join group';
          }
        } else {
          try {
            final response = jsonDecode(execution.responseBody);
            throw response['message'] ?? 'Function failed: ${execution.status}';
          } catch (_) {
            throw 'Function failed with status: ${execution.status}';
          }
        }
      } else {
        throw 'Join Function not configured. Please deploy function and update ID.';
      }
    } catch (e) {
      print('Error joining group: $e');
      if (e is AppwriteException) {
        throw e.message ?? 'Failed to join group';
      }
      rethrow;
    }
  }

  // Update Group
  Future<bool> updateGroup({
    required String groupId,
    required String name,
    required String type,
  }) async {
    try {
      await databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.dutchGroupsCollectionId,
        documentId: groupId,
        data: {'name': name, 'type': type},
      );
      return true;
    } catch (e) {
      print('Error updating group: $e');
      if (e is AppwriteException) {
        throw e.message ?? 'Failed to update group';
      }
      rethrow;
    }
  }

  // Delete Group
  Future<bool> deleteGroup(String groupId) async {
    try {
      await databases.deleteDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.dutchGroupsCollectionId,
        documentId: groupId,
      );
      return true;
    } catch (e) {
      print('Error deleting group: $e');
      if (e is AppwriteException) {
        throw e.message ?? 'Failed to delete group';
      }
      rethrow;
    }
  }

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
      final result = await databases
          .listDocuments(
            databaseId: AppwriteConfig.databaseId,
            collectionId: AppwriteConfig.categoriesCollectionId,
            queries: [
              Query.equal('userId', [user.$id]),
              Query.orderDesc('usageCount'),
            ],
          )
          .timeout(const Duration(seconds: 10));

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
        permissions: [
          Permission.read(Role.user(user.$id)),
          Permission.write(Role.user(user.$id)),
        ],
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
      final result = await databases
          .listDocuments(
            databaseId: AppwriteConfig.databaseId,
            collectionId: AppwriteConfig.itemsCollectionId,
            queries: [
              Query.equal('userId', [user.$id]),
              Query.orderDesc('\$createdAt'), // Newest first
              Query.limit(100),
            ],
          )
          .timeout(const Duration(seconds: 10));

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
      final result = await databases
          .listDocuments(
            databaseId: AppwriteConfig.databaseId,
            collectionId: AppwriteConfig.itemsCollectionId,
            queries: [
              Query.equal('userId', [user.$id]),
              Query.equal('categoryId', [categoryId]),
              Query.orderDesc('usageCount'),
            ],
          )
          .timeout(const Duration(seconds: 10));

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
        'isVariable': data['isVariable'] ?? false,
        if (data['dueDay'] != null) 'dueDay': data['dueDay'],
      };

      final doc = await databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.itemsCollectionId,
        documentId: ID.unique(),
        data: itemData,
        permissions: [
          Permission.read(Role.user(user.$id)),
          Permission.write(Role.user(user.$id)),
        ],
      );

      final response = doc.data;
      response['id'] = doc.$id;
      return response;
    } catch (e) {
      print('Error creating item: $e');
      rethrow; // Rethrow to let UI handle the error
    }
  }

  Future<String?> updateItem(String itemId, Map<String, dynamic> data) async {
    try {
      await databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.itemsCollectionId,
        documentId: itemId,
        data: data,
      );
      return null; // Success
    } catch (e) {
      print('Error updating item: $e');
      if (e is AppwriteException) {
        return e.message;
      }
      return e.toString();
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
    String? phone,
    String? photoUrl,
    List<String> banks = const [],
    Map<String, String> primaryPaymentMethods = const {},
    List<String> customPaymentMethods = const [],
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
          'phone': phone ?? '',
          'photoUrl': photoUrl ?? '',
          'banks': banks,
          'primaryPaymentMethods': jsonEncode(primaryPaymentMethods),
          'customPaymentMethods': jsonEncode(customPaymentMethods),
        },
        permissions: [
          Permission.read(
            Role.any(),
          ), // Allow anyone to find this profile (needed for Ledger search)
          Permission.write(Role.user(userId)),
        ],
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
  Future<List<Map<String, dynamic>>?> getLedgerTransactions({
    String? lastId,
    int limit = 25,
  }) async {
    try {
      final user = await account.get();
      final userId = user.$id;

      String contact = user.phone;
      // If auth phone is empty, try fetching from profile
      if (contact.isEmpty) {
        final profileDocs = await databases.listDocuments(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.profilesCollectionId,
          queries: [
            Query.equal('userId', [userId]),
          ],
        );
        if (profileDocs.documents.isNotEmpty) {
          contact = profileDocs.documents.first.data['phone'] ?? '';
        }
      }

      final Map<String, Map<String, dynamic>> transactionMap = {};

      List<String> baseQueries = [
        Query.orderDesc('dateTime'),
        Query.limit(limit),
      ];
      if (lastId != null) {
        baseQueries.add(Query.cursorAfter(lastId));
      }

      // 1. Where I am the sender (by ID)
      final sentById = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.ledgerCollectionId,
        queries: [
          Query.equal('senderId', [userId]),
          ...baseQueries,
        ],
      );
      for (var doc in sentById.documents) {
        final data = doc.data;
        data['id'] = doc.$id;
        transactionMap[doc.$id] = data;
      }

      // 2. Where I am the receiver (by ID)
      final receivedById = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.ledgerCollectionId,
        queries: [
          Query.equal('receiverId', [userId]),
          ...baseQueries,
        ],
      );
      for (var doc in receivedById.documents) {
        final data = doc.data;
        data['id'] = doc.$id;
        transactionMap[doc.$id] = data;
      }

      // 3. Search by contact (Phone/Email) if available
      if (contact.isNotEmpty) {
        final sentByPhone = await databases.listDocuments(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.ledgerCollectionId,
          queries: [
            Query.equal('senderPhone', [contact]),
            ...baseQueries,
          ],
        );
        for (var doc in sentByPhone.documents) {
          if (!transactionMap.containsKey(doc.$id)) {
            final data = doc.data;
            data['id'] = doc.$id;
            transactionMap[doc.$id] = data;
          }
        }

        final receivedByPhone = await databases.listDocuments(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.ledgerCollectionId,
          queries: [
            Query.equal('receiverPhone', [contact]),
            ...baseQueries,
          ],
        );
        for (var doc in receivedByPhone.documents) {
          if (!transactionMap.containsKey(doc.$id)) {
            final data = doc.data;
            data['id'] = doc.$id;
            transactionMap[doc.$id] = data;
          }
        }
      }

      // Convert back to list and sort by date descending
      final allTransactions = transactionMap.values.toList();
      allTransactions.sort((a, b) {
        String? d1 = a['dateTime'] ?? a['date'] ?? a['\$createdAt'];
        String? d2 = b['dateTime'] ?? b['date'] ?? b['\$createdAt'];
        if (d1 == null || d2 == null) return 0;
        try {
          return DateTime.parse(
            d2,
          ).toLocal().compareTo(DateTime.parse(d1).toLocal());
        } catch (e) {
          return 0;
        }
      });

      return allTransactions;
    } catch (e) {
      print('Error fetching ledger transactions: $e');
      return null; // Return null on error to distinguish from empty list
    }
  }

  // End of method block if needed, but we are inserting after create LedgerTransaction which ends at 1016 in previous view.

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

      List<models.Document> docsToUpdate = [];

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

      List<models.Document> docsToDelete = [];

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

  // Send in-app notification
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String message,
    required String type, // 'nudge', 'reminder', etc.
  }) async {
    // Forward to unified createNotification method
    await createNotification(
      receiverId: userId,
      title: title,
      message: message,
      type: type,
    );
  }
  // --- INVESTMENTS ---

  Future<List<Map<String, dynamic>>> getInvestments({
    int limit = 100,
    String? lastId,
  }) async {
    try {
      final List<String> queries = [
        Query.orderDesc('investedAmount'),
        Query.limit(limit),
      ];
      if (lastId != null && lastId.isNotEmpty) {
        queries.add(Query.cursorAfter(lastId));
      }

      final result = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.investmentsCollectionId,
        queries: queries,
      );

      return result.documents.map((doc) {
        final data = doc.data;
        data['id'] = doc.$id;
        return data;
      }).toList();
    } catch (e) {
      if (e is! AppwriteException || e.code != 401) {
        print('Error fetching investments: $e');
      }
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
        permissions: [
          Permission.read(Role.user(user.$id)),
          Permission.write(Role.user(user.$id)),
        ],
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

  Future<List<Map<String, dynamic>>> getInvestmentTransactions({
    int limit = 25,
    String? lastId,
  }) async {
    if (_skipInvestmentFetch) return [];

    try {
      final List<String> queries = [
        Query.orderDesc('dateTime'),
        Query.limit(limit),
      ];
      if (lastId != null && lastId.isNotEmpty) {
        queries.add(Query.cursorAfter(lastId));
      }

      final result = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.investmentTransactionsCollectionId,
        queries: queries,
      );

      return result.documents.map((doc) {
        final data = doc.data;
        data['id'] = doc.$id;
        return data;
      }).toList();
    } catch (e) {
      // Silence 401 as it's common for this collection if permissions aren't fully set
      if (e is AppwriteException && e.code == 401) {
        _skipInvestmentFetch =
            true; // Guard against future attempts this session
      } else {
        debugPrint('Error fetching investment transactions: $e');
      }
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
        permissions: [
          Permission.read(Role.user(user.$id)),
          Permission.write(Role.user(user.$id)),
        ],
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

  // Fetch notifications for a user
  Future<List<Map<String, dynamic>>> getNotifications(
    String userId, {
    int limit = 20,
  }) async {
    try {
      final result = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.notificationsCollectionId,
        queries: [
          Query.equal('receiverId', userId),
          Query.orderDesc('\$createdAt'),
          Query.limit(limit),
        ],
      );
      return result.documents.map((d) {
        final data = d.data;
        data['\$id'] = d.$id;
        return data;
      }).toList();
    } catch (e) {
      if (e is! AppwriteException || e.code != 401) {
        print('Error fetching notifications: $e');
      }
      return [];
    }
  }

  // Create a notification for a user
  Future<bool> createNotification({
    required String receiverId,
    required String title,
    required String message,
    required String type,
    String? settlementId,
  }) async {
    try {
      await databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.notificationsCollectionId,
        documentId: ID.unique(),
        data: {
          'receiverId': receiverId,
          'title': title,
          'message': message,
          'type': type,
          'settlementId': settlementId,
          'isRead': false,
        },
      );
      return true;
    } catch (e) {
      print('Error creating notification: $e');
      return false;
    }
  }
}
