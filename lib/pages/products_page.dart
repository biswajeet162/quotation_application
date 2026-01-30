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
  String _sortColumn = 'itemNumber';
  bool _sortAscending = true;

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
        _sortProducts();
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

  void _sortProducts() {
    _products.sort((a, b) {
      int comparison = 0;
      switch (_sortColumn) {
        case 'itemNumber':
          // Sort as integer
          comparison = a.itemNumberAsInt.compareTo(b.itemNumberAsInt);
          break;
        case 'itemName':
          comparison = a.itemName.compareTo(b.itemName);
          break;
        case 'rate':
          // Sort as number
          comparison = a.rate.compareTo(b.rate);
          break;
        case 'description':
          comparison = a.description.compareTo(b.description);
          break;
        case 'hsnCode':
          // Sort as integer
          comparison = a.hsnCodeAsInt.compareTo(b.hsnCodeAsInt);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });
  }

  void _onSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
      _sortProducts();
    });
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
          // Title and Import Button
          Container(
            padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 16.0),
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
          const SizedBox(height: 16),
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
                    : _buildProductsTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsTable() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1.2),
                1: FlexColumnWidth(2.0),
                2: FlexColumnWidth(1.0),
                3: FlexColumnWidth(2.5),
                4: FlexColumnWidth(1.0),
              },
              children: [
                TableRow(
                  children: [
                    _buildHeaderCell('Item Number', 'itemNumber'),
                    _buildHeaderCell('Item Name', 'itemName'),
                    _buildHeaderCell('Rate', 'rate'),
                    _buildHeaderCell('Description', 'description'),
                    _buildHeaderCell('HSN Code', 'hsnCode'),
                  ],
                ),
              ],
            ),
          ),
          // Table Body
          Expanded(
            child: ListView.builder(
              itemCount: _products.length,
              itemBuilder: (context, index) {
                return _buildTableRow(_products[index], index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, String columnKey) {
    final isSorted = _sortColumn == columnKey;
    return InkWell(
      onTap: () => _onSort(columnKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (isSorted)
              Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 18,
                color: Colors.blue[700],
              )
            else
              Icon(
                Icons.unfold_more,
                size: 18,
                color: Colors.grey[600],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableRow(Product product, int index) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey[200]!),
          ),
        ),
        child: _HoverableTableRow(
          product: product,
          isEven: index % 2 == 0,
        ),
      ),
    );
  }
}

class _HoverableTableRow extends StatefulWidget {
  final Product product;
  final bool isEven;

  const _HoverableTableRow({
    required this.product,
    required this.isEven,
  });

  @override
  State<_HoverableTableRow> createState() => _HoverableTableRowState();
}

class _HoverableTableRowState extends State<_HoverableTableRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        color: _isHovered
            ? Colors.blue[50]
            : widget.isEven
                ? Colors.white
                : Colors.grey[50],
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(1.2),
            1: FlexColumnWidth(2.0),
            2: FlexColumnWidth(1.0),
            3: FlexColumnWidth(2.5),
            4: FlexColumnWidth(1.0),
          },
          children: [
            TableRow(
              children: [
                _buildCell(
                  widget.product.itemNumber,
                  fontWeight: FontWeight.w500,
                ),
                _buildCell(widget.product.itemName),
                _buildCell(
                  '₹${widget.product.rate.toStringAsFixed(2)}',
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
                _buildCell(
                  widget.product.description,
                  maxLines: 2,
                ),
                _buildCell(widget.product.hsnCode),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(
    String text, {
    FontWeight? fontWeight,
    Color? color,
    int? maxLines,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: fontWeight ?? FontWeight.normal,
          color: color ?? Colors.black87,
        ),
        maxLines: maxLines,
        overflow: maxLines != null ? TextOverflow.ellipsis : null,
      ),
    );
  }
}

