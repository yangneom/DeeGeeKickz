import 'package:supabase_flutter/supabase_flutter.dart';

// ================================================
// SALES REPORT SERVICE
//
// Computes real monthly sales performance from Supabase.
// Reuses the exact same "qualifying sale" definition as
// SalesManagementService, so the numbers here always agree
// with what's shown in Sales Management:
//   - In-Store: order_status == 'Completed'
//   - Online:   payment_status == 'Paid' (payment table)
// ================================================

class MonthlyReport {
  final String month;         // e.g. 'Jan 2026'
  final DateTime monthStart;  // for sorting
  final double totalSales;
  final double cogs;
  final double grossProfit;
  final String bestSeller;
  final double? growthPercent; // null = no real comparison available (first month, or previous month had ₱0)

  MonthlyReport({
    required this.month,
    required this.monthStart,
    required this.totalSales,
    required this.cogs,
    required this.grossProfit,
    required this.bestSeller,
    required this.growthPercent,
  });
}

class BrandPerformanceData {
  final String brandName;
  final double revenue;
  final int unitsSold;

  BrandPerformanceData({
    required this.brandName,
    required this.revenue,
    required this.unitsSold,
  });
}

class SalesReportService {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatMonth(DateTime dt) =>
      '${_monthNames[dt.month - 1]} ${dt.year}';

  // ================================================
  // QUALIFYING ORDER IDS
  // Same definition as SalesManagementService.loadSales():
  //   In-Store -> order_status == 'Completed'
  //   Online   -> payment_status == 'Paid'
  // ================================================
  Future<Set<int>> _getQualifyingOrderIds() async {
    final List<dynamic> orders = await _supabase
        .from('orders')
        .select('order_id, order_type, order_status');

    final List<dynamic> paidPayments = await _supabase
        .from('payment')
        .select('order_id')
        .eq('payment_status', 'Paid');

    final Set<int> paidOrderIds = paidPayments
        .map((p) => (p['order_id'] as num).toInt())
        .toSet();

    final Set<int> qualifying = {};
    for (final row in orders) {
      final int orderId = (row['order_id'] as num).toInt();
      final String type = row['order_type'] ?? 'online';
      final String status = row['order_status'] ?? '';

      if (type == 'In-Store') {
        if (status == 'Completed') qualifying.add(orderId);
      } else {
        if (paidOrderIds.contains(orderId)) qualifying.add(orderId);
      }
    }
    return qualifying;
  }

  // ================================================
  // MONTHLY REPORTS (table rows)
  // ================================================
  Future<List<MonthlyReport>> getMonthlyReports() async {
    final Set<int> qualifyingIds = await _getQualifyingOrderIds();
    if (qualifyingIds.isEmpty) return [];

    final List<dynamic> orders = await _supabase
        .from('orders')
        .select('order_id, total_amount, created_at')
        .inFilter('order_id', qualifyingIds.toList());

    final List<dynamic> items = await _supabase
        .from('order_item')
        .select(
            'order_id, product_name_snapshot, quantity, subtotal, cost_price_snapshot')
        .inFilter('order_id', qualifyingIds.toList());

    // order_id -> created_at, for grouping order_item rows by month
    final Map<int, DateTime> orderDateMap = {};
    final Map<String, double> monthlyRevenue = {};
    final Map<String, DateTime> monthStartMap = {};

      for (final row in orders) {
      final int orderId = (row['order_id'] as num).toInt();
      final DateTime created =
          DateTime.parse(row['created_at'].toString()).toLocal();
      orderDateMap[orderId] = created;

      final String key =
          '${created.year}-${created.month.toString().padLeft(2, '0')}';

      // Total Sales is now built from item subtotals below (the shoes
      // themselves), not orders.total_amount — that field includes the
      // shipping fee, which was never earned from selling a product
      // and was never subtracted anywhere on the cost side either.
      monthStartMap[key] = DateTime(created.year, created.month);
    }

    // month -> productName -> qty sold (for best seller)
    final Map<String, Map<String, int>> monthlyProductQty = {};
    // month -> total COGS
    final Map<String, double> monthlyCogs = {};

    for (final row in items) {
      final int orderId = (row['order_id'] as num).toInt();
      final DateTime? created = orderDateMap[orderId];
      if (created == null) continue;

      final String key =
          '${created.year}-${created.month.toString().padLeft(2, '0')}';
      final String productName = row['product_name_snapshot'] ?? 'Unknown';
      final int qty = (row['quantity'] as num?)?.toInt() ?? 0;
      final double itemSubtotal = (row['subtotal'] as num?)?.toDouble() ?? 0;
      final double costEach =
          (row['cost_price_snapshot'] as num?)?.toDouble() ?? 0;

      monthlyProductQty.putIfAbsent(key, () => {});
      monthlyProductQty[key]![productName] =
          (monthlyProductQty[key]![productName] ?? 0) + qty;

      // Product revenue only — shipping is excluded (see note above).
      monthlyRevenue[key] = (monthlyRevenue[key] ?? 0) + itemSubtotal;

      monthlyCogs[key] = (monthlyCogs[key] ?? 0) + (costEach * qty);
    }

// Build every month key from the earliest to the latest qualifying
    // sale, inclusive — so a month with zero sales shows an explicit
    // 0 row instead of being silently skipped. Skipping was causing
    // the NEXT month with sales to compute growth % against a stale
    // earlier month instead of against the true (zero) previous month.
    // Uses monthStartMap (built from every qualifying order) instead of
    // monthlyRevenue, so a month never gets silently dropped even if an
    // order somehow had no line items.
    final List<String> presentKeys = monthStartMap.keys.toList()..sort();
    final DateTime firstMonth = monthStartMap[presentKeys.first]!;
    final DateTime lastMonth = monthStartMap[presentKeys.last]!;

    final List<String> sortedKeys = [];
    DateTime cursor = DateTime(firstMonth.year, firstMonth.month);
    while (!cursor.isAfter(lastMonth)) {
      final String key =
          '${cursor.year}-${cursor.month.toString().padLeft(2, '0')}';
      sortedKeys.add(key);
      monthStartMap.putIfAbsent(key, () => cursor);
      cursor = DateTime(cursor.year, cursor.month + 1);
    }

    final List<MonthlyReport> reports = [];
    double? previousTotal;

    for (final key in sortedKeys) {
      final double total = monthlyRevenue[key] ?? 0;
      final DateTime monthStart = monthStartMap[key]!;
      final double cogs = monthlyCogs[key] ?? 0;
      final double grossProfit = total - cogs;

      final Map<String, int> productQty = monthlyProductQty[key] ?? {};
      String bestSeller = '—';
      if (productQty.isNotEmpty) {
        final List<MapEntry<String, int>> sortedProducts =
            productQty.entries.toList()
              ..sort((a, b) {
                final int cmp = b.value.compareTo(a.value);
                return cmp != 0 ? cmp : a.key.compareTo(b.key);
              });
        bestSeller = sortedProducts.first.key;
      }
      double? growth;
      if (previousTotal != null && previousTotal != 0) {
        growth = ((total - previousTotal!) / previousTotal!) * 100;
      }

      reports.add(MonthlyReport(
        month: _formatMonth(monthStart),
        monthStart: monthStart,
        totalSales: total,
        cogs: cogs,
        grossProfit: grossProfit,
        bestSeller: bestSeller,
        growthPercent: growth,
      ));

      previousTotal = total;
    }

    // Most recent month first
    return reports.reversed.toList();
  }

