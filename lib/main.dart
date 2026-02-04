import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pages/products_page.dart';
import 'pages/create_quotation_page.dart';
import 'pages/login_page.dart';
import 'pages/user_management_page.dart';
import 'pages/password_reset_page.dart';
import 'pages/settings_page.dart';
import 'pages/companies_page.dart';
import 'widgets/navigation_sidebar.dart';
import 'widgets/page_header.dart';
import 'services/auth_service.dart';

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

  List<Widget> _buildPages(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isAdmin = authService.isAdmin;
    
    final pages = [
      const ProductsPage(),
      const PlaceholderPage(title: 'Dashboard'),
      const CreateQuotationPage(),
      const PlaceholderPage(title: 'Quotation History'),
      const CompaniesPage(),
      SettingsPage(userEmail: authService.currentUser?.email ?? ''),
    ];

    // Insert user management page for admin (index 5, before Settings)
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

  Future<void> _onItemSelected(int index) async {
    // If trying to navigate away from Create Quotation page and there's data
    if (_selectedIndex == 2 && index != 2 && _hasQuotationData) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unsaved Changes'),
          content: const Text(
            'You have unsaved quotation data. All data will be erased if you navigate away. Do you want to continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Continue'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        return; // Don't navigate if user cancelled
      }
    }

    setState(() {
      _selectedIndex = index;
    });
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
            child: _selectedIndex == 2
                ? CreateQuotationPage(
                    onDataChanged: _updateQuotationDataStatus,
                  )
                : pages[_selectedIndex],
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
