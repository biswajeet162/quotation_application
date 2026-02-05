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
        case 'designation':
          comparison = a.designationAsInt.compareTo(b.designationAsInt);
          break;
        case 'group':
          comparison = a.group.compareTo(b.group);
          break;
        case 'quantity':
          comparison = a.quantity.compareTo(b.quantity);
          break;
        case 'rsp':
          comparison = a.rsp.compareTo(b.rsp);
          break;
        case 'totalLineGrossWeight':
          comparison =
              a.totalLineGrossWeight.compareTo(b.totalLineGrossWeight);
          break;
        case 'packQuantity':
          comparison = a.packQuantity.compareTo(b.packQuantity);
          break;
        case 'packVolume':
          comparison = a.packVolume.compareTo(b.packVolume);
          break;
        case 'information':
          comparison = a.information.compareTo(b.information);
          break;
        default:
          comparison = 0;
      }
      return ascending ? comparison : -comparison;
    });
  }
}





