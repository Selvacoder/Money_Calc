import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'models/transaction.dart';
import 'models/category.dart';
import 'models/item.dart';
import 'models/user_profile.dart';
import 'services/auth_service.dart';
import 'services/appwrite_service.dart';
import 'services/sound_service.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/history_screen.dart';
import 'screens/graph_screen.dart';
import 'screens/account_screen.dart';
import 'screens/biometric_auth_screen.dart';
import 'package:track_expense/providers/theme_provider.dart';
import 'package:track_expense/widgets/arrow_tab_painter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Initialize Appwrite
  WidgetsFlutterBinding.ensureInitialized();
  AppwriteService().init();

  final themeProvider = ThemeProvider();

  runApp(MoneyCalcApp(themeProvider: themeProvider));
}

class MoneyCalcApp extends StatelessWidget {
  final ThemeProvider themeProvider;

  const MoneyCalcApp({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeProvider,
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'MoneyCalc',
          themeMode: themeProvider.themeMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: themeProvider.seedColor,
              brightness: Brightness.light,
            ),
            textTheme: GoogleFonts.interTextTheme(),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: themeProvider.seedColor,
              brightness: Brightness.dark,
            ),
            textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
            useMaterial3: true,
          ),
          home: const AuthWrapper(),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/signup': (context) => const SignUpScreen(),
            '/home': (context) => const HomePage(),
          },
        );
      },
    );
  }
}

