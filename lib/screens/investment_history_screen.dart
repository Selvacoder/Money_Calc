import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/investment_provider.dart';
import '../providers/currency_provider.dart';

class InvestmentHistoryScreen extends StatelessWidget {
  const InvestmentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final investmentProvider = context.watch<InvestmentProvider>();
    final currencySymbol = context.watch<CurrencyProvider>().currencySymbol;

    final history = investmentProvider.transactions;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'History',
            style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: history.isEmpty
                ? Center(
                    child: Text(
                      'No transactions yet',
                      style: GoogleFonts.inter(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final tx = history[index];
                      final isBuy = tx.type.toLowerCase() == 'buy';

                      // Find asset name from investmentID?
                      // Ideally Provider should join this or we populate it.
                      // For now, we just show "Investment" or ID.
                      // Actually, we can look it up from provider.investments
                      String name = 'Asset';
                      try {
                        final inv = investmentProvider.investments.firstWhere(
                          (i) => i.id == tx.investmentId,
                        );
                        name = inv.name;
                      } catch (e) {
                        // Missing investment ref
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isBuy
                                ? Colors.green.withOpacity(0.2)
                                : Colors.red.withOpacity(0.2),
                            child: Icon(
                              isBuy ? Icons.arrow_downward : Icons.arrow_upward,
                              color: isBuy ? Colors.green : Colors.red,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            name,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            DateFormat('MMM d, yyyy').format(tx.dateTime),
                            style: GoogleFonts.inter(fontSize: 12),
                          ),
                          trailing: Text(
                            '${isBuy ? '+' : '-'}$currencySymbol${tx.amount.toStringAsFixed(2)}',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: isBuy ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
