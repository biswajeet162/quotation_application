import 'dart:io';
import 'dart:convert';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import '../models/product.dart';

class ExcelImportService {
  Future<List<Product>> importFromExcel(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    final List<Product> products = [];

    for (var table in excel.tables.keys) {
      final sheet = excel.tables[table];
      if (sheet == null) continue;

      // Skip header row (row 0)
      for (var row in sheet.rows.skip(1)) {
        if (row.isEmpty) continue;

        try {
          // Access cell values directly
          // Column order: Item Number, Item Name, Rate, Description, HSN Code
          final itemNumber = row.isNotEmpty && row[0] != null
              ? _getCellValue(row[0])
              : '';
          final itemName = row.length > 1 && row[1] != null
              ? _getCellValue(row[1])
              : '';
          final rateStr = row.length > 2 && row[2] != null
              ? _getCellValue(row[2])
              : '0';
          final description = row.length > 3 && row[3] != null
              ? _getCellValue(row[3])
              : '';
          final hsnCode = row.length > 4 && row[4] != null
              ? _getCellValue(row[4])
              : '';

          if (itemName == null || itemName.toString().isEmpty) continue;

          final rate = double.tryParse(rateStr.toString()) ?? 0.0;
          
          // Parse Item Number as integer (remove any non-numeric characters)
          final itemNumberStr = itemNumber.toString().trim();
          final itemNumberInt = int.tryParse(itemNumberStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          
          // Parse HSN Code as integer (remove any non-numeric characters)
          final hsnCodeStr = hsnCode.toString().trim();
          final hsnCodeInt = int.tryParse(hsnCodeStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

          products.add(Product(
            itemNumber: itemNumberInt.toString(),
            itemName: itemName.toString(),
            rate: rate,
            description: description.toString(),
            hsnCode: hsnCodeInt.toString(),
          ));
        } catch (e) {
          // Skip invalid rows
          continue;
        }
      }
    }

    return products;
  }

  Future<List<Product>> importFromCSV(String filePath) async {
    final file = File(filePath);
    final input = file.openRead();
    final fields = await input
        .transform(const Utf8Decoder())
        .transform(const CsvToListConverter())
        .toList();

    final List<Product> products = [];

    // Skip header row (row 0)
    for (var i = 1; i < fields.length; i++) {
      final row = fields[i];
      if (row.isEmpty) continue;

      try {
        // Column order: Item Number, Item Name, Rate, Description, HSN Code
        final itemNumber = row.isNotEmpty ? row[0]?.toString() ?? '' : '';
        final itemName = row.length > 1 ? row[1]?.toString() ?? '' : '';
        final rateStr = row.length > 2 ? row[2]?.toString() ?? '0' : '0';
        final description = row.length > 3 ? row[3]?.toString() ?? '' : '';
        final hsnCode = row.length > 4 ? row[4]?.toString() ?? '' : '';

        if (itemName.isEmpty) continue;

        final rate = double.tryParse(rateStr.toString()) ?? 0.0;
        
        // Parse Item Number as integer (remove any non-numeric characters)
        final itemNumberClean = itemNumber.trim();
        final itemNumberInt = int.tryParse(itemNumberClean.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        
        // Parse HSN Code as integer (remove any non-numeric characters)
        final hsnCodeClean = hsnCode.trim();
        final hsnCodeInt = int.tryParse(hsnCodeClean.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

        products.add(Product(
          itemNumber: itemNumberInt.toString(),
          itemName: itemName,
          rate: rate,
          description: description,
          hsnCode: hsnCodeInt.toString(),
        ));
      } catch (e) {
        // Skip invalid rows
        continue;
      }
    }

    return products;
  }

  dynamic _getCellValue(dynamic cell) {
    if (cell == null) return null;
    // Access the value property if it exists
    try {
      return cell.value;
    } catch (e) {
      // If cell is already a value, return it directly
      return cell;
    }
  }
}

