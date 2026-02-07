import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../models/quotation_item.dart';
import '../models/quotation_history.dart';
import '../models/my_company.dart';
import '../database/database_helper.dart';
import '../services/auth_service.dart';

class PdfService {
  /// Generates and saves a quotation PDF
  static Future<void> generateAndSaveQuotation({
    required BuildContext context,
    required String quotationNumber,
    required DateTime quotationDate,
    required String customerName,
    required String customerAddress,
    required String customerContact,
    required String customerEmail,
    required List<QuotationItem> items,
    required double totalAmount,
    required double totalGstAmount,
    required double grandTotal,
    int? quotationId, // Optional ID - if provided, update existing instead of inserting
  }) async {
    try {
      // Create PDF document
      final pdf = pw.Document();
      
      // Calculate items per page dynamically based on available space
      // First page has header, so fewer items. Subsequent pages can fit more.
      // Reserve space for totals and T&C on the last page (approximately 5-6 rows worth)
      const int itemsPerPageFirst = 8; // Items on first page (with header)
      const int itemsPerPageSubsequent = 15; // Items per subsequent page (more space)
      const int reservedRowsForTotals = 6; // Reserve space for totals and T&C sections
      
      // Create first page with header
      int itemsToShowFirst = items.length > itemsPerPageFirst ? itemsPerPageFirst : items.length;
      bool isFirstPageAlsoLast = (items.length <= itemsPerPageFirst);
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(30),
          build: (pw.Context context) {
            return _buildFirstPage(
              quotationNumber: quotationNumber,
              quotationDate: quotationDate,
              customerName: customerName,
              customerAddress: customerAddress,
              customerContact: customerContact,
              items: items.sublist(0, itemsToShowFirst),
              showTotals: isFirstPageAlsoLast,
              totalAmount: totalAmount,
              totalGstAmount: totalGstAmount,
              grandTotal: grandTotal,
            );
          },
        ),
      );
      
      // Create subsequent pages if needed - ensure all items are included
      // Try to fit totals and T&C on the same page as the last items if space allows
      if (items.length > itemsPerPageFirst) {
        int currentIndex = itemsPerPageFirst;
        bool totalsShown = false;
        
        // Create pages for all remaining items
        while (currentIndex < items.length) {
          // Calculate remaining items
          int remainingItems = items.length - currentIndex;
          int endIndex;
          bool isLastPage = false;
          
          // Check if this is the last page
          if (remainingItems <= itemsPerPageSubsequent) {
            endIndex = items.length;
            isLastPage = true;
          } else {
            endIndex = currentIndex + itemsPerPageSubsequent;
          }
          
          // Ensure we have valid indices
          if (currentIndex >= endIndex || currentIndex >= items.length) {
            break;
          }
          
          // Capture values for the closure
          final pageStartIndex = currentIndex;
          final pageEndIndex = endIndex;
          final pageItems = items.sublist(pageStartIndex, pageEndIndex);
          final isLastPageFinal = isLastPage;
          
          // Check if there's space for totals on the last page
          // If last page has fewer items than capacity, there's likely space
          bool showTotalsOnThisPage = isLastPageFinal && 
                                      (remainingItems < itemsPerPageSubsequent - reservedRowsForTotals);
          
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4.landscape,
              margin: const pw.EdgeInsets.all(30),
              build: (pw.Context context) {
                return _buildSubsequentPage(
                  items: pageItems,
                  startItemNumber: pageStartIndex + 1,
                  showTotals: showTotalsOnThisPage,
                  totalAmount: totalAmount,
                  totalGstAmount: totalGstAmount,
                  grandTotal: grandTotal,
                );
              },
            ),
          );
          
          if (showTotalsOnThisPage) {
            totalsShown = true;
          }
          
