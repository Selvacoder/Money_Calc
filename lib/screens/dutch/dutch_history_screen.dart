import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/dutch_provider.dart';

class DutchHistoryScreen extends StatefulWidget {
  final bool isGlobal;
  const DutchHistoryScreen({super.key, this.isGlobal = false});

  @override
  State<DutchHistoryScreen> createState() => _DutchHistoryScreenState();
}

class _DutchHistoryScreenState extends State<DutchHistoryScreen> {
  String _filter = 'All'; // All, Expenses, Settlements

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DutchProvider>();
    List<Map<String, dynamic>> expenses = widget.isGlobal
        ? provider.globalExpenses
        : provider.currentGroupExpenses;
    List<Map<String, dynamic>> settlements = widget.isGlobal
        ? provider.globalSettlements
        : provider.currentGroupSettlements;

    // Apply filters
    if (_filter == 'Expenses') settlements = [];
    if (_filter == 'Settlements') expenses = [];

    // Merge and sort
    final List<Map<String, dynamic>> allItems = [
      ...expenses.map((e) => {...e, 'type': 'expense'}),
      ...settlements.map((s) => {...s, 'type': 'settlement'}),
    ];

    allItems.sort((a, b) {
      final dateA =
          DateTime.tryParse(a['dateTime'] ?? '') ??
          DateTime.tryParse(a['\$createdAt'] ?? '') ??
          DateTime(1970);
      final dateB =
          DateTime.tryParse(b['dateTime'] ?? '') ??
          DateTime.tryParse(b['\$createdAt'] ?? '') ??
          DateTime(1970);
      return dateB.compareTo(dateA); // Newest first
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Go Dutch History',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Filter Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: ['All', 'Expenses', 'Settlements'].map((f) {
                final isSelected = _filter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f),
                    selected: isSelected,
                    onSelected: (val) => setState(() => _filter = f),
                    selectedColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    labelStyle: GoogleFonts.inter(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: allItems.isEmpty
                ? Center(
                    child: Text(
                      'No activity found',
                      style: GoogleFonts.inter(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: allItems.length,
                    itemBuilder: (context, index) {
                      final item = allItems[index];
                      final isExpense = item['type'] == 'expense';
                      final status = item['status'] ?? 'pending';
                      final date =
                          DateTime.tryParse(item['dateTime'] ?? '') ??
                          DateTime.tryParse(item['\$createdAt'] ?? '') ??
                          DateTime.now();
                      final formattedDate =
                          '${date.day}/${date.month}/${date.year}';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: status == 'completed'
                                ? Colors.green.withOpacity(0.1)
                                : status == 'rejected'
                                ? Colors.red.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isExpense
                                        ? Colors.red.withOpacity(0.1)
                                        : Colors.blue.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isExpense
                                        ? Icons.receipt_long
                                        : Icons.handshake,
                                    color: isExpense ? Colors.red : Colors.blue,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              isExpense
                                                  ? item['description']
                                                  : 'Payment to ${provider.currentGroupMemberProfiles.firstWhere((p) => p['userId'] == item['receiverId'], orElse: () => {})['name'] ?? 'Member'}',
                                              style: GoogleFonts.inter(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          _StatusBadge(status: status),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Paid by ${provider.currentGroupMemberProfiles.firstWhere((p) => p['userId'] == item['payerId'], orElse: () => {})['name'] ?? 'Member'}',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '₹${item['amount']}',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isExpense
                                            ? Colors.red
                                            : Colors.blue,
                                      ),
                                    ),
                                    Text(
                                      formattedDate,
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            // Action Buttons if pending & user is receiver
                            if (status == 'pending' && !widget.isGlobal)
                              _buildActionButtons(context, item, provider),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    Map<String, dynamic> item,
    DutchProvider provider,
  ) {
    final isExpense = item['type'] == 'expense';
    final currentUserId = provider.currentUserId;

    // Only allow approval if user is the receiver of settlement
    // Or if it's an expense and user is not the payer (maybe?)
    bool canApprove = false;
    if (!isExpense && item['receiverId'] == currentUserId) {
      canApprove = true;
    }

    if (!canApprove) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () {
              if (isExpense) {
                provider.rejectExpense(item['id']);
              } else {
                provider.rejectSettlement(item['id']);
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('Reject'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              if (isExpense) {
                provider.approveExpense(item['id']);
              } else {
                provider.approveSettlement(item['id']);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'completed':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5), width: 0.5),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
