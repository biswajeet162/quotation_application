import 'product.dart';

class QuotationItem {
  Product? product;
  String hsnCode;
  double qty;
  double rsp;
  double discPercent;
  double unitPrice;
  double total;
  double gstPercent;
  double gstAmount;
  DateTime? deliveryDate;
  double lineTotal;

  QuotationItem({
    this.product,
    this.hsnCode = '',
    this.qty = 0,
    this.rsp = 0,
    this.discPercent = 0,
    this.unitPrice = 0,
    this.total = 0,
    this.gstPercent = 0,
    this.gstAmount = 0,
    this.deliveryDate,
    this.lineTotal = 0,
  });

  void calculateValues() {
    // Calculate Total = Qty * RSP
    total = qty * rsp;
    
    // Calculate Unit Price = Total - (Total * Disc% / 100)
    unitPrice = total - (total * discPercent / 100);
    
    // Calculate GST Amount = Unit Price * GST% / 100
    gstAmount = unitPrice * gstPercent / 100;
    
    // Calculate Line Total = Unit Price + GST Amount
    lineTotal = unitPrice + gstAmount;
  }
}

