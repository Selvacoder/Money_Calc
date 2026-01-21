import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

import '../providers/transaction_provider.dart';
import '../providers/currency_provider.dart';
import '../models/category.dart';
import '../models/transaction.dart';

class PersonalGraphScreen extends StatefulWidget {
  const PersonalGraphScreen({super.key});

  @override
  State<PersonalGraphScreen> createState() => _PersonalGraphScreenState();
}

class _PersonalGraphScreenState extends State<PersonalGraphScreen> {
  String _selectedPeriod = 'W'; // D, W, M, Y, All

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<TransactionProvider>();
    final currencySymbol = context.watch<CurrencyProvider>().currencySymbol;

    final transactions = _getFilteredTransactions(provider.transactions);
    final totalTransactions = transactions.length;
    final incomeTransactions = transactions.where((t) => !t.isExpense).toList();
    final expenseTransactions = transactions.where((t) => t.isExpense).toList();

    final totalIncome = incomeTransactions.fold(
      0.0,
      (sum, t) => sum + t.amount,
    );
    final totalExpense = expenseTransactions.fold(
      0.0,
      (sum, t) => sum + t.amount,
    );
    final average = totalTransactions > 0
        ? (totalIncome + totalExpense) / totalTransactions
        : 0.0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                'Statistics',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 24),

              // Income vs Expenses Card
              _buildIncomeExpenseCard(
                theme,
                currencySymbol,
                totalIncome,
                totalExpense,
              ),
              const SizedBox(height: 24),

              // Stat Cards Grid
              _buildStatCards(
                theme,
                currencySymbol,
                totalTransactions,
                average,
                incomeTransactions.length,
                expenseTransactions.length,
              ),
              const SizedBox(height: 24),

              // Spending Trend
              _buildSpendingTrend(theme, currencySymbol, provider.transactions),
              const SizedBox(height: 24),

              // Top Expenses
              _buildTopExpenses(theme, currencySymbol, provider),
              const SizedBox(height: 24),

              // Spending Insights Card
              _buildSpendingInsights(
                theme,
                currencySymbol,
                expenseTransactions,
                provider.categories,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Transaction> _getFilteredTransactions(List<Transaction> transactions) {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'D':
        return transactions
            .where(
              (t) =>
                  t.dateTime.year == now.year &&
                  t.dateTime.month == now.month &&
                  t.dateTime.day == now.day,
            )
            .toList();
      case 'W':
        final weekAgo = now.subtract(const Duration(days: 7));
        return transactions.where((t) => t.dateTime.isAfter(weekAgo)).toList();
      case 'M':
        return transactions
            .where(
              (t) =>
                  t.dateTime.year == now.year && t.dateTime.month == now.month,
            )
            .toList();
      case 'Y':
        return transactions.where((t) => t.dateTime.year == now.year).toList();
      case 'All':
      default:
        return transactions;
    }
  }

  Widget _buildIncomeExpenseCard(
    ThemeData theme,
    String currency,
    double income,
    double expense,
  ) {
    final total = income + expense;
    final incomePercent = total > 0 ? (income / total) * 100 : 0.0;
    final expensePercent = total > 0 ? (expense / total) * 100 : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
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
          const SizedBox(height: 20),
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
                      '$currency${income.toStringAsFixed(0)}',
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
                      '$currency${expense.toStringAsFixed(0)}',
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
        ],
      ),
    );
  }

  Widget _buildStatCards(
    ThemeData theme,
    String currency,
    int total,
    double avg,
    int incomeCount,
    int expenseCount,
  ) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.3,
      children: [
        _buildStatCard(
          theme,
          'Total Transactions',
          total.toString(),
          Icons.receipt_long,
          theme.colorScheme.primary,
        ),
        _buildStatCard(
          theme,
          'Average',
          '$currency${avg.toStringAsFixed(0)}',
          Icons.trending_up,
          Colors.red,
        ),
        _buildStatCard(
          theme,
          'Income Count',
          incomeCount.toString(),
          Icons.add_circle,
          Colors.green,
        ),
        _buildStatCard(
          theme,
          'Expense Count',
          expenseCount.toString(),
          Icons.remove_circle,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
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
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onBackground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpendingTrend(
    ThemeData theme,
    String currency,
    List<Transaction> allTransactions,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
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
            children: [
              Text(
                'Trend',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onBackground,
                ),
              ),
              _buildPeriodSelector(theme),
            ],
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: SizedBox(
              height: 180, // Increased height to prevent overflow
              child: _buildBarChart(theme, allTransactions),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(ThemeData theme) {
    final periods = ['D', 'W', 'M', 'Y', 'All'];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: periods.map((period) {
        final isSelected = period == _selectedPeriod;
        return GestureDetector(
          onTap: () => setState(() => _selectedPeriod = period),
          child: Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              period,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBarChart(ThemeData theme, List<Transaction> allTransactions) {
    final now = DateTime.now();
    Map<String, double> data = {};

    // Get filtered expenses
    final expenses = _getFilteredTransactions(
      allTransactions,
    ).where((t) => t.isExpense);

    // Build data based on period
    if (_selectedPeriod == 'W') {
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final key = DateFormat('E').format(date);
        data[key] = 0;
      }
      for (var t in expenses) {
        final key = DateFormat('E').format(t.dateTime);
        if (data.containsKey(key)) {
          data[key] = data[key]! + t.amount;
        }
      }
    } else if (_selectedPeriod == 'D') {
      for (int hour = 0; hour < 24; hour += 4) {
        data['${hour}h'] = 0;
      }
      for (var t in expenses) {
        final hour = (t.dateTime.hour ~/ 4) * 4;
        final key = '${hour}h';
        if (data.containsKey(key)) {
          data[key] = data[key]! + t.amount;
        }
      }
    } else if (_selectedPeriod == 'M') {
      // Monthly View - Show Weeks 1-5
      for (int i = 1; i <= 5; i++) {
        data['W$i'] = 0;
      }
      for (var t in expenses) {
        // Calculate week number (1-5 approximations)
        // Simple approximation: (day / 7).ceil()
        final day = t.dateTime.day;
        final week = (day / 7).ceil();
        final key = 'W${week > 5 ? 5 : week}'; // Handle 31st day edge case
        if (data.containsKey(key)) {
          data[key] = data[key]! + t.amount;
        }
      }
    } else {
      data = {'No': 0, 'Data': 0};
    }

    final maxAmount = data.values.isEmpty ? 1.0 : data.values.reduce(math.max);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: data.entries.map((entry) {
        final height = maxAmount > 0 ? (entry.value / maxAmount) * 100 : 0.0;
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 32,
              height: height,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              entry.key,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildTopExpenses(
    ThemeData theme,
    String currency,
    TransactionProvider provider,
  ) {
    final expenses = provider.transactions.where((t) => t.isExpense).toList();

    // Group by category
    Map<String, double> categoryTotals = {};
    for (var t in expenses) {
      if (t.categoryId != null) {
        categoryTotals[t.categoryId!] =
            (categoryTotals[t.categoryId] ?? 0) + t.amount;
      }
    }

    // Sort and take top 3
    final sorted = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3 = sorted.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
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
              color: theme.colorScheme.onBackground,
            ),
          ),
          const SizedBox(height: 16),
          if (top3.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No expense data available',
                  style: GoogleFonts.inter(color: Colors.grey.shade400),
                ),
              ),
            )
          else
            ...top3.map((entry) {
              final category = provider.categories.firstWhere(
                (c) => c.id == entry.key,
                orElse: () => provider.categories.first,
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.category,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        category.name,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '$currency${entry.value.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildSpendingInsights(
    ThemeData theme,
    String currency,
    List<Transaction> expenses,
    List<Category> categories,
  ) {
    final thisMonth = expenses.where((t) {
      final now = DateTime.now();
      return t.dateTime.year == now.year && t.dateTime.month == now.month;
    }).toList();

    final monthTotal = thisMonth.fold(0.0, (sum, t) => sum + t.amount);
    final avgDaily = thisMonth.isEmpty ? 0.0 : monthTotal / DateTime.now().day;
    final avgPerTransaction = thisMonth.isEmpty
        ? 0.0
        : monthTotal / thisMonth.length;

    // Find highest and lowest spending days
    Map<String, double> dailyTotals = {};
    for (var t in thisMonth) {
      final key = DateFormat('yyyy-MM-dd').format(t.dateTime);
      dailyTotals[key] = (dailyTotals[key] ?? 0) + t.amount;
    }

    final sortedDays = dailyTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final highestDay = sortedDays.isNotEmpty
        ? DateFormat('EEE').format(DateTime.parse(sortedDays.first.key))
        : 'N/A';
    final highestAmount = sortedDays.isNotEmpty ? sortedDays.first.value : 0.0;
    final lowestDay = sortedDays.isNotEmpty
        ? DateFormat('EEE').format(DateTime.parse(sortedDays.last.key))
        : 'N/A';
    final lowestAmount = sortedDays.isNotEmpty ? sortedDays.last.value : 0.0;

    // Most spent category
    Map<String, double> categoryTotals = {};
    for (var t in thisMonth) {
      if (t.categoryId != null) {
        categoryTotals[t.categoryId!] =
            (categoryTotals[t.categoryId] ?? 0) + t.amount;
      }
    }
    final topCategory = categoryTotals.entries.isEmpty
        ? null
        : categoryTotals.entries.reduce((a, b) => a.value > b.value ? a : b);

    String topCategoryName = 'N/A';
    if (topCategory != null && categories.isNotEmpty) {
      final found = categories.firstWhere(
        (c) => c.id == topCategory.key,
        orElse: () => categories.first,
      );
      topCategoryName = found.name;
    }

    final topCategoryTotal = topCategory?.value ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(0.8),
            theme.colorScheme.primary,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, color: Colors.white, size: 24),
              const SizedBox(width: 8),
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
          const SizedBox(height: 16),
          _buildInsightRow(
            'This Month Total',
            monthTotal > 0
                ? '$currency${monthTotal.toStringAsFixed(0)}'
                : 'N/A',
          ),
          _buildInsightRow(
            'Average Daily Spend',
            '$currency${avgDaily.toStringAsFixed(0)}',
          ),
          _buildInsightRow(
            'Average Per Transaction',
            avgPerTransaction > 0
                ? '$currency${avgPerTransaction.toStringAsFixed(0)}'
                : 'N/A',
          ),
          _buildInsightRow('Total Transactions', thisMonth.length.toString()),
          _buildInsightRow('Highest Spending Day', highestDay),
          _buildInsightRow(
            'Amount on Highest Day',
            highestAmount > 0
                ? '$currency${highestAmount.toStringAsFixed(0)}'
                : 'N/A',
          ),
          _buildInsightRow('Lowest Spending Day', lowestDay),
          _buildInsightRow(
            'Amount on Lowest Day',
            lowestAmount > 0
                ? '$currency${lowestAmount.toStringAsFixed(0)}'
                : 'N/A',
          ),
          _buildInsightRow('Most Spent Category', topCategoryName),
          _buildInsightRow(
            'Category Total',
            topCategoryTotal > 0
                ? '$currency${topCategoryTotal.toStringAsFixed(0)}'
                : 'N/A',
          ),
        ],
      ),
    );
  }

  Widget _buildInsightRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 14, color: Colors.white70),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
