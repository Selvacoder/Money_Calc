import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';

class BankDetailsScreen extends StatefulWidget {
  const BankDetailsScreen({super.key});

  @override
  State<BankDetailsScreen> createState() => _BankDetailsScreenState();
}

class _BankDetailsScreenState extends State<BankDetailsScreen> {
  final _bankController = TextEditingController();
  final _customMethodController = TextEditingController();

  @override
  void dispose() {
    _bankController.dispose();
    _customMethodController.dispose();
    super.dispose();
  }

  void _showAddBankDialog() {
    _bankController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Bank'),
        content: TextField(
          controller: _bankController,
          decoration: const InputDecoration(
            labelText: 'Bank Name',
            hintText: 'e.g., HDFC, SBI, Chase',
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (_bankController.text.trim().isNotEmpty) {
                context.read<UserProvider>().addBank(
                  _bankController.text.trim(),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddCustomMethodDialog() {
    _customMethodController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Payment Method'),
        content: TextField(
          controller: _customMethodController,
          decoration: const InputDecoration(
            labelText: 'Method Name',
            hintText: 'e.g., Wallet, Sodexo, Forex Card',
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = _customMethodController.text.trim();
              if (name.isNotEmpty) {
                // Prevent duplicates with standard methods
                if ([
                  'Cash',
                  'UPI',
                  'Debit Card',
                  'Credit Card',
                  'Bank Account',
                ].contains(name)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('This is already a standard method.'),
                    ),
                  );
                  return;
                }
                context.read<UserProvider>().addCustomPaymentMethod(name);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final banks = userProvider.banks;
    final primaryMethods = userProvider.primaryPaymentMethods;
    final customMethods = userProvider.customPaymentMethods;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Bank Details',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.textTheme.bodyLarge?.color,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- My Banks Section ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My Banks',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: _showAddBankDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Bank'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (banks.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.account_balance_outlined,
                      size: 48,
                      color: Colors.grey.withOpacity(0.5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No banks added yet',
                      style: GoogleFonts.inter(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _showAddBankDialog,
                      child: const Text('Add Your First Bank'),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: banks.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final bank = banks[index];
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(
                                  0.1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.account_balance,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              bank,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Remove Bank'),
                                content: Text(
                                  'Remove "$bank"? This will also clear any default payment settings using this bank.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      context.read<UserProvider>().removeBank(
                                        bank,
                                      );
                                      Navigator.pop(ctx);
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                    child: const Text('Remove'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),

            const SizedBox(height: 32),

            // --- Default Accounts Section ---
            Text(
              'Default Payment Accounts',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a primary bank for each payment method. This will be shown in your dashboard.',
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            _buildPrimarySelector(
              context: context,
              title: 'Debit Card',
              icon: Icons.credit_card,
              value: primaryMethods['Debit Card'],
              options: banks,
              onChanged: (val) {
                context.read<UserProvider>().setPrimaryPaymentMethod(
                  'Debit Card',
                  val,
                );
              },
            ),
            const SizedBox(height: 16),
            _buildPrimarySelector(
              context: context,
              title: 'UPI',
              icon: Icons.qr_code,
              value: primaryMethods['UPI'],
              options: banks,
              onChanged: (val) {
                context.read<UserProvider>().setPrimaryPaymentMethod(
                  'UPI',
                  val,
                );
              },
            ),
            const SizedBox(height: 16),
            _buildPrimarySelector(
              context: context,
              title: 'Credit Card',
              icon: Icons.credit_score,
              value: primaryMethods['Credit Card'],
              options: banks,
              onChanged: (val) {
                context.read<UserProvider>().setPrimaryPaymentMethod(
                  'Credit Card',
                  val,
                );
              },
            ),
            const SizedBox(height: 16),
            _buildPrimarySelector(
              context: context,
              title: 'Bank Account',
              icon: Icons.account_balance,
              value: primaryMethods['Bank Account'],
              options: banks,
              onChanged: (val) {
                context.read<UserProvider>().setPrimaryPaymentMethod(
                  'Bank Account',
                  val,
                );
              },
            ),

            if (customMethods.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Custom Payment Methods',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...customMethods.map((method) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Dismissible(
                    key: Key(method),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (direction) async {
                      return await showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Remove Method'),
                          content: Text('Remove custom method "$method"?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text('Remove'),
                            ),
                          ],
                        ),
                      );
                    },
                    onDismissed: (_) {
                      context.read<UserProvider>().removeCustomPaymentMethod(
                        method,
                      );
                    },
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: Colors.red,
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    child: _buildPrimarySelector(
                      context: context,
                      title: method,
                      icon: Icons.payment,
                      value: primaryMethods[method],
                      options: banks,
                      onChanged: (val) {
                        context.read<UserProvider>().setPrimaryPaymentMethod(
                          method,
                          val,
                        );
                      },
                    ),
                  ),
                );
              }),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showAddCustomMethodDialog,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Add Custom Payment Method'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: theme.colorScheme.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimarySelector({
    required BuildContext context,
    required String title,
    required IconData icon,
    required String? value,
    required List<String> options,
    required Function(String?) onChanged,
  }) {
    // If we have a value but it's not in options (e.g. bank deleted), treated as null
    final validValue = options.contains(value) ? value : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.secondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: validValue,
                    isDense: true,
                    isExpanded: true,
                    hint: Text(
                      'Select Bank',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: Colors.grey[400],
                      ),
                    ),
                    icon: const Icon(Icons.arrow_drop_down),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('None'),
                      ),
                      ...options.map(
                        (bank) => DropdownMenuItem(
                          value: bank,
                          child: Text(
                            bank,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                    onChanged: onChanged,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
