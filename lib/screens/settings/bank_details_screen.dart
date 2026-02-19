import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/formatters.dart';

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
        title: const Text('Add Account'),
        content: TextField(
          controller: _bankController,
          decoration: const InputDecoration(
            labelText: 'Account Name',
            hintText: 'e.g., HDFC, SBI, Chase',
          ),
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [CapitalizeFirstLetterTextFormatter()],
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

  void _showAddCustomMethodDialog({String? editingName}) {
    _customMethodController.text = editingName ?? '';
    final isEditing = editingName != null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Edit Payment Method' : 'Add Payment Method'),
        content: TextField(
          controller: _customMethodController,
          decoration: InputDecoration(
            labelText: 'Method Name',
            hintText: 'e.g., Wallet, Sodexo, Forex Card',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [CapitalizeFirstLetterTextFormatter()],
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
                try {
                  if (isEditing) {
                    context.read<UserProvider>().renameCustomPaymentMethod(
                      editingName,
                      name,
                    );
                  } else {
                    context.read<UserProvider>().addCustomPaymentMethod(name);
                  }
                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              }
            },
            child: Text(isEditing ? 'Save' : 'Add'),
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
          'Accounts Details',
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
                  'My Payment Accounts',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: _showAddBankDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Accounts'),
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
                      'No Accounts added yet',
                      style: GoogleFonts.inter(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _showAddBankDialog,
                      child: const Text('Add Your First Account'),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                height: banks.length > 5 ? 400 : null,
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 12),
                  physics: banks.length > 5
                      ? const AlwaysScrollableScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
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
              'Enable auto-selection for specific payment methods',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Cash Toggle Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.money,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Cash',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Switch(
                    value: userProvider.isPaymentMethodEnabled('Cash'),
                    onChanged: (val) {
                      context.read<UserProvider>().togglePaymentMethod(
                        'Cash',
                        val,
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _buildPrimarySelector(
              context: context,
              title: 'Debit Card',
              icon: Icons.credit_card,
              value: primaryMethods['Debit Card'],
              isEnabled: userProvider.isPaymentMethodEnabled('Debit Card'),
              options: banks,
              onToggle: (val) {
                context.read<UserProvider>().togglePaymentMethod(
                  'Debit Card',
                  val,
                );
              },
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
              isEnabled: userProvider.isPaymentMethodEnabled('UPI'),
              options: banks,
              onToggle: (val) {
                context.read<UserProvider>().togglePaymentMethod('UPI', val);
              },
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
              isEnabled: userProvider.isPaymentMethodEnabled('Credit Card'),
              options: banks,
              onToggle: (val) {
                context.read<UserProvider>().togglePaymentMethod(
                  'Credit Card',
                  val,
                );
              },
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
              isEnabled: userProvider.isPaymentMethodEnabled('Bank Account'),
              options: banks,
              onToggle: (val) {
                context.read<UserProvider>().togglePaymentMethod(
                  'Bank Account',
                  val,
                );
              },
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
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onLongPress: () {
                      showModalBottomSheet(
                        context: context,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        builder: (context) => SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  method,
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                ListTile(
                                  leading: const Icon(Icons.edit),
                                  title: const Text('Edit'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _showAddCustomMethodDialog(
                                      editingName: method,
                                    );
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  title: const Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                  onTap: () async {
                                    Navigator.pop(context);
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Remove Method'),
                                        content: Text(
                                          'Remove custom method "$method"?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.red,
                                            ),
                                            child: const Text('Remove'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      context
                                          .read<UserProvider>()
                                          .removeCustomPaymentMethod(method);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.payment,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  method,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  opacity:
                                      userProvider.isPaymentMethodEnabled(
                                        method,
                                      )
                                      ? 1.0
                                      : 0.4,
                                  child: IgnorePointer(
                                    ignoring: !userProvider
                                        .isPaymentMethodEnabled(method),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value:
                                            banks.contains(
                                              primaryMethods[method],
                                            )
                                            ? primaryMethods[method]
                                            : null,
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
                                          ...banks.map(
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
                                        onChanged: (val) {
                                          context
                                              .read<UserProvider>()
                                              .setPrimaryPaymentMethod(
                                                method,
                                                val,
                                              );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: userProvider.isPaymentMethodEnabled(method),
                            onChanged: (val) {
                              context.read<UserProvider>().togglePaymentMethod(
                                method,
                                val,
                              );
                            },
                          ),
                        ],
                      ),
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
    required bool isEnabled,
    required Function(bool) onToggle,
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
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isEnabled ? 1.0 : 0.4,
                  child: IgnorePointer(
                    ignoring: !isEnabled,
                    child: DropdownButtonHideUnderline(
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
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(value: isEnabled, onChanged: onToggle),
        ],
      ),
    );
  }
}
