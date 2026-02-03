import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/investment_provider.dart';
import '../providers/currency_provider.dart';

class InvestmentDashboard extends StatefulWidget {
  const InvestmentDashboard({super.key});

  @override
  State<InvestmentDashboard> createState() => _InvestmentDashboardState();
}

class _InvestmentDashboardState extends State<InvestmentDashboard> {
  @override
  Widget build(BuildContext context) {
    final investmentProvider = context.watch<InvestmentProvider>();
    final currencySymbol = context.watch<CurrencyProvider>().currencySymbol;
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        // Main Content
        RefreshIndicator(
          onRefresh: () async {
            await investmentProvider.fetchInvestments();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Portfolio Summary Card
                _buildPortfolioCard(
                  investmentProvider,
                  currencySymbol,
                  colorScheme,
                ),
                const SizedBox(height: 24),

                Text(
                  'Your Assets',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                if (investmentProvider.isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (investmentProvider.investments.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.show_chart,
                            size: 64,
                            color: Colors.grey.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Start Investing',
                            style: GoogleFonts.inter(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: investmentProvider.investments.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final investment = investmentProvider.investments[index];
                      return _buildInvestmentItem(
                        context,
                        investment,
                        currencySymbol,
                      );
                    },
                  ),
              ],
            ),
          ),
        ),

        // FAB
        Positioned(
          bottom: 24,
          right: 24,
          child: FloatingActionButton.extended(
            onPressed: () => _showAddInvestmentDialog(context),
            backgroundColor: colorScheme.primary,
            icon: const Icon(Icons.add),
            label: const Text('Add Asset'),
          ),
        ),
      ],
    );
  }

  Widget _buildPortfolioCard(
    InvestmentProvider provider,
    String currencySymbol,
    ColorScheme colorScheme,
  ) {
    final totalInvested = provider.totalInvestedValue;
    final currentValue = provider.totalCurrentValue;
    final profitLoss = provider.totalProfitLoss;
    final isProfit = profitLoss >= 0;
    final profitLossPercent = totalInvested > 0
        ? (profitLoss / totalInvested) * 100
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.primary,
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
                Icons.account_balance,
                color: Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Portfolio Value',
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
            '$currencySymbol${currentValue.toStringAsFixed(2)}',
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
                    Text(
                      'Invested',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$currencySymbol${totalInvested.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        color: Colors.white,
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
                    Text(
                      'Profit/Loss',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          isProfit ? Icons.arrow_upward : Icons.arrow_downward,
                          color: isProfit
                              ? const Color(0xFF51CF66)
                              : const Color(0xFFFF6B6B),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$currencySymbol${profitLoss.abs().toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            color: isProfit
                                ? const Color(0xFF51CF66)
                                : const Color(0xFFFF6B6B),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${isProfit ? '+' : '-'}${profitLossPercent.abs().toStringAsFixed(2)}%',
                      style: GoogleFonts.inter(
                        color: isProfit
                            ? const Color(0xFF51CF66).withOpacity(0.8)
                            : const Color(0xFFFF6B6B).withOpacity(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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

  Widget _buildInvestmentItem(
    BuildContext context,
    dynamic investment,
    String currencySymbol,
  ) {
    // Determine Icon based on Type
    IconData icon;
    Color iconColor;

    switch (investment.type.toLowerCase()) {
      case 'stock':
      case 'stocks':
        icon = Icons.show_chart;
        iconColor = Colors.blue;
        break;
      case 'gold':
        icon = Icons.monetization_on;
        iconColor = Colors.orange;
        break;
      case 'mutual fund':
      case 'mf':
        icon = Icons.pie_chart;
        iconColor = Colors.purple;
        break;
      case 'crypto':
        icon = Icons.currency_bitcoin;
        iconColor = Colors.indigo;
        break;
      case 'real estate':
        icon = Icons.home_work;
        iconColor = Colors.brown;
        break;
      case 'fd':
        icon = Icons.lock_clock;
        iconColor = Colors.green;
        break;
      default:
        icon = Icons.savings;
        iconColor = Colors.teal;
    }

    final profit = investment.currentAmount - investment.investedAmount;
    final isProfit = profit >= 0;

    return GestureDetector(
      onTap: () => _showAssetOptions(context, investment),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    investment.name,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    investment.type,
                    style: GoogleFonts.inter(color: Colors.grey, fontSize: 12),
                  ),
                  if (investment.quantity > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Text(
                            'Qty: ${investment.quantity.toStringAsFixed(investment.quantity % 1 == 0 ? 0 : 2)}',
                            style: GoogleFonts.inter(
                              color: Colors.blueGrey,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Avg: $currencySymbol${(investment.investedAmount / investment.quantity).toStringAsFixed(2)}',
                            style: GoogleFonts.inter(
                              color: Colors.blueGrey,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$currencySymbol${investment.currentAmount.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      isProfit ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 12,
                      color: isProfit ? Colors.green : Colors.red,
                    ),
                    Text(
                      '${profit.abs().toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        color: isProfit ? Colors.green : Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddInvestmentDialog(BuildContext context) {
    final nameController = TextEditingController();
    final priceController = TextEditingController(); // Renamed from amount
    final quantityController = TextEditingController();
    String selectedType = 'Stock';
    final types = [
      'Stock',
      'Mutual Fund',
      'Gold',
      'FD',
      'Crypto',
      'Real Estate',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Add New Asset',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Asset Name (e.g. Apple, Gold)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      items: types
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => selectedType = v!),
                      decoration: InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Buy Price (Per Unit)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Quantity',
                        hintText: 'e.g. 10',
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          if (nameController.text.isNotEmpty &&
                              priceController.text.isNotEmpty &&
                              quantityController.text.isNotEmpty) {
                            final price =
                                double.tryParse(priceController.text) ?? 0.0;
                            final quantity =
                                double.tryParse(quantityController.text) ?? 0.0;
                            final totalInvested = price * quantity;

                            // Assuming initial Current Value = Invested Value
                            // If user wants to track purely, we pass totalInvested as 'amount'
                            // but provider takes (amount, quantity). 'amount' there is usually investedAmount.

                            context.read<InvestmentProvider>().addInvestment(
                              nameController.text,
                              selectedType,
                              totalInvested,
                              quantity,
                            );
                            Navigator.pop(context);
                          }
                        },
                        child: const Text('Add Asset'),
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

  void _showAssetOptions(BuildContext context, dynamic investment) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              investment.name,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add, color: Colors.green),
              ),
              title: const Text('Buy More'),
              onTap: () {
                Navigator.pop(context);
                _showTransactionDialog(context, investment, 'buy');
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.remove, color: Colors.red),
              ),
              title: const Text('Sell'),
              onTap: () {
                Navigator.pop(context);
                _showTransactionDialog(context, investment, 'sell');
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit, color: Colors.blue),
              ),
              title: const Text('Update Current Value'),
              onTap: () {
                Navigator.pop(context);
                _showUpdateValueDialog(context, investment);
              },
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete, color: Colors.red),
              ),
              title: const Text('Delete Asset'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(context, investment);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDialog(
    BuildContext context,
    dynamic investment,
    String type,
  ) {
    final priceController = TextEditingController();
    final quantityController = TextEditingController();
    final isBuy = type == 'buy';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isBuy ? 'Buy More' : 'Sell Asset'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: isBuy
                    ? 'Buy Price (Per Unit)'
                    : 'Sell Price (Per Unit)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
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
              final price = double.tryParse(priceController.text) ?? 0.0;
              final quantity = double.tryParse(quantityController.text) ?? 0.0;
              final amount = price * quantity;

              if (amount > 0 && quantity > 0) {
                context.read<InvestmentProvider>().addTransaction(
                  investment.id,
                  type,
                  amount,
                  quantity,
                  price,
                );
                Navigator.pop(context);
              }
            },
            child: Text(isBuy ? 'Buy' : 'Sell'),
          ),
        ],
      ),
    );
  }

  void _showUpdateValueDialog(BuildContext context, dynamic investment) {
    final hasQuantity = investment.quantity > 0;
    // If has quantity, show Price per unit. Else show Total Value.
    final initialValue = hasQuantity
        ? (investment.currentAmount / investment.quantity)
        : investment.currentAmount;

    final valueController = TextEditingController(
      text: initialValue.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          hasQuantity ? 'Update Market Price' : 'Update Current Value',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: valueController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: hasQuantity
                    ? 'Current Price (Per Unit)'
                    : 'New Total Value',
                suffixText: hasQuantity
                    ? 'x ${investment.quantity} units'
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (hasQuantity)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Total Value will be calculated automatically.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
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
              final val = double.tryParse(valueController.text);
              if (val != null) {
                double newTotal;
                if (hasQuantity) {
                  newTotal = val * investment.quantity;
                } else {
                  newTotal = val;
                }

                context.read<InvestmentProvider>().updateCurrentValue(
                  investment.id,
                  newTotal,
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, dynamic investment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Asset'),
        content: Text('Are you sure you want to delete ${investment.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<InvestmentProvider>().deleteInvestment(
                investment.id,
              );
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
