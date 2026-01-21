import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/ledger_transaction.dart';

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
          if (widget.personPhone.isNotEmpty &&
              !widget.personPhone.startsWith('local:')) ...[
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              onPressed: _showSettleDialog,
              tooltip: 'Settle Up',
            ),
            IconButton(
              icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
              onPressed: widget.onRemind,
              tooltip: 'WhatsApp Reminder',
            ),
          ],
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
                  // Settle Up Button
                  if (_currentBalance != 0) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showSettleDialog,
                        icon: const Icon(Icons.check_circle_outline, size: 20),
                        label: Text(
                          'Settle Up',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.tertiaryContainer,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onTertiaryContainer,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

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
                isReceived ? 'You Got' : 'You Gave',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isReceived
                      ? const Color(0xFF51CF66)
                      : const Color(0xFFFF6B6B),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                autofocus: true,
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

                      widget.onAddTransaction(
                        widget.personName,
                        widget.personPhone,
                        amount,
                        descController.text,
                        isReceived: isReceived,
                      );

                      // Optimistic Update
                      setState(() {
                        // isReceived (Borrow) -> I owe them -> Balance decreases (becomes more negative)
                        // !isReceived (Lend) -> They owe me -> Balance increases (becomes more positive)
                        // Wait, in my logic:
                        // Balance > 0 -> They Owe Me.
                        // Balance < 0 -> I Owe Them.

                        // If I LEND (Gave) -> Balance should INCREASE (They owe me more).
                        // If I BORROW (Got) -> Balance should DECREASE (I owe them more).

                        if (isReceived) {
                          _currentBalance -= amount;
                        } else {
                          _currentBalance += amount;
                        }

                        _localTransactions.add(
                          LedgerTransaction(
                            id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
                            senderId: isReceived ? '' : 'me',
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
                  child: const Text('Save Record'),
                ),
              ),
            ],
          ),
        ),
      ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack),
    );
  }
}
