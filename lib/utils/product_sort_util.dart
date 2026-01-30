import '../models/product.dart';

class ProductSortUtil {
  /// Sort products by the specified column
  static void sortProducts(
    List<Product> products,
    String sortColumn,
    bool ascending,
  ) {
    products.sort((a, b) {
      int comparison = 0;
      switch (sortColumn) {
        case 'itemNumber':
          // Sort as integer
          comparison = a.itemNumberAsInt.compareTo(b.itemNumberAsInt);
          break;
        case 'itemName':
          comparison = a.itemName.compareTo(b.itemName);
          break;
        case 'rate':
          // Sort as number
          comparison = a.rate.compareTo(b.rate);
          break;
        case 'description':
          comparison = a.description.compareTo(b.description);
          break;
        case 'hsnCode':
          // Sort as integer
          comparison = a.hsnCodeAsInt.compareTo(b.hsnCodeAsInt);
          break;
        default:
          comparison = 0;
      }
      return ascending ? comparison : -comparison;
    });
  }
}

