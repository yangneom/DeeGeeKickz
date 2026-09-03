import 'package:supabase_flutter/supabase_flutter.dart';

// ================================================
// DASHBOARD STATS
// ================================================
class DashboardStats {
  final double monthlyRevenue;
  final double previousMonthRevenue;
  final int totalOrders;
  final int previousMonthOrders;
  final int lowStockItems;
  final int activeCustomers;
  final int previousMonthActiveCustomers;

  DashboardStats({
    required this.monthlyRevenue,
    required this.previousMonthRevenue,
    required this.totalOrders,
    required this.previousMonthOrders,
    required this.lowStockItems,
    required this.activeCustomers,
    required this.previousMonthActiveCustomers,
  });

  double get revenueChangePercent => _percentChange(previousMonthRevenue, monthlyRevenue);
  double get ordersChangePercent => _percentChange(previousMonthOrders.toDouble(), totalOrders.toDouble());
  double get customersChangePercent =>
      _percentChange(previousMonthActiveCustomers.toDouble(), activeCustomers.toDouble());

  static double _percentChange(double previous, double current) {
    if (previous == 0) return current == 0 ? 0 : 100;
    return ((current - previous) / previous) * 100;
  }
}

// ================================================
// BRAND SALES DATA
// (percentage computed here, color assigned by widget)
// ================================================
class BrandSales {
  final String brand;
  final double percentage;

  BrandSales({required this.brand, required this.percentage});
}

// ================================================
// DASHBOARD SERVICE
// Pure Supabase aggregation — no AI involved here.
// ================================================
class DashboardService {
  final SupabaseClient _supabase = Supabase.instance.client;

  DateTime _startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

  // ================================================
  // GET STATS
  // ================================================
  Future<DashboardStats> getStats() async {
    final now = DateTime.now();
    final thisMonthStart = _startOfMonth(now);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);

        // ── Orders this month & last month (revenue + count) ──
    // Uses the SAME qualifying definition as SalesReportService:
    //   In-Store -> order_status == 'Completed'
    //   Online   -> payment_status == 'Paid'
    // Previously this only excluded 'Cancelled', which meant
    // Pending/Awaiting Payment orders (not yet actually paid for)
    // were counted as real revenue here, disagreeing with the
    // audited numbers on the Sales Report screen.
    final List<dynamic> allOrders = await _supabase
        .from('orders')
        .select('order_id, total_amount, order_status, order_type, created_at');

    final List<dynamic> paidPayments = await _supabase
        .from('payment')
        .select('order_id')
        .eq('payment_status', 'Paid');

    final Set<int> paidOrderIds =
        paidPayments.map((p) => (p['order_id'] as num).toInt()).toSet();

    bool isQualifying(Map<String, dynamic> row) {
      final String type = row['order_type'] ?? 'online';
      final String status = row['order_status'] ?? '';
      final int orderId = (row['order_id'] as num).toInt();
      if (type == 'In-Store') return status == 'Completed';
      return paidOrderIds.contains(orderId);
    }

    double monthlyRevenue = 0;
    double previousMonthRevenue = 0;
    int totalOrders = 0;
    int previousMonthOrders = 0;

    for (final dynamic row in allOrders) {
      final Map<String, dynamic> order = row as Map<String, dynamic>;
      if (!isQualifying(order)) continue;

      final DateTime created =
          DateTime.parse(order['created_at'].toString()).toLocal();
      final double total = (order['total_amount'] as num?)?.toDouble() ?? 0;

      if (!created.isBefore(thisMonthStart)) {
        monthlyRevenue += total;
        totalOrders++;
      } else if (!created.isBefore(lastMonthStart) &&
          created.isBefore(thisMonthStart)) {
        previousMonthRevenue += total;
        previousMonthOrders++;
      }
    }

    // ── Low stock items (available <= 5) ──
    final lowStockRows = await _supabase
        .from('product_variant_size')
        .select('size_id, stock_quantity, reserved_quantity');

    int lowStockCount = 0;
    for (final row in lowStockRows as List) {
      final stock = (row['stock_quantity'] as num?)?.toInt() ?? 0;
      final reserved = (row['reserved_quantity'] as num?)?.toInt() ?? 0;
      final available = stock - reserved;
      if (available <= 5) lowStockCount++;
    }