  // ================================================
  // OVERVIEW STATS (for SuperStatsCard row)
  // ================================================
  Future<Map<String, dynamic>> getStats() async {
    final Set<int> qualifyingIds = await _getQualifyingOrderIds();

    if (qualifyingIds.isEmpty) {
      final List<dynamic> stockRows = await _supabase
          .from('product_variant_size')
          .select('stock_quantity, reserved_quantity');

      int lowStockCount = 0;
      for (final row in stockRows) {
        final int stock = (row['stock_quantity'] as num?)?.toInt() ?? 0;
        final int reserved = (row['reserved_quantity'] as num?)?.toInt() ?? 0;
        if ((stock - reserved) <= 10) lowStockCount++;
      }

      return {
        'monthlyRevenue': 0.0,
        'revenueGrowthPercent': 0.0,
        'totalOrders': 0,
        'lowStockItems': lowStockCount,
        'activeCustomers': 0,
      };
    }

    final List<dynamic> orders = await _supabase
        .from('orders')
        .select('order_id, total_amount, created_at, user_id')
        .inFilter('order_id', qualifyingIds.toList());

    final DateTime now = DateTime.now();
    final DateTime lastMonth = DateTime(now.year, now.month - 1);

    double monthlyRevenue = 0;
    double lastMonthRevenue = 0;
    final Set<String> activeCustomerIds = {};

    for (final row in orders) {
      final DateTime created =
          DateTime.parse(row['created_at'].toString()).toLocal();
      final double total = (row['total_amount'] as num?)?.toDouble() ?? 0;
      final bool isThisMonth =
          created.year == now.year && created.month == now.month;

      if (isThisMonth) {
        monthlyRevenue += total;
      }
      if (created.year == lastMonth.year && created.month == lastMonth.month) {
        lastMonthRevenue += total;
      }
      // Only counts as "active" if they bought something THIS month —
      // previously this counted every customer who ever bought anything.
      if (isThisMonth && row['user_id'] != null) {
        activeCustomerIds.add(row['user_id'].toString());
      }
    }

    double revenueGrowth = 0;
    if (lastMonthRevenue != 0) {
      revenueGrowth =
          ((monthlyRevenue - lastMonthRevenue) / lastMonthRevenue) * 100;
    }

    // Low stock: available (stock - reserved) at or below 10 units
    final List<dynamic> stockRows = await _supabase
        .from('product_variant_size')
        .select('stock_quantity, reserved_quantity');

    int lowStockCount = 0;
    for (final row in stockRows) {
      final int stock = (row['stock_quantity'] as num?)?.toInt() ?? 0;
      final int reserved = (row['reserved_quantity'] as num?)?.toInt() ?? 0;
      if ((stock - reserved) <= 10) lowStockCount++;
    }

    return {
      'monthlyRevenue': monthlyRevenue,
      'revenueGrowthPercent': revenueGrowth,
      'totalOrders': qualifyingIds.length,
      'lowStockItems': lowStockCount,
      'activeCustomers': activeCustomerIds.length,
    };
  }

