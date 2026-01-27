import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/investment_provider.dart';
import '../providers/currency_provider.dart';
import '../models/investment_transaction.dart';
import '../services/export_service.dart';

class InvestmentHistoryScreen extends StatefulWidget {
  const InvestmentHistoryScreen({super.key});

  @override
  State<InvestmentHistoryScreen> createState() =>
      _InvestmentHistoryScreenState();
}

class _InvestmentHistoryScreenState extends State<InvestmentHistoryScreen> {
  DateTime? _selectedDate;
  String _searchQuery = '';
  String _selectedType = 'All'; // All, Buy, Sell
  String _sortOption = 'Date'; // Date, Amount High, Amount Low

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // --- Export Feature ---
  void _showExportDialog(
    List<InvestmentTransaction> transactions,
    Map<String, String> assetNames,
    String currencySymbol,
  ) {
    String selectedRange =
        'Yearly'; // Default to Yearly for investments usually
    bool isPdf = true;
    DateTime? customStartDate;
    DateTime? customEndDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
              'Export Investment History',
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
                  items: ['All Time', 'Month', 'Yearly', 'Custom']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
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
                    transactions,
                    assetNames,
                    currencySymbol,
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
    List<InvestmentTransaction> allTransactions,
    Map<String, String> assetNames,
    String currencySymbol,
    String range,
    bool isPdf,
    DateTime? customStart,
    DateTime? customEnd,
  ) async {
    final now = DateTime.now();
    DateTime start = DateTime(2000); // Default all time start
    DateTime end = now;

    // Filter Logic for Export Time Range
    switch (range) {
      case 'Month':
        start = DateTime(now.year, now.month, 1);
        break;
      case 'Yearly':
        start = DateTime(now.year, 1, 1);
        break;
      case 'All Time':
        start = DateTime(2000); // Far past
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
    }

    final exportTransactions = allTransactions.where((t) {
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
    final title = '$range Investment Report';

    try {
      if (isPdf) {
        await ExportService().generateInvestmentPdf(
          exportTransactions,
          title,
          currencySymbol,
          assetNames,
        );
      } else {
        await ExportService().generateInvestmentCsv(
          exportTransactions,
          title,
          currencySymbol,
          assetNames,
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
    final investmentProvider = context.watch<InvestmentProvider>();
    final currencySymbol = context.watch<CurrencyProvider>().currencySymbol;

    final allTransactions = investmentProvider.transactions;

    // Create Asset Name Map for resolving IDs
    final assetNames = {
      for (var inv in investmentProvider.investments) inv.id: inv.name,
    };

    // Filter logic
    List<InvestmentTransaction> filteredHistory = allTransactions.where((t) {
      // 1. Date Filter
      if (_selectedDate != null) {
        if (t.dateTime.year != _selectedDate!.year ||
            t.dateTime.month != _selectedDate!.month ||
            t.dateTime.day != _selectedDate!.day) {
          return false;
        }
      }

      // 2. Search Filter (Asset Name)
      if (_searchQuery.isNotEmpty) {
        final name = assetNames[t.investmentId] ?? '';
        if (!name.toLowerCase().contains(_searchQuery.toLowerCase())) {
          return false;
        }
      }

      // 3. Type Filter
      if (_selectedType == 'Buy' && t.type.toLowerCase() != 'buy') {
        return false;
      }
      if (_selectedType == 'Sell' && t.type.toLowerCase() != 'sell') {
        return false;
      }

      return true;
    }).toList();

    // Sort
    if (_sortOption == 'Amount High') {
      filteredHistory.sort((a, b) => b.amount.compareTo(a.amount));
    } else if (_sortOption == 'Amount Low') {
      filteredHistory.sort((a, b) => a.amount.compareTo(b.amount));
    } else {
      // Date default
      filteredHistory.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Row & Download
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'History',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          InkWell(
                            onTap: () => _showExportDialog(
                              allTransactions,
                              assetNames,
                              currencySymbol,
                            ),
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
                                size: 20,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
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
                              child: Icon(
                                Icons.calendar_today,
                                size: 20,
                                color: _selectedDate != null
                                    ? Colors.white
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ),
                          if (_selectedDate != null) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => setState(() => _selectedDate = null),
                              child: Icon(
                                Icons.close,
                                size: 20,
                                color: Colors.grey,
                              ),
                            ),
                          ],
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
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Search asset name...',
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
                        _buildFilterChip(
                          label: _selectedType,
                          icon: Icons.filter_list,
                          isSelected: _selectedType != 'All',
                          onTap: () => _showTypeFilterDialog(context),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: _sortOption,
                          icon: Icons.sort,
                          isSelected: _sortOption != 'Date',
                          onTap: () => _showSortFilterDialog(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: filteredHistory.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.history_outlined,
                              size: 48,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No transactions found',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: filteredHistory.length,
                      itemBuilder: (context, index) {
                        final tx = filteredHistory[index];
                        final isBuy = tx.type.toLowerCase() == 'buy';
                        final name = assetNames[tx.investmentId] ?? 'Asset';

                        return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.grey.withOpacity(0.1),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isBuy
                                        ? Colors.green.withOpacity(0.1)
                                        : Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    isBuy
                                        ? Icons.arrow_downward
                                        : Icons.arrow_upward,
                                    color: isBuy ? Colors.green : Colors.red,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  name,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      '${isBuy ? 'Bought' : 'Sold'} on ${DateFormat('MMM d, yyyy').format(tx.dateTime)}',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    if (tx.quantity != null && tx.quantity! > 0)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          'Qty: ${tx.quantity} @ ${tx.pricePerUnit != null ? currencySymbol + tx.pricePerUnit!.toStringAsFixed(2) : ""}',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: Colors.blueGrey,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${isBuy ? '+' : ''}$currencySymbol${tx.amount.toStringAsFixed(2)}',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isBuy
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
              _buildRadioOption('Buy', _selectedType, (val) {
                setState(() => _selectedType = val);
                Navigator.pop(context);
              }),
              _buildRadioOption('Sell', _selectedType, (val) {
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
}
