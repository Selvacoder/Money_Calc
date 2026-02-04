import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:hive_flutter/hive_flutter.dart';

import 'providers/theme_provider.dart';
import 'providers/currency_provider.dart';
import 'providers/user_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/ledger_provider.dart';

import 'models/investment.dart';
import 'models/investment_transaction.dart';
import 'models/transaction.dart';
import 'models/category.dart';
import 'models/item.dart';
import 'models/ledger_transaction.dart';
import 'models/user_profile.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/ledger_screen.dart';
import 'providers/investment_provider.dart';
import 'providers/dutch_provider.dart';
import 'providers/notification_provider.dart';

import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  // Cache cleared line removed for persistence

  Hive.registerAdapter(TransactionAdapter());
  Hive.registerAdapter(CategoryAdapter());
  Hive.registerAdapter(ItemAdapter());
  Hive.registerAdapter(LedgerTransactionAdapter());
  Hive.registerAdapter(InvestmentAdapter());
  Hive.registerAdapter(InvestmentTransactionAdapter());
  Hive.registerAdapter(UserProfileAdapter());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => LedgerProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => CurrencyProvider()),
        ChangeNotifierProvider(create: (_) => InvestmentProvider()),
        ChangeNotifierProvider(create: (_) => DutchProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: Consumer2<UserProvider, ThemeProvider>(
        builder: (context, userProvider, themeProvider, _) {
          return MaterialApp(
            title: 'Money Calc',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: themeProvider.seedColor,
                brightness: Brightness.light,
              ),
              useMaterial3: true,
              scaffoldBackgroundColor: Colors.white,
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.white,
                elevation: 0,
                iconTheme: IconThemeData(color: Colors.black),
                titleTextStyle: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: themeProvider.seedColor,
                brightness: Brightness.dark,
                surface: const Color(0xFF1E1E1E),
                background: const Color(0xFF121212),
                error: const Color(0xFFFF6B6B),
                errorContainer: const Color(0xFF422222),
                onErrorContainer: const Color(0xFFFFD9D9),
              ),
              useMaterial3: true,
              scaffoldBackgroundColor: const Color(0xFF121212),
              cardColor: const Color(0xFF1E1E1E),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF121212),
                elevation: 0,
                iconTheme: IconThemeData(color: Colors.white),
                titleTextStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            home: const AuthWrapper(),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/signup': (context) => const SignUpScreen(),
              '/home': (context) => const HomeScreen(),
              '/ledger': (context) => const LedgerScreen(),
            },
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    // Check Auth
    await context.read<UserProvider>().checkAuthStatus();

    // Init Notifications
    await NotificationService().init();
    await NotificationService().requestPermissions();

    // Setup Notification Provider
    if (mounted) {
      final user = context.read<UserProvider>().user;
      if (user != null) {
        context.read<NotificationProvider>().init(user.userId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, auth, _) {
        if (auth.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return auth.isAuthenticated ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}
