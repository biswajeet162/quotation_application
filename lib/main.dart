import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pages/products_page.dart';
import 'pages/create_quotation_page.dart';
import 'pages/login_page.dart';
import 'pages/user_management_page.dart';
import 'pages/password_reset_page.dart';
import 'pages/settings_page.dart';
import 'pages/companies_page.dart';
import 'pages/quotation_history_page.dart';
import 'pages/sync_logs_page.dart';
import 'widgets/navigation_sidebar.dart';
import 'widgets/page_header.dart';
import 'services/auth_service.dart';
import 'services/auto_sync_service.dart';
import 'services/google_auth_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthService(),
      child: MaterialApp(
        title: 'Quotation Application',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const AuthWrapper(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        if (authService.isAuthenticated) {
          return const MainScreen();
        } else {
          return const LoginPage();
        }
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool _hasQuotationData = false;
  final GlobalKey<QuotationHistoryPageState> _quotationHistoryKey = GlobalKey<QuotationHistoryPageState>();

  @override
  void initState() {
    super.initState();
    // Initialize auto-sync on app startup
    _initializeAutoSync();
  }

  Future<void> _initializeAutoSync() async {
    // Wait a bit for the app to fully initialize
    await Future.delayed(const Duration(seconds: 2));
    
    // Check if Google Drive is authenticated
    if (GoogleAuthService.instance.isSignedIn) {
      // Start automatic pull timer
      AutoSyncService.instance.startAutoPull();
      
      // Perform initial pull on app startup
      AutoSyncService.instance.performPull();
    }
  }

  @override
  void dispose() {
    AutoSyncService.instance.stopAutoPull();
    super.dispose();
  }

  List<Widget> _buildPages(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isAdmin = authService.isAdmin;
    
    final pages = [
      const ProductsPage(),
      const PlaceholderPage(title: 'Dashboard'),
      CreateQuotationPage(
        onDataChanged: _updateQuotationDataStatus,
      ),
      QuotationHistoryPage(key: _quotationHistoryKey),
      const CompaniesPage(),
      const SyncLogsPage(),
      SettingsPage(userEmail: authService.currentUser?.email ?? ''),
    ];

    // Insert user management page for admin (index 5, before Sync Monitor)
    if (isAdmin) {
      pages.insert(5, const UserManagementPage());
    }

    return pages;
  }

  void _updateQuotationDataStatus(bool hasData) {
    setState(() {
      _hasQuotationData = hasData;
    });
  }

  void _onItemSelected(int index) {
    // Allow navigation without warning - data will be preserved
    setState(() {
      _selectedIndex = index;
    });
    
    // Reload quotation history when that tab is selected (always at index 3)
    if (index == 3) {
      // Small delay to ensure the widget is built
      Future.delayed(const Duration(milliseconds: 100), () {
        _quotationHistoryKey.currentState?.reloadData();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages(context);
    final authService = Provider.of<AuthService>(context, listen: false);
    final isAdmin = authService.isAdmin;

    return Scaffold(
      body: Row(
        children: [
          NavigationSidebar(
            selectedIndex: _selectedIndex,
            onItemSelected: _onItemSelected,
            isAdmin: isAdmin,
          ),
          Expanded(
            // Use IndexedStack to preserve state of all pages, including CreateQuotationPage
            child: IndexedStack(
              index: _selectedIndex,
              children: pages,
            ),
          ),
        ],
      ),
    );
  }
}

class PlaceholderPage extends StatelessWidget {
  final String title;

  const PlaceholderPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          PageHeader(title: title),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
