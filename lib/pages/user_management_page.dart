import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../database/database_helper.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../widgets/page_header.dart';
import '../utils/google_drive_auth_helper.dart';
import '../services/google_auth_service.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  List<User> _users = [];
  bool _isLoading = true;
  bool _isGoogleDriveSignedIn = false;
  String? _googleDriveAccountEmail;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _checkGoogleDriveStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh Google Drive status when page becomes visible
    _checkGoogleDriveStatus();
  }

  Future<void> _checkGoogleDriveStatus() async {
    final googleAuth = GoogleAuthService.instance;
    await googleAuth.loadStoredTokens();
    final isSignedIn = googleAuth.isSignedIn;
    final account = googleAuth.currentUser;
    
    if (mounted) {
      setState(() {
        _isGoogleDriveSignedIn = isSignedIn;
        _googleDriveAccountEmail = account?.email ?? (isSignedIn ? 'Authenticated' : null);
      });
    }
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    final users = await DatabaseHelper.instance.getAllUsers();
    setState(() {
      _users = users;
      _isLoading = false;
    });
  }

  Future<void> _showCreateUserDialog() async {
    // Check Google Drive sign-in
    final isSignedIn = await GoogleDriveAuthHelper.checkAndShowNotificationIfNotSignedIn(context);
    if (!isSignedIn) {
      return;
    }

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final mobileController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscurePassword = true;
    bool obscureConfirmPassword = true;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create New User'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.person_outlined),
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: mobileController,
                    decoration: const InputDecoration(
                      labelText: 'Mobile Number',
                      prefixIcon: Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter mobile number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    obscureText: obscurePassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter password';
                      }
                      if (value.length < 4) {
                        return 'Password must be at least 4 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            obscureConfirmPassword = !obscureConfirmPassword;
                          });
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    obscureText: obscureConfirmPassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm password';
                      }
                      if (value != passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    final authService = Provider.of<AuthService>(context, listen: false);
                    final createdBy = authService.currentUser?.email;
                    await DatabaseHelper.instance.createUser(
                      emailController.text.trim(),
                      passwordController.text,
                      'user',
                      nameController.text.trim(),
                      mobileController.text.trim(),
                      createdBy,
                    );
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      _loadUsers();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('User created successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    emailController.dispose();
    mobileController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
  }

  Future<void> _showResetPasswordDialog(User user) async {
    // Check Google Drive sign-in
    final isSignedIn = await GoogleDriveAuthHelper.checkAndShowNotificationIfNotSignedIn(context);
    if (!isSignedIn) {
      return;
    }

    final formKey = GlobalKey<FormState>();
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureOldPassword = true;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Reset Password for ${user.email}'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: oldPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureOldPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            obscureOldPassword = !obscureOldPassword;
                          });
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    obscureText: obscureOldPassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter current password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: newPasswordController,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureNewPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            obscureNewPassword = !obscureNewPassword;
                          });
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    obscureText: obscureNewPassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter new password';
                      }
                      if (value.length < 4) {
                        return 'Password must be at least 4 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            obscureConfirmPassword = !obscureConfirmPassword;
                          });
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    obscureText: obscureConfirmPassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm new password';
                      }
                      if (value != newPasswordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    // Verify old password first
                    final authenticated = await DatabaseHelper.instance
                        .authenticateUser(user.email, oldPasswordController.text);
                    if (authenticated == null) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Current password is incorrect'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                      return;
                    }

                    await DatabaseHelper.instance.updateUserPassword(
                      user.id!,
                      newPasswordController.text,
                    );
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Password reset successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('Reset'),
            ),
          ],
        ),
      ),
    );

    oldPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _deleteUser(User user) async {
    // Check Google Drive sign-in
    final isSignedIn = await GoogleDriveAuthHelper.checkAndShowNotificationIfNotSignedIn(context);
    if (!isSignedIn) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete user ${user.email}?'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DatabaseHelper.instance.deleteUser(user.id!);
        if (context.mounted) {
          _loadUsers();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          PageHeader(
            title: 'User Management',
            actionButton: IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showCreateUserDialog,
              tooltip: 'Create New User',
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(12),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No users found',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: user.isAdmin
                              ? Colors.blue
                              : Colors.grey,
                          child: Icon(
                            user.isAdmin ? Icons.admin_panel_settings : Icons.person,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(user.name.isNotEmpty ? user.name : user.email),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.email),
                            Text(
                              'Role: ${user.role.toUpperCase()}',
                              style: TextStyle(
                                color: user.isAdmin ? Colors.blue : Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.lock_reset),
                              onPressed: () => _showResetPasswordDialog(user),
                              tooltip: 'Reset Password',
                            ),
                            if (!user.isAdmin)
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _deleteUser(user),
                                tooltip: 'Delete User',
                                color: Colors.red,
                              ),
                          ],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (user.mobileNumber.isNotEmpty)
                                  _buildInfoRow('Mobile', user.mobileNumber, Icons.phone),
                                if (user.createdBy != null)
                                  _buildInfoRow('Created By', user.createdBy!, Icons.person_add),
                                _buildInfoRow(
                                  'Created At',
                                  _formatDate(user.createdAt),
                                  Icons.calendar_today,
                                ),
                                if (user.lastLoginTime != null)
                                  _buildInfoRow(
                                    'Last Login',
                                    _formatDate(user.lastLoginTime!),
                                    Icons.access_time,
                                  )
                                else
                                  _buildInfoRow('Last Login', 'Never', Icons.access_time),
                                const Divider(height: 24),
                                // Google Drive Status Section
                                Row(
                                  children: [
                                    Icon(
                                      _isGoogleDriveSignedIn ? Icons.cloud_done : Icons.cloud_off,
                                      size: 16,
                                      color: _isGoogleDriveSignedIn ? Colors.green : Colors.orange[700],
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Google Drive: ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        _isGoogleDriveSignedIn
                                            ? (_googleDriveAccountEmail ?? 'Signed In')
                                            : 'Not Signed In',
                                        style: TextStyle(
                                          color: _isGoogleDriveSignedIn ? Colors.green[700] : Colors.orange[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    if (!_isGoogleDriveSignedIn)
                                      TextButton.icon(
                                        onPressed: () async {
                                          final success = await GoogleDriveAuthHelper.signInDirectly(context);
                                          if (success) {
                                            await _checkGoogleDriveStatus();
                                          }
                                        },
                                        icon: const Icon(Icons.login, size: 16),
                                        label: const Text('Sign In'),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}