          currentIndex = pageEndIndex;
        }
        
        // Only create a separate page for totals if they weren't shown on the last items page
        if (!totalsShown) {
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4.landscape,
              margin: const pw.EdgeInsets.all(30),
              build: (pw.Context context) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(height: 40), // Top margin for subsequent page
                    _buildTotalsAndTermsRow(
                      totalAmount: totalAmount,
                      totalGstAmount: totalGstAmount,
                      grandTotal: grandTotal,
                    ),
                  ],
                );
              },
            ),
          );
        }
      }

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

        // Update or save to quotation history
        if (quotationId != null) {
          // Update existing quotation by ID (keep original creation date)
          await DatabaseHelper.instance.updateQuotationHistoryAction(
            quotationId!,
            'download',
          );
        } else {
          // Check if quotation with same number already exists
          final existingQuotations = await DatabaseHelper.instance.getQuotationHistoryByNumber(quotationNumber);
          if (existingQuotations.isNotEmpty) {
            // Update the existing quotation instead of creating a new one (keep original creation date)
            final existingQuotation = existingQuotations.first;
            await DatabaseHelper.instance.updateQuotationHistoryAction(
              existingQuotation.id!,
              'download',
            );
          } else {
            // No existing quotation found, create new one
            await _saveQuotationHistory(
              context: context,
              quotationNumber: quotationNumber,
              quotationDate: quotationDate,
              customerName: customerName,
              customerAddress: customerAddress,
              customerContact: customerContact,
              customerEmail: customerEmail,
              items: items,
              totalAmount: totalAmount,
              totalGstAmount: totalGstAmount,
              grandTotal: grandTotal,
              action: 'download',
            );
          }
        }

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

        // Update or save to quotation history even if user cancelled file picker
        if (quotationId != null) {
          // Update existing quotation by ID (keep original creation date)
          await DatabaseHelper.instance.updateQuotationHistoryAction(
            quotationId!,
            'download',
          );
        } else {
          // Check if quotation with same number already exists
          final existingQuotations = await DatabaseHelper.instance.getQuotationHistoryByNumber(quotationNumber);
          if (existingQuotations.isNotEmpty) {
            // Update the existing quotation instead of creating a new one (keep original creation date)
            final existingQuotation = existingQuotations.first;
            await DatabaseHelper.instance.updateQuotationHistoryAction(
              existingQuotation.id!,
              'download',
            );
          } else {
            // No existing quotation found, create new one
            await _saveQuotationHistory(
              context: context,
              quotationNumber: quotationNumber,
              quotationDate: quotationDate,
              customerName: customerName,
              customerAddress: customerAddress,
              customerContact: customerContact,
              customerEmail: customerEmail,
              items: items,
              totalAmount: totalAmount,
              totalGstAmount: totalGstAmount,
              grandTotal: grandTotal,
              action: 'download',
            );
          }
        }

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

  /// Generates PDF bytes for a quotation (useful for email attachments)
  static Future<List<int>> generateQuotationPdfBytes({
    required String quotationNumber,
    required DateTime quotationDate,
    required String customerName,
    required String customerAddress,
    required String customerContact,
    required List<QuotationItem> items,
    required double totalAmount,
    required double totalGstAmount,
    required double grandTotal,
  }) async {
    final pdf = pw.Document();
    
    // Calculate items per page dynamically based on available space
    // First page has header, so fewer items. Subsequent pages can fit more.
    // Reserve space for totals and T&C on the last page (approximately 5-6 rows worth)
    const int itemsPerPageFirst = 8; // Items on first page (with header)
    const int itemsPerPageSubsequent = 15; // Items per subsequent page (more space)
    const int reservedRowsForTotals = 6; // Reserve space for totals and T&C sections
    
    // Create first page with header
    int itemsToShowFirst = items.length > itemsPerPageFirst ? itemsPerPageFirst : items.length;
    bool isFirstPageAlsoLast = (items.length <= itemsPerPageFirst);
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return _buildFirstPage(
            quotationNumber: quotationNumber,
            quotationDate: quotationDate,
            customerName: customerName,
            customerAddress: customerAddress,
            customerContact: customerContact,
            items: items.sublist(0, itemsToShowFirst),
            showTotals: isFirstPageAlsoLast,
            totalAmount: totalAmount,
            totalGstAmount: totalGstAmount,
            grandTotal: grandTotal,
          );
        },
      ),
    );
    
    // Create subsequent pages if needed - ensure all items are included
    // Try to fit totals and T&C on the same page as the last items if space allows
    if (items.length > itemsPerPageFirst) {
      int currentIndex = itemsPerPageFirst;
      bool totalsShown = false;
      
      // Create pages for all remaining items
      while (currentIndex < items.length) {
        // Calculate remaining items
        int remainingItems = items.length - currentIndex;
        int endIndex;
        bool isLastPage = false;
        
        // Check if this is the last page
        if (remainingItems <= itemsPerPageSubsequent) {
          endIndex = items.length;
          isLastPage = true;
        } else {
          endIndex = currentIndex + itemsPerPageSubsequent;
        }
        
        // Ensure we have valid indices
        if (currentIndex >= endIndex || currentIndex >= items.length) {
          break;
        }
        
        // Capture values for the closure
        final pageStartIndex = currentIndex;
        final pageEndIndex = endIndex;
        final pageItems = items.sublist(pageStartIndex, pageEndIndex);
        final isLastPageFinal = isLastPage;
        
        // Check if there's space for totals on the last page
        // If last page has fewer items than capacity, there's likely space
        bool showTotalsOnThisPage = isLastPageFinal && 
                                    (remainingItems < itemsPerPageSubsequent - reservedRowsForTotals);
        
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(30),
            build: (pw.Context context) {
              return _buildSubsequentPage(
                items: pageItems,
                startItemNumber: pageStartIndex + 1,
                showTotals: showTotalsOnThisPage,
                totalAmount: totalAmount,
                totalGstAmount: totalGstAmount,
                grandTotal: grandTotal,
              );
            },
          ),
        );
        
        if (showTotalsOnThisPage) {
          totalsShown = true;
        }
        
        currentIndex = pageEndIndex;
      }
      
      // Only create a separate page for totals if they weren't shown on the last items page
      if (!totalsShown) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(30),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(height: 40), // Top margin for subsequent page
                  _buildTotalsAndTermsRow(
                    totalAmount: totalAmount,
                    totalGstAmount: totalGstAmount,
                    grandTotal: grandTotal,
                  ),
                ],
              );
            },
          ),
        );
      }
    }
    
    return await pdf.save();
  }

  /// Builds the first page with full header and initial items
  static pw.Widget _buildFirstPage({
    required String quotationNumber,
    required DateTime quotationDate,
    required String customerName,
    required String customerAddress,
    required String customerContact,
    required List<QuotationItem> items,
    required bool showTotals,
    required double totalAmount,
    required double totalGstAmount,
    required double grandTotal,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header Section
        _buildPdfHeader(
          quotationNumber: quotationNumber,
          quotationDate: quotationDate,
          customerName: customerName,
          customerAddress: customerAddress,
          customerContact: customerContact,
        ),
        pw.SizedBox(height: 16),
        // Item Details Table
        _buildTableWithRows(items: items, startItemNumber: 1),
        if (showTotals) ...[
          pw.SizedBox(height: 16),
          _buildTotalsAndTermsRow(
            totalAmount: totalAmount,
            totalGstAmount: totalGstAmount,
            grandTotal: grandTotal,
          ),
        ],
      ],
    );
  }

  /// Builds subsequent pages with top margin and remaining items
  static pw.Widget _buildSubsequentPage({
    required List<QuotationItem> items,
    required int startItemNumber,
    required bool showTotals,
    required double totalAmount,
    required double totalGstAmount,
    required double grandTotal,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Top margin for subsequent pages
        pw.SizedBox(height: 40),
        // Item Details Table
        _buildTableWithRows(items: items, startItemNumber: startItemNumber),
        if (showTotals) ...[
          pw.SizedBox(height: 16),
          _buildTotalsAndTermsRow(
            totalAmount: totalAmount,
            totalGstAmount: totalGstAmount,
            grandTotal: grandTotal,
          ),
        ],
      ],
    );
  }

  /// Builds the PDF header section (company and customer details)
  static pw.Widget _buildPdfHeader({
    required String quotationNumber,
    required DateTime quotationDate,
    required String customerName,
    required String customerAddress,
    required String customerContact,
  }) {
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
                              MyCompany.name,
                              style: pw.TextStyle(
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            ...MyCompany.address.split('\n').map((line) => pw.Padding(
                              padding: const pw.EdgeInsets.only(bottom: 2),
                              child: pw.Text(
                                line,
                                style: const pw.TextStyle(fontSize: 12),
                              ),
                            )),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'GST: ${MyCompany.gst}',
                              style: const pw.TextStyle(fontSize: 12),
                            ),
                            pw.Text(
                              'PAN: ${MyCompany.pan}',
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
      ],
    );
  }

  /// Builds table with header and rows
  static pw.Widget _buildTableWithRows({
    required List<QuotationItem> items,
    required int startItemNumber,
  }) {
    return pw.Table(
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
        _buildTableHeader(),
        // Table Rows
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: (startItemNumber - 1 + index) % 2 == 0 ? PdfColors.white : PdfColors.grey100,
            ),
            children: [
              _buildPdfCell('${startItemNumber + index}'),
              _buildPdfCell(
                item.product?.information ?? '',
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
    );
  }

  /// Builds table header row
  static pw.TableRow _buildTableHeader() {
    return pw.TableRow(
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
    );
  }

  /// Builds totals section
  static pw.Widget _buildTotalsSection({
    required double totalAmount,
    required double totalGstAmount,
    required double grandTotal,
  }) {
    return pw.Align(
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
    );
  }

  /// Builds terms and conditions section
  static pw.Widget _buildTermsSection() {
    return pw.Column(
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
    );
  }

  /// Builds totals and terms side by side on the same horizontal line
  static pw.Widget _buildTotalsAndTermsRow({
    required double totalAmount,
    required double totalGstAmount,
    required double grandTotal,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Terms and Conditions on the left
        pw.Expanded(
          flex: 2,
          child: _buildTermsSection(),
        ),
        pw.SizedBox(width: 20), // Spacing between terms and totals
        // Totals on the right
        pw.Expanded(
          flex: 1,
          child: _buildTotalsSection(
            totalAmount: totalAmount,
            totalGstAmount: totalGstAmount,
            grandTotal: grandTotal,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildPdfContent({
    required String quotationNumber,
    required DateTime quotationDate,
    required String customerName,
    required String customerAddress,
    required String customerContact,
    required List<QuotationItem> items,
    required double totalAmount,
    required double totalGstAmount,
    required double grandTotal,
  }) {
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
                              MyCompany.name,
                              style: pw.TextStyle(
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            ...MyCompany.address.split('\n').map((line) => pw.Padding(
                              padding: const pw.EdgeInsets.only(bottom: 2),
                              child: pw.Text(
                                line,
                                style: const pw.TextStyle(fontSize: 12),
                              ),
                            )),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'GST: ${MyCompany.gst}',
                              style: const pw.TextStyle(fontSize: 12),
                            ),
                            pw.Text(
                              'PAN: ${MyCompany.pan}',
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
                    item.product?.information ?? '',
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
  }

  static pw.Widget _buildPdfCell(String text, {bool isHeader = false, pw.FontWeight? fontWeight}) {
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

  static pw.Widget _buildPdfTotalRow(String label, String value, {bool isBold = false, double fontSize = 12}) {
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

  /// Saves quotation to history
  static Future<void> _saveQuotationHistory({
    required BuildContext context,
    required String quotationNumber,
    required DateTime quotationDate,
    required String customerName,
    required String customerAddress,
    required String customerContact,
    required String customerEmail,
    required List<QuotationItem> items,
    required double totalAmount,
    required double totalGstAmount,
    required double grandTotal,
    required String action,
  }) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;
      final createdBy = currentUser?.name.isNotEmpty == true
          ? currentUser!.name
          : (currentUser?.email ?? 'Unknown');
      
      final quotationHistory = QuotationHistory(
        quotationNumber: quotationNumber,
        quotationDate: quotationDate,
        customerName: customerName,
        customerAddress: customerAddress,
        customerContact: customerContact,
        customerEmail: customerEmail,
        items: items,
        totalAmount: totalAmount,
        totalGstAmount: totalGstAmount,
        grandTotal: grandTotal,
        action: action,
        createdBy: createdBy,
        createdAt: DateTime.now(),
      );

      await DatabaseHelper.instance.insertQuotationHistory(quotationHistory);
    } catch (e) {
      // Silently handle errors - don't interrupt the download process
      debugPrint('Error saving quotation history: $e');
    }
  }
}

