class Product {
  final int? id;
  final String itemNumber;
  final String itemName;
  final double rate;
  final String description;
  final String hsnCode;

  Product({
    this.id,
    required this.itemNumber,
    required this.itemName,
    required this.rate,
    required this.description,
    required this.hsnCode,
  });

  // Helper methods for numeric sorting
  int get itemNumberAsInt {
    return int.tryParse(itemNumber.trim().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  int get hsnCodeAsInt {
    return int.tryParse(hsnCode.trim().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'itemNumber': itemNumber,
      'itemName': itemName,
      'rate': rate,
      'description': description,
      'hsnCode': hsnCode,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      itemNumber: map['itemNumber'] as String,
      itemName: map['itemName'] as String,
      rate: (map['rate'] as num).toDouble(),
      description: map['description'] as String,
      hsnCode: map['hsnCode'] as String,
    );
  }
}