// Authentication wrapper to check login status
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _checkAuthAndBiometrics(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data;
        if (data?['isLoggedIn'] == true) {
          if (data?['biometricEnabled'] == true) {
            return const BiometricAuthScreen();
          }
          return const HomePage();
        }

        return const LoginScreen();
      },
    );
  }

  Future<Map<String, dynamic>> _checkAuthAndBiometrics() async {
    final isLoggedIn = await AuthService().isLoggedIn();
    if (!isLoggedIn) {
      return {'isLoggedIn': false, 'biometricEnabled': false};
    }

    final prefs = await SharedPreferences.getInstance();
    final biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
    return {'isLoggedIn': true, 'biometricEnabled': biometricEnabled};
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final AppwriteService _appwriteService = AppwriteService();
  final AuthService _authService = AuthService(); // Fixed missing service
  List<Transaction> _transactions = [];
  List<Category> _categories = [];
  List<Item> _items = []; // Items for the selected category
  List<Item> _quickItems = []; // Frequently used items (Global)
  String? _selectedCategoryId;
  UserProfile? _userProfile; // Fixed duplicate definition
  bool _isLoading = true;
  int _selectedIndex = 0;
  int _recentTransactionsLimit = 5;
  int _categoryItemsLimit = 9;
  String _quickItemFilter = 'daily'; // 'daily' or 'monthly'
  bool _showAllQuickEntries = false;
  String _currencySymbol = '₹';

  // Map of basic icons for quick entries
  final Map<String, IconData> _itemIcons = {
    'Food': Icons.fastfood,
    'Transport': Icons.directions_car,
    'Shopping': Icons.shopping_bag,
    'Entertainment': Icons.movie,
    'Health': Icons.local_hospital,
    'Bills': Icons.receipt,
    'Education': Icons.school,
    'Coffee': Icons.coffee,
    'Restaurant': Icons.restaurant,
    'Groceries': Icons.local_grocery_store,
    'Fuel': Icons.local_gas_station,
    'Gift': Icons.card_giftcard,
    'Travel': Icons.flight,
    'Other': Icons.category,
  };

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _loadCurrency();
  }

  Future<void> _loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currencySymbol = prefs.getString('currency_symbol') ?? '₹';
    });
  }

  Future<void> _checkAuth() async {
    final userData = await _authService.getCurrentUser();
    if (userData == null) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SignUpScreen()),
        );
      }
    } else {
      setState(() {
        _userProfile = UserProfile(
          name: userData['name'],
          email: userData['email'],
          phone: userData['phone'],
          photoUrl: '', // Placeholder
          joinDate: DateTime.parse(userData['joinDate']),
        );
      });
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    try {
      // Load Transactions
      final transactionData = await _appwriteService.getTransactions();
      final transactions = transactionData
          .map((data) {
            try {
              return Transaction.fromJson(data);
            } catch (e) {
              return null;
            }
          })
          .whereType<Transaction>()
          .toList();

      // Load Categories
      await _loadCategories();
      final categories = _categories;

      List<Item> items = [];
      String? initialCategoryId;

      // Load Top Items (Quick Items)
      await _loadQuickItems();

      // Load Items for the first category if available
      if (categories.isNotEmpty) {
        initialCategoryId = categories.first.id;
        final itemData = await _appwriteService.getItems(initialCategoryId);
        items = itemData
            .map((data) {
              try {
                return Item.fromJson(data);
              } catch (e) {
                return null;
              }
            })
            .whereType<Item>()
            .toList();
      }

      if (mounted) {
        setState(() {
          _transactions = transactions;
          _categories = categories;
          _selectedCategoryId = initialCategoryId;
          _items = items;
          // _quickItems is already set by _loadQuickItems()
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categoryData = await _appwriteService.getCategories();
      final categories = categoryData
          .map((data) {
            try {
              return Category.fromJson(data);
            } catch (e) {
              return null;
            }
          })
          .whereType<Category>()
          .toList();

      if (mounted) {
        setState(() {
          _categories = categories;
        });
      }
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  Future<void> _loadQuickItems() async {
    try {
      final quickItemData = await _appwriteService.getQuickItems();
      final quickItems = quickItemData
          .map((data) {
            try {
              return Item.fromJson(data);
            } catch (e) {
              return null;
            }
          })
          .whereType<Item>()
          .toList();

      if (mounted) {
        setState(() {
          _quickItems = quickItems;
        });
      }
    } catch (e) {
      print('Error loading quick items: $e');
    }
  }

  double get totalBalance {
    double total = 0;
    for (var transaction in _transactions) {
      if (transaction.isExpense) {
        total -= transaction.amount;
      } else {
        total += transaction.amount;
      }
    }
    return total;
  }

  double get totalIncome {
    return _transactions
        .where((t) => !t.isExpense)
        .fold(0, (sum, t) => sum + t.amount);
  }

  double get totalExpenses {
    return _transactions
        .where((t) => t.isExpense)
        .fold(0, (sum, t) => sum + t.amount);
  }

  Future<void> _addTransaction(
    String title,
    double amount,
    bool isExpense, {
    String? categoryId,
    String? itemId,
  }) async {
    SoundService().play(isExpense ? 'expense.mp3' : 'income.mp3');

    // 1. Create locally for immediate UI update (Optimistic)
    final tempId = DateTime.now().toString();
    final newTransaction = Transaction(
      id: tempId,
      title: title,
      amount: amount,
      isExpense: isExpense,
      dateTime: DateTime.now(),
      categoryId: categoryId,
      itemId: itemId,
    );

    setState(() {
      _transactions.insert(0, newTransaction);
    });

    // 2. Save to Appwrite
    final result = await _appwriteService.createTransaction(
      newTransaction.toJson(),
    );

    // 3. Update with real ID if successful, or revert if failed
    if (result != null) {
      setState(() {
        final index = _transactions.indexWhere((t) => t.id == tempId);
        if (index != -1) {
          _transactions[index] = Transaction.fromJson(result);
        }
      });
      // Refresh Quick Items (Most Used) to reflect new usage
      _loadQuickItems();
      await _loadCategories(); // Refresh Categories order
    } else {
      // Revert optimization on failure
      setState(() {
        _transactions.removeWhere((t) => t.id == tempId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save transaction')),
        );
      }
    }
  }

  Future<void> _deleteTransaction(String id) async {
    SoundService().play('delete.mp3');

    // 1. Remove locally
    final index = _transactions.indexWhere((t) => t.id == id);
    final removedItem = _transactions[index];

    setState(() {
      _transactions.removeAt(index);
    });

    // 2. Delete from Appwrite
    final success = await _appwriteService.deleteTransaction(id);

    // 3. Revert if failed
    if (!success) {
      setState(() {
        _transactions.insert(index, removedItem);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete transaction')),
        );
      }
    } else {
      // Success: Refresh Quick Items usage
      _loadQuickItems();
      await _loadCategories();
    }
  }

  void _showAddDialog(BuildContext context) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    bool isExpense = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).cardColor,
                  Theme.of(context).colorScheme.primary.withOpacity(0.05),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Transaction',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 24),

                // Transaction Type Toggle
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => isExpense = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isExpense
                                  ? const Color(0xFFFF6B6B)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.remove_circle_outline,
                                  color: isExpense ? Colors.white : Colors.grey,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Expense',
                                  style: TextStyle(
                                    color: isExpense
                                        ? Colors.white
                                        : Colors.grey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => isExpense = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !isExpense
                                  ? const Color(0xFF51CF66)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_circle_outline,
                                  color: !isExpense
                                      ? Colors.white
                                      : Colors.grey,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Income',
                                  style: TextStyle(
                                    color: !isExpense
                                        ? Colors.white
                                        : Colors.grey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    hintText: 'Enter transaction name',
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    hintText: 'Enter amount',
                    prefixText: '₹',
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (titleController.text.isNotEmpty &&
                              amountController.text.isNotEmpty) {
                            _addTransaction(
                              titleController.text,
                              double.parse(amountController.text),
                              isExpense,
                            );
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text('Add'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack).fade(),
      ),
    );
  }

  void _showOptionsSheet({
    required String title,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                onEdit();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete'),
              textColor: Colors.red,
              iconColor: Colors.red,
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _updateCategory(String id, String name) async {
    final success = await _appwriteService.updateCategory(id, {'name': name});
    if (success) {
      setState(() {
        final index = _categories.indexWhere((c) => c.id == id);
        if (index != -1) {
          _categories[index] = Category(
            id: id,
            userId: _categories[index].userId,
            name: name,
            type: _categories[index].type,
            icon: _categories[index].icon,
            usageCount: _categories[index].usageCount,
          );
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Category updated successfully')),
        );
      }
    }
  }

  Future<void> _updateItem(
    String id,
    String title,
    double amount,
    bool isExpense,
    String categoryId,
    String frequency,
    String? icon,
  ) async {
    final success = await _appwriteService.updateItem(id, {
      'title': title,
      'amount': amount,
      'isExpense': isExpense,
      'categoryId': categoryId,
      'frequency': frequency,
      'icon': icon,
    });

    if (success) {
      _fetchData(); // Refresh all data
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item updated successfully')),
        );
      }
    }
  }

  Future<void> _showAddCategoryDialog({Category? categoryToEdit}) async {
    final categoryNameController = TextEditingController(
      text: categoryToEdit?.name ?? '',
    );
    String selectedType = categoryToEdit?.type ?? 'expense';
    String selectedIcon = categoryToEdit?.icon ?? 'category';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  categoryToEdit != null ? 'Edit Category' : 'New Category',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                // Type Toggle
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setDialogState(() => selectedType = 'expense'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: selectedType == 'expense'
                                  ? const Color(0xFFFF6B6B)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                'Expense',
                                style: TextStyle(
                                  color: selectedType == 'expense'
                                      ? Colors.white
                                      : Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setDialogState(() => selectedType = 'income'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: selectedType == 'income'
                                  ? const Color(0xFF51CF66)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                'Income',
                                style: TextStyle(
                                  color: selectedType == 'income'
                                      ? Colors.white
                                      : Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: categoryNameController,
                  decoration: InputDecoration(
                    labelText: 'Category Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (categoryNameController.text.isNotEmpty) {
                        if (categoryToEdit != null) {
                          _updateCategory(
                            categoryToEdit.id,
                            categoryNameController.text,
                          );
                        } else {
                          _addCategory(
                            categoryNameController.text,
                            selectedType,
                            selectedIcon,
                          );
                        }
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      categoryToEdit != null ? 'Update' : 'Create Category',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addCategory(String name, String type, String icon) async {
    final newCategoryData = {
      'name': name,
      'type': type,
      'icon': icon, // Default icon
    };

    final result = await _appwriteService.createCategory(newCategoryData);
    if (result != null) {
      final newCategory = Category.fromJson(result);
      setState(() {
        _categories.add(newCategory);
      });
      // Auto-select the new category
      _onCategorySelected(newCategory);
    }
  }

  void _showAddItemDialog({Item? itemToEdit}) {
    final titleController = TextEditingController(
      text: itemToEdit?.title ?? '',
    );
    final amountController = TextEditingController(
      text: itemToEdit != null ? itemToEdit.amount.toString() : '',
    );
    bool isExpense = itemToEdit?.isExpense ?? true;
    String frequency = itemToEdit?.frequency ?? 'daily';
    String? selectedCatId = itemToEdit != null
        ? itemToEdit.categoryId
        : _selectedCategoryId;
    bool isOneTime = false;
    String? selectedIcon = itemToEdit?.icon;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Container(
                width: MediaQuery.of(context).size.width,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      itemToEdit != null
                          ? 'Edit Quick Entry'
                          : 'New Quick Entry',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Icon Selection
                    SizedBox(
                      height: 50,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _itemIcons.entries.map((entry) {
                          final isSelected = selectedIcon == entry.key;
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedIcon = entry.key;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.surfaceVariant,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                entry.value,
                                color: isSelected
                                    ? Colors.white
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                size: 20,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      value: selectedCatId,
                      items: [
                        const DropdownMenuItem(
                          value: 'new_category',
                          child: Text(
                            '+ New Category',
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        ..._categories.map((c) {
                          return DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          );
                        }).toList(),
                        const DropdownMenuItem(
                          value: 'others',
                          child: Text('Others'),
                        ),
                      ],
                      onChanged: (val) async {
                        if (val == 'new_category') {
                          // Reset selection temporarily until we have a new one + dialog close
                          setDialogState(() => selectedCatId = null);
                          await _showAddCategoryDialog();
                          // Refresh dialog state to include new category
                          setDialogState(() {
                            if (_categories.isNotEmpty) {
                              selectedCatId = _categories.last.id;
                            }
                          });
                        } else if (val != null) {
                          setDialogState(() => selectedCatId = val);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Item Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        prefixText: _currencySymbol,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    if (itemToEdit == null) ...[
                      const SizedBox(height: 16),
                      // One Time Transaction Toggle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'One Time Transaction',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Switch(
                            value: isOneTime,
                            onChanged: (value) {
                              setDialogState(() {
                                isOneTime = value;
                              });
                            },
                            activeColor: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ],
                    if (!isOneTime) ...[
                      const SizedBox(height: 16),
                      // Frequency Toggle
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setDialogState(() => frequency = 'daily'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: frequency == 'daily'
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Daily',
                                      style: TextStyle(
                                        color: frequency == 'daily'
                                            ? Colors.white
                                            : Colors.grey,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setDialogState(() => frequency = 'monthly'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: frequency == 'monthly'
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Monthly',
                                      style: TextStyle(
                                        color: frequency == 'monthly'
                                            ? Colors.white
                                            : Colors.grey,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (titleController.text.isNotEmpty &&
                              amountController.text.isNotEmpty &&
                              selectedCatId != null) {
                            if (itemToEdit != null) {
                              _updateItem(
                                itemToEdit.id,
                                titleController.text,
                                double.parse(amountController.text),
                                isExpense,
                                selectedCatId!,
                                frequency,
                                selectedIcon,
                              );
                            } else {
                              // Existing Add Logic
                              bool isExpense;
                              if (selectedCatId == 'others') {
                                isExpense =
                                    true; // Default to expense for Others
                              } else {
                                final category = _categories.firstWhere(
                                  (c) => c.id == selectedCatId,
                                );
                                isExpense = category.type == 'expense';
                              }

                              if (isOneTime) {
                                _addOneTimeTransaction(
                                  titleController.text,
                                  double.parse(amountController.text),
                                  isExpense,
                                  selectedCatId!,
                                );
                              } else {
                                _addItem(
                                  titleController.text,
                                  double.parse(amountController.text),
                                  isExpense,
                                  selectedCatId!,
                                  frequency,
                                  selectedIcon,
                                );
                              }
                            }
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          itemToEdit != null
                              ? 'Update Item'
                              : (isOneTime ? 'Confirm' : 'Add Item'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _addItem(
    String title,
    double amount,
    bool isExpense,
    String categoryId,
    String frequency,
    String? icon,
  ) async {
    final newItemData = {
      'title': title,
      'amount': amount,
      'isExpense': isExpense,
      'categoryId': categoryId,
      'frequency': frequency,
      'icon': icon,
    };

    try {
      final result = await _appwriteService.createItem(newItemData);
      if (result != null) {
        final newItem = Item.fromJson(result);
        setState(() {
          _quickItems.insert(0, newItem); // Update Quick Items list

          if (_selectedCategoryId == categoryId) {
            _items.insert(0, newItem);
          } else {
            _selectedCategoryId = categoryId;
            _onCategorySelected(
              _categories.firstWhere((c) => c.id == categoryId),
            );
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item added successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add item: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addOneTimeTransaction(
    String title,
    double amount,
    bool isExpense,
    String categoryId,
  ) async {
    final transactionData = {
      'title': title,
      'amount': amount,
      'isExpense': isExpense,
      'categoryId': categoryId,
      'dateTime': DateTime.now().toIso8601String(),
    };

    try {
      final result = await _appwriteService.createTransaction(transactionData);
      if (result != null) {
        final newTransaction = Transaction.fromJson(result);
        setState(() {
          _transactions.insert(0, newTransaction);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaction added successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add transaction: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _confirmDeleteCategory(Category category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
          'Are you sure you want to delete "${category.name}"? This will not delete transactions but might hide them from filters.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteCategory(category.id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategory(String categoryId) async {
    SoundService().play('delete.mp3');

    final success = await _appwriteService.deleteCategory(categoryId);
    if (success) {
      if (!mounted) return;

      final indexToRemove = _categories.indexWhere((c) => c.id == categoryId);
      if (indexToRemove == -1) return;

      setState(() {
        _categories.removeAt(indexToRemove);
        _quickItems.removeWhere((i) => i.categoryId == categoryId);

        // If we deleted the selected category, select another one
        if (_selectedCategoryId == categoryId) {
          if (_categories.isNotEmpty) {
            // Try to keep the same index, or go to the last one
            final newIndex = indexToRemove < _categories.length
                ? indexToRemove
                : _categories.length - 1;
            _onCategorySelected(_categories[newIndex]);
          } else {
            _selectedCategoryId = null;
            _items = [];
          }
        }
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Category deleted')));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete category')),
        );
      }
    }
  }

  Future<void> _deleteItem(String itemId) async {
    SoundService().play('delete.mp3');
    final success = await _appwriteService.deleteItem(itemId);
    if (success) {
      setState(() {
        _items.removeWhere((i) => i.id == itemId);
        _quickItems.removeWhere((i) => i.id == itemId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: _selectedIndex == 0
          ? AppBar(
              backgroundColor: Theme.of(context).colorScheme.background,
              elevation: 0,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.calculate,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'MoneyCalc',
                    style: GoogleFonts.inter(
                      color: Theme.of(context).colorScheme.onBackground,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            )
          : null,
      body: _getScreen(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Theme.of(context).cardColor,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Colors.grey.shade400,
          selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.inter(),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: 'Graph',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Account',
            ),
          ],
        ),
      ),
    );
  }

  Widget _getScreen() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeScreen();
      case 1:
        return HistoryScreen(
          transactions: _transactions,
          categories: _categories,
        );
      case 2:
        return GraphScreen(
          transactions: _transactions,
          totalIncome: totalIncome,
          totalExpenses: totalExpenses,
        );
      case 3:
        return AccountScreen(
          profile: _userProfile ?? UserProfile.getDefault(),
          onLogout: () async {
            // Handle logout
            await _appwriteService.logout();

            setState(() {
              _transactions = [];
              _userProfile = UserProfile.getDefault();
            });

            if (mounted) {
              Navigator.of(context).pushReplacementNamed('/login');
            }
          },
          onUpdateProfile: (profile) {
            setState(() {
              _userProfile = profile;
            });
          },
          currencySymbol: _currencySymbol,
          onUpdateCurrency: (symbol) {
            setState(() {
              _currencySymbol = symbol;
            });
          },
        );
      default:
        return _buildHomeScreen();
    }
  }

  Widget _buildHomeScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance Card
          _buildBalanceCard()
              .animate()
              .fadeIn(duration: 600.ms)
              .slideY(
                begin: -0.2,
                end: 0,
                duration: 600.ms,
                curve: Curves.easeOutCubic,
              ),

          const SizedBox(height: 24),

          // Category & Items Section
          _buildCategorySection()
              .animate()
              .fadeIn(duration: 600.ms, delay: 100.ms)
              .slideY(
                begin: 0.1,
                end: 0,
                duration: 600.ms,
                curve: Curves.easeOutCubic,
              ),

          const SizedBox(height: 24),

          // Recent Transactions
          _buildRecentTransactions()
              .animate()
              .fadeIn(duration: 600.ms, delay: 200.ms)
              .slideY(
                begin: 0.1,
                end: 0,
                duration: 600.ms,
                curve: Curves.easeOutCubic,
              ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet,
                color: Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Total Balance',
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$_currencySymbol${NumberFormat('#,##0.00').format(totalBalance)}',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildBalanceItem(
                  'Income',
                  totalIncome,
                  Icons.trending_up,
                  true,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withOpacity(0.2),
              ),
              Expanded(
                child: _buildBalanceItem(
                  'Expenses',
                  totalExpenses,
                  Icons.trending_down,
                  false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceItem(
    String label,
    double amount,
    IconData icon,
    bool isIncome,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$_currencySymbol${NumberFormat('#,##0.00').format(amount)}',
              style: GoogleFonts.inter(
                color: isIncome
                    ? const Color(0xFF4ADE80) // Green for Income
                    : const Color(0xFFFF6B6B), // Red for Expense
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- CATEGORY & ITEMS LOGIC ---

  Widget _buildFilterToggle(String title, String value) {
    final isSelected = _quickItemFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _quickItemFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: GoogleFonts.inter(
            color: isSelected ? Colors.white : Colors.grey.shade600,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Future<void> _onCategorySelected(Category category) async {
    setState(() {
      _selectedCategoryId = category.id;
      _categoryItemsLimit = 9; // Reset limit to 3x3
    });
    // Fetch items for this category
    final itemData = await _appwriteService.getItems(category.id);
    final items = itemData
        .map((data) {
          try {
            return Item.fromJson(data);
          } catch (e) {
            return null;
          }
        })
        .whereType<Item>()
        .toList();

    if (mounted) {
      setState(() {
        _items = items;
      });
    }
  }

  // --- CATEGORY & ITEMS UI ---

  Widget _buildCategorySection() {
    final filteredQuickItems = _quickItems
        .where((item) => item.frequency == _quickItemFilter)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick Items (Most Used) - Global Top Items
        // Always show Quick Items section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Quick Entries',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      _buildFilterToggle('Daily', 'daily'),
                      _buildFilterToggle('Monthly', 'monthly'),
                    ],
                  ),
                ),
              ],
            ),
            IconButton(
              onPressed: () => _showAddItemDialog(),
              icon: Icon(
                Icons.add_circle,
                color: Theme.of(context).colorScheme.primary,
              ),
              tooltip: 'Add Quick Entry',
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (filteredQuickItems.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Row(
              children: [
                Text(
                  'No $_quickItemFilter entries yet.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          )
        else ...[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.0,
            ),
            itemCount: _showAllQuickEntries || filteredQuickItems.length <= 9
                ? filteredQuickItems.length
                : 9,
            itemBuilder: (context, index) {
              final item = filteredQuickItems[index];
              return _buildItemButton(
                item,
                allowDelete: true,
              ).animate().fadeIn(delay: (index * 50).ms, duration: 400.ms);
            },
          ),
          if (filteredQuickItems.length > 9)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Center(
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showAllQuickEntries = !_showAllQuickEntries;
                    });
                  },
                  icon: Icon(
                    _showAllQuickEntries
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                  ),
                  label: Text(
                    _showAllQuickEntries ? 'Show Less' : 'Show More',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
        ],

        // Categories List
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Categories',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
            IconButton(
              onPressed: () => _showAddCategoryDialog(),
              icon: Icon(
                Icons.add_circle,
                color: Theme.of(context).colorScheme.primary,
              ),
              tooltip: 'Add Category',
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 55,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final category = _categories[index];
              return _buildCategoryBox(category)
                  .animate()
                  .slideX(begin: 0.2, end: 0, delay: (index * 30).ms)
                  .fadeIn();
            },
          ),
        ),
        const SizedBox(height: 24),

        // Selected Category Items (With Add Button)
        if (_selectedCategoryId != null) ...[
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
              child: Text(
                'No items yet. Add one below:',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          // Grid of Items (Last is Add Button)
          GridView.builder(
            padding: const EdgeInsets.only(bottom: 24), // Add bottom padding
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.0, // Square items
            ),
            itemCount: (_items.length + 1) > _categoryItemsLimit
                ? _categoryItemsLimit
                : (_items.length + 1),
            itemBuilder: (context, index) {
              if (index == _items.length) {
                return _buildAddQuickItemButton().animate().fadeIn(
                  duration: 400.ms,
                );
              }
              final item = _items[index];
              return _buildItemButton(
                item,
              ).animate().fadeIn(delay: (index * 50).ms, duration: 400.ms);
            },
          ),
          if ((_items.length + 1) > 9)
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if ((_items.length + 1) > _categoryItemsLimit)
                    _buildExpandButton(
                      text: 'Show More',
                      icon: Icons.keyboard_arrow_down,
                      onPressed: () {
                        setState(() {
                          _categoryItemsLimit += 3;
                        });
                      },
                    ),
                  if ((_items.length + 1) > _categoryItemsLimit &&
                      _categoryItemsLimit > 9)
                    const SizedBox(width: 16),
                  if (_categoryItemsLimit > 9)
                    _buildExpandButton(
                      text: 'Show Less',
                      icon: Icons.keyboard_arrow_up,
                      onPressed: () {
                        setState(() {
                          _categoryItemsLimit = 9;
                        });
                      },
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildExpandButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 6),
            Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildAddQuickItemButton() {
    return GestureDetector(
      onTap: () => _showAddItemDialog(),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add New',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBox(Category category) {
    final isSelected = _selectedCategoryId == category.id;
    return GestureDetector(
      onTap: () => _onCategorySelected(category),
      onLongPress: () => _showOptionsSheet(
        title: category.name,
        onEdit: () => _showAddCategoryDialog(categoryToEdit: category),
        onDelete: () => _confirmDeleteCategory(category),
      ),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        child: CustomPaint(
          painter: isSelected
              ? ArrowTabPainter(color: Theme.of(context).colorScheme.primary)
              : null,
          child: Container(
            padding: EdgeInsets.fromLTRB(16, 8, 16, isSelected ? 16 : 8),
            decoration: isSelected
                ? null
                : BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
            alignment: Alignment.center,
            child: Text(
              category.name,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemButton(Item item, {bool allowDelete = true}) {
    return GestureDetector(
      onTap: () => _addTransaction(
        item.title,
        item.amount,
        item.isExpense,
        categoryId: item.categoryId,
        itemId: item.id,
      ),
      onLongPress: !allowDelete
          ? null
          : () => _showOptionsSheet(
              title: item.title,
              onEdit: () => _showAddItemDialog(itemToEdit: item),
              onDelete: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Item'),
                    content: Text('Delete "${item.title}"?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          _deleteItem(item.id);
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.isExpense
                ? const Color(0xFFFFE5E5)
                : const Color(0xFFE5F5E9),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: item.isExpense
                        ? const Color(0xFFFFE5E5)
                        : const Color(0xFFE5F5E9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item.icon != null && _itemIcons.containsKey(item.icon)
                        ? _itemIcons[item.icon]
                        : (item.isExpense ? Icons.remove : Icons.add),
                    color: item.isExpense
                        ? const Color(0xFFFF6B6B)
                        : const Color(0xFF51CF66),
                    size: 16,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  item.title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  '$_currencySymbol${NumberFormat('#,##0').format(item.amount)}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: item.isExpense
                        ? const Color(0xFFFF6B6B)
                        : const Color(0xFF51CF66),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Transactions',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
            IconButton(
              onPressed: () => _showAddDialog(context),
              icon: Icon(
                Icons.add_circle,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_transactions.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No transactions yet',
                    style: GoogleFonts.inter(
                      color: Colors.grey.shade500,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _transactions.length > _recentTransactionsLimit
                ? _recentTransactionsLimit
                : _transactions.length,
            itemBuilder: (context, index) {
              final transaction = _transactions[index];
              return _buildTransactionItem(transaction, index);
            },
          ),
          if (_transactions.length > 5)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_transactions.length > _recentTransactionsLimit)
                    _buildExpandButton(
                      text: 'Show More',
                      icon: Icons.keyboard_arrow_down,
                      onPressed: () {
                        setState(() {
                          _recentTransactionsLimit += 5;
                        });
                      },
                    ),
                  if (_transactions.length > _recentTransactionsLimit &&
                      _recentTransactionsLimit > 5)
                    const SizedBox(width: 16),
                  if (_recentTransactionsLimit > 5)
                    _buildExpandButton(
                      text: 'Show Less',
                      icon: Icons.keyboard_arrow_up,
                      onPressed: () {
                        setState(() {
                          _recentTransactionsLimit = 5;
                        });
                      },
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildTransactionItem(Transaction transaction, int index) {
    return Dismissible(
      key: Key(transaction.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteTransaction(transaction.id),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: transaction.isExpense
                    ? const Color(0xFFFFE5E5)
                    : const Color(0xFFE5F5E9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                transaction.isExpense
                    ? Icons.remove_circle_outline
                    : Icons.add_circle_outline,
                color: transaction.isExpense
                    ? const Color(0xFFFF6B6B)
                    : const Color(0xFF51CF66),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onBackground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('MMM d, h:mm a').format(transaction.dateTime),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${transaction.isExpense ? '-' : '+'}$_currencySymbol${NumberFormat('#,##0.00').format(transaction.amount)}',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: transaction.isExpense
                    ? const Color(0xFFFF6B6B)
                    : const Color(0xFF51CF66),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: Colors.grey.shade400,
                size: 20,
              ),
              onPressed: () => _deleteTransaction(transaction.id),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
