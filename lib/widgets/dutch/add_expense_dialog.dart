import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/dutch_provider.dart';

class AddExpenseDialog extends StatefulWidget {
  final String groupId;
  final List<Map<String, dynamic>> members;
  final List<String> allMemberIds;

  const AddExpenseDialog({
    super.key,
    required this.groupId,
    required this.members,
    required this.allMemberIds,
  });

  @override
  State<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<AddExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  String _selectedPayerId = '';
  String _splitType = 'equal'; // 'equal' or 'exact'
  final Map<String, bool> _involvedMembers = {};
  final Map<String, double> _exactAmounts = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Default payer is current user (expense creator)
    // Find current user by checking context.read
    // Note: We can't access Provider in initState, so we'll set it in didChangeDependencies
    _selectedPayerId = widget.members.isNotEmpty
        ? widget.members.first['userId']
        : '';

    // Default everyone is involved in equal split
    for (var m in widget.members) {
      _involvedMembers[m['userId']] = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Set current user as default payer if not already set
    if (widget.members.isNotEmpty &&
        (_selectedPayerId.isEmpty ||
            _selectedPayerId == widget.members.first['userId'])) {
      final provider = context.read<DutchProvider>();
      final currentUserId = provider.currentUserId ?? '';
      if (currentUserId.isNotEmpty) {
        _selectedPayerId = currentUserId;
      }
    }
  }

  void _submit() async {
    if (_isSubmitting) return; // Prevent double-click
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final description = _descriptionController.text.trim();
    final amount = double.parse(_amountController.text);
    final provider = context.read<DutchProvider>();

    String splitData = '';
    if (_splitType == 'equal') {
      final beneficiaries = _involvedMembers.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();
      if (beneficiaries.isEmpty) {
        _showError('Select at least one person to split with');
        setState(() => _isSubmitting = false);
        return;
      }
      splitData = jsonEncode(beneficiaries);
    } else {
      // Exact split logic
      final totalExact = _exactAmounts.values.fold(
        0.0,
        (sum, val) => sum + val,
      );
      if ((totalExact - amount).abs() > 0.1) {
        _showError(
          'Exact amounts must sum up to ₹$amount (Current: ₹$totalExact)',
        );
        setState(() => _isSubmitting = false);
        return;
      }
      splitData = jsonEncode(_exactAmounts);
    }

    try {
      await provider.addExpense(
        description: description,
        amount: amount,
        category: 'General',
        paidBy: _selectedPayerId,
        splitType: _splitType,
        splitData: splitData,
        groupMembers: widget.allMemberIds,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError('Failed to add expense: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Expense',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                    hintText: 'e.g. Dinner, Rent',
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (double.tryParse(v) == null) return 'Invalid number';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                if (widget.members.isEmpty)
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 48,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Waiting for group members...',
                          style: GoogleFonts.inter(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const CircularProgressIndicator(),
                      ],
                    ),
                  )
                else ...[
                  // Payer Selection
                  Text(
                    'Paid By',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedPayerId.isEmpty && widget.members.isNotEmpty
                        ? widget.members.first['userId']
                        : _selectedPayerId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: widget.members.map((m) {
                      return DropdownMenuItem(
                        value: m['userId'] as String,
                        child: Text(m['name'] ?? 'Unknown'),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedPayerId = v!),
                  ),
                ],
                const SizedBox(height: 16),

                // Split Type
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Split Type',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        FilterChip(
                          label: const Text('Equal'),
                          selected: _splitType == 'equal',
                          onSelected: (s) =>
                              setState(() => _splitType = 'equal'),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Exact'),
                          selected: _splitType == 'exact',
                          onSelected: (s) =>
                              setState(() => _splitType = 'exact'),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(),

                // Split List
                ...widget.members.map((m) {
                  final uid = m['userId'] as String;
                  if (_splitType == 'equal') {
                    return CheckboxListTile(
                      title: Text(m['name'] ?? 'Unknown'),
                      value: _involvedMembers[uid] ?? false,
                      onChanged: (v) =>
                          setState(() => _involvedMembers[uid] = v!),
                    );
                  } else {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text(m['name'] ?? 'Unknown')),
                          SizedBox(
                            width: 100,
                            child: TextFormField(
                              decoration: const InputDecoration(
                                prefixText: '₹ ',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 0,
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (v) {
                                _exactAmounts[uid] = double.tryParse(v) ?? 0.0;
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                }),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Add Expense'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
