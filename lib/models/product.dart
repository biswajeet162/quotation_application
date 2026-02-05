class Product {
  final int? id;

  /// Designation (string) - main identifier coming from Excel
  final String designation;

  /// Group (string)
  final String group;

  /// Quantity (number)
  final double quantity;

  /// RSP (decimal number)
  final double rsp;

  /// Total Line Gross Weight (decimal number)
  final double totalLineGrossWeight;

  /// Pack Quantity (number)
  final int packQuantity;

  /// Pack volume (decimal number)
  final double packVolume;

  /// Information (string)
  final String information;

  Product({
    this.id,
    required this.designation,
    required this.group,
    required this.quantity,
    required this.rsp,
    required this.totalLineGrossWeight,
    required this.packQuantity,
    required this.packVolume,
    required this.information,
  });

  /// Helper for numeric sorting on designation (extracts numeric part if exists)
  int get designationAsInt {
    // Extract numeric part from designation string for sorting
    final numericPart = designation.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(numericPart) ?? 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'designation': designation,
      'groupName': group,
      'quantity': quantity,
      'rsp': rsp,
      'totalLineGrossWeight': totalLineGrossWeight,
      'packQuantity': packQuantity,
      'packVolume': packVolume,
      'information': information,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    // Handle designation - can be int (old data) or string (new data)
    // SQLite might return it as int even if column is TEXT (if migration didn't run)
    String designation = '';
    try {
      final designationValue = map['designation'];
      if (designationValue != null) {
        if (designationValue is String) {
          designation = designationValue;
        } else if (designationValue is int) {
          designation = designationValue.toString();
        } else if (designationValue is double) {
          designation = designationValue.toInt().toString();
        } else if (designationValue is num) {
          designation = designationValue.toString();
        } else {
          designation = designationValue.toString();
        }
      }
    } catch (e) {
      // If anything goes wrong, default to empty string
      designation = '';
    }
    
    return Product(
      id: map['id'] as int?,
      designation: designation,
      group: (map['groupName'] as String?) ?? '',
      quantity: ((map['quantity'] ?? 0) as num).toDouble(),
      rsp: ((map['rsp'] ?? 0) as num).toDouble(),
      totalLineGrossWeight:
          ((map['totalLineGrossWeight'] ?? 0) as num).toDouble(),
      packQuantity: ((map['packQuantity'] ?? 0) as num).toInt(),
      packVolume: ((map['packVolume'] ?? 0) as num).toDouble(),
      information: (map['information'] as String?) ?? '',
    );
  }
}

