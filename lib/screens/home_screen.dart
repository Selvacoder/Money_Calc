import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/transaction_provider.dart';
import '../providers/user_provider.dart';
import '../providers/ledger_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/investment_provider.dart';
import '../widgets/personal_dashboard.dart';
import '../widgets/ledger_dashboard.dart';
import '../widgets/investment_dashboard.dart';

import 'ledger_history_screen.dart';
import 'ledger_graph_screen.dart';
import 'personal_history_screen.dart';
import 'personal_graph_screen.dart';
import 'investment_history_screen.dart';
import 'investment_graph_screen.dart';
import 'account_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  // 0: Personal, 1: Ledger, 2: Investment
  int _currentMode = 0;
  final LocalAuthentication auth = LocalAuthentication();

  Future<void> _authenticate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool isBiometricEnabled =
          prefs.getBool('biometric_enabled') ?? false;

      if (!isBiometricEnabled) {
        setState(() {
          _currentMode = 1; // Switch to Ledger
        });
        return;
      }

      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Please authenticate to access Ledger',
        options: const AuthenticationOptions(stickyAuth: true),
      );
      if (didAuthenticate) {
        setState(() {
          _currentMode = 1; // Switch to Ledger
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
      context.read<InvestmentProvider>().fetchInvestments();
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

    // Dynamic Title based on mode? Or generic?
    // User requested toggle inside AppBar actions.

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar:
          _selectedIndex ==
              3 // Hide AppBar for Account Screen
          ? null
          : AppBar(
              automaticallyImplyLeading: false,
              toolbarHeight: 80,
              backgroundColor: Colors.transparent,
              elevation: 0,
              titleSpacing: 20,
              title: Row(
                children: [
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
                  // Show "Invest" or "Ledger" or "MoneyCalc" based on mode?
                  // Keeping generic "MoneyCalc" title as per design
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
                // Custom Toggle Switch (3 states)
                Container(
                  margin: const EdgeInsets.only(right: 20),
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      _buildToggleBtn('Personal', 0),
                      _buildToggleBtn('Ledger', 1),
                      _buildToggleBtn('Invest', 2),
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
          backgroundColor: theme.cardColor,
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

  Widget _buildToggleBtn(String text, int modeIndex) {
    final isActive = _currentMode == modeIndex;
    return GestureDetector(
      onTap: () {
        if (!isActive) {
          if (modeIndex == 1) {
            // Ledger needs auth
            _authenticate();
          } else {
            setState(() {
              _currentMode = modeIndex;
            });
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            fontSize: 12,
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
      case 0: // Dashboard
        if (_currentMode == 0) return const PersonalDashboard();
        if (_currentMode == 1) return const LedgerDashboard();
        return const InvestmentDashboard();

      case 1: // History
        if (_currentMode == 0) {
          return PersonalHistoryScreen(
            transactions: context.watch<TransactionProvider>().transactions,
            currencySymbol: currencySymbol,
          );
        }
        if (_currentMode == 1) {
          return LedgerHistoryScreen(
            transactions: ledgerTransactions,
            currentUserContact: currentUserContact,
            currencySymbol: currencySymbol,
          );
        }
        return const InvestmentHistoryScreen(); // Ensure arguments passed if needed later

      case 2: // Graph/Report
        if (_currentMode == 0) return const PersonalGraphScreen();
        if (_currentMode == 1) {
          return LedgerGraphScreen(
            transactions: ledgerTransactions,
            currentUserContact: currentUserContact,
            currencySymbol: currencySymbol,
          );
        }
        return const InvestmentGraphScreen();

      case 3: // Account
        return const AccountScreen();
      default:
        return const SizedBox.shrink();
    }
  }
}
