import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../models/quotation_item.dart';
import '../models/company.dart';
import '../models/quotation_history.dart';
import '../database/database_helper.dart';
import '../services/auth_service.dart';
import 'quotation_preview_page.dart';
import '../widgets/page_header.dart';

// Wrapper class for autocomplete options
class CompanyOption {
  final Company? company;
  final String? newCompanyName;

  CompanyOption.existing(this.company) : newCompanyName = null;
  CompanyOption.newCompany(this.newCompanyName) : company = null;

  bool get isNew => company == null;
  String get displayName => company?.name ?? newCompanyName ?? '';
}

class CreateQuotationPage extends StatefulWidget {
  final Function(bool)? onDataChanged;

  const CreateQuotationPage({super.key, this.onDataChanged});

  @override
  State<CreateQuotationPage> createState() => _CreateQuotationPageState();
}

class _CreateQuotationPageState extends State<CreateQuotationPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  
  // Customer Details
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  DateTime? _selectedDate;
  
  // Items List
  final List<QuotationItem> _items = [];
  List<Product> _products = [];
  List<Company> _companies = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _loadCompanies();
    _addNewItem();
    // Add listeners to text controllers
    _customerNameController.addListener(_onDataChanged);
    _addressController.addListener(_onDataChanged);
    _mobileController.addListener(_onDataChanged);
    _emailController.addListener(_onDataChanged);
  }

  void _onDataChanged() {
    // Schedule callback after the current build phase to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onDataChanged?.call(_hasData());
    });
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _addressController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await _dbHelper.getAllProducts();
      setState(() {
        _products = products;
      });
    } catch (e) {
      // Handle error silently or show message
    }
  }

  Future<void> _loadCompanies() async {
    try {
      final companies = await _dbHelper.getAllCompanies();
      setState(() {
        _companies = companies;
      });
    } catch (e) {
      // Handle error silently or show message
    }
  }

  void _addNewItem() {
    setState(() {
      final newItem = QuotationItem();
      newItem.deliveryDate = DateTime.now();
      newItem.calculateValues();
      _items.add(newItem);
    });
    // Schedule callback after the current build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onDataChanged?.call(_hasData());
    });
  }

  Future<void> _removeItem(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this item?'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

      if (confirmed == true) {
        setState(() {
          _items.removeAt(index);
          if (_items.isEmpty) {
            _addNewItem();
          }
        });
        // Schedule callback after the current build phase
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onDataChanged?.call(_hasData());
        });
      }
  }

  bool _hasData() {
    // Check if at least one item has a product selected
    return _items.any((item) => item.product != null) ||
        _customerNameController.text.isNotEmpty ||
        _addressController.text.isNotEmpty ||
        _mobileController.text.isNotEmpty ||
        _emailController.text.isNotEmpty ||
        _selectedDate != null;
  }

  void _onProductSelected(int itemIndex, Product? product) {
    setState(() {
      final item = _items[itemIndex];
      item.product = product;
      if (product != null) {
        // Use designation as HSN-like code for now (no dedicated HSN in new model)
        item.hsnCode = product.designation.toString();
        item.rsp = product.rsp;
        // Set qty to 1 when item is selected
        if (item.qty == 0) {
          item.qty = 1;
        }
        item.calculateValues();
      } else {
        item.hsnCode = '';
        item.rsp = 0;
        item.qty = 0;
        item.calculateValues();
      }
    });
    // Schedule callback after the current build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onDataChanged?.call(_hasData());
    });
  }

  void _updateItemValue(int index, String field, dynamic value) {
    setState(() {
      final item = _items[index];
      switch (field) {
        case 'hsnCode':
          item.hsnCode = value.toString();
          break;
        case 'qty':
          item.qty = double.tryParse(value.toString()) ?? 0;
          break;
        case 'rsp':
          item.rsp = double.tryParse(value.toString()) ?? 0;
          break;
        case 'discPercent':
          item.discPercent = double.tryParse(value.toString()) ?? 0;
          break;
        case 'gstPercent':
          item.gstPercent = double.tryParse(value.toString()) ?? 0;
          break;
      }
      item.calculateValues();
    });
    // Schedule callback after the current build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onDataChanged?.call(_hasData());
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      // Schedule callback after the current build phase
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onDataChanged?.call(_hasData());
      });
    }
  }

  Future<void> _selectDeliveryDate(int itemIndex) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _items[itemIndex].deliveryDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _items[itemIndex].deliveryDate = picked;
      });
      // Schedule callback after the current build phase
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onDataChanged?.call(_hasData());
      });
    }
  }

  String _generateQuotationNumber() {
    // Generate quotation number based on current date/time
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
  }

  void _previewQuotation() {
    // Check if there's at least one item with a product selected
    final validItems = _items.where((item) => item.product != null).toList();
    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one item to preview'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => QuotationPreviewPage(
        quotationNumber: _generateQuotationNumber(),
        quotationDate: _selectedDate ?? DateTime.now(),
        customerName: _customerNameController.text,
        customerAddress: _addressController.text,
        customerContact: _mobileController.text,
        customerEmail: _emailController.text,
        items: validItems,
      ),
    );
  }

  Future<void> _saveQuotation() async {
    // Validate required fields
    if (_customerNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter customer name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if company exists, if not, save it
    final companyName = _customerNameController.text.trim();
    final existingCompany = _companies.firstWhere(
      (company) => company.name.toLowerCase() == companyName.toLowerCase(),
      orElse: () => Company(
        id: null,
        name: '',
        address: '',
        mobile: '',
        email: '',
        createdAt: DateTime.now(),
      ),
    );

    // Get valid items for quotation
    final validItems = _items.where((item) => item.product != null).toList();
    if (validItems.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add at least one item to save'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Calculate totals
    double totalAmount = 0;
    double totalGstAmount = 0;
    double grandTotal = 0;
    for (var item in validItems) {
      totalAmount += item.unitPrice;
      totalGstAmount += item.gstAmount;
      grandTotal += item.lineTotal;
    }

    if (existingCompany.id == null) {
      // Company doesn't exist, create new one
      try {
        await _dbHelper.insertCompany(
          Company(
            name: companyName,
            address: _addressController.text.trim(),
            mobile: _mobileController.text.trim(),
            email: _emailController.text.trim(),
            createdAt: DateTime.now(),
          ),
        );
        // Reload companies list
        await _loadCompanies();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving company: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    // Save quotation to history
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;
      final createdBy = currentUser?.name.isNotEmpty == true
          ? currentUser!.name
          : (currentUser?.email ?? 'Unknown');
      
      final quotationHistory = QuotationHistory(
        quotationNumber: _generateQuotationNumber(),
        quotationDate: _selectedDate ?? DateTime.now(),
        customerName: _customerNameController.text.trim(),
        customerAddress: _addressController.text.trim(),
        customerContact: _mobileController.text.trim(),
        customerEmail: _emailController.text.trim(),
        items: validItems,
        totalAmount: totalAmount,
        totalGstAmount: totalGstAmount,
        grandTotal: grandTotal,
        action: 'saved',
        createdBy: createdBy,
        createdAt: DateTime.now(),
      );

      await _dbHelper.insertQuotationHistory(quotationHistory);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quotation saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving quotation: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onCompanySelected(Company company) {
    setState(() {
      _customerNameController.text = company.name;
      _addressController.text = company.address;
      _mobileController.text = company.mobile;
      _emailController.text = company.email;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Column(
        children: [
          const PageHeader(
            title: 'Create Quotation',
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0),
                child: Card(
                  elevation: 2,
                  color: Colors.grey[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        // Customer Details Section
                        _buildCustomerDetailsSection(),
                        const SizedBox(height: 24),
                        // Item Details Section
                        _buildItemDetailsSection(),
                        const SizedBox(height: 20),
                        // Add Item Button
                        ElevatedButton.icon(
                          onPressed: _addNewItem,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Item'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Action Buttons (Preview, Save)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _previewQuotation,
                              icon: const Icon(Icons.preview, color: Colors.white),
                              label: const Text(
                                'Preview',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _saveQuotation,
                              icon: const Icon(Icons.save, color: Colors.white),
                              label: const Text(
                                'Save',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Customer Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _buildCompanyAutocomplete(),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 4,
              child: _buildAddressField(),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 2,
              child: _buildTextField(
                controller: _mobileController,
                label: 'Mobile',
                hint: 'Enter Mobile Number',
                keyboardType: TextInputType.phone,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 2,
              child: _buildTextField(
                controller: _emailController,
                label: 'Email',
                hint: 'Enter Email Address',
                keyboardType: TextInputType.emailAddress,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 2,
              child: _buildDateField(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompanyAutocomplete() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Company Name',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Autocomplete<CompanyOption>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            final query = textEditingValue.text.trim().toLowerCase();
            
            // If empty, show all companies
            if (query.isEmpty) {
              return _companies
                  .map((company) => CompanyOption.existing(company))
                  .toList();
            }
            
            // Filter companies by name
            final matchingCompanies = _companies
                .where((company) {
                  return company.name.toLowerCase().contains(query);
                })
                .map((company) => CompanyOption.existing(company))
                .toList();
            
            // If no matches found, show only "Add new" option
            if (matchingCompanies.isEmpty) {
              return [CompanyOption.newCompany(textEditingValue.text)];
            }
            
            return matchingCompanies;
          },
          displayStringForOption: (CompanyOption option) {
            return option.displayName;
          },
          fieldViewBuilder: (
            BuildContext context,
            TextEditingController textEditingController,
            FocusNode focusNode,
            VoidCallback onFieldSubmitted,
          ) {
            // Sync the autocomplete controller with our main controller
            // Initialize on first build
            if (textEditingController.text != _customerNameController.text) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (textEditingController.text != _customerNameController.text) {
                  textEditingController.text = _customerNameController.text;
                }
              });
            }
            
            // Update main controller when autocomplete field changes
            textEditingController.addListener(() {
              if (_customerNameController.text != textEditingController.text) {
                _customerNameController.text = textEditingController.text;
              }
            });
            
            return TextField(
              controller: textEditingController,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: 'Type company name...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            );
          },
          onSelected: (CompanyOption option) {
            if (option.isNew) {
              // "Add new" was selected - keep the typed text
              // Don't auto-fill other fields, user can enter manually
              // The company will be saved when quotation is saved
            } else {
              // Existing company selected - auto-fill all fields
              _onCompanySelected(option.company!);
            }
          },
          optionsViewBuilder: (BuildContext context,
              AutocompleteOnSelected<CompanyOption> onSelected,
              Iterable<CompanyOption> options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                borderRadius: BorderRadius.circular(4),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final CompanyOption option = options.elementAt(index);
                      if (option.isNew) {
                        // "Add new" option
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.add_circle, color: Colors.blue),
                          title: Text(
                            'Add new: ${option.newCompanyName}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.blue,
                            ),
                          ),
                          onTap: () {
                            onSelected(option);
                          },
                        );
                      } else {
                        // Existing company option
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.business, size: 20),
                          title: Text(option.company!.name),
                          subtitle: Text(
                            option.company!.email,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onTap: () {
                            onSelected(option);
                          },
                        );
                      }
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAddressField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Address',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _addressController,
          maxLines: 2,
          minLines: 1,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            hintText: 'Enter Address',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          style: const TextStyle(
            height: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _selectDate,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[400]!),
              borderRadius: BorderRadius.circular(4),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedDate != null
                        ? DateFormat('dd-MM-yyyy').format(_selectedDate!)
                        : 'dd-mm-yyyy',
                    style: TextStyle(
                      color: _selectedDate != null
                          ? Colors.black87
                          : Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(Icons.calendar_today, size: 20, color: Colors.grey[700]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Item Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTableHeader(),
              ...List.generate(_items.length, (index) {
                return _buildItemRow(index);
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          _buildHeaderCell('S.No', 60),
          const SizedBox(width: 12),
          _buildHeaderCell('Select Item', 200),
          const SizedBox(width: 12),
          _buildHeaderCell('HSN Code', 100),
          const SizedBox(width: 12),
          _buildHeaderCell('Qty', 80),
          const SizedBox(width: 12),
          _buildHeaderCell('RSP', 100),
          const SizedBox(width: 12),
          _buildHeaderCell('Disc%', 80),
          const SizedBox(width: 12),
          _buildHeaderCell('Unit Price', 100),
          const SizedBox(width: 12),
          _buildHeaderCell('Total', 100),
          const SizedBox(width: 12),
          _buildHeaderCell('GST %', 80),
          const SizedBox(width: 12),
          _buildHeaderCell('GST Amount', 100),
          const SizedBox(width: 12),
          _buildHeaderCell('Delivery Date', 130),
          const SizedBox(width: 12),
          _buildHeaderCell('Line Total', 100),
          const SizedBox(width: 12),
          _buildHeaderCell('Action', 80),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildItemRow(int index) {
    final item = _items[index];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          _buildItemCell(
            width: 60,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                '${index + 1}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildItemCell(
            width: 200,
            child: _buildProductDropdown(index, item),
          ),
          const SizedBox(width: 12),
          _buildItemCell(
            width: 100,
            child: _buildTextInputField(
              value: item.hsnCode,
              onChanged: (value) => _updateItemValue(index, 'hsnCode', value),
            ),
          ),
          const SizedBox(width: 12),
          _buildItemCell(
            width: 80,
            child: _buildNumberField(
              value: item.qty.toString(),
              onChanged: (value) => _updateItemValue(index, 'qty', value),
            ),
          ),
          const SizedBox(width: 12),
          _buildItemCell(
            width: 100,
            child: _buildNumberField(
              value: item.rsp.toStringAsFixed(2),
              onChanged: (value) => _updateItemValue(index, 'rsp', value),
            ),
          ),
          const SizedBox(width: 12),
          _buildItemCell(
            width: 80,
            child: _buildNumberField(
              value: item.discPercent.toStringAsFixed(2),
              onChanged: (value) => _updateItemValue(index, 'discPercent', value),
            ),
          ),
          const SizedBox(width: 12),
          _buildItemCell(
            width: 100,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                item.unitPrice.toStringAsFixed(2),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildItemCell(
            width: 100,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                item.total.toStringAsFixed(2),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildItemCell(
            width: 80,
            child: _buildNumberField(
              value: item.gstPercent.toStringAsFixed(2),
              onChanged: (value) => _updateItemValue(index, 'gstPercent', value),
            ),
          ),
          const SizedBox(width: 12),
          _buildItemCell(
            width: 100,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                item.gstAmount.toStringAsFixed(2),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildItemCell(
            width: 140,
            child: _buildDeliveryDateField(index, item),
          ),
          const SizedBox(width: 12),
          _buildItemCell(
            width: 100,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                item.lineTotal.toStringAsFixed(2),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildItemCell(
            width: 80,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.red, size: 20),
              onPressed: () => _removeItem(index),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Delete Item',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCell({required double width, required Widget child}) {
    return SizedBox(
      width: width,
      child: Center(
        child: child,
      ),
    );
  }

  Widget _buildProductDropdown(int itemIndex, QuotationItem item) {
    // Use a key to ensure the autocomplete rebuilds when product changes
    return Autocomplete<Product>(
      key: ValueKey('product_${itemIndex}_${item.product?.id ?? 'none'}'),
      displayStringForOption: (Product product) => product.information,
      optionsBuilder: (TextEditingValue textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        
        // If empty, return all products
        if (query.isEmpty) {
          return _products;
        }
        
        // Filter products based on group, price (RSP), and information
        return _products.where((product) {
          // Search in group
          if (product.group.toLowerCase().contains(query)) {
            return true;
          }
          
          // Search in price (RSP) - check both formatted and raw values
          final rspString = product.rsp.toString();
          final rspFormatted = product.rsp.toStringAsFixed(2);
          if (rspString.contains(query) || rspFormatted.contains(query)) {
            return true;
          }
          
          // Search in information
          if (product.information.toLowerCase().contains(query)) {
            return true;
          }
          
          return false;
        });
      },
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController textEditingController,
        FocusNode focusNode,
        VoidCallback onFieldSubmitted,
      ) {
        // Initialize with selected product's information if available
        final currentProduct = item.product;
        if (currentProduct != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (currentProduct == item.product && 
                textEditingController.text != currentProduct.information) {
              textEditingController.text = currentProduct.information;
            }
          });
        }
        
        return TextField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: 'Type to search item...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: Colors.grey[400]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: Colors.grey[400]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            isDense: true,
          ),
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        );
      },
      onSelected: (Product product) {
        _onProductSelected(itemIndex, product);
      },
      optionsViewBuilder: (BuildContext context,
          AutocompleteOnSelected<Product> onSelected,
          Iterable<Product> options) {
        if (options.isEmpty) {
          return const SizedBox.shrink();
        }
        
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(4),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final Product product = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.inventory_2, size: 20),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Group: ${product.group}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Designation: ${product.designation}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Price: ₹${product.rsp.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      onSelected(product);
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNumberField({
    required String value,
    required Function(String) onChanged,
  }) {
    return TextField(
      controller: TextEditingController(text: value),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 14, color: Colors.black87),
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: Colors.grey[400]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: Colors.grey[400]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        isDense: true,
      ),
      onChanged: onChanged,
    );
  }

  Widget _buildTextInputField({
    required String value,
    required Function(String) onChanged,
  }) {
    return TextField(
      controller: TextEditingController(text: value),
      keyboardType: TextInputType.text,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 14, color: Colors.black87),
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: Colors.grey[400]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: Colors.grey[400]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        isDense: true,
      ),
      onChanged: onChanged,
    );
  }

  Widget _buildDeliveryDateField(int itemIndex, QuotationItem item) {
    return InkWell(
      onTap: () => _selectDeliveryDate(itemIndex),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(4),
          color: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                item.deliveryDate != null
                    ? DateFormat('dd-MM-yyyy').format(item.deliveryDate!)
                    : 'Select Date',
                style: TextStyle(
                  color: item.deliveryDate != null
                      ? Colors.black87
                      : Colors.grey[600],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.calendar_today, size: 16, color: Colors.grey[700]),
          ],
        ),
      ),
    );
  }
}

