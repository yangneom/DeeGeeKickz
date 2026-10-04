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
  // AUDIT ADD: needed for the Year view's summary cards (Total Orders,
  // Total Quantity Sold) — cheap to populate since getMonthlyReports()
  // already iterates every qualifying order/item.
  final int totalOrders;
  final int totalQuantitySold;

  MonthlyReport({
    required this.month,
    required this.monthStart,
    required this.totalSales,
    required this.cogs,
    required this.grossProfit,
    required this.bestSeller,
    required this.growthPercent,
    required this.totalOrders,
    required this.totalQuantitySold,
  });
}

class DayTransaction {
  final int orderId;
  final DateTime dateTime;
  final double totalAmount;
  final String paymentMethod;
  final String orderType;
  final String orderStatus;

  DayTransaction({
    required this.orderId,
    required this.dateTime,
    required this.totalAmount,
    required this.paymentMethod,
    required this.orderType,
    required this.orderStatus,
  });
}

class DailySalesSummary {
  final DateTime date;
  final double totalSales;
  final int totalOrders;
  final int totalQuantitySold;
  final double grossProfit;

  DailySalesSummary({
    required this.date,
    required this.totalSales,
    required this.totalOrders,
    required this.totalQuantitySold,
    required this.grossProfit,
  });
}

class CustomRangeSummary {
  final DateTime start;
  final DateTime end;
  final double totalSales;
  final double cogs;
  final double grossProfit;
  final int totalOrders;
  final int totalQuantitySold;

  CustomRangeSummary({
    required this.start,
    required this.end,
    required this.totalSales,
    required this.cogs,
    required this.grossProfit,
    required this.totalOrders,
    required this.totalQuantitySold,
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

// ================================================
// PRODUCT SALES ENTRY
// One product's performance within a selected month.
// imageUrl is null when no image could be resolved —
// e.g. no size_id on the order_item rows (old data),
// or the variant/image chain came up empty. Callers
// must render a placeholder in that case, never guess.
class ProductSalesEntry {
  final String productName;
  final int quantitySold;
  final double salesAmount;
  final String? imageUrl;

  ProductSalesEntry({
    required this.productName,
    required this.quantitySold,
    required this.salesAmount,
    this.imageUrl,
  });
}

// ================================================
// MONTH SALES DETAIL
// Everything needed for one selected month's detail
// view: totals + every product sold, sorted by
// quantity sold descending. The screen takes(5) for
// the Top 5 preview and passes the full list to the
// "View Full Report" dialog — same data, no second
// query, so the two views can never disagree.
// ================================================
class MonthSalesDetail {
  final DateTime month;
  final double totalSales;
  final int totalOrders;
  final int totalQuantitySold;
  final List<ProductSalesEntry> products; // ALL products, sorted desc

  MonthSalesDetail({
    required this.month,
    required this.totalSales,
    required this.totalOrders,
    required this.totalQuantitySold,
    required this.products,
  });
}

class SalesReportService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // AUDIT ADD: created_at is confirmed `timestamp with time zone`
  // (Postgres/Supabase returns it as real UTC). Grouping by month/day
  // previously used .toLocal(), which follows whatever timezone the
  // VIEWING DEVICE happens to be set to — correct only by coincidence
  // today. This fixes the business date to Philippine time (UTC+8)
  // explicitly, regardless of the device's own clock/timezone. The
  // Philippines does not observe Daylight Saving Time, so a fixed
  // +8 offset is stable and correct, not a fragile shortcut.
  DateTime _toPhilippineTime(dynamic rawTimestamp) {
    return DateTime.parse(rawTimestamp.toString()).toUtc().add(const Duration(hours: 8));
  }

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
    // AUDIT ADD: month -> set of order_ids, for the Year view's
    // Total Orders card. A Set (not a count) so an order with
    // multiple items is never counted more than once.
    final Map<String, Set<int>> monthlyOrderIds = {};

    for (final row in orders) {
      final int orderId = (row['order_id'] as num).toInt();
      final DateTime created =
                   _toPhilippineTime(row['created_at']);
      orderDateMap[orderId] = created;

      final String key =
          '${created.year}-${created.month.toString().padLeft(2, '0')}';

      // Total Sales is now built from item subtotals below (the shoes
      // themselves), not orders.total_amount — that field includes the
      // shipping fee, which was never earned from selling a product
      // and was never subtracted anywhere on the cost side either.
      monthStartMap[key] = DateTime(created.year, created.month);

      monthlyOrderIds.putIfAbsent(key, () => {});
      monthlyOrderIds[key]!.add(orderId);
    }

    // month -> productName -> qty sold (for best seller)
    final Map<String, Map<String, int>> monthlyProductQty = {};
    // month -> total COGS
    final Map<String, double> monthlyCogs = {};
    // AUDIT ADD: month -> total units sold, for the Year view's
    // Total Quantity Sold card.
    final Map<String, int> monthlyQuantity = {};

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

      monthlyQuantity[key] = (monthlyQuantity[key] ?? 0) + qty;
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
        totalOrders: monthlyOrderIds[key]?.length ?? 0,
        totalQuantitySold: monthlyQuantity[key] ?? 0,
      ));

