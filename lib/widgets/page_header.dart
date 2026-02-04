import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class PageHeader extends StatelessWidget {
  final String title;
  final int? count;
  final Widget? actionButton;
  final bool showWelcome;

  const PageHeader({
    super.key,
    required this.title,
    this.count,
    this.actionButton,
    this.showWelcome = true,
  });

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    final userName = currentUser?.name.isNotEmpty == true
        ? currentUser!.name
        : (currentUser?.email ?? 'User');

    return Column(
      children: [
        // Welcome Header
        if (showWelcome)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.person,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Welcome, $userName',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.logout),
                  color: Colors.red,
                  tooltip: 'Logout',
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Logout'),
                        content: const Text('Are you sure you want to logout?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Logout'),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true && context.mounted) {
                      await authService.logout();
                    }
                  },
                ),
              ],
            ),
          ),
        // Page Title Header
        Container(
          padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '($count)',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
              if (actionButton != null) actionButton!,
            ],
          ),
        ),
      ],
    );
  }
}

