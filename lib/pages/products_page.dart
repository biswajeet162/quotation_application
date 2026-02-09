import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/product.dart';
import '../database/database_helper.dart';
import '../services/excel_import_service.dart';
import '../utils/product_search_util.dart';
import '../utils/product_sort_util.dart';
import '../widgets/page_header.dart';
import '../widgets/search_bar.dart' show AppSearchBar;
import '../widgets/products_table.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => ProductsPageState();
}

class ProductsPageState extends State<ProductsPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final ExcelImportService _importService = ExcelImportService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = false;
  String _sortColumn = 'designation';
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void reloadData() {
    if (mounted) {
      _loadProducts();
    }
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      // Apply search filter
      _filteredProducts = ProductSearchUtil.searchProducts(
        _allProducts,
        _searchController.text,
      );
      
      // Apply sorting
      ProductSortUtil.sortProducts(
        _filteredProducts,
        _sortColumn,
        _sortAscending,
      );
    });
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final products = await _dbHelper.getAllProducts();
      setState(() {
        _allProducts = products;
        _applyFilters();
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

  void _onSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
      _applyFilters();
    });
  }

  Future<void> _clearDatabase() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Database'),
        content: const Text(
          'Are you sure you want to clear all products from the database? This action cannot be undone.',
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
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await _dbHelper.clearAllProducts();
        await _loadProducts();
        _searchController.clear();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Database cleared successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error clearing database: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }

      setState(() {
        _isLoading = false;
      });
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
            // Clear search after import
            _searchController.clear();
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
          // Page Header with Import and Clear DB Buttons
          PageHeader(
            title: 'Products',
            count: _filteredProducts.length,
            actionButton: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _clearDatabase,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  label: const Text('Clear DB'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    side: BorderSide(color: Colors.red[300]!),
                    foregroundColor: Colors.red[700],
                  ),
                ),
                const SizedBox(width: 12),
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
          AppSearchBar(
            hintText: 'Search by Designation, Group, Quantity, RSP, or Information',
            controller: _searchController,
          ),
          const SizedBox(height: 16),
          // Products Table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ProductsTable(
                    products: _filteredProducts,
                    sortColumn: _sortColumn,
                    sortAscending: _sortAscending,
                    onSort: _onSort,
                  ),
          ),
        ],
      ),
    );
  }
}

