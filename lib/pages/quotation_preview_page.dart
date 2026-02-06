import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/quotation_item.dart';
import '../services/pdf_service.dart';
import '../services/email_service.dart';
import '../database/database_helper.dart';

class QuotationPreviewPage extends StatelessWidget {
  final String quotationNumber;
  final DateTime quotationDate;
  final String customerName;
  final String customerAddress;
  final String customerContact;
  final String customerEmail;
  final List<QuotationItem> items;
  final int? quotationId; // Optional ID to update action when downloaded

  const QuotationPreviewPage({
    super.key,
    required this.quotationNumber,
    required this.quotationDate,
    required this.customerName,
    required this.customerAddress,
    required this.customerContact,
    required this.customerEmail,
    required this.items,
    this.quotationId,
  });

  // Calculate totals
  Map<String, double> _calculateTotals() {
    double totalAmount = 0;
    double totalGstAmount = 0;
    double grandTotal = 0;
    for (var item in items) {
      totalAmount += item.unitPrice;
      totalGstAmount += item.gstAmount;
      grandTotal += item.lineTotal;
    }
    return {
      'totalAmount': totalAmount,
      'totalGstAmount': totalGstAmount,
      'grandTotal': grandTotal,
    };
  }

  Future<void> _downloadQuotation(BuildContext context) async {
    final totals = _calculateTotals();
    await PdfService.generateAndSaveQuotation(
      context: context,
      quotationNumber: quotationNumber,
      quotationDate: quotationDate,
      customerName: customerName,
      customerAddress: customerAddress,
      customerContact: customerContact,
      customerEmail: customerEmail,
      items: items,
      totalAmount: totals['totalAmount']!,
      totalGstAmount: totals['totalGstAmount']!,
      grandTotal: totals['grandTotal']!,
      quotationId: quotationId, // Pass ID to prevent duplicate insertion
    );
    
    // If this is a saved quotation from history, update its action to "downloaded" and update timestamp
    if (quotationId != null) {
      try {
        await DatabaseHelper.instance.updateQuotationHistoryAction(
          quotationId!,
          'download',
          updatedAt: DateTime.now(), // Update to current time when downloaded
        );
      } catch (e) {
        // Log error but don't show to user as PDF was already downloaded
        debugPrint('Error updating quotation action: $e');
      }
    }
  }

