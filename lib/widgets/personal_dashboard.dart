import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/currency_provider.dart';

class PersonalDashboard extends StatefulWidget {
  const PersonalDashboard({super.key});

  @override
  State<PersonalDashboard> createState() => _PersonalDashboardState();
}

class _PersonalDashboardState extends State<PersonalDashboard> {
  bool _isDaily = true;
  String? _selectedCategoryId;
  bool _showMoreCategoryItems = false;
  bool _showMoreTransactions = false;

  @override
  @override
  Widget build(BuildContext context) {
    // Access transaction data
    final provider = context.watch<TransactionProvider>();
    final currencySymbol = context.watch<CurrencyProvider>().currencySymbol;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final income = provider.totalIncome;
    final expense = provider.totalExpenses;
    final totalBalance = provider.totalBalance;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total Balance Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.primary,
              // gradient: LinearGradient(
              //   colors: [colorScheme.primary, colorScheme.tertiary],
              //   begin: Alignment.topLeft,
              //   end: Alignment.bottomRight,
              // ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.3),
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
                      Icons.account_balance_wallet_outlined,
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
                  '$currencySymbol${totalBalance.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.arrow_upward_rounded,
                                color: Colors.white70,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Income',
                                style: GoogleFonts.inter(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$currencySymbol${income.toStringAsFixed(2)}',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF51CF66), // Green
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 40, width: 1, color: Colors.white12),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.arrow_downward_rounded,
                                color: Colors.white70,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Expenses',
                                style: GoogleFonts.inter(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$currencySymbol${expense.toStringAsFixed(2)}',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFFF6B6B), // Red
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Quick Entries Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Quick Entries',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    _buildToggleOption('Daily', _isDaily),
                    _buildToggleOption('Monthly', !_isDaily),
                  ],
                ),
              ),
              IconButton(
                onPressed: _showAddItemDialog, // Updated
                icon: const Icon(Icons.add_circle),
                color: colorScheme.primary,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Quick Entries - Dynamic Display
          () {
            final items = provider.items
                .where(
                  (item) => item.frequency == (_isDaily ? 'daily' : 'monthly'),
                )
                .toList();

            if (items.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    _isDaily
                        ? 'No daily entries yet.'
                        : 'No monthly entries yet.',
                    style: GoogleFonts.inter(color: Colors.grey),
                  ),
                ),
              );
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.1,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return _buildItemButton(item, currencySymbol);
              },
            );
          }(),

          const SizedBox(height: 32),

          // Categories
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Categories',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: _showAddCategoryDialog, // Updated
                icon: const Icon(Icons.add_circle),
                color: colorScheme.primary,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Categories - Horizontal Scrollable
          () {
            final categories = provider.categories;

            if (categories.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No categories yet.',
                    style: GoogleFonts.inter(color: Colors.grey),
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 60, // Increased from 50 to accommodate arrow
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final isSelected = _selectedCategoryId == category.id;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (_selectedCategoryId == category.id) {
                              _selectedCategoryId = null;
                              _showMoreCategoryItems = false;
                            } else {
                              _selectedCategoryId = category.id;
                              _showMoreCategoryItems = false;
                            }
                          });
                        },
                        onLongPress: () => _showCategoryOptions(category),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ), // Reduced padding
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colorScheme.primary.withOpacity(0.15)
                                    : theme.cardColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? colorScheme.primary
                                      : Colors.grey.withOpacity(0.3),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.category,
                                    size: 14, // Reduced icon size
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    category.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.arrow_drop_down,
                                  color: colorScheme.primary,
                                  size: 18,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Category Items - 3x3 Grid
                if (_selectedCategoryId != null) ...[
                  const SizedBox(height: 16),
                  () {
                    final categoryItems = provider.items
                        .where((item) => item.categoryId == _selectedCategoryId)
                        .toList();

                    if (categoryItems.isEmpty) {
                      // Show single cell-sized Add Item button when category is empty
                      final selectedCategory = provider.categories.firstWhere(
                        (cat) => cat.id == _selectedCategoryId,
                      );
                      return GestureDetector(
                        onTap: () {
                          _showAddItemDialog(
                            preSelectedCategoryId: selectedCategory.id,
                            preSelectedIsExpense:
                                selectedCategory.type == 'expense',
                          );
                        },
                        child: Container(
                          width: 110, // Match grid cell width
                          height: 100, // Match grid cell height
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.primary.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_circle_outline,
                                color: colorScheme.primary,
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add First\nItem',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.primary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final itemsToShow = _showMoreCategoryItems
                        ? categoryItems
                        : categoryItems.take(9).toList();

                    return Column(
                      children: [
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 3,
                          childAspectRatio: 1.1,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          children: [
                            ...itemsToShow.map(
                              (item) => _buildItemButton(item, currencySymbol),
                            ),
                            // Add button at the end
                            GestureDetector(
                              onTap: () {
                                final selectedCategory = provider.categories
                                    .firstWhere(
                                      (cat) => cat.id == _selectedCategoryId,
                                    );
                                _showAddItemDialog(
                                  preSelectedCategoryId: selectedCategory.id,
                                  preSelectedIsExpense:
                                      selectedCategory.type == 'expense',
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: colorScheme.primary.withOpacity(0.3),
                                    style: BorderStyle.solid,
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_circle_outline,
                                      color: colorScheme.primary,
                                      size: 32,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Add Item',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: colorScheme.primary,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (categoryItems.length > 9) ...[
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _showMoreCategoryItems =
                                    !_showMoreCategoryItems;
                              });
                            },
                            icon: Icon(
                              _showMoreCategoryItems
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 16,
                            ),
                            label: Text(
                              _showMoreCategoryItems
                                  ? 'Show Less'
                                  : 'Show More (${categoryItems.length - 9})',
                              style: GoogleFonts.inter(fontSize: 12),
                            ),
                          ),
                        ],
                      ],
                    );
                  }(),
                ],
              ],
            );
          }(),

          const SizedBox(height: 16),

          // Recent Transactions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Transactions',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: _showAddTransactionDialog, // Updated
                icon: const Icon(Icons.add_circle),
                color: colorScheme.primary,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Recent Transactions - Last 24 Hours with Show More/Less
          () {
            final now = DateTime.now();
            final last24Hours = now.subtract(const Duration(hours: 24));

            final last24HoursTransactions = provider.transactions
                .where((tx) => tx.dateTime.isAfter(last24Hours))
                .toList();

            final transactionsToShow = _showMoreTransactions
                ? last24HoursTransactions
                : last24HoursTransactions.take(5).toList();

            if (last24HoursTransactions.isEmpty) {
              return Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.receipt_long_outlined,
                      size: 48,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No transactions in last 24 hours',
                      style: GoogleFonts.inter(color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: transactionsToShow.length,
                  itemBuilder: (context, index) {
                    final tx = transactionsToShow[index];
                    return Dismissible(
                      key: Key(tx.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        return await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Transaction'),
                            content: Text('Delete "${tx.title}"?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                      },
                      onDismissed: (direction) {
                        context.read<TransactionProvider>().deleteTransaction(
                          tx.id,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Deleted ${tx.title}')),
                        );
                      },
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: tx.isExpense
                              ? Colors.red.withOpacity(0.1)
                              : Colors.green.withOpacity(0.1),
                          child: Icon(
                            tx.isExpense
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: tx.isExpense ? Colors.red : Colors.green,
                          ),
                        ),
                        title: Text(
                          tx.title,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          tx.dateTime.toString().split(' ')[0],
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${tx.isExpense ? '-' : '+'}$currencySymbol${tx.amount.toStringAsFixed(2)}',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                color: tx.isExpense ? Colors.red : Colors.green,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                                size: 20,
                              ),
                              onPressed: () => _confirmDeleteTransaction(tx),
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                if (last24HoursTransactions.length > 5) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showMoreTransactions = !_showMoreTransactions;
                      });
                    },
                    icon: Icon(
                      _showMoreTransactions
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 16,
                    ),
                    label: Text(
                      _showMoreTransactions
                          ? 'Show Less'
                          : 'Show More (${last24HoursTransactions.length - 5} more)',
                      style: GoogleFonts.inter(fontSize: 12),
                    ),
                  ),
                ],
              ],
            );
          }(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildToggleOption(String text, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isDaily = text == 'Daily';
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            color: isSelected ? Colors.white : Colors.grey,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildItemButton(dynamic item, String currencySymbol) {
    final theme = Theme.of(context);

    // Map icon string to IconData
    IconData iconData = Icons.star;
    if (item.icon == 'shopping_cart')
      iconData = Icons.shopping_cart;
    else if (item.icon == 'restaurant')
      iconData = Icons.restaurant;
    else if (item.icon == 'commute')
      iconData = Icons.commute;
    else if (item.icon == 'home')
      iconData = Icons.home;
    else if (item.icon == 'medical_services')
      iconData = Icons.medical_services;
    else if (item.icon == 'school')
      iconData = Icons.school;
    else if (item.icon == 'fitness_center')
      iconData = Icons.fitness_center;

    return GestureDetector(
      onTap: () {
        // Add transaction when tapped
        context.read<TransactionProvider>().addTransaction(
          item.title,
          item.amount,
          item.isExpense,
          categoryId: item.categoryId,
          itemId: item.id,
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Added ${item.title}')));
      },
      onLongPress: () => _showItemOptions(item),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              iconData,
              color: item.isExpense ? Colors.red : Colors.green,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '$currencySymbol${item.amount.toStringAsFixed(0)}',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: item.isExpense ? Colors.red : Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showItemOptions(dynamic item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.title,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _showEditItemDialog(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteItem(item);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteItem(dynamic item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Quick Entry'),
        content: Text('Are you sure you want to delete "${item.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<TransactionProvider>().deleteItem(item.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Deleted ${item.title}')));
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditItemDialog(dynamic item) {
    // Will update _showAddItemDialog to accept editingItem parameter
    // For now, just show the add dialog with pre-filled category
    _showAddItemDialog(
      preSelectedCategoryId: item.categoryId,
      preSelectedIsExpense: item.isExpense,
    );
  }

  void _showCategoryOptions(dynamic category) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              category.name,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _showEditCategoryDialog(category);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteCategory(category);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteCategory(dynamic category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
          'Are you sure you want to delete "${category.name}"? Items in this category will also be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<TransactionProvider>().deleteCategory(category.id);
              Navigator.pop(context);
              setState(() {
                if (_selectedCategoryId == category.id) {
                  _selectedCategoryId = null;
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Deleted ${category.name}')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditCategoryDialog(dynamic category) {
    // Pre-fill with existing category data
    final nameController = TextEditingController(text: category.name);
    String type = category.type;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final isExpense = type == 'expense';

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Edit Category',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Category Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => type = 'expense'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isExpense
                                    ? Colors.red.withOpacity(0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  'Expense',
                                  style: TextStyle(
                                    color: isExpense ? Colors.red : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => type = 'income'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !isExpense
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  'Income',
                                  style: TextStyle(
                                    color: !isExpense
                                        ? Colors.green
                                        : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (nameController.text.isNotEmpty) {
                          // For now, just delete and recreate - update can be added to provider later
                          context.read<TransactionProvider>().deleteCategory(
                            category.id,
                          );
                          context.read<TransactionProvider>().addCategory(
                            nameController.text,
                            type,
                            'category', // Default icon
                          );
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('Update Category'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteTransaction(dynamic tx) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Text('Are you sure you want to delete "${tx.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<TransactionProvider>().deleteTransaction(tx.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Deleted ${tx.title}')));
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // --- Add Transaction Dialog ---
  void _showAddTransactionDialog() {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    bool isExpense = true;
    String? selectedCategoryId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final categories = context.watch<TransactionProvider>().categories;

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'New Transaction',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Type Toggle
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => isExpense = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isExpense
                                      ? Colors.red.withOpacity(0.1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    'Expense',
                                    style: TextStyle(
                                      color: isExpense
                                          ? Colors.red
                                          : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => isExpense = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: !isExpense
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    'Income',
                                    style: TextStyle(
                                      color: !isExpense
                                          ? Colors.green
                                          : Colors.grey,
                                      fontWeight: FontWeight.bold,
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
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Title',
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
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Category Dropdown
                    DropdownButtonFormField<String>(
                      value: selectedCategoryId,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: categories
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => selectedCategoryId = val,
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          if (titleController.text.isNotEmpty &&
                              amountController.text.isNotEmpty) {
                            context.read<TransactionProvider>().addTransaction(
                              titleController.text,
                              double.tryParse(amountController.text) ?? 0.0,
                              isExpense,
                              categoryId: selectedCategoryId,
                            );
                            Navigator.pop(context);
                          }
                        },
                        child: const Text('Add Transaction'),
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

  // --- Add Category Dialog ---
  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    String type = 'expense';
    // Simple icon picker placeholder - can be expanded to a grid selector
    String selectedIcon = 'category';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final isExpense = type == 'expense';

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'New Category',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Type Toggle (Styled like Transaction Dialog)
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => type = 'expense'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isExpense
                                    ? Colors.red.withOpacity(0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  'Expense',
                                  style: TextStyle(
                                    color: isExpense ? Colors.red : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => type = 'income'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !isExpense
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  'Income',
                                  style: TextStyle(
                                    color: !isExpense
                                        ? Colors.green
                                        : Colors.grey,
                                    fontWeight: FontWeight.bold,
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
                    controller: nameController,
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
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        if (nameController.text.isNotEmpty) {
                          context.read<TransactionProvider>().addCategory(
                            nameController.text,
                            type,
                            selectedIcon,
                          );
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('Add Category'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Add Quick Entry Dialog ---
  void _showAddItemDialog({
    String? preSelectedCategoryId,
    bool? preSelectedIsExpense,
    bool? preSelectedIsDaily,
  }) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    bool isDaily =
        preSelectedIsDaily ?? _isDaily; // Use dashboard's current tab
    String? selectedCategoryId = preSelectedCategoryId;
    bool isExpense = preSelectedIsExpense ?? true;
    String selectedIcon = 'star';

    final iconOptions = [
      'star',
      'shopping_cart',
      'restaurant',
      'commute',
      'home',
      'medical_services',
      'school',
      'fitness_center',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final categories = context.watch<TransactionProvider>().categories;

          // Enhanced Dropdown Logic: Find "Others" or default, add "+ New Category"
          final List<DropdownMenuItem<String>> dropdownItems = categories
              .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
              .toList();

          // Add "Other" virtual option
          dropdownItems.add(
            const DropdownMenuItem(
              value: 'other_virtual',
              child: Text('Other'),
            ),
          );

          // Add "+ New Category" LAST
          dropdownItems.add(
            DropdownMenuItem(
              value: 'new_category',
              child: Text(
                '+ New Category',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );

          // Only auto-select if not pre-selected
          if (selectedCategoryId == null && categories.isNotEmpty) {
            // Try to find 'Others' or similar, else first
            final others = categories
                .where((c) => c.name.toLowerCase().contains('other'))
                .firstOrNull;
            selectedCategoryId = others?.id ?? categories.first.id;
          }

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'New Quick Entry',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Category Dropdown FIRST
                    DropdownButtonFormField<String>(
                      value: selectedCategoryId,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.category),
                      ),
                      items: dropdownItems,
                      onChanged: (value) {
                        if (value == 'new_category') {
                          Navigator.pop(context);
                          _showAddCategoryDialog();
                        } else {
                          setState(() {
                            selectedCategoryId = value;
                            // Auto-set isExpense based on category type
                            if (value != null && value != 'other_virtual') {
                              final cat = categories.firstWhere(
                                (c) => c.id == value,
                              );
                              // Auto-set based on category type
                              isExpense = cat.type == 'expense';
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Icon Selector
                    SizedBox(
                      height: 60,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: iconOptions.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final iconName = iconOptions[index];
                          // Map string to IconData (simplified mapping for demo, usually need a map)
                          // Using a helper or assumes specific set. For now, using generic Icons based on index/name logic?
                          // In a real app we need a String -> IconData map.
                          // I'll stick to a simple circle selector highlighting the selected one.
                          // Since I don't have the map handy here, I will use a placeholder map or logic.
                          IconData iconData = Icons.star;
                          if (iconName == 'shopping_cart')
                            iconData = Icons.shopping_cart;
                          else if (iconName == 'restaurant')
                            iconData = Icons.restaurant;
                          else if (iconName == 'commute')
                            iconData = Icons.commute;
                          else if (iconName == 'home')
                            iconData = Icons.home;
                          else if (iconName == 'medical_services')
                            iconData = Icons.medical_services;
                          else if (iconName == 'school')
                            iconData = Icons.school;
                          else if (iconName == 'fitness_center')
                            iconData = Icons.fitness_center;

                          final isSelected = selectedIcon == iconName;

                          return GestureDetector(
                            onTap: () =>
                                setState(() => selectedIcon = iconName),
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey.withOpacity(0.1),
                              ),
                              child: Icon(
                                iconData,
                                color: isSelected ? Colors.white : Colors.grey,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Type Toggle (Daily vs One Time) matches request "toggle daily or expanse below that one time option"
                    // Interpreting as: Main toggle is Daily/One Time for the Quick Entry context?
                    // Or Expense/Income?
                    // Request: "toggle daily or expanse below that one time option"
                    // I will do: Expense/Income Toggle first, then Daily/OneTime Toggle below.

                    // Show Expense/Income Toggle ONLY for "Other" category
                    if (selectedCategoryId == 'other_virtual' ||
                        (selectedCategoryId != null &&
                            selectedCategoryId != 'other_virtual' &&
                            selectedCategoryId != 'new_category' &&
                            categories.isNotEmpty &&
                            categories
                                .firstWhere(
                                  (c) => c.id == selectedCategoryId,
                                  orElse: () => categories.first,
                                )
                                .name
                                .toLowerCase()
                                .contains('other'))) ...[
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => isExpense = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isExpense
                                        ? Colors.red.withOpacity(0.1)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Expense',
                                      style: TextStyle(
                                        color: isExpense
                                            ? Colors.red
                                            : Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => isExpense = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: !isExpense
                                        ? Colors.green.withOpacity(0.1)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Income',
                                      style: TextStyle(
                                        color: !isExpense
                                            ? Colors.green
                                            : Colors.grey,
                                        fontWeight: FontWeight.bold,
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
                    ],

                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Title',
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
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const SizedBox(height: 16),

                    // Frequency Toggle (Daily/Monthly)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => isDaily = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isDaily
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.primary.withOpacity(0.1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    'Daily',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDaily
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => isDaily = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: !isDaily
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.primary.withOpacity(0.1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    'Monthly',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: !isDaily
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Main Action: Save Quick Entry
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          if (titleController.text.isNotEmpty &&
                              amountController.text.isNotEmpty &&
                              selectedCategoryId != null) {
                            // Add as Quick Item (Recurring)
                            final itemData = {
                              'title': titleController.text,
                              'amount':
                                  double.tryParse(amountController.text) ?? 0.0,
                              'frequency': isDaily ? 'daily' : 'monthly',
                              'categoryId':
                                  selectedCategoryId == 'other_virtual'
                                  ? null
                                  : selectedCategoryId,
                              'isExpense': isExpense,
                              'icon': selectedIcon,
                            };
                            context.read<TransactionProvider>().addItem(
                              itemData,
                            );
                            Navigator.pop(context);
                          }
                        },
                        child: const Text('Save Quick Entry'),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Secondary Action: One Time Only
                    TextButton(
                      onPressed: () {
                        if (titleController.text.isNotEmpty &&
                            amountController.text.isNotEmpty &&
                            selectedCategoryId != null) {
                          // Add as One Time Transaction (Confirm)
                          context.read<TransactionProvider>().addTransaction(
                            titleController.text,
                            double.tryParse(amountController.text) ?? 0.0,
                            isExpense,
                            categoryId: selectedCategoryId == 'other_virtual'
                                ? null
                                : selectedCategoryId,
                          );
                          Navigator.pop(context);
                        }
                      },
                      child: Text(
                        'Just Add as One-Time Transaction',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.7),
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
}
