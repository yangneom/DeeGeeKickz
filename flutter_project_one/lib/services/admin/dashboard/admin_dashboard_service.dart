import 'package:supabase_flutter/supabase_flutter.dart';
import '../inventory/inventory_service.dart';
import '../../../models/product.dart';

// ================================================
// ADMIN DASHBOARD SERVICE
//
// Powers AdminDashboardScreen's stat cards, inventory
// summary, and order status donut chart with real data.
//
// NOTE ON THRESHOLDS: Inventory counts here reuse
// Product/ProductVariant.status (threshold: availableQty
// <= 5), the SAME logic InventoryScreen's filter dropdown
// uses. This is intentionally different from StockService's
// _lowStockThreshold (<=10), which only governs the
// low-stock NOTIFICATION alerts, not the UI status label.
// Two separate thresholds for two separate purposes —
// left as-is rather than unified, since changing either
// would change existing, already-relied-upon behavior.
// ================================================

class AdminDashboardData {
  final int pendingOrders;
  final int flaggedFeedback;
  final int totalProducts;
  final int inStockProducts;
  final int lowStockProducts;
  final int outOfStockProducts;
  final Map<String, int> orderStatusCounts; // Pending/Confirmed/.../Cancelled

  AdminDashboardData({
    required this.pendingOrders,
    required this.flaggedFeedback,
    required this.totalProducts,
    required this.inStockProducts,
    required this.lowStockProducts,
    required this.outOfStockProducts,
    required this.orderStatusCounts,
  });
}

class AdminDashboardService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final InventoryService _inventoryService = InventoryService();

  // ================================================
  // GET EVERYTHING FOR THE DASHBOARD IN ONE CALL
  // ================================================
  Future<AdminDashboardData> getDashboardData() async {
    final results = await Future.wait([
      _getPendingOrdersCount(),
      _getFlaggedFeedbackCount(),
      _inventoryService.fetchProducts(), // reuse real product data + status logic
      _getOrderStatusCounts(),
    ]);

    final int pendingOrders = results[0] as int;
    final int flaggedFeedback = results[1] as int;
    final List<Product> products = results[2] as List<Product>;
    final Map<String, int> orderStatusCounts =
        results[3] as Map<String, int>;

    // ── Categorize each product by its overall status ──
    // Mirrors ProductVariant.status logic, aggregated at the
    // product level (worst-case across its variants/sizes).
    int inStock = 0;
    int lowStock = 0;
    int outOfStock = 0;

    for (final product in products) {
      if (product.variants.isEmpty || product.totalStock == 0) {
        outOfStock++;
      } else if (product.totalAvailable <= 5) {
        lowStock++;
      } else {
        inStock++;
      }
    }

    return AdminDashboardData(
      pendingOrders: pendingOrders,
      flaggedFeedback: flaggedFeedback,
      totalProducts: products.length,
      inStockProducts: inStock,
      lowStockProducts: lowStock,
      outOfStockProducts: outOfStock,
      orderStatusCounts: orderStatusCounts,
    );
  }

  // ================================================
  // PENDING ORDERS COUNT
  // Matches OrderManagementService.loadOrders' definition
  // of a real order (excludes In-Store + Awaiting Payment).
  // ================================================
  Future<int> _getPendingOrdersCount() async {
    final List<dynamic> rows = await _supabase
        .from('orders')
        .select('order_id')
        .eq('order_status', 'Pending')
        .neq('order_type', 'In-Store');

    return rows.length;
  }
  // ================================================
  // NEW FEEDBACK COUNT = reviews still waiting for an admin reply.
  //
  // This used to count status = 'Flagged', but moderation-by-hiding
  // was removed (see FeedbackService.saveReply), so nothing can set
  // that status any more and the card was permanently 0. The method
  // and AdminDashboardData.flaggedFeedback keep their old names so no
  // other file has to change.
  // ================================================
  Future<int> _getFlaggedFeedbackCount() async {
    final List<dynamic> rows = await _supabase
        .from('feedback')
        .select('feedback_id')
        .isFilter('admin_reply', null);

    return rows.length;
  }

  // ================================================
  // ORDER STATUS BREAKDOWN (for the donut chart)
  // ================================================
  Future<Map<String, int>> _getOrderStatusCounts() async {
    final List<dynamic> rows = await _supabase
        .from('orders')
        .select('order_status')
        .neq('order_type', 'In-Store')
        .neq('order_status', 'Awaiting Payment');

    final Map<String, int> counts = {
      'Pending': 0,
      'Confirmed': 0,
      'Preparing': 0,
      'Shipped': 0,
      'Completed': 0,
      'Cancelled': 0,
    };

    for (final row in rows) {
      final String status = (row['order_status'] as String?) ?? '';
      if (counts.containsKey(status)) {
        counts[status] = counts[status]! + 1;
      }
    }

    return counts;
  }
}