    // ── Active customers ──
    final activeCustomersResp = await _supabase
        .from('users')
        .select('id')
        .eq('role', 'Customer')
        .eq('is_disabled', false);

    final int activeCustomers = (activeCustomersResp as List).length;

    // Previous-month active customer count isn't meaningfully
    // trackable without a historical snapshot table, so we compare
    // against customers registered before this month as a proxy.
    final previousCustomersResp = await _supabase
        .from('users')
        .select('id')
        .eq('role', 'Customer')
        .eq('is_disabled', false)
        .lt('registered_date', thisMonthStart.toIso8601String());

    final int previousMonthActiveCustomers = (previousCustomersResp as List).length;

    return DashboardStats(
      monthlyRevenue: monthlyRevenue,
      previousMonthRevenue: previousMonthRevenue,
      totalOrders: totalOrders,
      previousMonthOrders: previousMonthOrders,
      lowStockItems: lowStockCount,
      activeCustomers: activeCustomers,
      previousMonthActiveCustomers: previousMonthActiveCustomers,
    );
  }

  // ================================================
  // GET BRAND PERFORMANCE
  // Based on order_item.brand_snapshot (captures the brand
  // at time of sale — correct even if a product's brand or
  // the product itself later changes/gets archived).
  // ================================================
  Future<List<BrandSales>> getBrandPerformance() async {
    final rows = await _supabase
        .from('order_item')
        .select('brand_snapshot, subtotal');

    final Map<String, double> totals = {};
    double grandTotal = 0;

    for (final row in rows as List) {
      final brand = (row['brand_snapshot'] as String?)?.trim();
      if (brand == null || brand.isEmpty) continue;
      final subtotal = (row['subtotal'] as num?)?.toDouble() ?? 0;
      totals[brand] = (totals[brand] ?? 0) + subtotal;
      grandTotal += subtotal;
    }

    if (grandTotal == 0) return [];

    final result = totals.entries
        .map((e) => BrandSales(
              brand: e.key,
              percentage: (e.value / grandTotal) * 100,
            ))
        .toList();

    result.sort((a, b) => b.percentage.compareTo(a.percentage));
    return result;
  }

  // ================================================
  // GET MONTHLY SALES HISTORY
  // Last [months] months of revenue, oldest first —
  // feeds the Sales Trend chart + Groq prediction input.
  // ================================================
  Future<List<double>> getMonthlySalesHistory({int months = 6}) async {
    final now = DateTime.now();
    final List<double> result = [];

    for (int i = months - 1; i >= 0; i--) {
      final start = DateTime(now.year, now.month - i, 1);
      final end = DateTime(now.year, now.month - i + 1, 1);

      final rows = await _supabase
          .from('orders')
          .select('total_amount')
          .gte('created_at', start.toIso8601String())
          .lt('created_at', end.toIso8601String())
          .neq('order_status', 'Cancelled');

      double total = 0;
      for (final row in rows as List) {
        total += (row['total_amount'] as num?)?.toDouble() ?? 0;
      }
      result.add(total);
    }

    return result;
  }

  // ================================================
  // GET PRODUCT SALES SUMMARY (for AI Trending Shoes)
  // Compares this-period vs previous-period sales count
  // per product, computing REAL growth % (no AI involved
  // in the math — only in the ranking/phrasing afterward).
  // ================================================
  Future<List<Map<String, dynamic>>> getProductSalesGrowth({int days = 14}) async {
    final now = DateTime.now();
    final periodStart = now.subtract(Duration(days: days));
    final previousPeriodStart = now.subtract(Duration(days: days * 2));

    final rows = await _supabase
        .from('order_item')
        .select('product_name_snapshot, quantity, orders!inner(created_at)');

    final Map<String, int> currentCounts = {};
    final Map<String, int> previousCounts = {};

    for (final row in rows as List) {
      final name = row['product_name_snapshot']?.toString() ?? 'Unknown';
      final qty = (row['quantity'] as num?)?.toInt() ?? 0;
      final createdAtStr = row['orders']?['created_at']?.toString();
      final createdAt = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;
      if (createdAt == null) continue;

      if (createdAt.isAfter(periodStart)) {
        currentCounts[name] = (currentCounts[name] ?? 0) + qty;
      } else if (createdAt.isAfter(previousPeriodStart) && createdAt.isBefore(periodStart)) {
        previousCounts[name] = (previousCounts[name] ?? 0) + qty;
      }
    }

    final List<Map<String, dynamic>> results = [];
    for (final entry in currentCounts.entries) {
      final prev = previousCounts[entry.key] ?? 0;
      final growth = prev == 0 ? 100.0 : ((entry.value - prev) / prev) * 100;
      results.add({
        'productName': entry.key,
        'salesCount': entry.value,
        'growthPercent': growth.round(),
      });
    }

    results.sort((a, b) => (b['growthPercent'] as int).compareTo(a['growthPercent'] as int));
    return results.take(10).toList();
  }

  // ================================================
  // GET INVENTORY FOR RESTOCK PREDICTION
  // dailySalesRate computed from last 30 days of real sales.
  // ================================================
  Future<List<Map<String, dynamic>>> getInventoryForRestock() async {
  final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

  // Sales in the last 30 days, per SIZE (not per product) — a specific
  // size selling out while other sizes of the same product are fully
  // stocked needs to be visible on its own. The old code summed stock
  // across every size of a product (Puma RS-X: 201 units total), so a
  // single sold-out, fast-moving size never crossed the threshold.
  final salesRows = await _supabase
      .from('order_item')
      .select('size_id, quantity, orders!inner(created_at)')
      .not('size_id', 'is', null);

  final Map<int, int> salesBySize = {};
  for (final row in salesRows as List) {
    final sizeId = (row['size_id'] as num?)?.toInt();
    if (sizeId == null) continue;
    final createdAtStr = row['orders']?['created_at']?.toString();
    final createdAt = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;
    if (createdAt == null || createdAt.isBefore(thirtyDaysAgo)) continue;
    final qty = (row['quantity'] as num?)?.toInt() ?? 0;
    salesBySize[sizeId] = (salesBySize[sizeId] ?? 0) + qty;
  }

  // Same nested-select shape already used elsewhere in this file —
  // just now carrying size_id/color/size/reserved through instead of
  // collapsing everything into one product-level total.
  final stockRows = await _supabase
      .from('product')
      .select(
        'product_name, is_archived, '
        'product_variant(color_name, product_variant_size(size_id, size, stock_quantity, reserved_quantity))',
      )
      .eq('is_archived', false);

  final List<Map<String, dynamic>> result = [];

  for (final product in stockRows as List) {
    final productName = product['product_name']?.toString() ?? 'Unknown';
    final variants = product['product_variant'] as List<dynamic>? ?? [];

    for (final variant in variants) {
      final colorName = variant['color_name']?.toString() ?? '';
      final sizes = variant['product_variant_size'] as List<dynamic>? ?? [];

      for (final size in sizes) {
        final sizeId = (size['size_id'] as num?)?.toInt();
        if (sizeId == null) continue;

        final stock = (size['stock_quantity'] as num?)?.toInt() ?? 0;
        final reserved = (size['reserved_quantity'] as num?)?.toInt() ?? 0;
        final available = stock - reserved;
        final sizeLabel = size['size']?.toString() ?? '';

        final salesCount = salesBySize[sizeId] ?? 0;
        final dailyRate = salesCount / 30.0;

                // Flag a SPECIFIC size that's actually selling AND running
        // low — not the product as a whole. Two ways to qualify:
        // (1) less than 14 days of stock left at current pace, OR
        // (2) an absolute floor of 3 units — catches genuinely slow
        // sellers (e.g. 1 sale/month) whose 14-day math rounds down
        // to nearly zero and would otherwise never get flagged, even
        // sitting at just 2 units left.
        final bool velocityLow = available <= dailyRate * 14;
        final bool absoluteFloorLow = available <= 3;

        if (dailyRate > 0 && (velocityLow || absoluteFloorLow)) {
          result.add({
            'productName': '$productName ($colorName, size $sizeLabel)',
            'currentStock': available,
            'maxStock': 100,
            'dailySalesRate': dailyRate,
          });
        }
      }
    }
  }

  return result;
}
}