import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../models/quotation_item.dart';
import '../database/database_helper.dart';
import '../widgets/page_header.dart';

class CreateQuotationPage extends StatefulWidget {
  const CreateQuotationPage({super.key});

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
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      if (_items.isEmpty) {
        _addNewItem();
      }
    });
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
    }
  }

  void _generateQuotation() {
    // TODO: Implement quotation generation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Quotation generation will be implemented'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.all(24.0),
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'Create Quotation',
              ),
              const SizedBox(height: 24),
              // Customer Details Section
              _buildCustomerDetailsSection(),
              const SizedBox(height: 32),
              // Item Details Section
              _buildItemDetailsSection(),
              const SizedBox(height: 24),
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
            ],
          ),
        ),
      ),
      // Generate Button (Fixed at bottom right)
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _generateQuotation,
        backgroundColor: Colors.green,
        icon: const Icon(Icons.description, color: Colors.white),
        label: const Text(
          'Generate',
          style: TextStyle(color: Colors.white),
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
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
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
                    ),
                  ),
                ),
                Icon(Icons.calendar_today, size: 20, color: Colors.grey[600]),
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
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        isDense: true,
      ),
      hint: const Text(
        'Items',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14),
      ),
      isExpanded: true,
      style: const TextStyle(fontSize: 14),
      alignment: Alignment.center,
      items: _products.map((product) {
        return DropdownMenuItem<Product>(
          value: product,
          child: Text(
            product.itemName,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14),
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
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
        ),
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
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                item.deliveryDate != null
                    ? DateFormat('dd-MM-yyyy').format(item.deliveryDate!)
                    : '',
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
            Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }
}

