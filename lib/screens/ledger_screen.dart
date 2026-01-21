import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:country_code_picker/country_code_picker.dart';
import '../models/ledger_transaction.dart';
import '../services/appwrite_service.dart';
import 'ledger/person_ledger_screen.dart';
import '../providers/ledger_provider.dart';
import '../providers/user_provider.dart';
import '../providers/currency_provider.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/empty_state.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  bool _showAllPeople = false;

  // Dialog Implementation
  void _showAddDialog({
    String? initialName,
    String? initialPhone,
    double? initialAmount,
    bool isReceived = false,
  }) {
    final nameController = TextEditingController(text: initialName);
    final phoneController = TextEditingController(text: initialPhone);
    final amountController = TextEditingController(
      text: initialAmount?.toString() ?? '',
    );
    final descController = TextEditingController();
    String selectedCountryCode = '+91';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            // Added scroll view for smaller screens
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isReceived ? 'Borrow Money' : 'Lend Money',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                // Replaced generic TextField with Autocomplete
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Autocomplete<Map<String, dynamic>>(
                      optionsBuilder:
                          (TextEditingValue textEditingValue) async {
                            if (textEditingValue.text.isEmpty) {
                              return const Iterable<
                                Map<String, dynamic>
                              >.empty();
                            }
                            return await AppwriteService().searchContacts(
                              textEditingValue.text,
                            );
                          },
                      displayStringForOption: (option) => option['name'] ?? '',
                      onSelected: (Map<String, dynamic> selection) {
                        nameController.text = selection['name'];
                        final phone = selection['phone'];
                        if (phone != null && phone.isNotEmpty) {
                          phoneController.text = phone;
                        }
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(12),
                            color: Theme.of(context).cardColor,
                            child: Container(
                              width: constraints.maxWidth,
                              constraints: const BoxConstraints(maxHeight: 200),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (BuildContext context, int index) {
                                  final option = options.elementAt(index);
                                  return ListTile(
                                    title: Text(option['name'] ?? 'Unknown'),
                                    subtitle:
                                        option['phone'] != null &&
                                            option['phone'].isNotEmpty
                                        ? Text(option['phone'])
                                        : null,
                                    onTap: () {
                                      onSelected(option);
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                      fieldViewBuilder:
                          (
                            context,
                            fieldTextEditingController,
                            fieldFocusNode,
                            onFieldSubmitted,
                          ) {
                            if (nameController.text.isNotEmpty &&
                                fieldTextEditingController.text.isEmpty) {
                              fieldTextEditingController.text =
                                  nameController.text;
                            }
                            fieldTextEditingController.addListener(() {
                              nameController.text =
                                  fieldTextEditingController.text;
                            });

                            return TextField(
                              controller: fieldTextEditingController,
                              focusNode: fieldFocusNode,
                              decoration: InputDecoration(
                                labelText: isReceived
                                    ? 'Lender Name'
                                    : 'Borrower Name',
                                prefixIcon: const Icon(Icons.person),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          },
                    );
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: CountryCodePicker(
                        onChanged: (code) {
                          selectedCountryCode = code.dialCode ?? '+91';
                          // basic logic to try and strip old code if exists roughly
                          final phone = phoneController.text.replaceAll(
                            RegExp(r'^\+\d+'),
                            '',
                          );
                          // But user might not have typed code.
                          // Ideally just store code separate or prepend on submit
                          // Keeping it simple as before
                        },
                        initialSelection: 'IN',
                        favorite: const ['+91', 'IN'],
                        showCountryOnly: false,
                        showOnlyCountryWhenClosed: false,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          helperText: 'Optional',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText:
                        '${context.read<CurrencyProvider>().currencySymbol} ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    prefixIcon: const Icon(Icons.description),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (nameController.text.isNotEmpty &&
                          amountController.text.isNotEmpty) {
                        final phoneStr = phoneController.text.isEmpty
                            ? null
                            : (phoneController.text.startsWith('+')
                                  ? phoneController.text
                                  : '$selectedCountryCode${phoneController.text}');

                        context.read<LedgerProvider>().addLedgerTransaction(
                          nameController.text,
                          phoneStr,
                          double.tryParse(amountController.text) ?? 0.0,
                          descController.text,
                          isReceived: isReceived,
                        );
                        Navigator.pop(context);
                      }
                    },
                    child: Text(isReceived ? 'Add Record' : 'Lend Money'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ledgerProvider = context.watch<LedgerProvider>();
    final userProvider = context.watch<UserProvider>();
    final currencySymbol = context.watch<CurrencyProvider>().currencySymbol;
    final transactions = ledgerProvider.ledgerTransactions;
    final currentUserContact = userProvider.user?.phone ?? '';

    if (ledgerProvider.isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: AppBar(
          title: const Text('Ledger'),
          backgroundColor: Colors.transparent,
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SkeletonLoader(height: 150, borderRadius: 24),
              const SizedBox(height: 24),
              Row(
                children: const [
                  Expanded(child: SkeletonLoader(height: 80, borderRadius: 16)),
                  SizedBox(width: 16),
                  Expanded(child: SkeletonLoader(height: 80, borderRadius: 16)),
                ],
              ),
            ],
          ),
        ),
      );
    }

    double totalReceived = transactions
        .where((t) => !_arePhonesEqual(t.senderPhone, currentUserContact))
        .fold(0, (sum, t) => sum + t.amount);

    double totalSent = transactions
        .where((t) => _arePhonesEqual(t.senderPhone, currentUserContact))
        .fold(0, (sum, t) => sum + t.amount);

    double netBalance = totalReceived - totalSent;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBalanceCard(
                netBalance,
                totalReceived,
                totalSent,
                currencySymbol,
              ).animate().fadeIn().slideY(begin: 0.2, end: 0),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.upload,
                      label: 'Lend',
                      color: const Color(0xFFFF6B6B),
                      onTap: () => _showAddDialog(isReceived: false),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.download,
                      label: 'Receive',
                      color: const Color(0xFF51CF66),
                      onTap: () => _showAddDialog(isReceived: true),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 100.ms).slideX(),

              const SizedBox(height: 24),

              Text(
                'People',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 16),

              Builder(
                builder: (context) {
                  final balances = _calculateUserBalances(
                    transactions,
                    currentUserContact,
                  );
                  if (balances.isEmpty) {
                    return _buildEmptyState();
                  }
                  return Column(
                    children: [
                      GridView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 0.8,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                        itemCount: _showAllPeople
                            ? balances.length
                            : (balances.length > 9 ? 9 : balances.length),
                        itemBuilder: (context, index) {
                          final b = balances[index];
                          return _buildPersonGridItem(
                            b['name'],
                            b['phone'],
                            b['balance'],
                            transactions,
                            currentUserContact,
                            currencySymbol,
                          );
                        },
                      ),
                      if (balances.length > 9) ...[
                        const SizedBox(height: 16),
                        Center(
                          child: TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _showAllPeople = !_showAllPeople;
                              });
                            },
                            icon: Icon(
                              _showAllPeople
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                            ),
                            label: Text(
                              _showAllPeople ? 'Show Less' : 'Show More',
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 80),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const EmptyState(
      title: 'No records yet',
      message: 'Start by lending or receiving money.',
      icon: Icons.people_outline,
    );
  }

  Widget _buildBalanceCard(
    double net,
    double received,
    double sent,
    String currencySymbol,
  ) {
    return Container(
      width: double.infinity,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Net Ledger Balance',
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$currencySymbol${NumberFormat('#,##0.00').format(net)}',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 32,
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
                    Row(
                      children: [
                        const Icon(
                          Icons.arrow_downward,
                          color: Color(0xFF51CF66),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Received',
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '$currencySymbol${NumberFormat('#,##0').format(received)}',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.arrow_outward,
                          color: Color(0xFFFF8A8A),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Sent',
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '$currencySymbol${NumberFormat('#,##0').format(sent)}',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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

  bool _arePhonesEqual(String? p1, String? p2) {
    if (p1 == null || p2 == null) return false;
    final n1 = p1.replaceAll(RegExp(r'\D'), '');
    final n2 = p2.replaceAll(RegExp(r'\D'), '');
    if (n1.isEmpty || n2.isEmpty) return false;
    if (n1.length >= 10 && n2.length >= 10) {
      return n1.substring(n1.length - 10) == n2.substring(n2.length - 10);
    }
    return n1 == n2;
  }

  List<Map<String, dynamic>> _calculateUserBalances(
    List<LedgerTransaction> transactions,
    String currentUserContact,
  ) {
    Map<String, double> balances = {};
    Map<String, String> names = {};
    Map<String, String> nameToPhone = {};

    for (var t in transactions) {
      final isSent = _arePhonesEqual(t.senderPhone, currentUserContact);
      final otherPhone = isSent ? t.receiverPhone : t.senderPhone;
      final otherName = isSent ? t.receiverName : t.senderName;

      if (otherPhone != null &&
          otherPhone.isNotEmpty &&
          !otherPhone.startsWith('local:')) {
        nameToPhone[otherName.trim().toLowerCase()] = otherPhone;
      }
    }

    for (var t in transactions) {
      final isSent = _arePhonesEqual(t.senderPhone, currentUserContact);
      final otherPhone = isSent ? t.receiverPhone : t.senderPhone;
      final otherName = isSent ? t.receiverName : t.senderName;
      String key;
      if (otherPhone != null &&
          otherPhone.isNotEmpty &&
          !otherPhone.startsWith('local:')) {
        key = otherPhone;
      } else {
        key = nameToPhone[otherName.trim().toLowerCase()] ?? otherName;
      }

      if (!names.containsKey(key)) {
        names[key] = otherName;
      }
      double amount = t.amount;
      if (!isSent) amount = -amount;
      balances[key] = (balances[key] ?? 0) + amount;
    }
    return balances.entries.map((e) {
      String displayPhone = e.key;
      if (displayPhone == names[e.key] || displayPhone.startsWith('local:')) {
        displayPhone = '';
      }
      return {
        'phone': displayPhone,
        'name': names[e.key] ?? 'Unknown',
        'balance': e.value,
      };
    }).toList();
  }

  Widget _buildPersonGridItem(
    String name,
    String phone,
    double balance,
    List<LedgerTransaction> allTransactions,
    String currentUserContact,
    String currencySymbol,
  ) {
    final isOwesYou = balance > 0;
    final isYouOwe = balance < 0;

    return GestureDetector(
      onTap: () {
        final personTransactions = allTransactions.where((t) {
          final isSent = _arePhonesEqual(t.senderPhone, currentUserContact);
          final otherPhone = isSent ? t.receiverPhone : t.senderPhone;
          final otherName = isSent ? t.receiverName : t.senderName;

          if (phone.isNotEmpty && !phone.startsWith('local:')) {
            return _arePhonesEqual(otherPhone, phone);
          } else {
            return otherName.trim().toLowerCase() == name.trim().toLowerCase();
          }
        }).toList();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PersonLedgerScreen(
              personName: name,
              personPhone: phone,
              currentBalance: balance,
              transactions: personTransactions,
              currencySymbol: currencySymbol,
              currentUserContact: currentUserContact,
              onAddTransaction:
                  (name, phone, amount, desc, {isReceived = false}) {
                    context.read<LedgerProvider>().addLedgerTransaction(
                      name,
                      phone,
                      amount,
                      desc,
                      isReceived: isReceived,
                    );
                  },
              onRemind: () {
                _launchWhatsAppReminder(name, phone, balance, currencySymbol);
              },
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isOwesYou
                    ? const Color(0xFFE5F5E9)
                    : (isYouOwe
                          ? const Color(0xFFFFE5E5)
                          : Colors.grey.shade100),
                shape: BoxShape.circle,
              ),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isOwesYou
                      ? const Color(0xFF51CF66)
                      : (isYouOwe ? const Color(0xFFFF6B6B) : Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
            ),

            Text(
              '$currencySymbol${NumberFormat('#,##0').format(balance.abs())}',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isOwesYou
                    ? const Color(0xFF51CF66)
                    : (isYouOwe ? const Color(0xFFFF6B6B) : Colors.grey),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isOwesYou ? 'Owes You' : (isYouOwe ? 'You Owe' : 'Settled'),
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _launchWhatsAppReminder(
    String name,
    String phone,
    double balance,
    String currencySymbol,
  ) async {
    // Reuse logic
    final amount = '$currencySymbol${balance.abs().toStringAsFixed(2)}';
    final message =
        "Hello $name, a gentle reminder regarding the balance of $amount in MoneyCalc. Thanks!";
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final url = Uri.parse(
      'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
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
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
