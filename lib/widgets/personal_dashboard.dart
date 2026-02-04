import 'package:flutter/material.dart';

import 'package:shimmer/shimmer.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../models/item.dart';
import '../providers/transaction_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/user_provider.dart';
import '../screens/settings/bank_details_screen.dart';
import 'add_item_dialog.dart';
import 'transaction_details_dialog.dart';

class PersonalDashboard extends StatefulWidget {
  const PersonalDashboard({super.key});

  @override
  State<PersonalDashboard> createState() => _PersonalDashboardState();
}

class _PersonalDashboardState extends State<PersonalDashboard> {
  String _entryMode = 'daily'; // daily, monthly, variable
  bool _isReordering = false; // Track reordering mode

  int _currentPage = 0;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Access transaction data
    final provider = context.watch<TransactionProvider>();
    final currencySymbol = context.watch<CurrencyProvider>().currencySymbol;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return RefreshIndicator(
      onRefresh: () async {
        await provider.fetchData();
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (scrollInfo.metrics.pixels >=
                  scrollInfo.metrics.maxScrollExtent - 200 &&
              !provider.isLoading &&
              provider.hasMore) {
            provider.loadMoreTransactions();
          }
          return false;
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Balance Cards
              GestureDetector(
                onTap: () {
                  setState(() {
                    _currentPage = (_currentPage + 1) % 5;
                  });
                },
                child: SizedBox(
                  height: 240,
                  child: provider.isLoading
                      ? Shimmer.fromColors(
                          baseColor: theme.brightness == Brightness.dark
                              ? Colors.grey[800]!
                              : Colors.grey[300]!,
                          highlightColor: theme.brightness == Brightness.dark
                              ? Colors.grey[700]!
                              : Colors.grey[100]!,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        )
                      : AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          switchInCurve: Curves.easeInOut,
                          switchOutCurve: Curves.easeInOut,
                          transitionBuilder:
                              (Widget child, Animation<double> animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: ScaleTransition(
                                    scale: Tween<double>(
                                      begin: 0.9,
                                      end: 1.0,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },

                          child: KeyedSubtree(
                            key: ValueKey<int>(_currentPage),
                            child: _buildCurrentBalanceCard(
                              provider,
                              colorScheme,
                              currencySymbol,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              const SizedBox(height: 32),

              // Quick Entries Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isReordering ? 'Reordering Items...' : 'Quick Entries',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _isReordering
                      ? TextButton.icon(
                          onPressed: () =>
                              setState(() => _isReordering = false),
                          icon: const Icon(Icons.check),
                          label: const Text('Done'),
                          style: TextButton.styleFrom(
                            foregroundColor: colorScheme.primary,
                          ),
                        )
                      : IconButton(
                          onPressed: _showAddItemDialog, // Updated
                          icon: const Icon(Icons.add_circle),
                          color: colorScheme.primary,
                        ),
                ],
              ),

              const SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min, // Center content
                    children: [
                      _buildToggleOption(
                        'Daily',
                        _entryMode == 'daily',
                        () => setState(() => _entryMode = 'daily'),
                      ),
                      _buildToggleOption(
                        'Monthly',
                        _entryMode == 'monthly',
                        () => setState(() => _entryMode = 'monthly'),
                      ),
                      _buildToggleOption(
                        'Flexi',
                        _entryMode == 'variable',
                        () => setState(() => _entryMode = 'variable'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Quick Entries - Dynamic Display
              () {
                if (provider.isLoading) {
                  return _buildSkeletonLoader();
                }

                final items = provider.items.where((item) {
                  if (_entryMode == 'variable') {
                    return item.isVariable ?? false;
                  } else {
                    // Show fixed AND variable items matching the frequency
                    return item.frequency == _entryMode;
                  }
                }).toList();

                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        _entryMode == 'daily'
                            ? 'No daily entries yet.'
                            : (_entryMode == 'monthly'
                                  ? 'No monthly entries yet.'
                                  : 'No variable entries yet.'),
                        style: GoogleFonts.inter(color: Colors.grey),
                      ),
                    ),
                  );
                }

                return ReorderableGridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.1,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: items.length,
                  onReorder: (oldIndex, newIndex) {
                    final item = items.removeAt(oldIndex);
                    items.insert(newIndex, item);
                    provider.updateItemsOrder(items);
                  },
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Container(
                      key: ValueKey(item.id),
                      child: _buildItemButton(
                        item,
                        currencySymbol,
                        provider.transactions, // Pass transactions here
                      ),
                    );
                  },
                );
              }(),

              const SizedBox(height: 32),

              const SizedBox(height: 16),

              // Transactions History
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Transactions History',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Recent Transactions - Last 24 Hours with Show More/Less
              () {
                if (provider.isLoading && provider.transactions.isEmpty) {
                  return Shimmer.fromColors(
                    baseColor: theme.brightness == Brightness.dark
                        ? Colors.grey[800]!
                        : Colors.grey[300]!,
                    highlightColor: theme.brightness == Brightness.dark
                        ? Colors.grey[700]!
                        : Colors.grey[100]!,
                    child: Column(
                      children: List.generate(
                        3,
                        (index) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  );
                }

                if (provider.transactions.isEmpty) {
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
                          'No transactions found',
                          style: GoogleFonts.inter(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    ...provider.transactions.map((tx) {
                      return Dismissible(
                        key: Key(tx.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (direction) {
                          context.read<TransactionProvider>().deleteTransaction(
                            tx.id,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Deleted ${tx.title}')),
                          );
                        },
                        child: ListTile(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => TransactionDetailsDialog(
                                transaction: tx,
                                currencySymbol: currencySymbol,
                              ),
                            );
                          },
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
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w500,
                            ),
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
                                  color: tx.isExpense
                                      ? Colors.red
                                      : Colors.green,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                onPressed: () => _deleteTransaction(tx),
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    if (provider.hasMore)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: provider.isLoading
                              ? const CircularProgressIndicator()
                              : TextButton(
                                  onPressed: () =>
                                      provider.loadMoreTransactions(),
                                  child: const Text('Load More'),
                                ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            'No more transactions',
                            style: GoogleFonts.inter(
                              color: Colors.grey.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              }(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleOption(
    String text,
    bool isSelected,
    VoidCallback onTap, {
    bool isSubSelect = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSubSelect ? 12 : 16,
          vertical: isSubSelect ? 6 : 8,
        ),
        margin: EdgeInsets.only(right: 8, top: isSubSelect ? 0 : 0),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : (isSubSelect
                    ? theme.colorScheme.primary.withOpacity(0.1)
                    : Colors.transparent),
          borderRadius: BorderRadius.circular(20),
          border: isSubSelect && !isSelected
              ? Border.all(color: theme.colorScheme.primary.withOpacity(0.2))
              : null,
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            color: isSelected
                ? Colors.white
                : (isSubSelect
                      ? theme.colorScheme.primary
                      : (isDark ? Colors.grey[400] : Colors.grey)),
            fontWeight: FontWeight.w600,
            fontSize: isSubSelect ? 11 : 12,
          ),
        ),
      ),
    );
  }

  Widget _buildItemButton(
    dynamic item,
    String currencySymbol,
    List<Transaction> transactions,
  ) {
    final theme = Theme.of(context);

    // Map icon string to IconData
    IconData iconData = Icons.star;
    if (item.icon == 'shopping_cart') {
      iconData = Icons.shopping_cart;
    } else if (item.icon == 'restaurant') {
      iconData = Icons.restaurant;
    } else if (item.icon == 'commute') {
      iconData = Icons.commute;
    } else if (item.icon == 'home') {
      iconData = Icons.home;
    } else if (item.icon == 'medical_services') {
      iconData = Icons.medical_services;
    } else if (item.icon == 'school') {
      iconData = Icons.school;
    } else if (item.icon == 'fitness_center') {
      iconData = Icons.fitness_center;
    }

    // Dynamic Background Color Logic
    Color backgroundColor = theme.cardColor;
    Color borderColor = theme.colorScheme.primary.withOpacity(0.3);

    String displayAmount = '$currencySymbol${item.amount.toStringAsFixed(0)}';

    if (item.isVariable) {
      // Find last transaction amount for this item
      try {
        final lastTransaction = transactions.firstWhere(
          (t) => t.itemId == item.id,
        );
        displayAmount =
            '$currencySymbol${lastTransaction.amount.toStringAsFixed(0)}';
      } catch (e) {
        displayAmount = 'Variable';
      }
    } else if (item.dueDay != null) {
      final now = DateTime.now();
      DateTime nextDue = DateTime(now.year, now.month, item.dueDay!);

      // If due date passed this month, move to next month
      if (nextDue.isBefore(DateTime(now.year, now.month, now.day))) {
        nextDue = DateTime(now.year, now.month + 1, item.dueDay!);
      }

      final daysUntil = nextDue
          .difference(DateTime(now.year, now.month, now.day))
          .inDays;

      if (daysUntil <= 3) {
        backgroundColor = item.isExpense
            ? Colors.red.withOpacity(0.2)
            : Colors.green.withOpacity(0.2);
      } else if (daysUntil <= 7) {
        backgroundColor = item.isExpense
            ? Colors.red.withOpacity(0.1)
            : Colors.green.withOpacity(0.1);
      }
    }

    return GestureDetector(
      onTap: _isReordering
          ? null
          : () async {
              if (item.isVariable) {
                await _showVariableEntryDialog(item);
                return;
              }

              // Regular Quick Entry Logic
              // Ask for Payment Method for ALL transactions
              String? paymentMethod = await _selectPaymentMethod();
              if (paymentMethod == null) return; // Cancelled

              context.read<TransactionProvider>().addTransaction(
                item.title,
                item.amount,
                item.isExpense,
                categoryId: item.categoryId,
                itemId: item.id,
                paymentMethod: paymentMethod,
              );
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Added ${item.title}')));
            },
      onLongPress: _isReordering ? null : () => _showItemOptions(item),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    iconData,
                    color: item.isVariable
                        ? Colors.amber.shade700
                        : (item.isExpense ? Colors.red : Colors.green),
                    size: 28,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displayAmount,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: item.isVariable
                          ? Colors.amber.shade700
                          : (item.isExpense ? Colors.red : Colors.green),
                    ),
                  ),
                ],
              ),
            ),
            if (item.dueDay != null)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: item.isExpense
                        ? Colors.red.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Due ${item.dueDay}${_getOrdinal(item.dueDay!)}',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: item.isExpense ? Colors.red : Colors.green,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showVariableEntryDialog(dynamic item) async {
    final amountController = TextEditingController();
    String? selectedPaymentMethod;
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add ${item.title}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: amountController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixText: context.read<CurrencyProvider>().currencySymbol,
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Payment Method',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items:
                    ['Cash', 'UPI', 'Debit Card', 'Credit Card', 'Net Banking']
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                onChanged: (val) => selectedPaymentMethod = val,
                validator: (value) => value == null ? 'Required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                context.read<TransactionProvider>().addTransaction(
                  item.title,
                  double.parse(amountController.text),
                  item.isExpense,
                  categoryId: item.categoryId,
                  itemId: item.id,
                  paymentMethod: selectedPaymentMethod,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Added ${item.title}')));
              }
            },
            child: const Text('Add'),
          ),
        ],
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
              leading: const Icon(Icons.swap_vert),
              title: const Text('Reorder Items'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _isReordering = true);
              },
            ),
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
                _deleteItem(item);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _deleteItem(dynamic item) {
    context.read<TransactionProvider>().deleteItem(item.id);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Deleted ${item.title}')));
  }

  void _showEditItemDialog(dynamic item) {
    _showAddItemDialog(editingItem: item);
  }

  void _deleteTransaction(dynamic tx) {
    context.read<TransactionProvider>().deleteTransaction(tx.id);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Deleted ${tx.title}')));
  }

  // --- Add/Edit Quick Entry Dialog ---
  void _showAddItemDialog({
    String? preSelectedCategoryId,
    bool? preSelectedIsExpense,
    bool? preSelectedIsDaily,
    bool? preSelectedIsVariable, // NEW
    Item? editingItem,
  }) {
    showDialog(
      context: context,
      builder: (context) => AddItemDialog(
        category: null, // We don't have a category context here
        editingItem: editingItem,
        isDaily: preSelectedIsDaily ?? (_entryMode == 'daily'),
        initialIsVariable:
            preSelectedIsVariable ?? (_entryMode == 'variable'), // NEW
      ),
    );
  }

  Widget _buildBalanceCard({
    required String title,
    required double balance,
    required double income,
    required double expense,
    required ColorScheme colorScheme,
    required String currencySymbol,
    required int currentPage,
    required int totalPages,
    Color? boxColor, // Added
  }) {
    return Container(
      // margin removed to match LedgerDashboard and fix shade mismatch
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: boxColor ?? colorScheme.primary, // Use boxColor if provided
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Content
          Column(
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
                    title,
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
                '$currencySymbol${balance.toStringAsFixed(2)}',
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

          // Indicators (Dots)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(totalPages, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: currentPage == index
                        ? Colors.white
                        : Colors.white.withOpacity(0.3),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentBalanceCard(
    TransactionProvider provider,
    ColorScheme colorScheme,
    String currencySymbol,
  ) {
    switch (_currentPage) {
      case 0:
        return _buildBalanceCard(
          title: 'Total Balance',
          balance: provider.totalBalance,
          income: provider.totalIncome,
          expense: provider.totalExpenses,
          colorScheme: colorScheme,
          currencySymbol: currencySymbol,
          currentPage: 0,
          totalPages: 5,
        );
      case 1:
        return _buildBalanceCard(
          title: 'Yearly Balance',
          balance: _calculateBalance(provider.transactions, (t) {
            final now = DateTime.now();
            return t.dateTime.year == now.year;
          }),
          income: _calculateIncome(provider.transactions, (t) {
            final now = DateTime.now();
            return t.dateTime.year == now.year;
          }),
          expense: _calculateExpense(provider.transactions, (t) {
            final now = DateTime.now();
            return t.dateTime.year == now.year;
          }),
          colorScheme: colorScheme,
          currencySymbol: currencySymbol,
          currentPage: 1,
          totalPages: 5,
        );
      case 2:
        return _buildBalanceCard(
          title: 'Monthly Balance',
          balance: _calculateBalance(provider.transactions, (t) {
            final now = DateTime.now();
            return t.dateTime.year == now.year && t.dateTime.month == now.month;
          }),
          income: _calculateIncome(provider.transactions, (t) {
            final now = DateTime.now();
            return t.dateTime.year == now.year && t.dateTime.month == now.month;
          }),
          expense: _calculateExpense(provider.transactions, (t) {
            final now = DateTime.now();
            return t.dateTime.year == now.year && t.dateTime.month == now.month;
          }),
          colorScheme: colorScheme,
          currencySymbol: currencySymbol,
          currentPage: 2,
          totalPages: 5,
        );
      case 3:
        return _buildBalanceCard(
          title: 'Weekly Balance',
          balance: _calculateBalance(provider.transactions, (t) {
            final now = DateTime.now();
            final weekAgo = now.subtract(const Duration(days: 7));
            return t.dateTime.isAfter(weekAgo);
          }),
          income: _calculateIncome(provider.transactions, (t) {
            final now = DateTime.now();
            final weekAgo = now.subtract(const Duration(days: 7));
            return t.dateTime.isAfter(weekAgo);
          }),
          expense: _calculateExpense(provider.transactions, (t) {
            final now = DateTime.now();
            final weekAgo = now.subtract(const Duration(days: 7));
            return t.dateTime.isAfter(weekAgo);
          }),
          colorScheme: colorScheme,
          currencySymbol: currencySymbol,
          currentPage: 3,
          totalPages: 5,
        );
      case 4:
      default:
        return _buildBalanceCard(
          title: 'Daily Balance',
          balance: _calculateBalance(provider.transactions, (t) {
            final now = DateTime.now();
            return t.dateTime.year == now.year &&
                t.dateTime.month == now.month &&
                t.dateTime.day == now.day;
          }),
          income: _calculateIncome(provider.transactions, (t) {
            final now = DateTime.now();
            return t.dateTime.year == now.year &&
                t.dateTime.month == now.month &&
                t.dateTime.day == now.day;
          }),
          expense: _calculateExpense(provider.transactions, (t) {
            final now = DateTime.now();
            return t.dateTime.year == now.year &&
                t.dateTime.month == now.month &&
                t.dateTime.day == now.day;
          }),
          colorScheme: colorScheme,
          currencySymbol: currencySymbol,
          currentPage: 4,
          totalPages: 5,
        );
    }
  }

  // Helper methods for calculations
  double _calculateBalance(
    List<Transaction> transactions,
    bool Function(Transaction) filter,
  ) {
    double total = 0;
    for (var t in transactions) {
      if (filter(t)) {
        if (t.isExpense) {
          total -= t.amount;
        } else {
          total += t.amount;
        }
      }
    }
    return total;
  }

  double _calculateIncome(
    List<Transaction> transactions,
    bool Function(Transaction) filter,
  ) {
    return transactions
        .where((t) => !t.isExpense && filter(t))
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double _calculateExpense(
    List<Transaction> transactions,
    bool Function(Transaction) filter,
  ) {
    return transactions
        .where((t) => t.isExpense && filter(t))
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  Future<String?> _selectPaymentMethod() {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Consumer<UserProvider>(
          builder: (context, userProvider, child) {
            final primaryMethods = userProvider.primaryPaymentMethods;

            Future<void> handleLongPress(String method) async {
              // One-time bank selection override
              final selectedBank = await showModalBottomSheet<String>(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (BuildContext context) {
                  final banks = userProvider.banks;
                  return Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Bank for this Transaction',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (banks.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text(
                                "No banks added in Settings.",
                                style: GoogleFonts.inter(color: Colors.grey),
                              ),
                            ),
                          ),
                        ...banks.map(
                          (bank) => ListTile(
                            leading: const Icon(Icons.account_balance),
                            title: Text(
                              bank,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            onTap: () {
                              Navigator.pop(context, bank);
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );

              if (selectedBank != null) {
                // If a bank was selected, return the combined string immediately
                Navigator.pop(context, '$method ($selectedBank)');
              }
            }

            return AlertDialog(
              title: Text(
                'Select Payment Method',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildPaymentOption(
                    context,
                    'Cash',
                    Icons.money,
                    userProvider,
                  ),
                  const SizedBox(height: 12),
                  _buildPaymentOption(
                    context,
                    'UPI',
                    Icons.qr_code,
                    userProvider,
                    primaryBank: primaryMethods['UPI'],
                    onLongPress: () => handleLongPress('UPI'),
                  ),
                  const SizedBox(height: 12),
                  _buildPaymentOption(
                    context,
                    'Debit Card',
                    Icons.credit_card,
                    userProvider,
                    primaryBank: primaryMethods['Debit Card'],
                    onLongPress: () => handleLongPress('Debit Card'),
                  ),
                  const SizedBox(height: 12),
                  _buildPaymentOption(
                    context,
                    'Credit Card',
                    Icons.credit_score,
                    userProvider,
                    primaryBank: primaryMethods['Credit Card'],
                    onLongPress: () => handleLongPress('Credit Card'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentOption(
    BuildContext context,
    String method,
    IconData icon,
    UserProvider userProvider, {
    String? primaryBank,
    VoidCallback? onLongPress,
  }) {
    return InkWell(
      onTap: () {
        if (method != 'Cash' && userProvider.banks.isEmpty) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(
                'Add Bank Details?',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
              content: Text(
                'You haven\'t added any banks yet. Adding a bank helps you track accounts better.',
                style: GoogleFonts.inter(),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx); // Close suggestion
                    Navigator.pop(context, method); // Return default method
                  },
                  child: const Text('Use Default'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx); // Close suggestion
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BankDetailsScreen(),
                      ),
                    );
                  },
                  child: const Text('Add Bank'),
                ),
              ],
            ),
          );
        } else {
          String result = method;
          if (primaryBank != null) {
            result = '$method ($primaryBank)';
          }
          Navigator.pop(context, result);
        }
      },
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    method,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                  // Always reserve space for subtitle to match height
                  Align(
                    alignment: Alignment.centerRight,
                    child: Visibility(
                      visible: primaryBank != null,
                      maintainSize: true,
                      maintainAnimation: true,
                      maintainState: true,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          primaryBank != null
                              ? 'Primary as $primaryBank'
                              : 'Primary as Placeholder',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getOrdinal(int n) {
    if (n >= 11 && n <= 13) return 'th';
    switch (n % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  Widget _buildSkeletonLoader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1.1,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          );
        },
      ),
    );
  }
}
