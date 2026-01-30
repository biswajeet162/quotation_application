import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/product.dart';
import '../database/database_helper.dart';
import '../services/excel_import_service.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final ExcelImportService _importService = ExcelImportService();
  List<Product> _products = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final products = await _dbHelper.getAllProducts();
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $e')),
        );
      }
    }
  }

  Future<void> _importExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final fileName = result.files.single.name.toLowerCase();

        setState(() {
          _isLoading = true;
        });

        List<Product> products;

        if (fileName.endsWith('.csv')) {
          products = await _importService.importFromCSV(filePath);
        } else {
          products = await _importService.importFromExcel(filePath);
        }

        if (products.isNotEmpty) {
          // Clear existing data before importing new data
          await _dbHelper.clearAllProducts();
          // Insert new products from Excel/CSV
          await _dbHelper.insertProductsBatch(products);
          await _loadProducts();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Successfully imported ${products.length} products'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No products found in the file'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }

        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header with Title and Import Button
          Container(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Products',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _importExcel,
                  icon: const Icon(Icons.upload_file, size: 20),
                  label: const Text('Import Excel'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
              ],
            ),
          ),
          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by Item Name or HSN Code',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Products Table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No products found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Click "Import Excel" to add products',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
                              border: TableBorder.all(
                                color: Colors.grey[300]!,
                                width: 1,
                              ),
                              columns: const [
                                DataColumn(
                                  label: Text(
                                    'Item Number',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Item Name',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Rate',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  numeric: true,
                                ),
                                DataColumn(
                                  label: Text(
                                    'Description',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'HSN Code',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                              rows: _products.map((product) {
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        product.itemNumber,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(product.itemName),
                                    ),
                                    DataCell(
                                      Text(
                                        '₹${product.rate.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 200,
                                        child: Text(
                                          product.description,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(product.hsnCode),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

