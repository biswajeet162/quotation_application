import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/product.dart';
import '../models/quotation_item.dart';
import '../database/database_helper.dart';

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
  DateTime? _selectedDate;
  
  // Items List
  final List<QuotationItem> _items = [];
  List<Product> _products = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _addNewItem();
    // Add listeners to text controllers
    _customerNameController.addListener(_onDataChanged);
    _addressController.addListener(_onDataChanged);
    _mobileController.addListener(_onDataChanged);
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
        _selectedDate != null;
  }

  void _onProductSelected(int itemIndex, Product? product) {
    setState(() {
      final item = _items[itemIndex];
      item.product = product;
      if (product != null) {
        item.hsnCode = product.hsnCode;
        item.rsp = product.rate;
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
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              width: constraints.maxWidth * 0.95,
              height: constraints.maxHeight * 0.95,
              constraints: BoxConstraints(
                maxWidth: 1200,
                maxHeight: constraints.maxHeight * 0.95,
              ),
              child: _QuotationPreviewDialog(
                quotationNumber: _generateQuotationNumber(),
                quotationDate: _selectedDate ?? DateTime.now(),
                customerName: _customerNameController.text,
                customerAddress: _addressController.text,
                customerContact: _mobileController.text,
                items: validItems,
              ),
            );
          },
        ),
      ),
    );
  }

  void _saveQuotation() {
    // TODO: Implement quotation save
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Save functionality will be implemented'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: SingleChildScrollView(
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
                  // Title
                  const Text(
                    'Create Quotation',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
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
              child: _buildTextField(
                controller: _customerNameController,
                label: 'Customer Name',
                hint: 'Enter Customer Name',
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildTextField(
                controller: _addressController,
                label: 'Address',
                hint: 'Enter Address',
              ),
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
              child: _buildDateField(),
            ),
          ],
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
          _buildHeaderCell('Delivery Date', 120),
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
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                item.hsnCode,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
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
            width: 120,
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
    return DropdownButtonFormField<Product>(
      value: item.product,
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
      hint: const Text(
        'Select Item',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: Colors.grey),
      ),
      isExpanded: true,
      style: const TextStyle(
        fontSize: 14,
        color: Colors.black87,
      ),
      alignment: Alignment.center,
      dropdownColor: Colors.white,
      menuMaxHeight: 400,
      icon: const Icon(Icons.arrow_drop_down, color: Colors.black87),
      selectedItemBuilder: (BuildContext context) {
        // Show only item name when selected
        return _products.map((product) {
          return Align(
            alignment: Alignment.center,
            child: Text(
              product.itemName,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList();
      },
      items: _products.map((product) {
        return DropdownMenuItem<Product>(
          value: product,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        product.itemName,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'HSN: ${product.hsnCode} | Rate: ₹${product.rate.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
      onChanged: (product) => _onProductSelected(itemIndex, product),
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

class _QuotationPreviewDialog extends StatelessWidget {
  final String quotationNumber;
  final DateTime quotationDate;
  final String customerName;
  final String customerAddress;
  final String customerContact;
  final List<QuotationItem> items;

  const _QuotationPreviewDialog({
    required this.quotationNumber,
    required this.quotationDate,
    required this.customerName,
    required this.customerAddress,
    required this.customerContact,
    required this.items,
  });

  Future<void> _downloadQuotation(BuildContext context) async {
    try {
      // Calculate totals
      double totalAmount = 0;
      double totalGstAmount = 0;
      double grandTotal = 0;
      for (var item in items) {
        totalAmount += item.unitPrice;
        totalGstAmount += item.gstAmount;
        grandTotal += item.lineTotal;
      }

      // Create PDF document
      final pdf = pw.Document();
      
      // Match the preview modal layout - use a wider format
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(30),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header Section
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Company Details (Left)
                    pw.Expanded(
                      flex: 2,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            children: [
                              // Company Logo
                              pw.Container(
                                width: 50,
                                height: 50,
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.blue700,
                                  shape: pw.BoxShape.circle,
                                ),
                                child: pw.Center(
                                  child: pw.Column(
                                    mainAxisAlignment: pw.MainAxisAlignment.center,
                                    children: [
                                      pw.Text(
                                        'ABE',
                                        style: pw.TextStyle(
                                          color: PdfColors.white,
                                          fontSize: 16,
                                          fontWeight: pw.FontWeight.bold,
                                        ),
                                      ),
                                      pw.Text(
                                        'GROUP',
                                        style: pw.TextStyle(
                                          color: PdfColors.white,
                                          fontSize: 8,
                                          fontWeight: pw.FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              pw.SizedBox(width: 12),
                              pw.Expanded(
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text(
                                      'Ashoka Bearing Enterprises',
                                      style: pw.TextStyle(
                                        fontSize: 18,
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                    pw.SizedBox(height: 4),
                                    pw.Text(
                                      '2, Ring Rd, Awas Vikas, Rudrapur, Jagatpura, Uttarakhand 263153',
                                      style: const pw.TextStyle(fontSize: 12),
                                    ),
                                    pw.SizedBox(height: 4),
                                    pw.Text(
                                      'GSTIN No.: XXXXXXX XXXXXXXX',
                                      style: const pw.TextStyle(fontSize: 12),
                                    ),
                                    pw.Text(
                                      'PAN No.: XXXXX XXXXXX',
                                      style: const pw.TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 16),
                    // Customer Details (Right)
                    pw.Expanded(
                      flex: 1,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Customer Details',
                              style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 8),
                            pw.Text(
                              customerName.isEmpty ? 'Customer Name' : customerName,
                              style: const pw.TextStyle(fontSize: 12),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              customerAddress.isEmpty ? 'Address' : customerAddress,
                              style: const pw.TextStyle(fontSize: 12),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              customerContact.isEmpty
                                  ? 'Contact.: XXXXXXX XXXXXXXX'
                                  : 'Contact.: $customerContact',
                              style: const pw.TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),
                // Quotation Number and Date
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Quotation Number: $quotationNumber',
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Quotation Date: ${DateFormat('dd-MM-yyyy').format(quotationDate)}',
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),
                // Item Details Table
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(30),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(1),
                    3: const pw.FixedColumnWidth(30),
                    4: const pw.FlexColumnWidth(1),
                    5: const pw.FixedColumnWidth(35),
                    6: const pw.FlexColumnWidth(1),
                    7: const pw.FlexColumnWidth(1),
                    8: const pw.FixedColumnWidth(35),
                    9: const pw.FlexColumnWidth(1),
                    10: const pw.FlexColumnWidth(1),
                    11: const pw.FlexColumnWidth(1),
                  },
                  children: [
                    // Table Header
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        _buildPdfCell('S.No.', isHeader: true),
                        _buildPdfCell('Item Description', isHeader: true),
                        _buildPdfCell('HSN Code', isHeader: true),
                        _buildPdfCell('Qty', isHeader: true),
                        _buildPdfCell('RSP(INR)', isHeader: true),
                        _buildPdfCell('Disc%', isHeader: true),
                        _buildPdfCell('Unit Price', isHeader: true),
                        _buildPdfCell('Total', isHeader: true),
                        _buildPdfCell('GST %', isHeader: true),
                        _buildPdfCell('GST Amount', isHeader: true),
                        _buildPdfCell('Line Total', isHeader: true),
                        _buildPdfCell('Delivery Date', isHeader: true),
                      ],
                    ),
                    // Table Rows
                    ...items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color: index % 2 == 0 ? PdfColors.white : PdfColors.grey100,
                        ),
                        children: [
                          _buildPdfCell('${index + 1}'),
                          _buildPdfCell(
                            item.product?.itemName ?? '',
                            fontWeight: pw.FontWeight.bold,
                          ),
                          _buildPdfCell(item.hsnCode),
                          _buildPdfCell(item.qty.toStringAsFixed(0)),
                          _buildPdfCell('Rs.${item.rsp.toStringAsFixed(2)}'),
                          _buildPdfCell('${item.discPercent.toStringAsFixed(0)}%'),
                          _buildPdfCell('Rs.${item.unitPrice.toStringAsFixed(2)}'),
                          _buildPdfCell('Rs.${item.total.toStringAsFixed(2)}'),
                          _buildPdfCell('${item.gstPercent.toStringAsFixed(0)}%'),
                          _buildPdfCell('Rs.${item.gstAmount.toStringAsFixed(2)}'),
                          _buildPdfCell(
                            'Rs.${item.lineTotal.toStringAsFixed(2)}',
                            fontWeight: pw.FontWeight.bold,
                          ),
                          _buildPdfCell(
                            item.deliveryDate != null
                                ? DateFormat('dd-MM-yyyy').format(item.deliveryDate!)
                                : '',
                          ),
                        ],
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 16),
                // Totals Section
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        _buildPdfTotalRow('Subtotal:', 'Rs.${totalAmount.toStringAsFixed(2)}'),
                        pw.SizedBox(height: 6),
                        _buildPdfTotalRow('GST Amount:', 'Rs.${totalGstAmount.toStringAsFixed(2)}'),
                        pw.SizedBox(height: 6),
                        _buildPdfTotalRow(
                          'Grand Total:',
                          'Rs.${grandTotal.toStringAsFixed(2)}',
                          isBold: true,
                          fontSize: 14,
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(height: 16),
                // Terms & Conditions
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'T&Cs:',
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Taxes amounting 18% of the total value will be included in the invoice',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Lorem Ipsum Doler Sit Amet',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );

      // Generate PDF bytes
      final pdfBytes = await pdf.save();

      // Save PDF using file picker
      final String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Quotation PDF',
        fileName: 'quotation_$quotationNumber.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (outputPath != null) {
        final file = File(outputPath);
        await file.writeAsBytes(pdfBytes);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF saved successfully to: $outputPath'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        // User cancelled, save to temp directory as fallback
        final output = await getTemporaryDirectory();
        final file = File('${output.path}/quotation_$quotationNumber.pdf');
        await file.writeAsBytes(pdfBytes);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF saved to: ${file.path}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  pw.Widget _buildPdfCell(String text, {bool isHeader = false, pw.FontWeight? fontWeight}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: fontWeight ?? (isHeader ? pw.FontWeight.bold : pw.FontWeight.normal),
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildPdfTotalRow(String label, String value, {bool isBold = false, double fontSize = 12}) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.SizedBox(width: 16),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    );
  }

  void _emailQuotation(BuildContext context) {
    // TODO: Implement quotation email
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Email functionality will be implemented'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate totals
    double totalAmount = 0;
    double totalGstAmount = 0;
    double grandTotal = 0;
    for (var item in items) {
      totalAmount += item.unitPrice;
      totalGstAmount += item.gstAmount;
      grandTotal += item.lineTotal;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Quotation Preview'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          ElevatedButton.icon(
            onPressed: () => _downloadQuotation(context),
            icon: const Icon(Icons.download, color: Colors.white, size: 18),
            label: const Text(
              'Download',
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
                horizontal: 16,
                vertical: 8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _emailQuotation(context),
            icon: const Icon(Icons.email, color: Colors.white, size: 18),
            label: const Text(
              'Email',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 100,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header Section
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Company Details (Left)
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Company Logo
                            Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.blue[700],
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'ABE',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'GROUP',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Ashoka Bearing Enterprises',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        '2, Ring Rd, Awas Vikas, Rudrapur, Jagatpura, Uttarakhand 263153',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'GSTIN No.: XXXXXXX XXXXXXXX',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                      Text(
                                        'PAN No.: XXXXX XXXXXX',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Customer Details (Right)
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Customer Details',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                customerName.isEmpty ? 'Customer Name' : customerName,
                                style: const TextStyle(fontSize: 11),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                customerAddress.isEmpty ? 'Address' : customerAddress,
                                style: const TextStyle(fontSize: 11),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                customerContact.isEmpty
                                    ? 'Contact.: XXXXXXX XXXXXXXX'
                                    : 'Contact.: $customerContact',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Quotation Number and Date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Quotation Number: $quotationNumber',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          'Quotation Date: ${DateFormat('dd-MM-yyyy').format(quotationDate)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
            // Item Details Table
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  children: [
                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildHeaderCell('S.No.', 50),
                          _buildHeaderCell('Item Description', 200),
                          _buildHeaderCell('HSN Code', 100),
                          _buildHeaderCell('Qty', 60),
                          _buildHeaderCell('RSP(INR)', 100),
                          _buildHeaderCell('Disc%', 70),
                          _buildHeaderCell('Unit Price', 100),
                          _buildHeaderCell('Total', 100),
                          _buildHeaderCell('GST %', 70),
                          _buildHeaderCell('GST Amount', 100),
                          _buildHeaderCell('Line Total', 100),
                          _buildHeaderCell('Delivery Date', 120),
                        ],
                      ),
                    ),
                    // Table Rows
                    ...items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey[200]!),
                          ),
                          color: index % 2 == 0 ? Colors.white : Colors.grey[50],
                        ),
                        child: Row(
                          children: [
                            _buildDataCell('${index + 1}', 50),
                            _buildDataCell(
                              item.product?.itemName ?? '',
                              200,
                              fontWeight: FontWeight.w500,
                            ),
                            _buildDataCell(item.hsnCode, 100),
                            _buildDataCell(item.qty.toStringAsFixed(0), 60),
                            _buildDataCell(
                              '₹${item.rsp.toStringAsFixed(2)}',
                              100,
                            ),
                            _buildDataCell(
                              '${item.discPercent.toStringAsFixed(0)}%',
                              70,
                            ),
                            _buildDataCell(
                              '₹${item.unitPrice.toStringAsFixed(2)}',
                              100,
                            ),
                            _buildDataCell(
                              '₹${item.total.toStringAsFixed(2)}',
                              100,
                            ),
                            _buildDataCell(
                              '${item.gstPercent.toStringAsFixed(0)}%',
                              70,
                            ),
                            _buildDataCell(
                              '₹${item.gstAmount.toStringAsFixed(2)}',
                              100,
                            ),
                            _buildDataCell(
                              '₹${item.lineTotal.toStringAsFixed(2)}',
                              100,
                              fontWeight: FontWeight.bold,
                            ),
                            _buildDataCell(
                              item.deliveryDate != null
                                  ? DateFormat('dd-MM-yyyy').format(item.deliveryDate!)
                                  : '',
                              120,
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
                  const SizedBox(height: 16),
                  // Totals Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildTotalRow('Subtotal:', '₹${totalAmount.toStringAsFixed(2)}'),
                            const SizedBox(height: 6),
                            _buildTotalRow('GST Amount:', '₹${totalGstAmount.toStringAsFixed(2)}'),
                            const SizedBox(height: 6),
                            _buildTotalRow(
                              'Grand Total:',
                              '₹${grandTotal.toStringAsFixed(2)}',
                              isBold: true,
                              fontSize: 14,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Terms & Conditions
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'T&Cs:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Taxes amounting 18% of the total value will be included in the invoice',
                        style: TextStyle(fontSize: 11),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Lorem Ipsum Doler Sit Amet',
                        style: TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCell(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildDataCell(String text, double width, {FontWeight? fontWeight}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: fontWeight ?? FontWeight.normal,
        ),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, {bool isBold = false, double fontSize = 14}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(width: 16),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