  // ================================================
  // CHART DATA (actual monthly sales, chronological)
  // ================================================
  Future<Map<String, List<dynamic>>> getMonthlySalesForChart(
      {int monthsBack = 6}) async {
    final List<MonthlyReport> reportsDescending = await getMonthlyReports();
    final List<MonthlyReport> chronological =
        reportsDescending.reversed.toList();

    final List<MonthlyReport> lastN = chronological.length > monthsBack
        ? chronological.sublist(chronological.length - monthsBack)
        : chronological;

    return {
      'months': lastN.map((r) => r.month).toList(),
      'sales': lastN.map((r) => r.totalSales).toList(),
    };
  }

  // ================================================
  // BRAND PERFORMANCE
  // ================================================
  Future<List<BrandPerformanceData>> getBrandPerformance() async {
    final Set<int> qualifyingIds = await _getQualifyingOrderIds();
    if (qualifyingIds.isEmpty) return [];

    final List<dynamic> items = await _supabase
        .from('order_item')
        .select('order_id, brand_snapshot, quantity, subtotal')
        .inFilter('order_id', qualifyingIds.toList());

    final Map<String, double> brandRevenue = {};
    final Map<String, int> brandUnits = {};

    for (final row in items) {
      final String brand = row['brand_snapshot'] ?? 'Unknown';
      final double subtotal = (row['subtotal'] as num?)?.toDouble() ?? 0;
      final int qty = (row['quantity'] as num?)?.toInt() ?? 0;

      brandRevenue[brand] = (brandRevenue[brand] ?? 0) + subtotal;
      brandUnits[brand] = (brandUnits[brand] ?? 0) + qty;
    }

    final List<BrandPerformanceData> result = brandRevenue.entries
        .map((e) => BrandPerformanceData(
              brandName: e.key,
              revenue: e.value,
              unitsSold: brandUnits[e.key] ?? 0,
            ))
        .toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    return result;
  }

  // ================================================
  // TOP PRODUCTS SALES DATA — feeds AI Trending
  // ================================================
  Future<List<Map<String, dynamic>>> getTopProductsSalesData(
      {int monthsBack = 3}) async {
    final Set<int> qualifyingIds = await _getQualifyingOrderIds();
    if (qualifyingIds.isEmpty) return [];

    final List<dynamic> orders = await _supabase
        .from('orders')
        .select('order_id, created_at')
        .inFilter('order_id', qualifyingIds.toList());

    final DateTime cutoff =
        DateTime.now().subtract(Duration(days: monthsBack * 30));
    final Set<int> recentOrderIds = {};

    for (final row in orders) {
      final DateTime created =
          DateTime.parse(row['created_at'].toString()).toLocal();
      if (created.isAfter(cutoff)) {
        recentOrderIds.add((row['order_id'] as num).toInt());
      }
    }
    if (recentOrderIds.isEmpty) return [];

    final List<dynamic> items = await _supabase
        .from('order_item')
        .select('order_id, product_name_snapshot, quantity')
        .inFilter('order_id', recentOrderIds.toList());

    final Map<String, int> productQty = {};
    for (final row in items) {
      final String name = row['product_name_snapshot'] ?? 'Unknown';
      final int qty = (row['quantity'] as num?)?.toInt() ?? 0;
      productQty[name] = (productQty[name] ?? 0) + qty;
    }

    final List<MapEntry<String, int>> sorted = productQty.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted
        .take(10)
        .map((e) => {'productName': e.key, 'salesCount': e.value})
        .toList();
  }

  // ================================================
  // INVENTORY DATA — feeds Restock Prediction
  // ================================================
  Future<List<Map<String, dynamic>>> getInventoryDataForRestock() async {
    final List<dynamic> rows = await _supabase.from('product_variant_size').select('''
          stock_quantity,
          reserved_quantity,
          product_variant (
            product (
              product_name
            )
          )
        ''');

    final Map<String, int> productStock = {};

    for (final row in rows) {
      final variant = row['product_variant'];
      final product = variant is Map ? variant['product'] : null;
      final String name =
          product is Map ? (product['product_name'] ?? 'Unknown') : 'Unknown';

      final int stock = (row['stock_quantity'] as num?)?.toInt() ?? 0;
      final int reserved = (row['reserved_quantity'] as num?)?.toInt() ?? 0;
      final int available = (stock - reserved).clamp(0, 1 << 31);

      productStock[name] = (productStock[name] ?? 0) + available;
    }

    // No configured "max stock" or daily sales rate exists in the schema
    // yet, so maxStock is a placeholder constant for now — good enough
    // for Groq to reason about relative stock levels, not exact velocity.
    return productStock.entries
        .map((e) => {
              'productName': e.key,
              'currentStock': e.value,
              'maxStock': 100,
            })
        .toList();
  }
}