  Future<void> _emailQuotation(BuildContext context) async {
    final totals = _calculateTotals();
    await EmailService.sendQuotationEmail(
      context: context,
      quotationNumber: quotationNumber,
      quotationDate: quotationDate,
      customerName: customerName,
      customerAddress: customerAddress,
      customerContact: customerContact,
      customerEmail: customerEmail,
      items: items,
      totalAmount: totals['totalAmount']!,
      totalGstAmount: totals['totalGstAmount']!,
      grandTotal: totals['grandTotal']!,
      quotationId: quotationId, // Pass ID to prevent duplicate insertion
    );
    
    // If this is a saved quotation from history, update its action to "email" and update timestamp
    if (quotationId != null) {
      try {
        await DatabaseHelper.instance.updateQuotationHistoryAction(
          quotationId!,
          'email',
          updatedAt: DateTime.now(), // Update to current time when emailed
        );
      } catch (e) {
        // Log error but don't show to user as email was already sent
        debugPrint('Error updating quotation action: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totals = _calculateTotals();
    final totalAmount = totals['totalAmount']!;
    final totalGstAmount = totals['totalGstAmount']!;
    final grandTotal = totals['grandTotal']!;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final availableHeight = constraints.maxHeight;
          
          return Container(
            width: availableWidth,
            height: availableHeight,
            constraints: BoxConstraints(
              maxWidth: 1400,
              maxHeight: availableHeight,
            ),
            child: Column(
              children: [
                // Header Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue[700],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Quotation Preview',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _downloadQuotation(context),
                        icon: const Icon(Icons.download, color: Colors.white, size: 16),
                        label: const Text(
                          'Download',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                        ),
                      ),
                      // Email button hidden for now
                      // const SizedBox(width: 8),
                      // ElevatedButton.icon(
                      //   onPressed: () => _emailQuotation(context),
                      //   icon: const Icon(Icons.email, color: Colors.white, size: 16),
                      //   label: const Text(
                      //     'Email',
                      //     style: TextStyle(
                      //       color: Colors.white,
                      //       fontSize: 12,
                      //       fontWeight: FontWeight.bold,
                      //     ),
                      //   ),
                      //   style: ElevatedButton.styleFrom(
                      //     backgroundColor: Colors.orange,
                      //     foregroundColor: Colors.white,
                      //     padding: const EdgeInsets.symmetric(
                      //       horizontal: 12,
                      //       vertical: 6,
                      //     ),
                      //   ),
                      // ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
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
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        '2, Ring Rd, Awas Vikas,',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                      Text(
                                        'Rudrapur, Jagatpura,',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                      Text(
                                        'Uttarakhand 263153',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        'GSTIN No.: XXXXXXX XXXXXXXX',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                      SizedBox(height: 2),
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
                  // Item Details Table - Fits to screen width
                  LayoutBuilder(
                    builder: (context, tableConstraints) {
                            final tableWidth = tableConstraints.maxWidth;
                            // Calculate column widths as percentages of available width
                            final colWidths = {
                              'sno': tableWidth * 0.04,
                              'item': tableWidth * 0.20,
                              'hsn': tableWidth * 0.08,
                              'qty': tableWidth * 0.05,
                              'rsp': tableWidth * 0.08,
                              'disc': tableWidth * 0.05,
                              'unitPrice': tableWidth * 0.08,
                              'total': tableWidth * 0.08,
                              'gstPercent': tableWidth * 0.05,
                              'gstAmount': tableWidth * 0.08,
                              'lineTotal': tableWidth * 0.08,
                              'deliveryDate': tableWidth * 0.09,
                            };
                            
                            return Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Column(
                                children: [
                                  // Table Header
                                  Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(4),
                                        topRight: Radius.circular(4),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        _buildHeaderCell('S.No.', colWidths['sno']!),
                                        _buildHeaderCell('Item', colWidths['item']!),
                                        _buildHeaderCell('HSN', colWidths['hsn']!),
                                        _buildHeaderCell('Qty', colWidths['qty']!),
                                        _buildHeaderCell('RSP', colWidths['rsp']!),
                                        _buildHeaderCell('Disc%', colWidths['disc']!),
                                        _buildHeaderCell('Unit Price', colWidths['unitPrice']!),
                                        _buildHeaderCell('Total', colWidths['total']!),
                                        _buildHeaderCell('GST%', colWidths['gstPercent']!),
                                        _buildHeaderCell('GST Amt', colWidths['gstAmount']!),
                                        _buildHeaderCell('Line Total', colWidths['lineTotal']!),
                                        _buildHeaderCell('Del. Date', colWidths['deliveryDate']!),
                                      ],
                                    ),
                                  ),
                                  // Table Rows
                                  ...items.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final item = entry.value;
                                    return Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(color: Colors.grey[200]!),
                                        ),
                                        color: index % 2 == 0 ? Colors.white : Colors.grey[50],
                                      ),
                                      child: Row(
                                        children: [
                                          _buildDataCell('${index + 1}', colWidths['sno']!),
                                          _buildDataCell(
                                            item.product?.information ?? '',
                                            colWidths['item']!,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          _buildDataCell(item.hsnCode, colWidths['hsn']!),
                                          _buildDataCell(item.qty.toStringAsFixed(0), colWidths['qty']!),
                                          _buildDataCell(
                                            '₹${item.rsp.toStringAsFixed(2)}',
                                            colWidths['rsp']!,
                                          ),
                                          _buildDataCell(
                                            '${item.discPercent.toStringAsFixed(0)}%',
                                            colWidths['disc']!,
                                          ),
                                          _buildDataCell(
                                            '₹${item.unitPrice.toStringAsFixed(2)}',
                                            colWidths['unitPrice']!,
                                          ),
                                          _buildDataCell(
                                            '₹${item.total.toStringAsFixed(2)}',
                                            colWidths['total']!,
                                          ),
                                          _buildDataCell(
                                            '${item.gstPercent.toStringAsFixed(0)}%',
                                            colWidths['gstPercent']!,
                                          ),
                                          _buildDataCell(
                                            '₹${item.gstAmount.toStringAsFixed(2)}',
                                            colWidths['gstAmount']!,
                                          ),
                                          _buildDataCell(
                                            '₹${item.lineTotal.toStringAsFixed(2)}',
                                            colWidths['lineTotal']!,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          _buildDataCell(
                                            item.deliveryDate != null
                                                ? DateFormat('dd-MM-yyyy').format(item.deliveryDate!)
                                                : '',
                                            colWidths['deliveryDate']!,
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            );
                          },
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
                    ],
                  ),
                      ],
                    ),
                  ),
                ),
              ],
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



