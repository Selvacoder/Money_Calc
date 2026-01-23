import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/transaction.dart';
import '../widgets/transaction_details_dialog.dart';
import '../services/export_service.dart';

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

  // --- Export Feature ---
  void _showExportDialog() {
    String selectedRange = 'Monthly';
    bool isPdf = true;
    DateTime? customStartDate;
    DateTime? customEndDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
              'Export History',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Time Period',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedRange,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  items:
                      [
                            'Daily',
                            'Weekly',
                            'Monthly',
                            'Quarterly',
                            'Yearly',
                            'Custom',
                          ]
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                  onChanged: (val) => setState(() => selectedRange = val!),
                ),
                if (selectedRange == 'Custom') ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: customStartDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => customStartDate = picked);
                            }
                          },
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(
                            customStartDate == null
                                ? 'Start Date'
                                : DateFormat('MMM dd').format(customStartDate!),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: customEndDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => customEndDate = picked);
                            }
                          },
                          icon: const Icon(Icons.event, size: 16),
                          label: Text(
                            customEndDate == null
                                ? 'End Date'
                                : DateFormat('MMM dd').format(customEndDate!),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'Format',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilterChip(
                        label: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.picture_as_pdf, size: 16),
                            SizedBox(width: 8),
                            Text('PDF'),
                          ],
                        ),
                        selected: isPdf,
                        onSelected: (val) => setState(() => isPdf = true),
                        showCheckmark: false,
                        selectedColor: Colors.red.withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: isPdf ? Colors.red : Colors.grey[700],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilterChip(
                        label: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.table_chart, size: 16),
                            SizedBox(width: 8),
                            Text('Excel/CSV'),
                          ],
                        ),
                        selected: !isPdf,
                        onSelected: (val) => setState(() => isPdf = false),
                        showCheckmark: false,
                        selectedColor: Colors.green.withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: !isPdf ? Colors.green : Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _generateExport(
                    selectedRange,
                    isPdf,
                    customStartDate,
                    customEndDate,
                  );
                },
                child: const Text('Export'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _generateExport(
    String range,
    bool isPdf,
    DateTime? customStart,
    DateTime? customEnd,
  ) async {
    final now = DateTime.now();
    DateTime start;
    DateTime end = now;

    // Filter Logic
    switch (range) {
      case 'Daily':
        start = DateTime(now.year, now.month, now.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'Weekly':
        start = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(start.year, start.month, start.day); // Start of week
        break;
      case 'Monthly':
        start = DateTime(now.year, now.month, 1);
        break;
      case 'Quarterly':
        int quarter = ((now.month - 1) / 3).floor();
        start = DateTime(now.year, quarter * 3 + 1, 1);
        break;
      case 'Yearly':
        start = DateTime(now.year, 1, 1);
        break;
      case 'Custom':
        start = customStart ?? DateTime(now.year, now.month, 1);
        end = customEnd != null
            ? DateTime(
                customEnd.year,
                customEnd.month,
                customEnd.day,
                23,
                59,
                59,
              )
            : DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      default:
        start = DateTime(now.year, now.month, 1);
    }

    final exportTransactions = widget.transactions.where((t) {
      return t.dateTime.isAfter(start.subtract(const Duration(seconds: 1))) &&
          t.dateTime.isBefore(end.add(const Duration(seconds: 1)));
    }).toList();

    if (exportTransactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No transactions to export for this period.'),
        ),
      );
      return;
    }

    // Call Service
    final title =
        '$range Report (${DateFormat('MMM d').format(start)}${range == 'Daily' ? '' : ' - ${DateFormat('MMM d').format(end)}'})';

    try {
      if (isPdf) {
        await ExportService().generatePdf(
          exportTransactions,
          title,
          widget.currencySymbol,
        );
      } else {
        await ExportService().generateCsv(
          exportTransactions,
          title,
          widget.currencySymbol,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
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
                      Row(
                        children: [
                          InkWell(
                            onTap: _showExportDialog,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Icon(
                                Icons.download,
                                size: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
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
                                      DateFormat(
                                        'MMM dd',
                                      ).format(_selectedDate!),
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
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => TransactionDetailsDialog(
              transaction: transaction,
              currencySymbol: widget.currencySymbol,
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
        ),
      ),
    );
  }
}
