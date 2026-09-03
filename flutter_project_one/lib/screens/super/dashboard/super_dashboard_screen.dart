import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/super/groq_service.dart';
import '../../../services/super/dashboard/dashboard_service.dart';
import '../../../services/admin/inventory/archive_service.dart';
import '../../../widgets/super/dashboard/super_stats_card.dart';
import '../../../widgets/super/dashboard/sales_trend_card.dart';
import '../../../widgets/super/dashboard/brand_performance_card.dart';
import '../../../widgets/super/dashboard/ai_trending_card.dart';
import '../../../widgets/super/dashboard/restock_prediction_card.dart';
import '../../../widgets/super/dashboard/product_replacement_card.dart';

// ================================================
// SUPER ADMIN DASHBOARD SCREEN
// Analytics Dashboard — real Supabase data +
// AI predictions (Groq for trend/trending/restock,
// Gemini+Search for product replacement).
// ================================================
class SuperDashboardScreen extends ConsumerStatefulWidget {
  const SuperDashboardScreen({super.key});

  @override
  ConsumerState<SuperDashboardScreen> createState() =>
      _SuperDashboardScreenState();
}

class _SuperDashboardScreenState
    extends ConsumerState<SuperDashboardScreen> {

  final GroqService _groqService = GroqService();
  final DashboardService _dashboardService = DashboardService();
  final ArchiveService _archiveService = ArchiveService();

  // ── LOADING STATES ──
  bool _isStatsLoading = true;
  bool _isTrendLoading = true;
  bool _isTrendingLoading = true;
  bool _isRestockLoading = true;
  bool _isReplacementLoading = true;

  // ── STATS ──
  DashboardStats? _stats;
  List<BrandData> _brands = [];

  // ── SALES TREND ──
  List<double> _actualSales = [];
  List<double> _predictedSales = [];
  String _aiInsight = '';
  List<String> _months = [];

  // ── AI DATA ──
  List<Map<String, dynamic>> _trendingShoes = [];
  List<Map<String, dynamic>> _restockItems = [];
  List<Map<String, dynamic>> _replacements = [];
   List<String> _availableBrands = [];   // ← new

  // Brand colors — cycled if there are more brands than colors
  static const List<Color> _brandPalette = [
    Color(0xFF7C3AED),
    Color(0xFF06B6D4),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFFEF4444),
    Color(0xFF6366F1),
  ];

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadAllAiData();
  }

  // ================================================
  // LOAD REAL STATS + BRAND PERFORMANCE (no AI)
  // ================================================
  Future<void> _loadStats() async {
    try {
      setState(() => _isStatsLoading = true);

      final results = await Future.wait([
        _dashboardService.getStats(),
        _dashboardService.getBrandPerformance(),
        _dashboardService.getMonthlySalesHistory(months: 6),
      ]);

      final stats = results[0] as DashboardStats;
      final brandSales = results[1] as List<BrandSales>;
      final history = results[2] as List<double>;

      final now = DateTime.now();
      final monthLabels = List.generate(6, (i) {
        final date = DateTime(now.year, now.month - (5 - i), 1);
        const names = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
        ];
        return names[date.month - 1];
      });

      if (mounted) {
        setState(() {
          _stats = stats;
          _brands = brandSales.asMap().entries.map((entry) {
            return BrandData(
              name: entry.value.brand,
              percentage: entry.value.percentage,
              color: _brandPalette[entry.key % _brandPalette.length],
            );
          }).toList();
          _actualSales = history;
          _months = monthLabels;
          _isStatsLoading = false;
        });
      }
    } catch (error) {
      print('_loadStats error: $error');
      if (mounted) setState(() => _isStatsLoading = false);
    }
  }

  // ================================================
  // LOAD ALL AI DATA
  // ================================================
  Future<void> _loadAllAiData() async {
    await Future.wait([
      _loadSalesTrend(),
      _loadTrendingShoes(),
      _loadRestockPrediction(),
      _loadProductReplacements(),
    ]);
  }

  // ================================================
  // SALES TREND PREDICTION (Groq)
  // ================================================
  Future<void> _loadSalesTrend() async {
    try {
      setState(() => _isTrendLoading = true);

      // wait for real sales history to be ready first
      while (_actualSales.isEmpty && _isStatsLoading) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
      if (_actualSales.isEmpty) {
        _actualSales = await _dashboardService.getMonthlySalesHistory(months: 6);
      }

      final predicted = await _groqService.getSalesTrendPrediction(
        monthlySales: _actualSales,
      );
      final insight = await _groqService.getSalesTrendInsight(
        monthlySales: _actualSales,
      );

      if (mounted) {
        setState(() {
          _predictedSales = predicted;
          _aiInsight = insight;
          _isTrendLoading = false;
        });
      }
    } catch (error) {
      print('_loadSalesTrend error: $error');
      if (mounted) {
        setState(() {
          _predictedSales = [];
          _aiInsight = 'Unable to load AI prediction right now.';
          _isTrendLoading = false;
        });
      }
    }
  }

  // ================================================
  // TRENDING SHOES (real growth data + Groq ranking)
  // ================================================
  Future<void> _loadTrendingShoes() async {
    try {
      setState(() => _isTrendingLoading = true);

      final realSalesData = await _dashboardService.getProductSalesGrowth();

      final trending = await _groqService.getTrendingShoes(
        salesData: realSalesData,
      );

      if (mounted) {
        setState(() {
          _trendingShoes = trending.isNotEmpty ? trending : realSalesData.take(5).toList();
          _isTrendingLoading = false;
        });
      }
    } catch (error) {
      print('_loadTrendingShoes error: $error');
      if (mounted) setState(() => _isTrendingLoading = false);
    }
  }

  // ================================================
  // RESTOCK PREDICTION (real inventory + deterministic math)
  // ================================================
  Future<void> _loadRestockPrediction() async {
    try {
      setState(() => _isRestockLoading = true);

      final realInventory = await _dashboardService.getInventoryForRestock();

      final restock = await _groqService.getRestockPrediction(
        inventoryData: realInventory,
      );

      if (mounted) {
        setState(() {
          _restockItems = restock;
          _isRestockLoading = false;
        });
      }
    } catch (error) {
      print('_loadRestockPrediction error: $error');
      if (mounted) setState(() => _isRestockLoading = false);
    }
  }

  // ================================================
  // PRODUCT REPLACEMENT (Gemini + Search, real archived products)
  // ================================================
  Future<void> _loadProductReplacements() async {
    try {
      setState(() => _isReplacementLoading = true);

      final archivedProducts = await _archiveService.fetchArchivedProducts();

      // Only the most recently archived, to keep API calls bounded
      final targets = archivedProducts.take(5).map((p) => {
            'productName': p.productName,
            'brand': p.brand,
          }).toList();

            final availableBrands = archivedProducts.map((p) => p.brand).toSet().toList();
      final replacements = targets.isEmpty
          ? <Map<String, dynamic>>[]
          : await _groqService.getProductReplacements(
              discontinuedProducts: targets,
              availableBrands: availableBrands,
            );
      if (mounted) {
        setState(() {
          _replacements = replacements.map((r) => {
                'discontinuedProduct': r['discontinuedProduct'],
                'recommendedReplacement': r['recommendedReplacement'],
                'brand': r['brand'],
              }).toList();
          _availableBrands = availableBrands;
          _isReplacementLoading = false;
        });
      }
    } catch (error) {
      print('_loadProductReplacements error: $error');
      if (mounted) setState(() => _isReplacementLoading = false);
    }
  }

  String _formatCurrency(double value) {
    return '₱${value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    )}';
  }

  String _formatPercent(double value) {
    final sign = value >= 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(1)}%';
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {
    final stats = _stats;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Text(
              'Analytics Dashboard',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Sneaker Retail Admin Panel',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),

            const SizedBox(height: 28),

            // ── 4 STATS CARDS ──
            _isStatsLoading || stats == null
                ? const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: SuperStatsCard(
                          icon: Icons.attach_money,
                          iconBackgroundColor: const Color(0xFFF5F3FF),
                          iconColor: const Color(0xFF7C3AED),
                          title: 'Monthly Revenue',
                          value: _formatCurrency(stats.monthlyRevenue),
                          badge: _formatPercent(stats.revenueChangePercent),
                          badgeColor: const Color(0xFF065F46),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SuperStatsCard(
                          icon: Icons.shopping_cart_outlined,
                          iconBackgroundColor: const Color(0xFFEFF6FF),
                          iconColor: const Color(0xFF2563EB),
                          title: 'Total Orders',
                          value: stats.totalOrders.toString(),
                          badge: _formatPercent(stats.ordersChangePercent),
                          badgeColor: const Color(0xFF065F46),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SuperStatsCard(
                          icon: Icons.warning_amber_outlined,
                          iconBackgroundColor: const Color(0xFFFFFBEB),
                          iconColor: const Color(0xFFF59E0B),
                          title: 'Low Stock Items',
                          value: stats.lowStockItems.toString(),
                          badge: stats.lowStockItems > 0 ? 'Needs attention' : 'All good',
                          badgeColor: const Color(0xFF92400E),
                          isWarning: stats.lowStockItems > 0,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SuperStatsCard(
                          icon: Icons.people_outline,
                          iconBackgroundColor: const Color(0xFFF0FDF4),
                          iconColor: const Color(0xFF16A34A),
                          title: 'Active Customers',
                          value: stats.activeCustomers.toString(),
                          badge: _formatPercent(stats.customersChangePercent),
                          badgeColor: const Color(0xFF065F46),
                        ),
                      ),
                    ],
                  ),

            const SizedBox(height: 24),

            // ── SALES TREND + BRAND PERFORMANCE ──
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: SalesTrendCard(
                      actualSales: _actualSales,
                      predictedSales: _predictedSales,
                      months: _months,
                      aiInsight: _aiInsight,
                      isLoading: _isTrendLoading || _isStatsLoading,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: BrandPerformanceCard(brands: _brands),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── AI TRENDING + RESTOCK + REPLACEMENT ──
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: AiTrendingCard(
                      trendingShoes: _trendingShoes,
                      isLoading: _isTrendingLoading,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: RestockPredictionCard(
                      restockItems: _restockItems,
                      isLoading: _isRestockLoading,
                    ),
                  ),
                  const SizedBox(width: 16),
                    Expanded(
                    child: ProductReplacementCard(
                      replacements: _replacements,
                      availableBrands: _availableBrands,
                      isLoading: _isReplacementLoading,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}