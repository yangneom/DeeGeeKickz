import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/product.dart';
import '../../services/admin/inventory/inventory_service.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

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




// ================================================
// REALTIME STOCK SUBSCRIPTION
//
// Listens for any change on product_variant_size (stock sales,
// reservations, admin adjustments) and invalidates productsProvider
// so every screen watching it refetches automatically.
//
// Debounced: process_cashier_sale/commit/release logic can update
// several size rows in a tight loop for one transaction — without
// debouncing, that would trigger a refetch per row instead of once
// per transaction.
//
// Any screen that needs live stock must `ref.watch(
// inventoryRealtimeProvider)` alongside `ref.watch(productsProvider)`
// — watching activates the subscription for as long as that screen
// is mounted; Riverpod disposes it automatically when no screen
// watches it anymore.
// ================================================
final inventoryRealtimeProvider = Provider<void>((ref) {
  final supabase = Supabase.instance.client;
  Timer? debounce;

  final channel = supabase
      .channel('product_variant_size_changes')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'product_variant_size',
        callback: (payload) {
          debounce?.cancel();
          debounce = Timer(const Duration(milliseconds: 400), () {
            ref.invalidate(productsProvider);
          });
        },
      )
      .subscribe();

  ref.onDispose(() {
    debounce?.cancel();
    supabase.removeChannel(channel);
  });
});