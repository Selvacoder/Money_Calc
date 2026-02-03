import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/ledger_provider.dart';
import '../providers/dutch_provider.dart';
import '../models/ledger_transaction.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Refresh Dutch data to ensure requests are visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<DutchProvider>().fetchGlobalData();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        title: Text(
          'Notifications',
          style: GoogleFonts.outfit(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurface.withOpacity(0.6),
          indicatorColor: colorScheme.primary,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Received'),
            Tab(text: 'Sent'),
          ],
        ),
      ),
      body: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: context.read<LedgerProvider>()),
          ChangeNotifierProvider.value(value: context.read<DutchProvider>()),
        ],
        child: Consumer2<LedgerProvider, DutchProvider>(
          builder: (context, ledgerProvider, dutchProvider, child) {
            if (ledgerProvider.isLoading || dutchProvider.isLoading) {
              return Center(
                child: CircularProgressIndicator(color: colorScheme.primary),
              );
            }

            return TabBarView(
              controller: _tabController,
              children: [
                _buildReceivedRequests(
                  context,
                  ledgerProvider,
                  dutchProvider,
                  theme,
                ),
                _buildSentRequests(
                  context,
                  ledgerProvider,
                  dutchProvider,
                  theme,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildReceivedRequests(
    BuildContext context,
    LedgerProvider ledgerProvider,
    DutchProvider dutchProvider,
    ThemeData theme,
  ) {
    final ledgerRequests = ledgerProvider.incomingRequests;
    final dutchRequests = dutchProvider.incomingSettlementRequests;
    final colorScheme = theme.colorScheme;

    if (ledgerRequests.isEmpty && dutchRequests.isEmpty) {
      return _buildEmptyState(
        'No pending requests',
        Icons.inbox_outlined,
        colorScheme,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (ledgerRequests.isNotEmpty) ...[
          _buildSectionHeader('Ledger Requests', colorScheme),
          ...ledgerRequests.map(
            (tx) => _buildRequestCard(
              context,
              ledgerProvider,
              tx,
              isReceived: true,
              theme: theme,
            ),
          ),
        ],
        if (dutchRequests.isNotEmpty) ...[
          _buildSectionHeader('Split Requests', colorScheme),
          ...dutchRequests.map(
            (req) => _buildDutchRequestCard(
              context,
              dutchProvider,
              req,
              isReceived: true,
              theme: theme,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSentRequests(
    BuildContext context,
    LedgerProvider ledgerProvider,
    DutchProvider dutchProvider,
    ThemeData theme,
  ) {
    final ledgerRequests = ledgerProvider.outgoingRequests;
    final dutchRequests = dutchProvider.outgoingSettlementRequests;
    final colorScheme = theme.colorScheme;

    if (ledgerRequests.isEmpty && dutchRequests.isEmpty) {
      return _buildEmptyState(
        'No sent requests',
        Icons.outbox_outlined,
        colorScheme,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (ledgerRequests.isNotEmpty) ...[
          _buildSectionHeader('Ledger Requests', colorScheme),
          ...ledgerRequests.map(
            (tx) => _buildRequestCard(
              context,
              ledgerProvider,
              tx,
              isReceived: false,
              theme: theme,
            ),
          ),
        ],
        if (dutchRequests.isNotEmpty) ...[
          _buildSectionHeader('Split Requests', colorScheme),
          ...dutchRequests.map(
            (req) => _buildDutchRequestCard(
              context,
              dutchProvider,
              req,
              isReceived: false,
              theme: theme,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    String message,
    IconData icon,
    ColorScheme colorScheme,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.outfit(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(
    BuildContext context,
    LedgerProvider provider,
    LedgerTransaction tx, {
    required bool isReceived,
    required ThemeData theme,
  }) {
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isReceived ? 'Request from' : 'Sent to',
                    style: GoogleFonts.outfit(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isReceived ? tx.senderName : tx.receiverName,
                    style: GoogleFonts.outfit(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isReceived
                      ? colorScheme.primary.withOpacity(0.1)
                      : Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isReceived ? 'Needed Action' : 'Pending',
                  style: GoogleFonts.outfit(
                    color: isReceived ? colorScheme.primary : Colors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            tx.description.isEmpty ? 'No description' : tx.description,
            style: GoogleFonts.outfit(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 12),
          Divider(color: theme.dividerColor),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amount',
                    style: GoogleFonts.outfit(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '₹${tx.amount.abs().toStringAsFixed(0)}',
                    style: GoogleFonts.outfit(
                      color: colorScheme.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (isReceived)
                Row(
                  children: [
                    TextButton(
                      onPressed: () async {
                        await provider.rejectLedgerTransaction(tx.id);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                      child: Text(
                        'Decline',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        await provider.acceptLedgerTransaction(tx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Accept',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                )
              else
                TextButton(
                  onPressed: () {
                    provider.deleteLedgerTransaction(tx.id);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.error,
                  ),
                  child: const Text("Cancel"),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDutchRequestCard(
    BuildContext context,
    DutchProvider provider,
    Map<String, dynamic> req, {
    required bool isReceived,
    required ThemeData theme,
  }) {
    final colorScheme = theme.colorScheme;
    final amount = (req['amount'] as num).toDouble();
    final payerId = req['payerId'];
    final receiverId = req['receiverId'];

    String getMemberName(String id) {
      final profile = provider.currentGroupMemberProfiles.firstWhere(
        (p) => p['userId'] == id,
        orElse: () => {},
      );
      return profile['name'] ?? id.substring(0, 6);
    }

    final String senderName = getMemberName(payerId);
    final String receiverName = getMemberName(receiverId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isReceived ? 'Split Pay from' : 'Split Pay to',
                    style: GoogleFonts.outfit(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isReceived ? senderName : receiverName,
                    style: GoogleFonts.outfit(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isReceived
                      ? colorScheme.primary.withOpacity(0.1)
                      : Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isReceived ? 'Approve Pay' : 'Pending',
                  style: GoogleFonts.outfit(
                    color: isReceived ? colorScheme.primary : Colors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Payment request for group expense',
            style: GoogleFonts.outfit(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 12),
          Divider(color: theme.dividerColor),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amount',
                    style: GoogleFonts.outfit(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '₹${amount.toStringAsFixed(2)}',
                    style: GoogleFonts.outfit(
                      color: colorScheme.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (isReceived)
                Row(
                  children: [
                    TextButton(
                      onPressed: () async {
                        await provider.rejectSettlement(req['id']);
                        if (context.mounted) provider.fetchGlobalData();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                      child: Text(
                        'Decline',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        await provider.approveSettlement(req['id']);
                        if (context.mounted) provider.fetchGlobalData();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Accept',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                )
              else
                TextButton(
                  onPressed: () async {
                    await provider.rejectSettlement(req['id']);
                    if (context.mounted) provider.fetchGlobalData();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.error,
                  ),
                  child: const Text("Cancel"),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
