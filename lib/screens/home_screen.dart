import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

import '../providers/transaction_provider.dart';
import '../providers/user_provider.dart';
import '../providers/ledger_provider.dart';
import '../providers/currency_provider.dart';
import '../widgets/personal_dashboard.dart';
import '../widgets/ledger_dashboard.dart';

import 'ledger_history_screen.dart';
import 'ledger_graph_screen.dart';
import 'personal_history_screen.dart';
import 'personal_graph_screen.dart';
import 'account_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isPersonalMode = true;
  final LocalAuthentication auth = LocalAuthentication();

  Future<void> _authenticate() async {
    try {
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Please authenticate to access Ledger',
        options: const AuthenticationOptions(stickyAuth: true),
      );
      if (didAuthenticate) {
        setState(() {
          _isPersonalMode = false;
        });
      }
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Authentication error: ${e.message}')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<TransactionProvider>().fetchData();
      context.read<LedgerProvider>().fetchLedgerTransactions();
      // context.read<UserProvider>().loadUser(); // Removed to prevent infinite loop with AuthWrapper
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar:
          _selectedIndex ==
              3 // Hide AppBar for Account Screen to use its own title
          ? null
          : AppBar(
              automaticallyImplyLeading: false, // Removes the back button
              toolbarHeight: 80, // Taller app bar for custom layout
              backgroundColor: Colors.transparent,
              elevation: 0,
              titleSpacing: 20,
              title: Row(
                children: [
                  // App Icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.calculate_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'MoneyCalc',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: theme.appBarTheme.titleTextStyle?.color,
                    ),
                  ),
                ],
              ),
              actions: [
                // Custom Toggle Switch
                Container(
                  margin: const EdgeInsets.only(right: 20),
                  padding: const EdgeInsets.all(2), // Reduced padding
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      _buildToggleBtn('Personal', _isPersonalMode),
                      _buildToggleBtn('Ledger', !_isPersonalMode),
                    ],
                  ),
                ),
              ],
            ),
      body: _buildBody(),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          labelTextStyle: MaterialStateProperty.all(
            GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onItemTapped,
          backgroundColor:
              theme.cardColor, // Use theme card color (darker surface)
          indicatorColor: theme.colorScheme.primary.withOpacity(0.2),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_filled), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.history), label: 'History'),
            NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Report'),
            NavigationDestination(icon: Icon(Icons.person), label: 'Account'),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleBtn(String text, bool isActive) {
    return GestureDetector(
      onTap: () {
        if (!isActive) {
          if (text == 'Ledger') {
            _authenticate();
          } else {
            setState(() {
              _isPersonalMode = true;
            });
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ), // Reduced padding
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            color: isActive ? Colors.white : Colors.grey,
            fontWeight: FontWeight.w600,
            fontSize: 12, // Reduced font size
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final ledgerProvider = context.watch<LedgerProvider>();
    final userProvider = context.watch<UserProvider>();
    final currencySymbol = context.watch<CurrencyProvider>().currencySymbol;
    final currentUserContact = userProvider.user?.phone ?? '';
    final ledgerTransactions = ledgerProvider.ledgerTransactions;

    switch (_selectedIndex) {
      case 0:
        return _isPersonalMode
            ? const PersonalDashboard()
            : const LedgerDashboard();
      case 1: // History
        return _isPersonalMode
            ? PersonalHistoryScreen(
                transactions: context.watch<TransactionProvider>().transactions,
                currencySymbol: currencySymbol,
              )
            : LedgerHistoryScreen(
                transactions: ledgerTransactions,
                currentUserContact: currentUserContact,
                currencySymbol: currencySymbol,
              );
      case 2: // Graph
        return _isPersonalMode
            ? const PersonalGraphScreen()
            : LedgerGraphScreen(
                transactions: ledgerTransactions,
                currentUserContact: currentUserContact,
                currencySymbol: currencySymbol,
              );
      case 3: // Account
        return const AccountScreen();
      default:
        return const SizedBox.shrink();
    }
  }
}
