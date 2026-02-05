import 'dart:convert';
import 'quotation_item.dart';
import 'product.dart';

class QuotationHistory {
  final int? id;
  final String quotationNumber;
  final DateTime quotationDate;
  final String customerName;
  final String customerAddress;
  final String customerContact;
  final String customerEmail;
  final List<QuotationItem> items;
  final double totalAmount;
  final double totalGstAmount;
  final double grandTotal;
  final String action; // 'download' or 'email'
  final String createdBy; // User who created the quotation
  final DateTime createdAt;

  QuotationHistory({
    this.id,
    required this.quotationNumber,
    required this.quotationDate,
    required this.customerName,
    required this.customerAddress,
    required this.customerContact,
    required this.customerEmail,
    required this.items,
    required this.totalAmount,
    required this.totalGstAmount,
    required this.grandTotal,
    required this.action,
    required this.createdBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    // Convert items to JSON
    final itemsJson = items.map((item) {
      return {
        'productId': item.product?.id,
        'productName': item.product?.information ?? '',
        'hsnCode': item.hsnCode,
        'qty': item.qty,
        'rsp': item.rsp,
        'discPercent': item.discPercent,
        'unitPrice': item.unitPrice,
        'total': item.total,
        'gstPercent': item.gstPercent,
        'gstAmount': item.gstAmount,
        'lineTotal': item.lineTotal,
        'deliveryDate': item.deliveryDate?.toIso8601String(),
      };
    }).toList();

    return {
      'id': id,
      'quotationNumber': quotationNumber,
      'quotationDate': quotationDate.toIso8601String(),
      'customerName': customerName,
      'customerAddress': customerAddress,
      'customerContact': customerContact,
      'customerEmail': customerEmail,
      'items': jsonEncode(itemsJson),
      'totalAmount': totalAmount,
      'totalGstAmount': totalGstAmount,
      'grandTotal': grandTotal,
      'action': action,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory QuotationHistory.fromMap(Map<String, dynamic> map) {
    // Parse items from JSON
    List<QuotationItem> items = [];
    try {
      final itemsJson = jsonDecode(map['items'] as String) as List;
      items = itemsJson.map((itemMap) {
        // Create a minimal Product object with stored data for display
        final productName = itemMap['productName'] as String? ?? '';
        final product = productName.isNotEmpty
            ? Product(
                id: itemMap['productId'] as int?,
                designation: '',
                group: '',
                quantity: 0,
                rsp: 0,
                totalLineGrossWeight: 0,
                packQuantity: 0,
                packVolume: 0,
                information: productName,
              )
            : null;

        final item = QuotationItem(
          product: product,
          hsnCode: itemMap['hsnCode'] as String? ?? '',
          qty: (itemMap['qty'] as num?)?.toDouble() ?? 0,
          rsp: (itemMap['rsp'] as num?)?.toDouble() ?? 0,
          discPercent: (itemMap['discPercent'] as num?)?.toDouble() ?? 0,
          unitPrice: (itemMap['unitPrice'] as num?)?.toDouble() ?? 0,
          total: (itemMap['total'] as num?)?.toDouble() ?? 0,
          gstPercent: (itemMap['gstPercent'] as num?)?.toDouble() ?? 0,
          gstAmount: (itemMap['gstAmount'] as num?)?.toDouble() ?? 0,
          lineTotal: (itemMap['lineTotal'] as num?)?.toDouble() ?? 0,
          deliveryDate: itemMap['deliveryDate'] != null
              ? DateTime.parse(itemMap['deliveryDate'] as String)
              : null,
        );
        return item;
      }).toList();
    } catch (e) {
      // If parsing fails, return empty list
      items = [];
    }

    return QuotationHistory(
      id: map['id'] as int?,
      quotationNumber: map['quotationNumber'] as String,
      quotationDate: DateTime.parse(map['quotationDate'] as String),
      customerName: map['customerName'] as String,
      customerAddress: map['customerAddress'] as String,
      customerContact: map['customerContact'] as String,
      customerEmail: map['customerEmail'] as String,
      items: items,
      totalAmount: (map['totalAmount'] as num).toDouble(),
      totalGstAmount: (map['totalGstAmount'] as num).toDouble(),
      grandTotal: (map['grandTotal'] as num).toDouble(),
      action: map['action'] as String,
      createdBy: map['createdBy'] as String? ?? 'Unknown',
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}

