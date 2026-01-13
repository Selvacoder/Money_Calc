import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math' as math;
import '../models/transaction.dart';

class GraphScreen extends StatefulWidget {
  final List<Transaction> transactions;
  final double totalIncome;
  final double totalExpenses;

  const GraphScreen({
    super.key,
    required this.transactions,
    required this.totalIncome,
    required this.totalExpenses,
  });

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  String _balanceDistributionPeriod = 'All Time';
  String _spendingTrendPeriod = 'Weekly';
  final ScrollController _scrollController = ScrollController();

  final List<String> _periods = [
    'Daily',
    'Weekly',
    'Monthly',
    'Yearly',
    'All Time',
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToLastTransaction() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Wait a bit for the UI to rebuild with new period data
      await Future.delayed(const Duration(milliseconds: 100));

      if (!_scrollController.hasClients) return;

      // Recalculate period data based on current selection
      var filteredTransactions = _getFilteredTransactions(_spendingTrendPeriod);
      Map<String, double> periodData = {};
      DateTime now = DateTime.now();

      if (_spendingTrendPeriod == 'Daily') {
        for (int hour = 0; hour < 24; hour++) {
          String hourKey = '${hour.toString().padLeft(2, '0')}:00';
          periodData[hourKey] = 0;
        }
        for (var transaction in filteredTransactions.where(
          (t) => t.isExpense,
        )) {
          if (transaction.dateTime.day == now.day) {
            String hourKey =
                '${transaction.dateTime.hour.toString().padLeft(2, '0')}:00';
            if (periodData.containsKey(hourKey)) {
              periodData[hourKey] = periodData[hourKey]! + transaction.amount;
            }
          }
        }
      } else if (_spendingTrendPeriod == 'Weekly') {
        for (int i = 6; i >= 0; i--) {
          DateTime date = now.subtract(Duration(days: i));
          String dateKey = DateFormat('EEE').format(date);
          periodData[dateKey] = 0;
        }
        for (var transaction in filteredTransactions.where(
          (t) => t.isExpense,
        )) {
          String dayKey = DateFormat('EEE').format(transaction.dateTime);
          if (periodData.containsKey(dayKey)) {
            periodData[dayKey] = periodData[dayKey]! + transaction.amount;
          }
        }
      } else if (_spendingTrendPeriod == 'Yearly') {
        for (int month = 1; month <= 12; month++) {
          DateTime monthDate = DateTime(now.year, month, 1);
          String monthKey = DateFormat('MMM').format(monthDate);
          periodData[monthKey] = 0;
        }
        for (var transaction in filteredTransactions.where(
          (t) => t.isExpense,
        )) {
          if (transaction.dateTime.year == now.year) {
            String monthKey = DateFormat('MMM').format(transaction.dateTime);
            if (periodData.containsKey(monthKey)) {
              periodData[monthKey] = periodData[monthKey]! + transaction.amount;
            }
          }
        }
      } else if (_spendingTrendPeriod == 'All Time') {
        for (var transaction in filteredTransactions.where(
          (t) => t.isExpense,
        )) {
          String monthKey = DateFormat('MMM yy').format(transaction.dateTime);
          periodData[monthKey] =
              (periodData[monthKey] ?? 0) + transaction.amount;
        }
      }

      if (periodData.isEmpty) return;

      // Find the last non-zero entry
      var entries = periodData.entries.toList();
      int lastNonZeroIndex = -1;

      for (int i = entries.length - 1; i >= 0; i--) {
        if (entries[i].value > 0) {
          lastNonZeroIndex = i;
          break;
        }
      }

      if (lastNonZeroIndex >= 0) {
        // Each bar is approximately 44 pixels wide (32px width + 12px margin)
        double barWidth = 44.0;

        // Scroll to show the transaction bar with some context before it
        double scrollPosition =
            (lastNonZeroIndex - 2).clamp(0, entries.length - 1).toDouble() *
            barWidth;

        // Ensure we don't scroll past the maximum
        double maxScroll = _scrollController.position.maxScrollExtent;
        double targetScroll = scrollPosition.clamp(0, maxScroll);

        _scrollController.animateTo(
          targetScroll,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  List<Transaction> _getFilteredTransactions(String period) {
    DateTime now = DateTime.now();

    switch (period) {
      case 'Daily':
        return widget.transactions.where((t) {
          return t.dateTime.year == now.year &&
              t.dateTime.month == now.month &&
              t.dateTime.day == now.day;
        }).toList();
      case 'Weekly':
        DateTime weekAgo = now.subtract(const Duration(days: 7));
        return widget.transactions
            .where((t) => t.dateTime.isAfter(weekAgo))
            .toList();
      case 'Monthly':
        return widget.transactions.where((t) {
          return t.dateTime.year == now.year && t.dateTime.month == now.month;
        }).toList();
      case 'Yearly':
        return widget.transactions
            .where((t) => t.dateTime.year == now.year)
            .toList();
      case 'All Time':
      default:
        return widget.transactions;
    }
  }

  double _getTotalIncome(List<Transaction> transactions) {
    return transactions
        .where((t) => !t.isExpense)
        .fold(0, (sum, t) => sum + t.amount);
  }

  double _getTotalExpenses(List<Transaction> transactions) {
    return transactions
        .where((t) => t.isExpense)
        .fold(0, (sum, t) => sum + t.amount);
  }

  Widget _buildPeriodChips(
    String currentPeriod,
    Function(String) onPeriodChanged,
  ) {
    Map<String, String> periodLabels = {
      'Daily': 'D',
      'Weekly': 'W',
      'Monthly': 'M',
      'Yearly': 'Y',
      'All Time': 'All',
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: _periods.map((period) {
        bool isSelected = period == currentPeriod;
        return GestureDetector(
          onTap: () => onPeriodChanged(period),
          child: Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              periodLabels[period]!,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Statistics',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 24),

              // Income vs Expense Chart
              _buildIncomeExpenseChart().animate().fadeIn().slideY(
                begin: 0.1,
                end: 0,
              ),

              const SizedBox(height: 20),

              // Pie Chart with Period Filter
              _buildPieChart(
                context,
              ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.1, end: 0),

              const SizedBox(height: 20),

              // Statistics Cards
              _buildStatisticsCards()
                  .animate()
                  .fadeIn(delay: 100.ms)
                  .slideY(begin: 0.1, end: 0),

              const SizedBox(height: 20),

              // Spending Trend with Period Filter
              _buildSpendingTrend()
                  .animate()
                  .fadeIn(delay: 150.ms)
                  .slideY(begin: 0.1, end: 0),

              const SizedBox(height: 20),

              // Category Breakdown
              _buildCategoryBreakdown()
                  .animate()
                  .fadeIn(delay: 200.ms)
                  .slideY(begin: 0.1, end: 0),

              const SizedBox(height: 20),

              // Spending Pattern
              _buildSpendingPattern()
                  .animate()
                  .fadeIn(delay: 250.ms)
                  .slideY(begin: 0.1, end: 0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIncomeExpenseChart() {
    double total = widget.totalIncome + widget.totalExpenses;
    double incomePercent = total > 0 ? (widget.totalIncome / total) * 100 : 0;
    double expensePercent = total > 0
        ? (widget.totalExpenses / total) * 100
        : 0;

    return Container(
      padding: const EdgeInsets.all(24),
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
        children: [
          Text(
            'Income vs Expenses',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${incomePercent.toStringAsFixed(1)}%',
                      style: GoogleFonts.inter(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Income',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${NumberFormat('#,##0').format(widget.totalIncome)}',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 80,
                color: Colors.white.withOpacity(0.3),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${expensePercent.toStringAsFixed(1)}%',
                      style: GoogleFonts.inter(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Expenses',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${NumberFormat('#,##0').format(widget.totalExpenses)}',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                if (incomePercent > 0)
                  Expanded(
                    flex: incomePercent.toInt(),
                    child: Container(
                      height: 12,
                      color: const Color(0xFF51CF66),
                    ),
                  ),
                if (expensePercent > 0)
                  Expanded(
                    flex: expensePercent.toInt(),
                    child: Container(
                      height: 12,
                      color: const Color(0xFFFF6B6B),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(BuildContext context) {
    var filteredTransactions = _getFilteredTransactions(
      _balanceDistributionPeriod,
    );
    double income = _getTotalIncome(filteredTransactions);
    double expenses = _getTotalExpenses(filteredTransactions);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Balance',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              _buildPeriodChips(_balanceDistributionPeriod, (period) {
                setState(() {
                  _balanceDistributionPeriod = period;
                });
              }),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: CustomPaint(
                painter: PieChartPainter(income: income, expenses: expenses),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLegendItem('Income', const Color(0xFF51CF66), income),
              _buildLegendItem('Expenses', const Color(0xFFFF6B6B), expenses),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, double amount) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            Text(
              '₹${NumberFormat('#,##0').format(amount)}',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E1E1E),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatisticsCards() {
    int transactionCount = widget.transactions.length;
    double avgTransaction = transactionCount > 0
        ? (widget.totalIncome - widget.totalExpenses) / transactionCount
        : 0;

    int incomeCount = widget.transactions.where((t) => !t.isExpense).length;
    int expenseCount = widget.transactions.where((t) => t.isExpense).length;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Transactions',
                transactionCount.toString(),
                Icons.receipt_long,
                const Color(0xFF5B5FED),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Average',
                '₹${NumberFormat('#,##0').format(avgTransaction)}',
                Icons.trending_up,
                const Color(0xFFFF6B6B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Income Count',
                incomeCount.toString(),
                Icons.add_circle,
                const Color(0xFF51CF66),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Expense Count',
                expenseCount.toString(),
                Icons.remove_circle,
                const Color(0xFFFF9800),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E1E1E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpendingTrend() {
    var filteredTransactions = _getFilteredTransactions(_spendingTrendPeriod);
    Map<String, double> periodData = {};
    DateTime now = DateTime.now();

    // Calculate data based on period
    if (_spendingTrendPeriod == 'Daily') {
      // 24 hours from 00:00 to 23:00
      for (int hour = 0; hour < 24; hour++) {
        String hourKey = '${hour.toString().padLeft(2, '0')}:00';
        periodData[hourKey] = 0;
      }

      for (var transaction in filteredTransactions.where((t) => t.isExpense)) {
        if (transaction.dateTime.day == now.day) {
          String hourKey =
              '${transaction.dateTime.hour.toString().padLeft(2, '0')}:00';
          if (periodData.containsKey(hourKey)) {
            periodData[hourKey] = periodData[hourKey]! + transaction.amount;
          }
        }
      }
    } else if (_spendingTrendPeriod == 'Weekly') {
      // Last 7 days
      for (int i = 6; i >= 0; i--) {
        DateTime date = now.subtract(Duration(days: i));
        String dateKey = DateFormat('EEE').format(date);
        periodData[dateKey] = 0;
      }

      for (var transaction in filteredTransactions.where((t) => t.isExpense)) {
        String dayKey = DateFormat('EEE').format(transaction.dateTime);
        if (periodData.containsKey(dayKey)) {
          periodData[dayKey] = periodData[dayKey]! + transaction.amount;
        }
      }
    } else if (_spendingTrendPeriod == 'Monthly') {
      // Last 4 weeks
      for (int i = 3; i >= 0; i--) {
        periodData['Week ${4 - i}'] = 0;
      }

      for (var transaction in filteredTransactions.where((t) => t.isExpense)) {
        int weekOfMonth = ((transaction.dateTime.day - 1) / 7).floor();
        String weekKey = 'Week ${weekOfMonth + 1}';
        periodData[weekKey] = (periodData[weekKey] ?? 0) + transaction.amount;
      }
    } else if (_spendingTrendPeriod == 'Yearly') {
      // All 12 months
      for (int month = 1; month <= 12; month++) {
        DateTime monthDate = DateTime(now.year, month, 1);
        String monthKey = DateFormat('MMM').format(monthDate);
        periodData[monthKey] = 0;
      }

      for (var transaction in filteredTransactions.where((t) => t.isExpense)) {
        if (transaction.dateTime.year == now.year) {
          String monthKey = DateFormat('MMM').format(transaction.dateTime);
          if (periodData.containsKey(monthKey)) {
            periodData[monthKey] = periodData[monthKey]! + transaction.amount;
          }
        }
      }
    } else {
      // All Time - all transactions from the beginning
      for (var transaction in filteredTransactions.where((t) => t.isExpense)) {
        String monthKey = DateFormat('MMM yy').format(transaction.dateTime);
        periodData[monthKey] = (periodData[monthKey] ?? 0) + transaction.amount;
      }
    }

    double maxAmount = periodData.values.isEmpty
        ? 1
        : periodData.values.reduce(math.max);
    if (maxAmount == 0) maxAmount = 1;

    bool isScrollable =
        _spendingTrendPeriod == 'Daily' ||
        _spendingTrendPeriod == 'Weekly' ||
        _spendingTrendPeriod == 'Yearly' ||
        _spendingTrendPeriod == 'All Time';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Spending Trend',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              _buildPeriodChips(_spendingTrendPeriod, (period) {
                setState(() {
                  _spendingTrendPeriod = period;
                });
                // Scroll to last transaction position
                if (period == 'Daily' ||
                    period == 'Weekly' ||
                    period == 'Yearly' ||
                    period == 'All Time') {
                  _scrollToLastTransaction();
                }
              }),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: periodData.isEmpty
                ? Center(
                    child: Text(
                      'No data for this period',
                      style: GoogleFonts.inter(color: Colors.grey.shade500),
                    ),
                  )
                : isScrollable
                ? SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: periodData.entries.map((entry) {
                        return _buildBarChart(entry, maxAmount);
                      }).toList(),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: periodData.entries.map((entry) {
                      return _buildBarChart(entry, maxAmount);
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(MapEntry<String, double> entry, double maxAmount) {
    double heightPercent = entry.value / maxAmount;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (entry.value > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '₹${entry.value.toInt()}',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            const SizedBox(height: 18),
          Container(
            width: 32,
            height: (heightPercent * 100).clamp(4.0, 100.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: const BorderRadius.all(Radius.circular(8)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 40,
            child: Text(
              entry.key,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown() {
    Map<String, int> categoryCounts = {};
    Map<String, double> categoryAmounts = {};

    for (var transaction in widget.transactions.where((t) => t.isExpense)) {
      categoryCounts[transaction.title] =
          (categoryCounts[transaction.title] ?? 0) + 1;
      categoryAmounts[transaction.title] =
          (categoryAmounts[transaction.title] ?? 0) + transaction.amount;
    }

    var sortedCategories = categoryAmounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Expenses',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E1E1E),
            ),
          ),
          const SizedBox(height: 16),
          if (sortedCategories.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No expense data available',
                  style: GoogleFonts.inter(color: Colors.grey.shade500),
                ),
              ),
            )
          else
            ...sortedCategories.take(5).map((entry) {
              double percentage = widget.totalExpenses > 0
                  ? (entry.value / widget.totalExpenses) * 100
                  : 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '${percentage.toStringAsFixed(1)}%',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '₹${NumberFormat('#,##0').format(entry.value)}',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFFF6B6B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFFFF6B6B),
                        ),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSpendingPattern() {
    double avgDaily = 0;
    double highestDay = 0;
    String highestDayName = '';
    double lowestDay = 0;
    String lowestDayName = '';
    double totalThisMonth = 0;
    String mostSpentCategory = '';
    double mostSpentAmount = 0;
    int totalTransactions = 0;
    double avgPerTransaction = 0;

    if (widget.transactions.isNotEmpty) {
      DateTime now = DateTime.now();
      Map<String, double> dailyTotals = {};
      Map<String, double> categoryTotals = {};

      // Calculate daily totals
      for (var transaction in widget.transactions.where((t) => t.isExpense)) {
        String day = DateFormat('EEEE').format(transaction.dateTime);
        dailyTotals[day] = (dailyTotals[day] ?? 0) + transaction.amount;

        // Calculate category totals
        categoryTotals[transaction.title] =
            (categoryTotals[transaction.title] ?? 0) + transaction.amount;

        // Calculate this month's total
        if (transaction.dateTime.year == now.year &&
            transaction.dateTime.month == now.month) {
          totalThisMonth += transaction.amount;
        }

        totalTransactions++;
      }

      if (dailyTotals.isNotEmpty) {
        avgDaily =
            dailyTotals.values.reduce((a, b) => a + b) / dailyTotals.length;

        var maxEntry = dailyTotals.entries.reduce(
          (a, b) => a.value > b.value ? a : b,
        );
        highestDay = maxEntry.value;
        highestDayName = maxEntry.key;

        var minEntry = dailyTotals.entries.reduce(
          (a, b) => a.value < b.value ? a : b,
        );
        lowestDay = minEntry.value;
        lowestDayName = minEntry.key;
      }

      // Find most spent category
      if (categoryTotals.isNotEmpty) {
        var maxCategory = categoryTotals.entries.reduce(
          (a, b) => a.value > b.value ? a : b,
        );
        mostSpentCategory = maxCategory.key;
        mostSpentAmount = maxCategory.value;
      }

      // Calculate average per transaction
      if (totalTransactions > 0) {
        avgPerTransaction = widget.totalExpenses / totalTransactions;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Text(
                'Spending Insights',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInsightRow(
            'This Month Total',
            totalThisMonth > 0
                ? '₹${NumberFormat('#,##0').format(totalThisMonth)}'
                : 'N/A',
          ),
          const SizedBox(height: 10),
          _buildInsightRow(
            'Average Daily Spend',
            '₹${NumberFormat('#,##0').format(avgDaily)}',
          ),
          const SizedBox(height: 10),
          _buildInsightRow(
            'Average Per Transaction',
            avgPerTransaction > 0
                ? '₹${NumberFormat('#,##0').format(avgPerTransaction)}'
                : 'N/A',
          ),
          const SizedBox(height: 10),
          _buildInsightRow('Total Transactions', totalTransactions.toString()),
          const SizedBox(height: 10),
          _buildInsightRow(
            'Highest Spending Day',
            highestDayName.isEmpty ? 'N/A' : highestDayName,
          ),
          const SizedBox(height: 10),
          _buildInsightRow(
            'Amount on Highest Day',
            highestDay > 0
                ? '₹${NumberFormat('#,##0').format(highestDay)}'
                : 'N/A',
          ),
          const SizedBox(height: 10),
          _buildInsightRow(
            'Lowest Spending Day',
            lowestDayName.isEmpty ? 'N/A' : lowestDayName,
          ),
          const SizedBox(height: 10),
          _buildInsightRow(
            'Amount on Lowest Day',
            lowestDay > 0
                ? '₹${NumberFormat('#,##0').format(lowestDay)}'
                : 'N/A',
          ),
          const SizedBox(height: 10),
          _buildInsightRow(
            'Most Spent Category',
            mostSpentCategory.isEmpty ? 'N/A' : mostSpentCategory,
          ),
          const SizedBox(height: 10),
          _buildInsightRow(
            'Category Total',
            mostSpentAmount > 0
                ? '₹${NumberFormat('#,##0').format(mostSpentAmount)}'
                : 'N/A',
          ),
        ],
      ),
    );
  }

  Widget _buildInsightRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 14, color: Colors.white70),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

// Custom Pie Chart Painter
class PieChartPainter extends CustomPainter {
  final double income;
  final double expenses;

  PieChartPainter({required this.income, required this.expenses});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final total = income + expenses;

    if (total == 0) {
      // Draw empty circle
      final paint = Paint()
        ..color = Colors.grey.shade300
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, paint);
      return;
    }

    // Calculate angles
    final incomeAngle = (income / total) * 2 * math.pi;
    final expenseAngle = (expenses / total) * 2 * math.pi;

    // Draw income arc
    final incomePaint = Paint()
      ..color = const Color(0xFF51CF66)
      ..style = PaintingStyle.fill;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      incomeAngle,
      true,
      incomePaint,
    );

    // Draw expense arc
    final expensePaint = Paint()
      ..color = const Color(0xFFFF6B6B)
      ..style = PaintingStyle.fill;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2 + incomeAngle,
      expenseAngle,
      true,
      expensePaint,
    );

    // Draw white center circle
    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.5, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
