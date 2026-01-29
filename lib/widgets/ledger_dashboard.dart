import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:country_code_picker/country_code_picker.dart';
import '../utils/formatters.dart';

import '../models/ledger_transaction.dart';
import '../services/appwrite_service.dart';
// import 'package:intl/intl.dart';
// import '../screens/ledger_graph_screen.dart';
// import '../screens/ledger_history_screen.dart';
import '../screens/ledger/person_ledger_screen.dart';
import '../providers/ledger_provider.dart';
import '../providers/user_provider.dart';
import '../providers/currency_provider.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/empty_state.dart';

class LedgerDashboard extends StatefulWidget {
  const LedgerDashboard({super.key});

  @override
  State<LedgerDashboard> createState() => _LedgerDashboardState();
}

class _LedgerDashboardState extends State<LedgerDashboard> {
  bool _showAllPeople = false;
  bool _isNotesMode = false;

  // Copied Dialog Logic
  void _showAddDialog({
    String? initialName,
    String? initialPhone,
    double? initialAmount,
    bool isReceived = false,
    String? customStatus,
  }) {
    final nameController = TextEditingController(text: initialName);
    final phoneController = TextEditingController(text: initialPhone);
    final amountController = TextEditingController(
      text: initialAmount?.toString() ?? '',
    );
    final descController = TextEditingController();
    String selectedCountryCode = '+91';

    bool? isRegistered;
    bool checkingRegistration = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isNotesMode
                        ? (isReceived ? 'Get Item' : 'Give Item')
                        : (isReceived ? 'Borrow Money' : 'Lend Money'),
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Autocomplete<Map<String, dynamic>>(
                    optionsBuilder: (TextEditingValue textEditingValue) async {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<Map<String, dynamic>>.empty();
                      }
                      return await AppwriteService().searchContacts(
                        textEditingValue.text,
                      );
                    },
                    displayStringForOption: (option) => option['name'] ?? '',
                    onSelected: (Map<String, dynamic> selection) {
                      nameController.text = selection['name'];
                      if (selection['phone'] != null) {
                        phoneController.text = selection['phone'];
                      }
                    },
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                          controller.addListener(
                            () => nameController.text = controller.text,
                          );
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            textCapitalization: TextCapitalization.sentences,
                            inputFormatters: [
                              CapitalizeFirstLetterTextFormatter(),
                            ],
                            decoration: InputDecoration(
                              labelText: _isNotesMode
                                  ? 'Person Name'
                                  : (isReceived
                                        ? 'Lender Name'
                                        : 'Borrower Name'),
                              prefixIcon: const Icon(Icons.person),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        },
                  ),
                  if (!_isNotesMode) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: CountryCodePicker(
                            onChanged: (code) =>
                                selectedCountryCode = code.dialCode ?? '+91',
                            initialSelection: 'IN',
                            showCountryOnly: false,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            onChanged: (value) async {
                              final phone = value.replaceAll(RegExp(r'\D'), '');
                              if (phone.length >= 10) {
                                setDialogState(
                                  () => checkingRegistration = true,
                                );
                                final fullPhone = '$selectedCountryCode$phone';
                                try {
                                  final user = await AppwriteService()
                                      .getUserByPhone(fullPhone);
                                  setDialogState(() {
                                    isRegistered = user != null;
                                    checkingRegistration = false;
                                  });
                                } catch (e) {
                                  setDialogState(
                                    () => checkingRegistration = false,
                                  );
                                }
                              } else {
                                if (isRegistered != null) {
                                  setDialogState(() => isRegistered = null);
                                }
                              }
                            },
                            decoration: InputDecoration(
                              labelText: 'Phone',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              suffixIcon: checkingRegistration
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: Padding(
                                        padding: EdgeInsets.all(12.0),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : isRegistered == true
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isRegistered == false) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Colors.orange,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This user is not on MoneyCalc. We recommend tracking this in the Notes section.',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.orange.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
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
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        print(
                          'DEBUG: Add Btn Pressed. Name: ${nameController.text}, Amount: ${amountController.text}, Phone: ${phoneController.text}',
                        );
                        if (nameController.text.isNotEmpty &&
                            amountController.text.isNotEmpty) {
                          Navigator.pop(context); // Close dialog first

                          final phoneStr = phoneController.text.isEmpty
                              ? null
                              : '$selectedCountryCode${phoneController.text}';
                          print('DEBUG: passing phoneStr: $phoneStr');

                          final userProvider = context.read<UserProvider>();
                          final currentUser = userProvider.user;

                          final error = await context
                              .read<LedgerProvider>()
                              .addLedgerTransaction(
                                nameController.text,
                                phoneStr,
                                double.tryParse(amountController.text) ?? 0.0,
                                descController.text,
                                isReceived: isReceived,
                                currentUserId: currentUser?.userId ?? '',
                                currentUserName: currentUser?.name ?? '',
                                currentUserPhone: currentUser?.phone ?? '',
                                customStatus: _isNotesMode ? 'notes' : null,
                              );
                          print('DEBUG: Provider returned error: $error');

                          print('DEBUG: Provider returned error: $error');

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Debug: Phone=$phoneStr, Reg=$isRegistered, Err=$error',
                                ),
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          }

                          if (error == null &&
                              !_isNotesMode &&
                              isRegistered == false &&
                              mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'User not on MoneyCalc. Added to Notes.',
                                  style: GoogleFonts.inter(color: Colors.white),
                                ),
                                backgroundColor: Colors.orange.shade700,
                              ),
                            );
                          }

                          if (error != null && mounted) {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Error Adding'),
                                content: Text(error),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        _isNotesMode
                            ? 'Add Note'
                            : (isReceived ? 'Add Record' : 'Lend Money'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ledgerProvider = context.watch<LedgerProvider>();
    final userProvider = context.watch<UserProvider>();
    final currencySymbol = context.watch<CurrencyProvider>().currencySymbol;

    // Data Source Switch
    final activeTransactions = _isNotesMode
        ? ledgerProvider.notes
        : [
            ...ledgerProvider.ledgerTransactions,
            ...ledgerProvider.outgoingRequests,
            ...ledgerProvider.incomingRequests,
          ]; // Merge pending with confirmed for visibility

    final user = userProvider.user;
    final myIdentities = [
      if (user?.phone != null && user!.phone.isNotEmpty) user.phone,
      if (user?.email != null && user!.email.isNotEmpty) user.email,
    ].cast<String>();

    final currentUserId = ledgerProvider.currentUserId;

    if (ledgerProvider.isLoading) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: const [
            SkeletonLoader(height: 150, borderRadius: 24),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: SkeletonLoader(height: 80)),
                SizedBox(width: 16),
                Expanded(child: SkeletonLoader(height: 80)),
              ],
            ),
          ],
        ),
      );
    }

    double totalReceived = activeTransactions
        .where(
          (t) =>
              !((currentUserId != null && t.senderId == currentUserId) ||
                  myIdentities.any((id) => _arePhonesEqual(t.senderPhone, id))),
        )
        .fold(0, (sum, t) => sum + t.amount);

    double totalSent = activeTransactions
        .where(
          (t) =>
              (currentUserId != null && t.senderId == currentUserId) ||
              myIdentities.any((id) => _arePhonesEqual(t.senderPhone, id)),
        )
        .fold(0, (sum, t) => sum + t.amount);

    // Net Balance formula: Received - Given
    double netBalance = totalReceived - totalSent;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBalanceCard(
            netBalance,
            totalSent, // Rec (To Receive) = Money I Sent
            totalReceived, // Sent (To Pay) = Money I Received
            currencySymbol,
          ),
          const SizedBox(height: 24),
          _buildToggleSwitch(),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  Icons.upload,
                  _isNotesMode ? 'Give' : 'Lend',
                  const Color(0xFFFF6B6B),
                  () => _showAddDialog(
                    isReceived: false,
                    customStatus: _isNotesMode ? 'notes' : null,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionButton(
                  Icons.download,
                  _isNotesMode ? 'Get' : 'Receive',
                  const Color(0xFF51CF66),
                  () => _showAddDialog(
                    isReceived: true,
                    customStatus: _isNotesMode ? 'notes' : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isNotesMode ? 'Recent Notes' : 'People',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!_isNotesMode)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'hidden') {
                      _showHiddenPeopleDialog();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'hidden',
                      child: Row(
                        children: [
                          Icon(
                            Icons.visibility_off,
                            size: 20,
                            color: Colors.grey,
                          ),
                          SizedBox(width: 8),
                          Text('Hidden People'),
                        ],
                      ),
                    ),
                  ],
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.more_horiz),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPeopleGrid(
            activeTransactions,
            myIdentities,
            currencySymbol,
            currentUserId,
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildToggleSwitch() {
    final theme = Theme.of(context);
    return Center(
      child: Container(
        height: 48,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildToggleItem(
              'Tracker',
              !_isNotesMode,
              Icons.analytics_outlined,
            ),
            _buildToggleItem('Notes', _isNotesMode, Icons.notes_outlined),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleItem(String label, bool isActive, IconData icon) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => setState(() => _isNotesMode = label == 'Notes'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isActive ? Colors.white : Colors.grey),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: isActive ? Colors.white : Colors.grey,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helpers
  Widget _buildPeopleGrid(
    List<LedgerTransaction> transactions,
    List<String> myIdentities,
    String currencySymbol,
    String? currentUserId,
  ) {
    final balances = _calculateUserBalances(
      transactions,
      myIdentities,
      currentUserId,
    );
    if (balances.isEmpty) {
      return const EmptyState(
        title: 'No records',
        message: 'Start lending/receiving',
        icon: Icons.people_outline,
      );
    }

    return Column(
      children: [
        GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
              myIdentities,
              currencySymbol,
              currentUserId,
              onLongPress: () => _showPersonOptions(
                b['name'],
                b['phone'],
                myIdentities.isNotEmpty ? myIdentities.first : '',
              ),
            );
          },
        ),
        if (balances.length > 9)
          TextButton(
            onPressed: () => setState(() => _showAllPeople = !_showAllPeople),
            child: Text(_showAllPeople ? 'Show Less' : 'Show More'),
          ),
      ],
    );
  }

  // Refactored helper to get transactions for a specific person
  List<LedgerTransaction> _getPersonTransactions(
    List<LedgerTransaction> allTx,
    String personName,
    String personPhone,
    List<String> myIdentities,
    String? currentUserId,
  ) {
    return allTx.where((t) {
      final isMeSender =
          (currentUserId != null && t.senderId == currentUserId) ||
          myIdentities.any((id) => _arePhonesEqual(t.senderPhone, id));
      final isMeReceiver =
          (currentUserId != null && t.receiverId == currentUserId) ||
          myIdentities.any((id) => _arePhonesEqual(t.receiverPhone, id));

      if (isMeSender) {
        // I sent, checking if receiver is this person
        if (personPhone.isNotEmpty && t.receiverPhone != null) {
          return _arePhonesEqual(t.receiverPhone, personPhone);
        }
        return t.receiverName == personName;
      } else if (isMeReceiver) {
        // I received, checking if sender is this person
        if (personPhone.isNotEmpty) {
          return _arePhonesEqual(t.senderPhone, personPhone);
        }
        return t.senderName == personName;
      }
      return false;
    }).toList();
  }

  bool _arePhonesEqual(String? p1, String? p2) {
    if (p1 == null || p2 == null) return false;
    if (p1.contains('@') || p2.contains('@')) {
      return p1.toLowerCase().trim() == p2.toLowerCase().trim();
    }
    final n1 = p1.replaceAll(RegExp(r'\D'), '');
    final n2 = p2.replaceAll(RegExp(r'\D'), '');
    if (n1.isEmpty || n2.isEmpty) return false;
    return (n1.length >= 10 && n2.length >= 10)
        ? n1.substring(n1.length - 10) == n2.substring(n2.length - 10)
        : n1 == n2;
  }

  // Reuse existing calculation logic
  List<Map<String, dynamic>> _calculateUserBalances(
    List<LedgerTransaction> transactions,
    List<String> myIdentities,
    String? currentUserId,
  ) {
    // Filter hidden people
    final hiddenPeople = context.read<LedgerProvider>().hiddenPeople;

    Map<String, double> balances = {};
    Map<String, String> names = {};
    Map<String, String> phones = {};

    for (var t in transactions) {
      final isSent =
          (currentUserId != null && t.senderId == currentUserId) ||
          myIdentities.any((id) => _arePhonesEqual(t.senderPhone, id));
      final otherName = isSent ? t.receiverName : t.senderName;
      final otherPhone = isSent ? t.receiverPhone : t.senderPhone;

      // Skip if hidden
      if (hiddenPeople.contains(otherName)) continue;

      // Simple keying by name for now if phone is missing, but ideally phone
      final key = otherName;
      names[key] = otherName;

      // Store phone if available (prefer non-empty)
      if (otherPhone != null && otherPhone.isNotEmpty) {
        phones[key] = otherPhone;
      }

      balances[key] = (balances[key] ?? 0) + (isSent ? t.amount : -t.amount);
    }
    return balances.entries
        .map(
          (e) => {
            'name': names[e.key],
            'phone': phones[e.key] ?? '',
            'balance': e.value,
          },
        )
        .toList();
  }

  Widget _buildBalanceCard(
    double net,
    double rec,
    double sent,
    String currencySymbol,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

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
                Icons.account_balance_wallet_outlined,
                color: Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Net Balance', // Changed from Net Ledger
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
            '$currencySymbol${net.toStringAsFixed(0)}',
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
                    Row(
                      children: [
                        const Icon(
                          Icons.arrow_downward_rounded, // Money In (To Receive)
                          color: Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'To Receive', // User asked for "To Rec"
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$currencySymbol${rec.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF51CF66), // Green
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
                    Row(
                      children: [
                        const Icon(
                          Icons.arrow_upward_rounded, // Money Out (To Pay)
                          color: Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'To Pay',
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$currencySymbol${sent.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFFF6B6B), // Red
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
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

  Widget _buildActionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            Text(label, style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonGridItem(
    String name,
    String phone,
    double bal,
    List<LedgerTransaction> tx,
    List<String> myIdentities,
    String currencySymbol,
    String? currentUserId, {
    VoidCallback? onLongPress,
  }) {
    return GestureDetector(
      onLongPress: onLongPress,
      onTap: () {
        final provider = context.read<LedgerProvider>();
        final personTransactions = _getPersonTransactions(
          _isNotesMode
              ? provider.notes
              : [
                  ...provider.ledgerTransactions,
                  ...provider.incomingRequests,
                  ...provider.outgoingRequests,
                ],
          name,
          phone,
          myIdentities,
          currentUserId,
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PersonLedgerScreen(
              personName: name,
              personPhone: phone,
              currentBalance: bal,
              transactions: personTransactions,
              currencySymbol: currencySymbol,
              myIdentities: myIdentities,
              currentUserId: provider.currentUserId ?? '',
              isNotesMode: _isNotesMode,
              onAddTransaction:
                  (
                    pName,
                    pPhone,
                    amount,
                    desc, {
                    isReceived = false,
                    currentUserPhone,
                    currentUserEmail,
                  }) {
                    final userProvider = context.read<UserProvider>();
                    final currentUser = userProvider.user;

                    return context.read<LedgerProvider>().addLedgerTransaction(
                      pName,
                      pPhone,
                      amount,
                      desc,
                      isReceived: isReceived,
                      currentUserId: currentUser?.userId ?? '',
                      currentUserName: currentUser?.name ?? '',
                      currentUserPhone:
                          currentUserPhone ?? currentUser?.phone ?? '',
                      currentUserEmail: currentUserEmail ?? currentUser?.email,
                      customStatus: _isNotesMode ? 'notes' : null,
                    );
                  },
              onRemind: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'WhatsApp reminder not implemented in this view yet',
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(child: Text(name.isNotEmpty ? name[0] : '?')),
            const SizedBox(height: 8),
            Text(
              name,
              style: const TextStyle(color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '$currencySymbol${bal.abs()}',
              style: TextStyle(
                color: bal >= 0 ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPersonOptions(
    String name,
    String phone,
    String currentUserContact,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Person'),
              onTap: () {
                Navigator.pop(context);
                _showEditPersonDialog(name, phone);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Delete Person',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmDeletePerson(name, phone);
              },
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off, color: Colors.grey),
              title: const Text('Hide from Dashboard'),
              onTap: () async {
                Navigator.pop(context);
                final provider = context.read<LedgerProvider>();
                await provider.hidePerson(name);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Removed $name from view')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPersonDialog(String currentName, String currentPhone) {
    final nameController = TextEditingController(text: currentName);

    // Separate logic to extract country code if possible, default to IN (+91)
    String initialPhone = currentPhone;
    String selectedCountryCode = '+91';

    if (initialPhone.startsWith('+91')) {
      initialPhone = initialPhone.substring(3);
    } else if (initialPhone.startsWith('local:')) {
      initialPhone = ''; // displaying empty for simpler editing
    }

    final phoneController = TextEditingController(text: initialPhone);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Theme.of(context).cardColor,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Person',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: nameController,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Name required' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.withOpacity(0.5)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: CountryCodePicker(
                        onChanged: (code) {
                          selectedCountryCode = code.dialCode ?? '+91';
                        },
                        initialSelection: 'IN', // Default to India for now
                        favorite: const ['+91', 'IN'],
                        showCountryOnly: false,
                        showOnlyCountryWhenClosed: false,
                        padding: EdgeInsets.zero,
                        flagWidth: 24,
                        textStyle: GoogleFonts.inter(fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          labelText: 'Phone (Optional)',
                          helperText: 'For reminders & nudges',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.phone_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        final newName = nameController.text.trim();
                        final rawPhone = phoneController.text.trim();

                        final newPhone = rawPhone.isEmpty
                            ? ''
                            : '$selectedCountryCode$rawPhone';

                        Navigator.pop(context);

                        if (newName == currentName &&
                            newPhone == currentPhone) {
                          return;
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Updating person...')),
                        );

                        final success = await context
                            .read<LedgerProvider>()
                            .updatePerson(
                              oldName: currentName,
                              oldPhone: currentPhone,
                              newName: newName,
                              newPhone: newPhone,
                            );

                        if (success) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Person updated successfully'),
                              ),
                            );
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to update person'),
                              ),
                            );
                          }
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Save Changes',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeletePerson(String name, String phone) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Person'),
        content: Text(
          'Are you sure you want to delete $name and all their transactions? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Deleting person...')),
              );

              final success = await context.read<LedgerProvider>().deletePerson(
                name: name,
                phone: phone,
              );

              if (success) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Person deleted successfully'),
                    ),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to delete person')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showHiddenPeopleDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final hiddenPeople = context.watch<LedgerProvider>().hiddenPeople;

            return AlertDialog(
              title: const Text('Hidden People'),
              content: SizedBox(
                width: double.maxFinite,
                child: hiddenPeople.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text(
                          'No hidden people.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: hiddenPeople.length,
                        itemBuilder: (context, index) {
                          final name = hiddenPeople[index];
                          return ListTile(
                            title: Text(name),
                            trailing: IconButton(
                              icon: const Icon(Icons.visibility),
                              onPressed: () async {
                                await context
                                    .read<LedgerProvider>()
                                    .unhidePerson(name);
                                setState(() {});
                              },
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
