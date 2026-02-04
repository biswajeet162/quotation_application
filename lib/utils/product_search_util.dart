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
      // Search in Item Number (as string and number)
      if (product.itemNumber.toLowerCase().contains(searchQuery) ||
          product.itemNumberAsInt.toString().contains(searchQuery)) {
        return true;
      }

      // Search in Item Name
      if (product.itemName.toLowerCase().contains(searchQuery)) {
        return true;
      }

      // Search in Rate (as string and number)
      if (product.rate.toString().contains(searchQuery) ||
          product.rate.toStringAsFixed(2).contains(searchQuery)) {
        return true;
      }

      // Search in Description
      if (product.description.toLowerCase().contains(searchQuery)) {
        return true;
      }

      // Search in HSN Code (as string and number)
      if (product.hsnCode.toLowerCase().contains(searchQuery) ||
          product.hsnCodeAsInt.toString().contains(searchQuery)) {
        return true;
      }

      return false;
    }).toList();
  }
}




