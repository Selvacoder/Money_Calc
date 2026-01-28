import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/ledger_transaction.dart';
import '../providers/ledger_provider.dart';
import '../providers/user_provider.dart';
import '../providers/currency_provider.dart';
import '../widgets/ledger_dashboard.dart';
import 'ledger_history_screen.dart';
import 'ledger/ledger_due_date_screen.dart';
import 'notification_screen.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  @override
  Widget build(BuildContext context) {
    // We need to pass data to History Screen, but Dashboard and DueDate access Provider directly.
    // Ideally HistoryScreen should also access Provider directly to be consistent,
    // but for now we follow its existing API which expects specific arguments.
    final ledgerProvider = context.watch<LedgerProvider>();
    final userProvider = context.watch<UserProvider>();
    final currencySymbol = context.watch<CurrencyProvider>().currencySymbol;
    final transactions = ledgerProvider.ledgerTransactions;
    // Construct multiple identities for correct filtering
    final myIdentities = [
      if (userProvider.user?.phone != null) userProvider.user!.phone!,
      if (userProvider.user?.email != null) userProvider.user!.email!,
    ].cast<String>();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: AppBar(
          title: const Text('Ledger'),
          backgroundColor: Theme.of(context).cardColor,
          actions: [
            Consumer<LedgerProvider>(
              builder: (context, provider, child) {
                final requestCount = provider.incomingRequests.length;
                return IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NotificationScreen(),
                      ),
                    );
                  },
                  icon: Badge(
                    isLabelVisible: requestCount > 0,
                    label: Text('$requestCount'),
                    child: const Icon(
                      Icons.notifications_outlined,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
            IconButton(
              onPressed: () {
                // Placeholder: Scan QR
              },
              icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
            ),
          ],
          bottom: TabBar(
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).colorScheme.primary,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'Dashboard'),
              Tab(text: 'Due Date'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Dashboard (Existing implementation moved to widget)
            const LedgerDashboard(),

            // Tab 2: Due Date (New Screen)
            const LedgerDueDateScreen(),

            // Tab 3: History (Existing Screen)
            LedgerHistoryScreen(
              transactions: transactions,
              myIdentities: myIdentities,
              currencySymbol: currencySymbol,
            ),
          ],
        ),
      ),
    );
  }
}
