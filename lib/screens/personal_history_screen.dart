import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/transaction.dart';

class PersonalHistoryScreen extends StatefulWidget {
  final List<Transaction> transactions;
  final String currencySymbol;

  const PersonalHistoryScreen({
    super.key,
    required this.transactions,
    this.currencySymbol = '₹',
  });

  @override
  State<PersonalHistoryScreen> createState() => _PersonalHistoryScreenState();
}

class _PersonalHistoryScreenState extends State<PersonalHistoryScreen> {
  DateTime? _selectedDate;
  String _searchQuery = '';
  String _selectedType = 'All'; // All, Income, Expense
  String _sortOption = 'Date'; // Date, Amount High, Amount Low

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Theme.of(context).colorScheme.onPrimary,
              onSurface: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter transactions
    List<Transaction> filteredTransactions = widget.transactions.where((t) {
      // 1. Date Filter
      if (_selectedDate != null) {
        if (t.dateTime.year != _selectedDate!.year ||
            t.dateTime.month != _selectedDate!.month ||
            t.dateTime.day != _selectedDate!.day) {
          return false;
        }
      }

      // 2. Search Filter (Title)
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!t.title.toLowerCase().contains(query)) {
          return false;
        }
      }

      // 3. Type Filter
      if (_selectedType == 'Income' && t.isExpense) return false;
      if (_selectedType == 'Expense' && !t.isExpense) return false;

      return true;
    }).toList();

    // Sort transactions
    if (_sortOption == 'Amount High') {
      filteredTransactions.sort((a, b) => b.amount.compareTo(a.amount));
    } else if (_sortOption == 'Amount Low') {
      filteredTransactions.sort((a, b) => a.amount.compareTo(b.amount));
    } else {
      // Date (Newest first) - default
      filteredTransactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    }

    // Group transactions by date
    Map<String, List<Transaction>> groupedTransactions = {};
    for (var transaction in filteredTransactions) {
      String dateKey = DateFormat('MMM dd, yyyy').format(transaction.dateTime);
      if (!groupedTransactions.containsKey(dateKey)) {
        groupedTransactions[dateKey] = [];
      }
      groupedTransactions[dateKey]!.add(transaction);
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Transaction History',
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onBackground,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${filteredTransactions.length} transactions',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () => _selectDate(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _selectedDate != null
                                ? Theme.of(context).colorScheme.primary
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedDate != null
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: _selectedDate != null
                                    ? Colors.white
                                    : Colors.grey.shade600,
                              ),
                              if (_selectedDate != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat('MMM dd').format(_selectedDate!),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedDate = null;
                                    });
                                  },
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Search Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: TextField(
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search transactions...',
                        hintStyle: GoogleFonts.inter(
                          color: Colors.grey.shade400,
                        ),
                        border: InputBorder.none,
                        icon: Icon(Icons.search, color: Colors.grey.shade400),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Filters Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Type Filter
                        _buildFilterChip(
                          label: _selectedType,
                          icon: Icons.filter_list,
                          isSelected: _selectedType != 'All',
                          onTap: () {
                            _showTypeFilterDialog(context);
                          },
                        ),
                        const SizedBox(width: 8),

                        // Sort Filter
                        _buildFilterChip(
                          label: _sortOption,
                          icon: Icons.sort,
                          isSelected: _sortOption != 'Date',
                          onTap: () {
                            _showSortFilterDialog(context);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filteredTransactions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 80,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _selectedDate != null
                                ? 'No transactions on this date'
                                : 'No transaction history',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: groupedTransactions.length,
                      itemBuilder: (context, index) {
                        String date = groupedTransactions.keys.elementAt(index);
                        List<Transaction> dayTransactions =
                            groupedTransactions[date]!;

                        return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Text(
                                    date,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                                ...dayTransactions.map(
                                  (transaction) => _buildTransactionItem(
                                    context,
                                    transaction,
                                  ),
                                ),
                              ],
                            )
                            .animate()
                            .fadeIn(delay: (index * 50).ms)
                            .slideY(begin: 0.1, end: 0);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTypeFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter by Type',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildRadioOption('All', _selectedType, (val) {
                setState(() => _selectedType = val);
                Navigator.pop(context);
              }),
              _buildRadioOption('Income', _selectedType, (val) {
                setState(() => _selectedType = val);
                Navigator.pop(context);
              }),
              _buildRadioOption('Expense', _selectedType, (val) {
                setState(() => _selectedType = val);
                Navigator.pop(context);
              }),
            ],
          ),
        );
      },
    );
  }

  void _showSortFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sort By',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildRadioOption('Date', _sortOption, (val) {
                setState(() => _sortOption = val);
                Navigator.pop(context);
              }),
              _buildRadioOption('Amount High', _sortOption, (val) {
                setState(() => _sortOption = val);
                Navigator.pop(context);
              }),
              _buildRadioOption('Amount Low', _sortOption, (val) {
                setState(() => _sortOption = val);
                Navigator.pop(context);
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRadioOption(
    String value,
    String groupValue,
    Function(String) onChanged,
  ) {
    return RadioListTile<String>(
      value: value,
      groupValue: groupValue,
      onChanged: (val) {
        if (val != null) onChanged(val);
      },
      title: Text(value, style: GoogleFonts.inter()),
      activeColor: Theme.of(context).colorScheme.primary,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildTransactionItem(BuildContext context, Transaction transaction) {
    final isExpense = transaction.isExpense;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isExpense
                  ? const Color(0xFFFFE5E5)
                  : const Color(0xFFE5F5E9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isExpense ? Icons.arrow_outward : Icons.arrow_downward,
              color: isExpense
                  ? const Color(0xFFFF6B6B)
                  : const Color(0xFF51CF66),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('h:mm a').format(transaction.dateTime),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isExpense ? '-' : '+'}${widget.currencySymbol}${NumberFormat('#,##0.00').format(transaction.amount)}',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isExpense
                  ? const Color(0xFFFF6B6B)
                  : const Color(0xFF51CF66),
            ),
          ),
        ],
      ),
    );
  }
}
