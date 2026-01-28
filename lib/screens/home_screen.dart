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
import 'ledger/ledger_due_date_screen.dart'; // NEW
import 'ledger_graph_screen.dart';
import 'personal_history_screen.dart';
import 'personal_graph_screen.dart';
import 'investment_history_screen.dart';
import 'investment_graph_screen.dart';
import 'account_screen.dart';
import 'category_screen.dart';
import 'ai_analyzer_screen.dart';

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
      appBar: AppBar(
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
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AccountScreen(),
                  ),
                );
              },
              icon: Icon(Icons.settings, color: theme.colorScheme.onSurface),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildToggleBtn('Personal', 0),
                  _buildToggleBtn('Ledger', 1),
                  _buildToggleBtn('Investment', 2),
                ],
              ),
            ),
          ),
        ),
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
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_filled),
              label: 'Home',
            ),
            if (_currentMode == 0)
              const NavigationDestination(
                icon: Icon(Icons.category),
                label: 'Category',
              ),
            if (_currentMode == 1) // Ledger Mode
              const NavigationDestination(
                icon: Icon(Icons.calendar_month),
                label: 'Due Date',
              ),
            if (_currentMode == 2) // Investment Mode
              const NavigationDestination(
                icon: Icon(Icons.auto_awesome),
                label: 'AI Analyzer',
              ),
            const NavigationDestination(
              icon: Icon(Icons.history),
              label: 'History',
            ),
            const NavigationDestination(
              icon: Icon(Icons.bar_chart),
              label: 'Report',
            ),
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
              _selectedIndex =
                  0; // Reset to Home when switching modes to avoid index mismatch
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

    // Index Mapping Logic
    // Mode 0: 0=Home, 1=Category, 2=History, 3=Report
    // Mode 1/2: 0=Home, 1=History, 2=Report

    // Simplified Logic Index Mapping:

    // Mode 0 (Personal): 0=Dash, 1=Category, 2=History, 3=Report
    // Mode 1 (Ledger):   0=Dash, 1=DueDate, 2=History, 3=Report
    // Mode 2 (Invest):   0=Dash, 1=AI,      2=History, 3=Report

    int adjustedIndex = 0;

    if (_currentMode == 0) {
      // Personal matches standard flow
      adjustedIndex = _selectedIndex;
    } else if (_currentMode == 1) {
      // Ledger: 0, 1(Due), 2(Hist), 3(Rep)
      // Since bottom bar has 4 items in this mode, _selectedIndex maps 1:1 to desired tabs
      adjustedIndex = _selectedIndex;
    } else if (_currentMode == 2) {
      // Investment: 0, 1(AI), 2(Hist), 3(Rep)
      // Standard 1:1 mapping
      adjustedIndex = _selectedIndex;
    }

    // However, the SWITCH below uses global "Content Type" IDs which were previously:
    // 0: Dash, 1: Category, 2: AI, 3: History, 4: Report
    // We need to map `adjustedIndex` to these `case` IDs.

    int contentId = 0;

    if (_currentMode == 0) {
      // 0->0, 1->1, 2->3, 3->4
      if (_selectedIndex == 0)
        contentId = 0;
      else if (_selectedIndex == 1)
        contentId = 1; // Category
      else if (_selectedIndex == 2)
        contentId = 3; // History
      else if (_selectedIndex == 3)
        contentId = 4; // Report
    } else if (_currentMode == 1) {
      // 0->0, 1->5 (NEW DueDate), 2->3 (History), 3->4 (Report)
      if (_selectedIndex == 0)
        contentId = 0;
      else if (_selectedIndex == 1)
        contentId = 5; // Due Date
      else if (_selectedIndex == 2)
        contentId = 3; // History
      else if (_selectedIndex == 3)
        contentId = 4; // Report
    } else {
      // 0->0, 1->2 (AI), 2->3 (History), 3->4 (Report)
      if (_selectedIndex == 0)
        contentId = 0;
      else if (_selectedIndex == 1)
        contentId = 2; // AI
      else if (_selectedIndex == 2)
        contentId = 3; // History
      else if (_selectedIndex == 3)
        contentId = 4; // Report
    }

    switch (contentId) {
      case 0: // Dashboard
        if (_currentMode == 0) return const PersonalDashboard();
        if (_currentMode == 1) return const LedgerDashboard();
        return const InvestmentDashboard();

      case 1: // Category (Personal)
        return const CategoryScreen();

      case 2: // AI Analyzer (Investment)
        return const AIAnalyzerScreen();

      case 3: // History
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
        return const InvestmentHistoryScreen();

      case 4: // Graph/Report
        if (_currentMode == 0) return const PersonalGraphScreen();
        if (_currentMode == 1) {
          return LedgerGraphScreen(
            transactions: ledgerTransactions,
            currentUserContact: currentUserContact,
            currencySymbol: currencySymbol,
          );
        }
        return const InvestmentGraphScreen();

      case 5: // Due Date (Ledger)
        return const LedgerDueDateScreen();

      default:
        return const SizedBox.shrink();
    }
  }
}
