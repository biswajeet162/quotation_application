import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../models/my_company.dart';
import 'password_reset_page.dart';
import 'package:intl/intl.dart';
import '../widgets/page_header.dart';

class SettingsPage extends StatelessWidget {
  final String userEmail;

  const SettingsPage({
    super.key,
    required this.userEmail,
  });

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      body: Column(
        children: [
          const PageHeader(
            title: 'Settings',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ExpansionTile(
                    leading: const Icon(Icons.business),
                    title: const Text('My Company Details'),
                    subtitle: Text(MyCompany.name),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow(
                              'Company Name',
                              MyCompany.name,
                              Icons.business_outlined,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.location_on_outlined, size: 20, color: Colors.grey[600]),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Address: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[700],
                                      fontSize: 16,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      MyCompany.address,
                                      style: TextStyle(
                                        color: Colors.grey[800],
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildInfoRow(
                              'GST',
                              MyCompany.gst,
                              Icons.receipt_outlined,
                            ),
                            _buildInfoRow(
                              'PAN',
                              MyCompany.pan,
                              Icons.badge_outlined,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ExpansionTile(
                    leading: const Icon(Icons.person),
                    title: const Text('Account Information'),
                    subtitle: Text(userEmail),
                    children: [
                      if (authService.currentUser != null)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (authService.currentUser!.name.isNotEmpty)
                                _buildInfoRow(
                                  'Name',
                                  authService.currentUser!.name,
                                  Icons.person_outline,
                                ),
                              _buildInfoRow(
                                'Email',
                                authService.currentUser!.email,
                                Icons.email_outlined,
                              ),
                              if (authService.currentUser!.mobileNumber.isNotEmpty)
                                _buildInfoRow(
                                  'Mobile',
                                  authService.currentUser!.mobileNumber,
                                  Icons.phone_outlined,
                                ),
                              _buildInfoRow(
                                'Role',
                                authService.currentUser!.role.toUpperCase(),
                                Icons.badge_outlined,
                              ),
                              if (authService.currentUser!.createdBy != null)
                                _buildInfoRow(
                                  'Created By',
                                  authService.currentUser!.createdBy!,
                                  Icons.person_add_outlined,
                                ),
                              _buildInfoRow(
                                'Created At',
                                DateFormat('dd/MM/yyyy HH:mm').format(
                                  authService.currentUser!.createdAt,
                                ),
                                Icons.calendar_today_outlined,
                              ),
                              if (authService.currentUser!.lastLoginTime != null)
                                _buildInfoRow(
                                  'Last Login',
                                  DateFormat('dd/MM/yyyy HH:mm').format(
                                    authService.currentUser!.lastLoginTime!,
                                  ),
                                  Icons.access_time_outlined,
                                )
                              else
                                _buildInfoRow('Last Login', 'Never', Icons.access_time_outlined),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.lock_reset),
                    title: const Text('Reset Password'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => PasswordResetPage(userEmail: userEmail),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text(
                      'Logout',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () async {
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
              fontSize: 16,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

