import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../providers/transaction_provider.dart';
import 'package:provider/provider.dart';

class TransactionDetailsDialog extends StatelessWidget {
  final Transaction transaction;
  final String currencySymbol;

  const TransactionDetailsDialog({
    super.key,
    required this.transaction,
    this.currencySymbol = '₹',
  });

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.isExpense;
    final categoryId = transaction.categoryId;

    // Fetch real category name if possible
    String categoryName = 'Uncategorized';
    if (categoryId != null) {
      final categories = context.read<TransactionProvider>().categories;
      final cat = categories.where((c) => c.id == categoryId).firstOrNull;
      if (cat != null) categoryName = cat.name;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Icon
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: isExpense
                      ? Colors.red.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  child: Icon(
                    isExpense ? Icons.arrow_downward : Icons.arrow_upward,
                    color: isExpense ? Colors.red : Colors.green,
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
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isExpense ? 'Expense' : 'Income',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Amount
            Center(
              child: Text(
                '$currencySymbol${transaction.amount.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: isExpense ? Colors.red : Colors.green,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Details Grid
            _buildDetailRow(
              context,
              Icons.calendar_today,
              'Date',
              DateFormat('MMM dd, yyyy').format(transaction.dateTime),
            ),
            const SizedBox(height: 16),
            _buildDetailRow(
              context,
              Icons.access_time,
              'Time',
              DateFormat('h:mm a').format(transaction.dateTime),
            ),
            const SizedBox(height: 16),
            _buildDetailRow(context, Icons.category, 'Category', categoryName),
            if (transaction.paymentMethod != null) ...[
              const SizedBox(height: 16),
              _buildDetailRow(
                context,
                Icons.payment,
                'Payment Method',
                transaction.paymentMethod!,
              ),
            ],

            const SizedBox(height: 32),

            // Delete Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Show confirmation/delete
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete'),
                      content: Text(
                        'Are you sure you want to delete "${transaction.title}"?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            context
                                .read<TransactionProvider>()
                                .deleteTransaction(transaction.id);
                            Navigator.pop(ctx); // Close confirmation
                            Navigator.pop(context); // Close details dialog
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Transaction deleted'),
                              ),
                            );
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
                icon: const Icon(Icons.delete_outline, color: Colors.white),
                label: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Close Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
