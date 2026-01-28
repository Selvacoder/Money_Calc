import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/ledger_transaction.dart';
import '../../providers/ledger_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/currency_provider.dart';
import '../../widgets/empty_state.dart';

class LedgerDueDateScreen extends StatefulWidget {
  const LedgerDueDateScreen({super.key});

  @override
  State<LedgerDueDateScreen> createState() => _LedgerDueDateScreenState();
}

class _LedgerDueDateScreenState extends State<LedgerDueDateScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final ledgerProvider = context.watch<LedgerProvider>();
    final userProvider = context.watch<UserProvider>();
    final currencySymbol = context.watch<CurrencyProvider>().currencySymbol;
    final transactions = ledgerProvider.ledgerTransactions;
    final currentUserContact = userProvider.user?.phone ?? '';

    // Calculate Overdue Details
    final overdueList = _calculateOverduePeople(
      transactions,
      currentUserContact,
    );

    // Filter by search
    final filteredList = _searchQuery.isEmpty
        ? overdueList
        : overdueList
              .where(
                (item) => item['name'].toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ),
              )
              .toList();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Due Dates',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onBackground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'People who owe you money',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: TextField(
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Search people...',
                        hintStyle: GoogleFonts.inter(
                          color: Colors.grey.shade400,
                        ),
                        border: InputBorder.none,
                        icon: Icon(Icons.search, color: Colors.grey.shade400),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filteredList.isEmpty
                  ? EmptyState(
                      title: _searchQuery.isEmpty
                          ? 'All Caught Up!'
                          : 'No one found',
                      message: _searchQuery.isEmpty
                          ? 'No one currently owes you money.'
                          : 'Try a different name.',
                      icon: Icons.check_circle_outline,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: filteredList.length,
                      itemBuilder: (context, index) {
                        final item = filteredList[index];
                        return _buildOverdueItem(context, item, currencySymbol)
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

  Widget _buildOverdueItem(
    BuildContext context,
    Map<String, dynamic> item,
    String currencySymbol,
  ) {
    final name = item['name'];
    final phone = item['phone'];
    final amount = item['amount'] as double;
    final daysOverdue = item['daysOverdue'] as int;
    final overdueSince = item['since'] as DateTime;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFE5F5E9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF51CF66),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: Colors.orange.shade400,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$daysOverdue days overdue',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.orange.shade400,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Since ${DateFormat('MMM dd, yyyy').format(overdueSince)}',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$currencySymbol${NumberFormat('#,##0').format(amount)}',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF51CF66),
                ),
              ),
              const SizedBox(height: 8),
              if (phone != null &&
                  phone.isNotEmpty &&
                  !phone.toString().startsWith('local:'))
                InkWell(
                  onTap: () => _launchWhatsAppReminder(
                    context,
                    name,
                    phone,
                    amount,
                    currencySymbol,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.send, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'Remind',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // Logic Helpers
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

  List<Map<String, dynamic>> _calculateOverduePeople(
    List<LedgerTransaction> transactions,
    String currentUserContact,
  ) {
    // 1. Group by Person
    Map<String, List<LedgerTransaction>> personTransactions = {};
    Map<String, String> personNames = {}; // Phone -> Name
    Map<String, String> personPhones =
        {}; // Name -> Phone (Reverse lookup for safety)

    for (var t in transactions) {
      final isSent = _arePhonesEqual(t.senderPhone, currentUserContact);
      final otherPhone = isSent ? t.receiverPhone : t.senderPhone;
      final otherName = isSent ? t.receiverName : t.senderName;

      // Use Phone as key if available, else Name
      String key = otherName.trim();
      if (otherPhone != null &&
          otherPhone.isNotEmpty &&
          !otherPhone.startsWith('local:')) {
        key = otherPhone;
      }

      if (!personTransactions.containsKey(key)) {
        personTransactions[key] = [];
        personNames[key] = otherName;
        if (otherPhone != null) personPhones[key] = otherPhone;
      }
      personTransactions[key]!.add(t);
    }

    List<Map<String, dynamic>> results = [];

    // 2. Analyze each person
    personTransactions.forEach((key, txList) {
      // Sort oldest to newest
      txList.sort((a, b) => a.dateTime.compareTo(b.dateTime));

      double netBalance = 0;
      DateTime? overdueStartDate;

      // Replay history to find when they went into debt
      for (var t in txList) {
        final isSent = _arePhonesEqual(t.senderPhone, currentUserContact);

        // Update balance (Positive = They owe me)
        if (isSent) {
          netBalance += t.amount;
        } else {
          netBalance -= t.amount;
        }

        // Check debt status
        if (netBalance > 0) {
          // They owe money. If this is the start of debt, record date
          overdueStartDate ??= t.dateTime;
        } else {
          // Debt cleared (or they lent me money). Reset overdue date.
          overdueStartDate = null;
        }
      }

      // 3. If final balance is positive, add to list
      if (netBalance > 0 && overdueStartDate != null) {
        final daysOverdue = DateTime.now().difference(overdueStartDate).inDays;

        results.add({
          'name': personNames[key] ?? 'Unknown',
          'phone': personPhones[key] ?? key, // Fallback to key if it's a phone
          'amount': netBalance,
          'daysOverdue': daysOverdue,
          'since': overdueStartDate,
        });
      }
    });

    // Sort by days overdue (descending)
    results.sort(
      (a, b) => (b['daysOverdue'] as int).compareTo(a['daysOverdue'] as int),
    );

    return results;
  }

  void _launchWhatsAppReminder(
    BuildContext context,
    String name,
    String phone,
    double amount,
    String currencySymbol,
  ) async {
    final formattedAmount = '$currencySymbol${amount.toStringAsFixed(2)}';
    final message =
        "Hello $name, just a gentle reminder about the pending amount of $formattedAmount. Please settle it when possible. Thanks!";
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final url = Uri.parse(
      'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp')),
        );
      }
    }
  }
}
