import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../models/quotation_item.dart';
import '../models/quotation_history.dart';
import '../database/database_helper.dart';
import 'pdf_service.dart';

class EmailService {
  /// Sends quotation via email
  static Future<void> sendQuotationEmail({
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
  }) async {
    try {
      // Generate PDF
      final pdfBytes = await PdfService.generateQuotationPdfBytes(
        quotationNumber: quotationNumber,
        quotationDate: quotationDate,
        customerName: customerName,
        customerAddress: customerAddress,
        customerContact: customerContact,
        items: items,
        totalAmount: totalAmount,
        totalGstAmount: totalGstAmount,
        grandTotal: grandTotal,
      );

      // Create email body with formatted quotation data
      final emailBody = _buildEmailBody(
        quotationNumber: quotationNumber,
        quotationDate: quotationDate,
        customerName: customerName,
        customerAddress: customerAddress,
        customerContact: customerContact,
        items: items,
        totalAmount: totalAmount,
        totalGstAmount: totalGstAmount,
        grandTotal: grandTotal,
      );

      // Save PDF temporarily
      final output = await getTemporaryDirectory();
      final pdfFile = File('${output.path}/quotation_$quotationNumber.pdf');
      await pdfFile.writeAsBytes(pdfBytes);

      // Create mailto URL with subject and body
      final subject = Uri.encodeComponent('Quotation #$quotationNumber - Ashoka Bearing Enterprises');
      final body = Uri.encodeComponent(emailBody);

      // Use mailto: to open default email client
      final mailtoUri = Uri.parse('mailto:?subject=$subject&body=$body');

      try {
        // Try to launch URL directly (works better on Windows)
        await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
        
        // Save to quotation history
        await _saveQuotationHistory(
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
          action: 'email',
        );
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Email client opened. PDF saved at: ${pdfFile.path}\nPlease attach the PDF manually.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } catch (e) {
        // If launch fails, show the email body and PDF path for manual copy
        // Still save to history even if email client fails to open
        await _saveQuotationHistory(
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
          action: 'email',
        );
        
        if (context.mounted) {
          _showEmailInfoDialog(
            context: context,
            pdfPath: pdfFile.path,
            quotationNumber: quotationNumber,
            emailBody: emailBody,
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error preparing email: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Builds the email body with formatted plain text table
  static String _buildEmailBody({
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
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('═══════════════════════════════════════════════════════════════════════════════');
    buffer.writeln('                    QUOTATION #$quotationNumber');
    buffer.writeln('                 Ashoka Bearing Enterprises');
    buffer.writeln('═══════════════════════════════════════════════════════════════════════════════');
    buffer.writeln('');
    
    // Greeting
    buffer.writeln('Dear ${customerName.isEmpty ? "Customer" : customerName},');
    buffer.writeln('');
    buffer.writeln('Please find below the quotation details:');
    buffer.writeln('');
    
    // Quotation Details
    buffer.writeln('QUOTATION DETAILS');
    buffer.writeln('─────────────────────────────────────────────────────────────────────────────────');
    buffer.writeln('Quotation Number: $quotationNumber');
    buffer.writeln('Quotation Date: ${DateFormat('dd-MM-yyyy').format(quotationDate)}');
    buffer.writeln('');
    buffer.writeln('Customer Details:');
    buffer.writeln('  Name:    ${customerName.isEmpty ? "Customer Name" : customerName}');
    buffer.writeln('  Address: ${customerAddress.isEmpty ? "Address" : customerAddress}');
    buffer.writeln('  Contact: ${customerContact.isEmpty ? "Contact Number" : customerContact}');
    buffer.writeln('');
    
    // Item Details Table
    buffer.writeln('ITEM DETAILS');
    buffer.writeln('─────────────────────────────────────────────────────────────────────────────────');
    buffer.writeln('');
    
    // Define column widths
    final colWidths = {
      'sno': 5,
      'item': 20,
      'hsn': 10,
      'qty': 6,
      'rsp': 12,
      'disc': 7,
      'unitPrice': 12,
      'total': 12,
      'gstPercent': 7,
      'gstAmount': 12,
      'lineTotal': 12,
      'deliveryDate': 12,
    };
    
    // Table Header
    final headerLine = _buildTableRow(
      ['S.No.', 'Item Description', 'HSN Code', 'Qty', 'RSP(INR)', 'Disc%', 'Unit Price', 'Total', 'GST%', 'GST Amt', 'Line Total', 'Del. Date'],
      colWidths,
      isHeader: true,
    );
    buffer.writeln(headerLine);
    buffer.writeln('─' * headerLine.length);
    
    // Table Rows
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final row = _buildTableRow(
        [
          '${i + 1}',
          item.product?.itemName ?? '',
          item.hsnCode,
          item.qty.toStringAsFixed(0),
          '₹${item.rsp.toStringAsFixed(2)}',
          '${item.discPercent.toStringAsFixed(0)}%',
          '₹${item.unitPrice.toStringAsFixed(2)}',
          '₹${item.total.toStringAsFixed(2)}',
          '${item.gstPercent.toStringAsFixed(0)}%',
          '₹${item.gstAmount.toStringAsFixed(2)}',
          '₹${item.lineTotal.toStringAsFixed(2)}',
          item.deliveryDate != null ? DateFormat('dd-MM-yyyy').format(item.deliveryDate!) : '',
        ],
        colWidths,
      );
      buffer.writeln(row);
    }
    
    buffer.writeln('');
    buffer.writeln('─────────────────────────────────────────────────────────────────────────────────');
    buffer.writeln('');
    
    // Totals Section
    buffer.writeln('TOTALS');
    buffer.writeln('─────────────────────────────────────────────────────────────────────────────────');
    final totalsWidth = 50;
    buffer.writeln('Subtotal:'.padLeft(totalsWidth - 15) + '₹${totalAmount.toStringAsFixed(2)}'.padLeft(15));
    buffer.writeln('GST Amount:'.padLeft(totalsWidth - 15) + '₹${totalGstAmount.toStringAsFixed(2)}'.padLeft(15));
    buffer.writeln('GRAND TOTAL:'.padLeft(totalsWidth - 15) + '₹${grandTotal.toStringAsFixed(2)}'.padLeft(15));
    buffer.writeln('');
    
    // Terms & Conditions
    buffer.writeln('TERMS & CONDITIONS');
    buffer.writeln('─────────────────────────────────────────────────────────────────────────────────');
    buffer.writeln('Taxes amounting 18% of the total value will be included in the invoice');
    buffer.writeln('Lorem Ipsum Doler Sit Amet');
    buffer.writeln('');
    
    // Footer
    buffer.writeln('─────────────────────────────────────────────────────────────────────────────────');
    buffer.writeln('');
    buffer.writeln('Please find the detailed quotation attached as PDF.');
    buffer.writeln('');
    buffer.writeln('Best Regards,');
    buffer.writeln('Ashoka Bearing Enterprises');
    buffer.writeln('2, Ring Rd, Awas Vikas, Rudrapur, Jagatpura, Uttarakhand 263153');
    
    return buffer.toString();
  }
  
  /// Builds a formatted table row with proper spacing
  static String _buildTableRow(
    List<String> values,
    Map<String, int> colWidths,
    {bool isHeader = false}
  ) {
    final columns = [
      'sno', 'item', 'hsn', 'qty', 'rsp', 'disc', 'unitPrice', 'total', 
      'gstPercent', 'gstAmount', 'lineTotal', 'deliveryDate'
    ];
    
    final buffer = StringBuffer();
    buffer.write('│');
    
    for (var i = 0; i < columns.length && i < values.length; i++) {
      final colKey = columns[i];
      final width = colWidths[colKey] ?? 10;
      final value = values[i];
      
      // Truncate or pad the value
      String formattedValue;
      if (value.length > width) {
        formattedValue = value.substring(0, width - 1) + '…';
      } else {
        if (i == 1) {
          // Left align item description
          formattedValue = value.padRight(width);
        } else {
          // Center align other columns
          final padding = width - value.length;
          final leftPad = padding ~/ 2;
          final rightPad = padding - leftPad;
          formattedValue = ' ' * leftPad + value + ' ' * rightPad;
        }
      }
      
      buffer.write(' $formattedValue │');
    }
    
    return buffer.toString();
  }

  /// Shows a dialog with email information when email client cannot be opened
  static void _showEmailInfoDialog({
    required BuildContext context,
    required String pdfPath,
    required String quotationNumber,
    required String emailBody,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Email Information'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Could not open email client automatically. Please use the information below:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('PDF Location:', style: TextStyle(fontWeight: FontWeight.bold)),
              SelectableText(pdfPath),
              const SizedBox(height: 16),
              const Text('Email Subject:', style: TextStyle(fontWeight: FontWeight.bold)),
              SelectableText('Quotation #$quotationNumber - Ashoka Bearing Enterprises'),
              const SizedBox(height: 16),
              const Text('Email Body:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(
                  emailBody,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Saves quotation to history
  static Future<void> _saveQuotationHistory({
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
        createdAt: DateTime.now(),
      );

      await DatabaseHelper.instance.insertQuotationHistory(quotationHistory);
    } catch (e) {
      // Silently handle errors - don't interrupt the email process
      debugPrint('Error saving quotation history: $e');
    }
  }
}

