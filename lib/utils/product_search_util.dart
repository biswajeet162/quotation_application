import '../models/product.dart';

class ProductSearchUtil {
  /// Search products across all fields
  /// Returns filtered list of products that match the search query
  static List<Product> searchProducts(
    List<Product> products,
    String query,
  ) {
    if (query.isEmpty) {
      return products;
    }

    final searchQuery = query.toLowerCase().trim();

    return products.where((product) {
      // Search in Designation (number)
      if (product.designation.toString().contains(searchQuery) ||
          product.designationAsInt.toString().contains(searchQuery)) {
        return true;
      }

      // Search in Group
      if (product.group.toLowerCase().contains(searchQuery)) {
        return true;
      }

      // Search in Quantity
      if (product.quantity.toString().contains(searchQuery)) {
        return true;
      }

      // Search in RSP
      if (product.rsp.toString().contains(searchQuery) ||
          product.rsp.toStringAsFixed(2).contains(searchQuery)) {
        return true;
      }

      // Search in Total Line Gross Weight
      if (product.totalLineGrossWeight
          .toString()
          .contains(searchQuery)) {
        return true;
      }

      // Search in Pack Quantity
      if (product.packQuantity.toString().contains(searchQuery)) {
        return true;
      }

      // Search in Pack Volume
      if (product.packVolume.toString().contains(searchQuery)) {
        return true;
      }

      // Search in Information
      if (product.information.toLowerCase().contains(searchQuery)) {
        return true;
      }

      return false;
    }).toList();
  }
}





