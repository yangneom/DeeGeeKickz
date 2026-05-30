import '../../../models/product.dart';

class InventoryService {

  // ================================================
  // GET ALL UNIQUE CATEGORIES
  // ================================================
  List<String> getCategories(List<Product> products) {
    List<String> categories = [];
    for (Product product in products) {
      if (!categories.contains(product.category)) {
        categories.add(product.category);
      }
    }
    return categories;
  }

  // ================================================
  // APPLY FILTERS
  // ================================================
  List<Product> applyFilters({
    required List<Product> allProducts,
    required String searchQuery,
    required String? selectedCategory,
    required String? selectedStatus,
  }) {
    List<Product> results = [];

    for (Product product in allProducts) {

      // Search filter
      bool matchesSearch = true;
      if (searchQuery.isNotEmpty) {
        bool nameMatch = product.productName.toLowerCase().contains(searchQuery);
        bool brandMatch = product.brand.toLowerCase().contains(searchQuery);
        bool categoryMatch = product.category.toLowerCase().contains(searchQuery);
        matchesSearch = nameMatch || brandMatch || categoryMatch;
      }
      if (matchesSearch == false) continue;

      // Category filter
      bool matchesCategory = true;
      if (selectedCategory != null) {
        matchesCategory = product.category == selectedCategory;
      }
      if (matchesCategory == false) continue;

      // Status filter    
      bool matchesStatus = true;
      if (selectedStatus != null) {
        matchesStatus = false;
        for (var variant in product.variants) {
          if (variant.status == selectedStatus) {
            matchesStatus = true;
            break;
          }
        }
      }
      if (matchesStatus == false) continue;

      results.add(product); 
    }

    return results;
  }
}