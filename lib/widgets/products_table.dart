import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/product.dart';

class ProductsTable extends StatelessWidget {
  final List<Product> products;
  final String sortColumn;
  final bool sortAscending;
  final Function(String) onSort;

  const ProductsTable({
    super.key,
    required this.products,
    required this.sortColumn,
    required this.sortAscending,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildTableHeader(),
          Expanded(
            child: _buildTableBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
    );
  }

  Widget _buildTableHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(1.0),
          1: FlexColumnWidth(1.8),
          2: FlexColumnWidth(1.0),
          3: FlexColumnWidth(1.2),
          4: FlexColumnWidth(2.5),
        },
        children: [
          TableRow(
            children: [
              _SortableHeaderCell(
                text: 'Designation',
                columnKey: 'designation',
                sortColumn: sortColumn,
                sortAscending: sortAscending,
                onSort: onSort,
              ),
              _SortableHeaderCell(
                text: 'Group',
                columnKey: 'group',
                sortColumn: sortColumn,
                sortAscending: sortAscending,
                onSort: onSort,
              ),
              _SortableHeaderCell(
                text: 'Quantity',
                columnKey: 'quantity',
                sortColumn: sortColumn,
                sortAscending: sortAscending,
                onSort: onSort,
              ),
              _SortableHeaderCell(
                text: 'RSP',
                columnKey: 'rsp',
                sortColumn: sortColumn,
                sortAscending: sortAscending,
                onSort: onSort,
              ),
              _SortableHeaderCell(
                text: 'Information',
                columnKey: 'information',
                sortColumn: sortColumn,
                sortAscending: sortAscending,
                onSort: onSort,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableBody() {
    return ListView.builder(
      itemCount: products.length,
      itemBuilder: (context, index) {
        return _ProductTableRow(
          product: products[index],
          isEven: index % 2 == 0,
        );
      },
    );
  }
}

class _SortableHeaderCell extends StatelessWidget {
  final String text;
  final String columnKey;
  final String sortColumn;
  final bool sortAscending;
  final Function(String) onSort;

  const _SortableHeaderCell({
    required this.text,
    required this.columnKey,
    required this.sortColumn,
    required this.sortAscending,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    final isSorted = sortColumn == columnKey;
    return InkWell(
      onTap: () => onSort(columnKey),
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
                sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
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
}

class _ProductTableRow extends StatefulWidget {
  final Product product;
  final bool isEven;

  const _ProductTableRow({
    required this.product,
    required this.isEven,
  });

  @override
  State<_ProductTableRow> createState() => _ProductTableRowState();
}

class _ProductTableRowState extends State<_ProductTableRow> {
  bool _isHovered = false;

  void _showProductDetails() {
    showDialog(
      context: context,
      builder: (context) => _ProductDetailsDialog(product: widget.product),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: _showProductDetails,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey[200]!),
            ),
            color: _isHovered
                ? Colors.blue[50]
                : widget.isEven
                    ? Colors.white
                    : Colors.grey[50],
          ),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(1.0),
              1: FlexColumnWidth(1.8),
              2: FlexColumnWidth(1.0),
              3: FlexColumnWidth(1.2),
              4: FlexColumnWidth(2.5),
            },
            children: [
              TableRow(
                children: [
                _DesignationCell(
                  text: widget.product.designation,
                  fontWeight: FontWeight.w500,
                ),
                  _TableCell(text: widget.product.group),
                  _TableCell(
                    text: widget.product.quantity.toStringAsFixed(2),
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                  _TableCell(
                    text: '₹${widget.product.rsp.toStringAsFixed(2)}',
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                  _TableCell(
                    text: widget.product.information,
                    maxLines: 2,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesignationCell extends StatefulWidget {
  final String text;
  final FontWeight? fontWeight;
  final Color? color;

  const _DesignationCell({
    required this.text,
    this.fontWeight,
    this.color,
  });

  @override
  State<_DesignationCell> createState() => _DesignationCellState();
}

class _DesignationCellState extends State<_DesignationCell> {
  bool _isHovered = false;

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copied "${widget.text}" to clipboard'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.text,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: widget.fontWeight ?? FontWeight.normal,
                  color: widget.color ?? Colors.black87,
                ),
              ),
            ),
            if (_isHovered) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: _copyToClipboard,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.copy,
                    size: 16,
                    color: Colors.blue[700],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final FontWeight? fontWeight;
  final Color? color;
  final int? maxLines;

  const _TableCell({
    required this.text,
    this.fontWeight,
    this.color,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
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

class _ProductDetailsDialog extends StatefulWidget {
  final Product product;

  const _ProductDetailsDialog({required this.product});

  @override
  State<_ProductDetailsDialog> createState() => _ProductDetailsDialogState();
}

class _ProductDetailsDialogState extends State<_ProductDetailsDialog> {
  Future<void> _copyDesignation() async {
    await Clipboard.setData(ClipboardData(text: widget.product.designation));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copied "${widget.product.designation}" to clipboard'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor, bool showCopyIcon = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: valueColor ?? Colors.black87,
                    fontWeight: valueColor != null ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (showCopyIcon) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: _copyDesignation,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.copy,
                        size: 18,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.inventory_2,
                    color: Colors.blue[700],
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Product Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey[700]),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildDetailRow('Designation', widget.product.designation, showCopyIcon: true),
                    _buildDetailRow('Group', widget.product.group),
                    _buildDetailRow(
                      'Quantity',
                      widget.product.quantity.toStringAsFixed(2),
                      valueColor: Colors.green[700],
                    ),
                    _buildDetailRow(
                      'RSP',
                      '₹${widget.product.rsp.toStringAsFixed(2)}',
                      valueColor: Colors.green[700],
                    ),
                    _buildDetailRow(
                      'Total Line Gross Weight',
                      widget.product.totalLineGrossWeight.toStringAsFixed(2),
                    ),
                    _buildDetailRow(
                      'Pack Quantity',
                      widget.product.packQuantity.toString(),
                    ),
                    _buildDetailRow(
                      'Pack Volume',
                      widget.product.packVolume.toStringAsFixed(2),
                    ),
                    _buildDetailRow(
                      'Information',
                      widget.product.information.isEmpty ? 'N/A' : widget.product.information,
                    ),
                    if (widget.product.id != null)
                      _buildDetailRow('ID', widget.product.id.toString()),
                  ],
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

