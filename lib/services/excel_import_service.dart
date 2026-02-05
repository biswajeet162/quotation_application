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
          // New column order:
          // 0: Designation (string)
          // 1: Group (string)
          // 2: Quantity (number)
          // 3: RSP (decimal)
          // 4: Total Line Gross Weight (decimal)
          // 5: Pack Quantity (number)
          // 6: Pack volume (decimal)
          // 7: Information (string)
          final designationCell =
              row.isNotEmpty && row[0] != null ? _getCellValue(row[0]) : null;
          final groupCell =
              row.length > 1 && row[1] != null ? _getCellValue(row[1]) : null;
          final quantityCell =
              row.length > 2 && row[2] != null ? _getCellValue(row[2]) : null;
          final rspCell =
              row.length > 3 && row[3] != null ? _getCellValue(row[3]) : null;
          final totalLineGrossWeightCell =
              row.length > 4 && row[4] != null ? _getCellValue(row[4]) : null;
          final packQuantityCell =
              row.length > 5 && row[5] != null ? _getCellValue(row[5]) : null;
          final packVolumeCell =
              row.length > 6 && row[6] != null ? _getCellValue(row[6]) : null;
          final informationCell =
              row.length > 7 && row[7] != null ? _getCellValue(row[7]) : null;

          // Parse designation as string - ALWAYS treat as string, never convert to number
          // Excel may store "FRB 4.85/180" in various ways, but we always want the text representation
          String designation = '';
          if (designationCell != null) {
            // Always convert to string, preserving the exact text value
            // Don't do any numeric parsing or conversion
            if (designationCell is String) {
              designation = designationCell;
            } else {
              // For any other type (int, double, etc.), convert to string
              // This preserves values like "FRB 4.85/180" even if Excel stored parts as numbers
              designation = designationCell.toString();
            }
            // Trim whitespace but preserve the content
            designation = designation.trim();
          }

          // Parse group
          final group = groupCell?.toString().trim() ?? '';

          // Parse quantity - handle both number and string types
          double quantity = 0.0;
          if (quantityCell != null) {
            if (quantityCell is num) {
              quantity = quantityCell.toDouble();
            } else {
              quantity = double.tryParse(quantityCell.toString().trim()) ?? 0.0;
            }
          }

          // Parse RSP - handle both number and string types
          double rsp = 0.0;
          if (rspCell != null) {
            if (rspCell is num) {
              rsp = rspCell.toDouble();
            } else {
              rsp = double.tryParse(rspCell.toString().trim()) ?? 0.0;
            }
          }

          // Parse totalLineGrossWeight - handle both number and string types
          double totalLineGrossWeight = 0.0;
          if (totalLineGrossWeightCell != null) {
            if (totalLineGrossWeightCell is num) {
              totalLineGrossWeight = totalLineGrossWeightCell.toDouble();
            } else {
              totalLineGrossWeight = double.tryParse(totalLineGrossWeightCell.toString().trim()) ?? 0.0;
            }
          }

          // Parse packQuantity - handle both number and string types
          int packQuantity = 0;
          if (packQuantityCell != null) {
            if (packQuantityCell is int) {
              packQuantity = packQuantityCell;
            } else if (packQuantityCell is double) {
              packQuantity = packQuantityCell.toInt();
            } else {
              packQuantity = int.tryParse(packQuantityCell.toString().trim()) ?? 0;
            }
          }

          // Parse packVolume - handle both number and string types
          double packVolume = 0.0;
          if (packVolumeCell != null) {
            if (packVolumeCell is num) {
              packVolume = packVolumeCell.toDouble();
            } else {
              packVolume = double.tryParse(packVolumeCell.toString().trim()) ?? 0.0;
            }
          }

          // Parse information
          final information = informationCell?.toString().trim() ?? '';

          // Skip rows without any meaningful data
          // Note: designation can be empty string, so we check both designation and information
          if (designation.isEmpty && information.isEmpty) continue;
          
          // Debug: Print to see what designation values are being read from Excel
          print('Importing Row ${products.length + 1}: Designation="$designation" (type: ${designationCell.runtimeType}), Group="$group", Information="$information"');

          products.add(Product(
            designation: designation,
            group: group,
            quantity: quantity,
            rsp: rsp,
            totalLineGrossWeight: totalLineGrossWeight,
            packQuantity: packQuantity,
            packVolume: packVolume,
            information: information,
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
        // New column order in CSV:
        // Designation, Group, Quantity, RSP, Total Line Gross Weight,
        // Pack Quantity, Pack volume, Information
        final designation =
            row.isNotEmpty ? row[0]?.toString().trim() ?? '' : '';
        final group = row.length > 1 ? row[1]?.toString().trim() ?? '' : '';
        final quantityStr = row.length > 2 ? row[2]?.toString() ?? '0' : '0';
        final rspStr = row.length > 3 ? row[3]?.toString() ?? '0' : '0';
        final totalLineGrossWeightStr =
            row.length > 4 ? row[4]?.toString() ?? '0' : '0';
        final packQuantityStr =
            row.length > 5 ? row[5]?.toString() ?? '0' : '0';
        final packVolumeStr =
            row.length > 6 ? row[6]?.toString() ?? '0' : '0';
        final information =
            row.length > 7 ? row[7]?.toString().trim() ?? '' : '';
        final quantity = double.tryParse(quantityStr) ?? 0.0;
        final rsp = double.tryParse(rspStr) ?? 0.0;
        final totalLineGrossWeight =
            double.tryParse(totalLineGrossWeightStr) ?? 0.0;
        final packQuantity = int.tryParse(packQuantityStr) ?? 0;
        final packVolume = double.tryParse(packVolumeStr) ?? 0.0;

        if (designation.isEmpty && information.isEmpty) continue;

        products.add(Product(
          designation: designation,
          group: group,
          quantity: quantity,
          rsp: rsp,
          totalLineGrossWeight: totalLineGrossWeight,
          packQuantity: packQuantity,
          packVolume: packVolume,
          information: information,
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
    
    // If cell is already a primitive value, return it directly
    // For designation (first column), we want to preserve strings exactly as they are
    if (cell is String) {
      return cell; // Return string as-is
    }
    if (cell is num || cell is bool) {
      return cell;
    }
    
    // Access the value property if it exists (Excel Cell object)
    try {
      // Check if cell has a 'value' property
      if (cell is Map) {
        final value = cell['value'];
        // If it's a string, return it directly
        if (value is String) return value;
        // Otherwise return as-is (will be converted to string later for designation)
        return value;
      }
      
      // Try to access .value property
      final value = cell.value;
      
      // If value is null, the cell might be empty or have special formatting
      if (value == null) {
        // Try to get innerText or text property for formatted cells (important for text cells)
        try {
          // Some Excel packages store text in innerText or text property
          if (cell.innerText != null) return cell.innerText;
          if (cell.text != null) return cell.text;
          // Try to access as string directly
          if (cell.stringValue != null) return cell.stringValue;
        } catch (e) {
          // innerText/text/stringValue not available
        }
        return null;
      }
      
      // Return the value - if it's a string, it will be preserved
      // If it's a number, it will be converted to string in the designation parsing
      return value;
    } catch (e) {
      // If accessing .value fails, try toString as fallback
      try {
        final str = cell.toString();
        // If toString returns something meaningful (not just object reference), use it
        if (str.isNotEmpty && !str.startsWith('Instance of')) {
          return str;
        }
      } catch (e2) {
        // toString also failed
      }
      return null;
    }
  }
}