      previousTotal = total;
    }

    // Most recent month first
    return reports.reversed.toList();
  }

  // ================================================
  // AVAILABLE MONTHS — full scope of the month picker,
  // independent of whether a month has any qualifying
  // sales. Spans from the earliest order EVER placed
  // (any status — even Cancelled/Pending counts, since
  // that's when the business/system activity began) up
  // through the current calendar month. This guarantees
  // a year with zero completed sales is still selectable,
  // so its empty state is something the admin can
  // deliberately check, not something hidden from them.
  // ================================================
  Future<List<DateTime>> getAvailableMonths() async {
    try {
      final List<dynamic> earliest = await _supabase
          .from('orders')
          .select('created_at')
          .order('created_at', ascending: true)
          .limit(1);

      final DateTime now = DateTime.now();
      DateTime start = DateTime(now.year, now.month);

      if (earliest.isNotEmpty) {
        final DateTime firstCreated =
                        _toPhilippineTime(earliest.first['created_at']);
        start = DateTime(firstCreated.year, firstCreated.month);
      }

      final DateTime end = DateTime(now.year, now.month);
      final List<DateTime> months = [];
      DateTime cursor = start;
      while (!cursor.isAfter(end)) {
        months.add(cursor);
        cursor = DateTime(cursor.year, cursor.month + 1);
      }
      return months.reversed.toList(); // most recent first
    } catch (e) {
      print('SalesReportService.getAvailableMonths error: $e');
      // Fall back to just the current month rather than an empty
      // list — the picker should never be completely unusable.
      final DateTime now = DateTime.now();
      return [DateTime(now.year, now.month)];
    }
  }

  // ================================================
  // MONTH SALES DETAIL
  // Same qualifying-order definition as everywhere else
  // in this service (In-Store: Completed, Online: Paid),
  // filtered down to the one selected month.
  // ================================================
  Future<MonthSalesDetail> getMonthSalesDetail(DateTime month) async {
    final DateTime start = DateTime(month.year, month.month);
    final DateTime end = DateTime(month.year, month.month + 1);

    final Set<int> qualifyingIds = await _getQualifyingOrderIds();
    if (qualifyingIds.isEmpty) {
      return MonthSalesDetail(
        month: start, totalSales: 0, totalOrders: 0,
        totalQuantitySold: 0, products: [],
      );
    }

    final List<dynamic> orders = await _supabase
        .from('orders')
        .select('order_id, created_at')
        .inFilter('order_id', qualifyingIds.toList());

    final Set<int> monthOrderIds = {};
    for (final row in orders) {
      // AUDIT FIX: was .toLocal() — follows the viewing device's own
      // timezone rather than a guaranteed Philippine business date,
      // same class of bug fixed everywhere else in this file.
      final DateTime created = _toPhilippineTime(row['created_at']);
      if (!created.isBefore(start) && created.isBefore(end)) {
        monthOrderIds.add((row['order_id'] as num).toInt());
      }
    }

    if (monthOrderIds.isEmpty) {
      return MonthSalesDetail(
        month: start, totalSales: 0, totalOrders: 0,
        totalQuantitySold: 0, products: [],
      );
    }

    final List<dynamic> items = await _supabase
        .from('order_item')
        .select('order_id, product_name_snapshot, quantity, subtotal, size_id')
        .inFilter('order_id', monthOrderIds.toList());

    double totalSales = 0;
    int totalQuantity = 0;
    final Map<String, int> qtyByProduct = {};
    final Map<String, double> revenueByProduct = {};
    // One representative size_id per product, used to resolve an
    // image afterward — doesn't need every row, just one real lead.
    final Map<String, int> sampleSizeIdByProduct = {};

    for (final row in items) {
      final String name = row['product_name_snapshot'] ?? 'Unknown';
      final int qty = (row['quantity'] as num?)?.toInt() ?? 0;
      final double subtotal = (row['subtotal'] as num?)?.toDouble() ?? 0;

      totalSales += subtotal;
      totalQuantity += qty;
      qtyByProduct[name] = (qtyByProduct[name] ?? 0) + qty;
      revenueByProduct[name] = (revenueByProduct[name] ?? 0) + subtotal;

      final dynamic sizeIdRaw = row['size_id'];
      if (sizeIdRaw != null && !sampleSizeIdByProduct.containsKey(name)) {
        sampleSizeIdByProduct[name] = (sizeIdRaw as num).toInt();
      }
    }

    final List<MapEntry<String, int>> sorted = qtyByProduct.entries.toList()
      ..sort((a, b) {
        final int cmp = b.value.compareTo(a.value);
        return cmp != 0 ? cmp : a.key.compareTo(b.key);
      });

    final Map<String, String?> imageByProduct =
        await _fetchProductImages(sampleSizeIdByProduct);

    final List<ProductSalesEntry> products = sorted.map((e) {
      return ProductSalesEntry(
        productName: e.key,
        quantitySold: e.value,
        salesAmount: revenueByProduct[e.key] ?? 0,
        imageUrl: imageByProduct[e.key],
      );
    }).toList();

    return MonthSalesDetail(
      month: start,
      totalSales: totalSales,
      totalOrders: monthOrderIds.length,
      totalQuantitySold: totalQuantity,
      products: products,
    );

    
  }

  // Resolves one image per product via the REAL foreign-key chain:
  // order_item.size_id -> product_variant_size -> product_variant
  // -> product_image. product_id on order_item is text with no FK
  // constraint and isn't trustworthy for this — deliberately unused.
  // Returns null per product (not an error) when the chain is empty,
  // so the UI can show a plain placeholder instead of guessing.
  Future<Map<String, String?>> _fetchProductImages(
      Map<String, int> sampleSizeIdByProduct) async {
    if (sampleSizeIdByProduct.isEmpty) return {};

    try {
      final List<int> sizeIds = sampleSizeIdByProduct.values.toSet().toList();

      final List<dynamic> rows = await _supabase
          .from('product_variant_size')
          .select('''
            size_id,
            product_variant (
              product_image ( image_url, is_primary )
            )
          ''')
          .inFilter('size_id', sizeIds);

      final Map<int, String?> imageBySizeId = {};
      for (final row in rows) {
        final int sizeId = (row['size_id'] as num).toInt();
        final variant = row['product_variant'];
        final images = variant is Map ? variant['product_image'] : null;

        String? url;
        if (images is List && images.isNotEmpty) {
          final primary = images.cast<Map?>().firstWhere(
                (img) => img?['is_primary'] == true,
                orElse: () => null,
              );
          url = (primary ?? images.first)['image_url'] as String?;
        }
        imageBySizeId[sizeId] = url;
      }

      return {
        for (final entry in sampleSizeIdByProduct.entries)
          entry.key: imageBySizeId[entry.value],
      };
    } catch (e) {
      print('SalesReportService._fetchProductImages error: $e');
      return {};
    }
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

  // AUDIT ADD: Phase 5 — Custom Date Range summary. Date-bounds the
  // query itself (rather than fetching everything and filtering in
  // Dart) since a custom range could span the account's entire
  // history.
  Future<CustomRangeSummary> getCustomRangeSummary(DateTime start, DateTime end) async {
    final Set<int> qualifyingIds = await _getQualifyingOrderIds();
    if (qualifyingIds.isEmpty) {
      return CustomRangeSummary(
        start: start, end: end, totalSales: 0, cogs: 0,
        grossProfit: 0, totalOrders: 0, totalQuantitySold: 0,
      );
    }
    // AUDIT FIX: previously called .toUtc() on `start` FIRST — but
    // `start` comes from the date picker as a device-local DateTime,
    // so .toUtc() applied the DEVICE's uncontrolled timezone offset
    // before the hardcoded -8h was even subtracted, silently
    // corrupting the boundary by however far off the device's
    // timezone was from Manila. This treats the picked Y-M-D as the
    // intended Philippine calendar date directly, converting that
    // naive date to UTC without ever touching the device's own clock.
    final DateTime rangeStartUtc =
        DateTime(start.year, start.month, start.day).subtract(const Duration(hours: 8));
    final DateTime rangeEndUtc =
        DateTime(end.year, end.month, end.day).add(const Duration(days: 1)).subtract(const Duration(hours: 8));

    final List<dynamic> orders = await _supabase
        .from('orders')
        .select('order_id, created_at')
        .inFilter('order_id', qualifyingIds.toList())
        .gte('created_at', rangeStartUtc.toIso8601String())
        .lt('created_at', rangeEndUtc.toIso8601String());

    final Set<int> rangeOrderIds =
        orders.map((o) => (o['order_id'] as num).toInt()).toSet();

    if (rangeOrderIds.isEmpty) {
      return CustomRangeSummary(
        start: start, end: end, totalSales: 0, cogs: 0,
        grossProfit: 0, totalOrders: 0, totalQuantitySold: 0,
      );
    }

    final List<dynamic> items = await _supabase
        .from('order_item')
        .select('order_id, quantity, subtotal, cost_price_snapshot')
        .inFilter('order_id', rangeOrderIds.toList());

    double totalSales = 0, cogs = 0;
    int totalQuantity = 0;
    for (final row in items) {
      final double sub = (row['subtotal'] as num?)?.toDouble() ?? 0;
      final int qty = (row['quantity'] as num?)?.toInt() ?? 0;
      final double cost = (row['cost_price_snapshot'] as num?)?.toDouble() ?? 0;
      totalSales += sub;
      cogs += cost * qty;
      totalQuantity += qty;
    }

    return CustomRangeSummary(
      start: start, end: end,
      totalSales: totalSales, cogs: cogs,
      grossProfit: totalSales - cogs,
      totalOrders: rangeOrderIds.length,
      totalQuantitySold: totalQuantity,
    );
  }


    // AUDIT ADD: Phase 4 — day-by-day breakdown within one month, for
  // the Month view's new daily table. Reuses the same qualifying-order
  // definition as everywhere else in this service.
  Future<List<DailySalesSummary>> getDailyBreakdown(DateTime month) async {
    final DateTime start = DateTime(month.year, month.month);
    final DateTime end = DateTime(month.year, month.month + 1);
    return getDailyBreakdownForRange(start, end.subtract(const Duration(days: 1)));
  }

  // AUDIT ADD: generalizes the day-bucketing logic to an arbitrary
  // [start, end] range (inclusive both ends) instead of a whole
  // month — getDailyBreakdown() above now just calls this with a
  // month's own boundaries, so there's one real implementation.
  Future<List<DailySalesSummary>> getDailyBreakdownForRange(DateTime start, DateTime end) async {
    final DateTime rangeStart = DateTime(start.year, start.month, start.day);
    final DateTime rangeEndExclusive = DateTime(end.year, end.month, end.day).add(const Duration(days: 1));

    final Set<int> qualifyingIds = await _getQualifyingOrderIds();
    if (qualifyingIds.isEmpty) return [];

    final List<dynamic> orders = await _supabase
        .from('orders')
        .select('order_id, created_at')
        .inFilter('order_id', qualifyingIds.toList());

    final Map<int, DateTime> orderDateMap = {};
    final Map<String, Set<int>> dailyOrderIds = {};

        for (final row in orders) {
      final DateTime created = _toPhilippineTime(row['created_at']);
      if (created.isBefore(rangeStart) || !created.isBefore(rangeEndExclusive)) continue;
      final int orderId = (row['order_id'] as num).toInt();
      orderDateMap[orderId] = created;
      final String key = '${created.year}-${created.month.toString().padLeft(2, '0')}-${created.day.toString().padLeft(2, '0')}';
      dailyOrderIds.putIfAbsent(key, () => {});
      dailyOrderIds[key]!.add(orderId);
    }

    if (orderDateMap.isEmpty) return [];

    final List<dynamic> items = await _supabase
        .from('order_item')
        .select('order_id, quantity, subtotal, cost_price_snapshot')
        .inFilter('order_id', orderDateMap.keys.toList());

    final Map<String, double> dailySales = {};
    final Map<String, double> dailyCogs = {};
    final Map<String, int> dailyQuantity = {};

    for (final row in items) {
      final int orderId = (row['order_id'] as num).toInt();
      final DateTime? created = orderDateMap[orderId];
      if (created == null) continue;
      final String key = '${created.year}-${created.month.toString().padLeft(2, '0')}-${created.day.toString().padLeft(2, '0')}';
      final double sub = (row['subtotal'] as num?)?.toDouble() ?? 0;
      final int qty = (row['quantity'] as num?)?.toInt() ?? 0;
      final double cost = (row['cost_price_snapshot'] as num?)?.toDouble() ?? 0;
      dailySales[key] = (dailySales[key] ?? 0) + sub;
      dailyCogs[key] = (dailyCogs[key] ?? 0) + (cost * qty);
      dailyQuantity[key] = (dailyQuantity[key] ?? 0) + qty;
    }

    final List<String> sortedKeys = dailyOrderIds.keys.toList()..sort();
    return sortedKeys.map((key) {
      final parts = key.split('-').map(int.parse).toList();
      final double sales = dailySales[key] ?? 0;
      final double cogs = dailyCogs[key] ?? 0;
      return DailySalesSummary(
        date: DateTime(parts[0], parts[1], parts[2]),
        totalSales: sales,
        totalOrders: dailyOrderIds[key]!.length,
        totalQuantitySold: dailyQuantity[key] ?? 0,
        grossProfit: sales - cogs,
      );
    }).toList();
  }

    // AUDIT ADD: Phase 5 — read-only transaction list for one specific
  // day, triggered by clicking a row in the daily breakdown table.
  Future<List<DayTransaction>> getDayTransactions(DateTime day) async {
    final Set<int> qualifyingIds = await _getQualifyingOrderIds();
    if (qualifyingIds.isEmpty) return [];

    final List<dynamic> orders = await _supabase
        .from('orders')
        .select('order_id, total_amount, payment_method, order_type, order_status, created_at')
        .inFilter('order_id', qualifyingIds.toList());

    final List<DayTransaction> result = [];
    for (final row in orders) {
      final DateTime created = _toPhilippineTime(row['created_at']);
      if (created.year == day.year && created.month == day.month && created.day == day.day) {
        result.add(DayTransaction(
          orderId: (row['order_id'] as num).toInt(),
          dateTime: created,
          totalAmount: (row['total_amount'] as num?)?.toDouble() ?? 0,
          paymentMethod: row['payment_method'] ?? '',
          orderType: row['order_type'] ?? 'Online',
          orderStatus: row['order_status'] ?? '',
        ));
      }
    }
    result.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return result;
  }

    // AUDIT ADD: generalizes getDayTransactions() to an arbitrary
  // [start, end] range — same underlying qualifying-order query and
  // DayTransaction shape, just a wider date comparison instead of an
  // exact day match. getDayTransactions() itself is left untouched
  // so the existing Month-view per-day drill-down keeps working
  // exactly as before.
  Future<List<DayTransaction>> getRangeTransactions(DateTime start, DateTime end) async {
    final Set<int> qualifyingIds = await _getQualifyingOrderIds();
    if (qualifyingIds.isEmpty) return [];

    final List<dynamic> orders = await _supabase
        .from('orders')
        .select('order_id, total_amount, payment_method, order_type, order_status, created_at')
        .inFilter('order_id', qualifyingIds.toList());

    final DateTime rangeStart = DateTime(start.year, start.month, start.day);
    final DateTime rangeEndExclusive = DateTime(end.year, end.month, end.day).add(const Duration(days: 1));

    final List<DayTransaction> result = [];
    for (final row in orders) {
      final DateTime created = _toPhilippineTime(row['created_at']);
      if (!created.isBefore(rangeStart) && created.isBefore(rangeEndExclusive)) {
        result.add(DayTransaction(
          orderId: (row['order_id'] as num).toInt(),
          dateTime: created,
          totalAmount: (row['total_amount'] as num?)?.toDouble() ?? 0,
          paymentMethod: row['payment_method'] ?? '',
          orderType: row['order_type'] ?? 'Online',
          orderStatus: row['order_status'] ?? '',
        ));
      }
    }
    result.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return result;
  }

  
  // AUDIT ADD: day-scoped twin of getMonthSalesDetail() — same
  // MonthSalesDetail shape and ProductSalesEntry reused as-is, so
  // the "View Details" dialog works identically for monthly rows
  // (This Year) and daily rows (This Month/Week/Custom), with no
  // duplicate model or rendering logic.
  Future<MonthSalesDetail> getDaySalesDetail(DateTime day) async {
    final DateTime start = DateTime(day.year, day.month, day.day);
    final DateTime end = start.add(const Duration(days: 1));

    final Set<int> qualifyingIds = await _getQualifyingOrderIds();
    if (qualifyingIds.isEmpty) {
      return MonthSalesDetail(
        month: start, totalSales: 0, totalOrders: 0,
        totalQuantitySold: 0, products: [],
      );
    }

    final List<dynamic> orders = await _supabase
        .from('orders')
        .select('order_id, created_at')
        .inFilter('order_id', qualifyingIds.toList());

    final Set<int> dayOrderIds = {};
    for (final row in orders) {
      final DateTime created = _toPhilippineTime(row['created_at']);
      if (!created.isBefore(start) && created.isBefore(end)) {
        dayOrderIds.add((row['order_id'] as num).toInt());
      }
    }

    if (dayOrderIds.isEmpty) {
      return MonthSalesDetail(
        month: start, totalSales: 0, totalOrders: 0,
        totalQuantitySold: 0, products: [],
      );
    }

    final List<dynamic> items = await _supabase
        .from('order_item')
        .select('order_id, product_name_snapshot, quantity, subtotal, size_id')
        .inFilter('order_id', dayOrderIds.toList());

    double totalSales = 0;
    int totalQuantity = 0;
    final Map<String, int> qtyByProduct = {};
    final Map<String, double> revenueByProduct = {};
    final Map<String, int> sampleSizeIdByProduct = {};

    for (final row in items) {
      final String name = row['product_name_snapshot'] ?? 'Unknown';
      final int qty = (row['quantity'] as num?)?.toInt() ?? 0;
      final double subtotal = (row['subtotal'] as num?)?.toDouble() ?? 0;

      totalSales += subtotal;
      totalQuantity += qty;
      qtyByProduct[name] = (qtyByProduct[name] ?? 0) + qty;
      revenueByProduct[name] = (revenueByProduct[name] ?? 0) + subtotal;

      final dynamic sizeIdRaw = row['size_id'];
      if (sizeIdRaw != null && !sampleSizeIdByProduct.containsKey(name)) {
        sampleSizeIdByProduct[name] = (sizeIdRaw as num).toInt();
      }
    }

    final List<MapEntry<String, int>> sorted = qtyByProduct.entries.toList()
      ..sort((a, b) {
        final int cmp = b.value.compareTo(a.value);
        return cmp != 0 ? cmp : a.key.compareTo(b.key);
      });

    final Map<String, String?> imageByProduct =
        await _fetchProductImages(sampleSizeIdByProduct);

    final List<ProductSalesEntry> products = sorted.map((e) {
      return ProductSalesEntry(
        productName: e.key,
        quantitySold: e.value,
        salesAmount: revenueByProduct[e.key] ?? 0,
        imageUrl: imageByProduct[e.key],
      );
    }).toList();

    return MonthSalesDetail(
      month: start,
      totalSales: totalSales,
      totalOrders: dayOrderIds.length,
      totalQuantitySold: totalQuantity,
      products: products,
    );
  }

}