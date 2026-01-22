import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:country_code_picker/country_code_picker.dart';
import '../../providers/ledger_provider.dart';
import '../../models/ledger_transaction.dart';
import '../../services/appwrite_service.dart';

class PersonLedgerScreen extends StatefulWidget {
  final String personName;
  final String personPhone;
  final double currentBalance;
  final List<LedgerTransaction> transactions;
  final String currencySymbol;
  final Function(String, String?, double, String, {bool isReceived})
  onAddTransaction;
  final Function() onRemind;
  final String currentUserContact;

  const PersonLedgerScreen({
    super.key,
    required this.personName,
    required this.personPhone,
    required this.currentBalance,
    required this.transactions,
    required this.currencySymbol,
    required this.onAddTransaction,
    required this.onRemind,
    required this.currentUserContact,
  });

  @override
  State<PersonLedgerScreen> createState() => _PersonLedgerScreenState();
}

class _PersonLedgerScreenState extends State<PersonLedgerScreen> {
  late List<LedgerTransaction> _localTransactions;
  late double _currentBalance;

  @override
  void initState() {
    super.initState();
    _localTransactions = List.from(widget.transactions);
    _currentBalance = widget.currentBalance;
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

  void _showSettleDialog() {
    final amountController = TextEditingController(
      text: _currentBalance.abs().toString(),
    );
    final descController = TextEditingController(text: 'Settlement');

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settle Up',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '${widget.currencySymbol} ',
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
                    if (amountController.text.isNotEmpty) {
                      final amount =
                          double.tryParse(amountController.text) ?? 0.0;
                      // Logic: If they owe me (balance > 0), I receive settlement.
                      // If I owe them (balance < 0), I send settlement (Lend -> but logically it's paying back).
                      // The main addTransaction logic:
                      // isReceived = true -> "Borrow Money" (I receive money).
                      // isReceived = false -> "Lend Money" (I give money).

                      // If Balance > 0 (They owe me): I should RECEIVE money to settle. So isReceived = true.
                      // If Balance < 0 (I owe them): I should GIVE money to settle. So isReceived = false.
                      final isReceived = _currentBalance > 0;

                      widget.onAddTransaction(
                        widget.personName,
                        widget.personPhone,
                        amount,
                        descController.text,
                        isReceived: isReceived,
                      );

                      // Optimistic Update
                      setState(() {
                        _currentBalance = 0; // Assuming full settlement
                        _localTransactions.add(
                          LedgerTransaction(
                            id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
                            senderId: isReceived
                                ? ''
                                : 'me', // simplistic check
                            senderName: isReceived ? widget.personName : 'Me',
                            senderPhone: isReceived
                                ? widget.personPhone
                                : widget.currentUserContact,
                            receiverName: isReceived ? 'Me' : widget.personName,
                            receiverPhone: isReceived
                                ? widget.currentUserContact
                                : widget.personPhone,
                            amount: amount,
                            description: descController.text,
                            dateTime: DateTime.now(),
                          ),
                        );
                      });

                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Settle Up'),
                ),
              ),
            ],
          ),
        ),
      ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack),
    );
  }

  Future<void> _handleNudge() async {
    // Show Selection Dialog immediately
    // We check for phone number validity inside the specific actions
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send Payment Reminder',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            // Option 1: In-App Notification
            ListTile(
              onTap: () async {
                Navigator.pop(context);
                if (_validatePhone()) {
                  await _sendInAppNudge();
                }
              },
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_active,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              title: Text(
                'In-App Nudge',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                'Notify instantly if they use MoneyCalc',
                style: GoogleFonts.inter(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            // Option 2: WhatsApp
            ListTile(
              onTap: () {
                Navigator.pop(context);
                if (_validatePhone()) {
                  _launchWhatsApp();
                }
              },
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chat, color: Color(0xFF25D366)),
              ),
              title: Text(
                'WhatsApp',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                'Send a pre-filled message',
                style: GoogleFonts.inter(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  bool _validatePhone() {
    if (widget.personPhone.isEmpty || widget.personPhone.startsWith('local:')) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Phone Number Required'),
          content: Text(
            'To send a nudge or reminder, please add a phone number for ${widget.personName}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showEditPersonDialog();
              },
              child: const Text('Add Number'),
            ),
          ],
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _sendInAppNudge() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checking user availability...'),
          duration: Duration(seconds: 1),
        ),
      );

      final user = await AppwriteService().getUserByPhone(widget.personPhone);

      if (user != null) {
        // User Exists -> Send Nudge
        await AppwriteService().sendNotification(
          userId: user['userId'],
          title: 'Payment Nudge',
          message: 'Friendly reminder to settle up!',
          type: 'nudge',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Nudge sent successfully!'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      } else {
        // User Doesn't Exist -> Suggest WhatsApp
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('User Not Found'),
              content: Text(
                '${widget.personName} is not on MoneyCalc yet. Would you like to send a WhatsApp reminder instead?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    _launchWhatsApp();
                  },
                  child: const Text('Open WhatsApp'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _launchWhatsApp() async {
    final phone = widget.personPhone.replaceAll(RegExp(r'[^\d+]'), '');
    final amount = NumberFormat('#,##0').format(_currentBalance.abs());

    // Construct message based on who owes whom
    String message = '';
    if (_currentBalance > 0) {
      message =
          'Hi ${widget.personName}, just a friendly reminder that you owe me ${widget.currencySymbol}$amount on MoneyCalc. Thanks!';
    } else {
      message =
          'Hi ${widget.personName}, I owe you ${widget.currencySymbol}$amount on MoneyCalc. Letting you know!';
    }

    final encodedMessage = Uri.encodeComponent(message);
    final url = Uri.parse('https://wa.me/$phone?text=$encodedMessage');

    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch WhatsApp';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open WhatsApp: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedTransactions = List<LedgerTransaction>.from(_localTransactions)
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    final isOwesYou = _currentBalance > 0;
    final isYouOwe = _currentBalance < 0;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.personName,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            if (widget.personPhone.isNotEmpty &&
                !widget.personPhone.startsWith('local:'))
              Text(
                widget.personPhone,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle_outline),
            onPressed: _showSettleDialog,
            tooltip: 'Settle Up',
          ),
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            onPressed: _handleNudge,
            tooltip: 'Nudge / Remind',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                _showEditPersonDialog();
              } else if (value == 'delete') {
                _confirmDeletePerson();
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20, color: Colors.blue),
                      SizedBox(width: 12),
                      Text('Edit Person'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: Colors.red),
                      SizedBox(width: 12),
                      Text(
                        'Delete Person',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner for Net Balance
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            color: Theme.of(context).cardColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Net Balance',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  isOwesYou
                      ? 'Owes You ${widget.currencySymbol}${NumberFormat('#,##0').format(_currentBalance.abs())}'
                      : (isYouOwe
                            ? 'You Owe ${widget.currencySymbol}${NumberFormat('#,##0').format(_currentBalance.abs())}'
                            : 'Settled'),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: isOwesYou
                        ? const Color(0xFF51CF66)
                        : (isYouOwe ? const Color(0xFFFF6B6B) : Colors.grey),
                  ),
                ),
              ],
            ),
          ),

          // Chat List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedTransactions.length,
              itemBuilder: (context, index) {
                final t = sortedTransactions[index];
                final isSentByMe = _arePhonesEqual(
                  t.senderPhone,
                  widget.currentUserContact,
                );

                // Check if it's a settlement
                final isSettlement = t.description.toLowerCase().contains(
                  'settl',
                );

                if (isSettlement) {
                  return Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 16,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Settlement Done',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.currencySymbol}${NumberFormat('#,##0').format(t.amount)} • ${DateFormat('MMM d, h:mm a').format(t.dateTime)}',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 300.ms);
                }

                return Align(
                  alignment: isSentByMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSentByMe
                          ? Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.1)
                          : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isSentByMe ? 16 : 4),
                        bottomRight: Radius.circular(isSentByMe ? 4 : 16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSentByMe ? 'You Gave' : 'You Got',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSentByMe
                                ? Theme.of(context).colorScheme.primary
                                : const Color(0xFF51CF66),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.currencySymbol}${NumberFormat('#,##0').format(t.amount)}',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onBackground,
                          ),
                        ),
                        if (t.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            t.description,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          DateFormat('MMM d, h:mm a').format(t.dateTime),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
              },
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Give / Get Buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildTransactionButton(
                          label: 'You Gave',
                          color: const Color(0xFFFF6B6B),
                          isReceived: false,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTransactionButton(
                          label: 'You Got',
                          color: const Color(0xFF51CF66),
                          isReceived: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionButton({
    required String label,
    required Color color,
    required bool isReceived,
  }) {
    return ElevatedButton(
      onPressed: () => _showTransactionDialog(isReceived: isReceived),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.2)),
        ),
      ),
      child: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
    );
  }

  void _showTransactionDialog({required bool isReceived}) {
    final amountController = TextEditingController();
    final descController = TextEditingController();

    // We use a local variable for the toggle state, initializing with the passed value
    bool currentIsReceived = isReceived;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isGave = !currentIsReceived;
          final primaryColor = currentIsReceived
              ? const Color(0xFF51CF66)
              : const Color(0xFFFF6B6B);

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: Theme.of(context).cardColor,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Title
                  Text(
                    'New Transaction',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Toggle Switch (Gave / Got)
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setDialogState(() => currentIsReceived = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isGave
                                    ? const Color(0xFFFF6B6B)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  'You Gave',
                                  style: GoogleFonts.inter(
                                    color: isGave ? Colors.white : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setDialogState(() => currentIsReceived = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: currentIsReceived
                                    ? const Color(0xFF51CF66)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  'You Got',
                                  style: GoogleFonts.inter(
                                    color: currentIsReceived
                                        ? Colors.white
                                        : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      prefixText: '${widget.currencySymbol} ',
                      prefixStyle: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      prefixIcon: const Icon(Icons.description_outlined),
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
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        if (amountController.text.isNotEmpty) {
                          final amount =
                              double.tryParse(amountController.text) ?? 0.0;

                          widget.onAddTransaction(
                            widget.personName,
                            widget.personPhone,
                            amount,
                            descController.text,
                            isReceived: currentIsReceived,
                          );

                          // Optimistic Update
                          setState(() {
                            if (currentIsReceived) {
                              _currentBalance -= amount;
                            } else {
                              _currentBalance += amount;
                            }

                            _localTransactions.add(
                              LedgerTransaction(
                                id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
                                senderId: currentIsReceived ? '' : 'me',
                                senderName: currentIsReceived
                                    ? widget.personName
                                    : 'Me',
                                senderPhone: currentIsReceived
                                    ? widget.personPhone
                                    : widget.currentUserContact,
                                receiverName: currentIsReceived
                                    ? 'Me'
                                    : widget.personName,
                                receiverPhone: currentIsReceived
                                    ? widget.currentUserContact
                                    : widget.personPhone,
                                amount: amount,
                                description: descController.text,
                                dateTime: DateTime.now(),
                              ),
                            );
                          });

                          Navigator.pop(context);
                        }
                      },
                      child: const Text(
                        'Save Record',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEditPersonDialog() {
    final nameController = TextEditingController(text: widget.personName);

    // Separate logic to extract country code if possible, default to IN (+91)
    String initialPhone = widget.personPhone;
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
                        initialSelection: 'IN',
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

                        Navigator.pop(context); // Close dialog

                        if (newName == widget.personName &&
                            newPhone == widget.personPhone) {
                          return;
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Updating person...')),
                        );

                        final success = await context
                            .read<LedgerProvider>()
                            .updatePerson(
                              oldName: widget.personName,
                              oldPhone: widget.personPhone,
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
                            Navigator.pop(
                              context,
                            ); // Return to Ledger Screen to refresh
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

  void _confirmDeletePerson() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Person'),
        content: Text(
          'Are you sure you want to delete ${widget.personName} and all their ${widget.transactions.length} transactions? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Deleting person...')),
              );

              final success = await context.read<LedgerProvider>().deletePerson(
                name: widget.personName,
                phone: widget.personPhone,
              );

              if (success) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Person deleted successfully'),
                    ),
                  );
                  Navigator.pop(context); // Return to Ledger Screen
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
}
