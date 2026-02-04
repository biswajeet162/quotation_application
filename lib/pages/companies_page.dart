import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/company.dart';
import '../widgets/page_header.dart';
import 'package:intl/intl.dart';

class CompaniesPage extends StatefulWidget {
  const CompaniesPage({super.key});

  @override
  State<CompaniesPage> createState() => _CompaniesPageState();
}

class _CompaniesPageState extends State<CompaniesPage> {
  List<Company> _companies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    setState(() {
      _isLoading = true;
    });

    final companies = await DatabaseHelper.instance.getAllCompanies();
    setState(() {
      _companies = companies;
      _isLoading = false;
    });
  }

  Future<void> _showAddEditCompanyDialog({Company? company}) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: company?.name ?? '');
    final addressController = TextEditingController(text: company?.address ?? '');
    final mobileController = TextEditingController(text: company?.mobile ?? '');
    final emailController = TextEditingController(text: company?.email ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(company == null ? 'Add Company' : 'Edit Company'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Company Name',
                    prefixIcon: Icon(Icons.business),
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter company name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    prefixIcon: Icon(Icons.location_on),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: mobileController,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number',
                    prefixIcon: Icon(Icons.phone),
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
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter email address';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
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
                  if (company == null) {
                    // Add new company
                    await DatabaseHelper.instance.insertCompany(
                      Company(
                        name: nameController.text.trim(),
                        address: addressController.text.trim(),
                        mobile: mobileController.text.trim(),
                        email: emailController.text.trim(),
                        createdAt: DateTime.now(),
                      ),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Company added successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } else {
                    // Update existing company
                    await DatabaseHelper.instance.updateCompany(
                      Company(
                        id: company.id,
                        name: nameController.text.trim(),
                        address: addressController.text.trim(),
                        mobile: mobileController.text.trim(),
                        email: emailController.text.trim(),
                        createdAt: company.createdAt,
                      ),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Company updated successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    _loadCompanies();
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
            child: Text(company == null ? 'Add' : 'Update'),
          ),
        ],
      ),
    );

    nameController.dispose();
    addressController.dispose();
    mobileController.dispose();
    emailController.dispose();
  }

  Future<void> _deleteCompany(Company company) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Company'),
        content: Text('Are you sure you want to delete ${company.name}?'),
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
        await DatabaseHelper.instance.deleteCompany(company.id!);
        if (context.mounted) {
          _loadCompanies();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Company deleted successfully'),
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
            title: 'Companies',
            count: _companies.length,
            actionButton: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showAddEditCompanyDialog(),
              tooltip: 'Add New Company',
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(12),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _companies.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.business_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No companies found',
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
                        itemCount: _companies.length,
                        itemBuilder: (context, index) {
                          final company = _companies[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue,
                                child: Icon(
                                  Icons.business,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(company.name),
                              subtitle: Text(company.email),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _showAddEditCompanyDialog(company: company),
                                    tooltip: 'Edit Company',
                                    color: Colors.blue,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () => _deleteCompany(company),
                                    tooltip: 'Delete Company',
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
                                      _buildInfoRow('Address', company.address, Icons.location_on),
                                      _buildInfoRow('Mobile', company.mobile, Icons.phone),
                                      _buildInfoRow('Email', company.email, Icons.email),
                                      _buildInfoRow(
                                        'Created At',
                                        DateFormat('dd/MM/yyyy HH:mm').format(company.createdAt),
                                        Icons.calendar_today,
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
}


