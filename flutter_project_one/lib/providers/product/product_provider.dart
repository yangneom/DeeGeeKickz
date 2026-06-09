import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/product.dart';
import '../../services/admin/inventory/inventory_service.dart';

final inventoryServiceProvider =
    Provider<InventoryService>((ref) {
  return InventoryService();
});

final productsProvider =
    FutureProvider<List<Product>>((ref) async {
  final service = ref.read(
    inventoryServiceProvider,
  );

  return service.fetchProducts();
});