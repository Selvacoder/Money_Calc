import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/dutch_provider.dart';

class DutchReportsScreen extends StatelessWidget {
  final bool isGlobal;
  const DutchReportsScreen({super.key, this.isGlobal = false});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DutchProvider>();
    final balances = isGlobal
        ? provider.globalBalances
        : provider.groupBalances;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Reports',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
      body: balances.isEmpty
          ? Center(
              child: Text(
                'No data available',
                style: GoogleFonts.inter(color: Colors.grey),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Net Balances',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...balances.entries.map((entry) {
                    final userId = entry.key;
                    final amount = entry.value;
                    final isOwed = amount > 0;
                    final isSettled = amount.abs() < 0.01;

                    if (isSettled) return const SizedBox.shrink();

                    final userProfile = provider.currentGroupMemberProfiles
                        .firstWhere(
                          (p) => p['userId'] == userId,
                          orElse: () => {},
                        );
                    final userName = userProfile['name'] ?? userId;
                    final initials = userName.isNotEmpty
                        ? userName[0].toUpperCase()
                        : '?';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isOwed
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: isOwed
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            child: Text(
                              initials,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                color: isOwed ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              userName,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                isOwed ? 'gets back' : 'owes',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                '₹${amount.abs().toStringAsFixed(2)}',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isOwed ? Colors.green : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 32),
                  // Future: Add "Settlement Plan" - who pays whom
                ],
              ),
            ),
    );
  }
}
