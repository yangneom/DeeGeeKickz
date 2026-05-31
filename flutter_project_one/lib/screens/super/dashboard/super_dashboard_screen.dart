import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/super/groq_service.dart';
import '../../../widgets/super/dashboard/super_stats_card.dart';
import '../../../widgets/super/dashboard/sales_trend_card.dart';
import '../../../widgets/super/dashboard/brand_performance_card.dart';
import '../../../widgets/super/dashboard/ai_trending_card.dart';
import '../../../widgets/super/dashboard/restock_prediction_card.dart';
import '../../../widgets/super/dashboard/product_replacement_card.dart';

// ================================================
// SUPER ADMIN DASHBOARD SCREEN
// Analytics Dashboard with AI predictions
// ================================================
class SuperDashboardScreen extends ConsumerStatefulWidget {
  const SuperDashboardScreen({super.key});

  @override
  ConsumerState<SuperDashboardScreen> createState() =>
      _SuperDashboardScreenState();
}

class _SuperDashboardScreenState
    extends ConsumerState<SuperDashboardScreen> {

  // ── GROQ SERVICE ──
  final GroqService _groqService = GroqService();

  // ── LOADING STATES ──
  bool _isTrendLoading = true;
  bool _isTrendingLoading = true;
  bool _isRestockLoading = true;
  bool _isReplacementLoading = true;

  // ── AI DATA ──
  List<double> _predictedSales = [];
  String _aiInsight = '';
  List<Map<String, dynamic>> _trendingShoes = [];
  List<Map<String, dynamic>> _restockItems = [];
  List<Map<String, dynamic>> _replacements = [];

  // ================================================
  // FAKE DATA — replace with Supabase later
  // ================================================

  // stats
  final String _monthlyRevenue = '₱2,450,000';
  final String _totalOrders = '1,284';
  final String _lowStockItems = '24';
  final String _activeCustomers = '8,542';

  // actual monthly sales for chart
  final List<double> _actualSales = [
    2000000,
    2100000,
    1900000,
    2200000,
    2300000,
    2450000,
  ];

  // month labels
  final List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep',
  ];

  // brand performance data
  final List<BrandData> _brands = [
    BrandData(
      name: 'Nike',
      percentage: 42,
      color: const Color(0xFF7C3AED),
    ),
    BrandData(
      name: 'Adidas',
      percentage: 28,
      color: const Color(0xFF06B6D4),
    ),
    BrandData(
      name: 'Puma',
      percentage: 18,
      color: const Color(0xFFF59E0B),
    ),
    BrandData(
      name: 'New Balance',
      percentage: 12,
      color: const Color(0xFF10B981),
    ),
  ];

  // fake sales data for AI trending
  final List<Map<String, dynamic>> _fakeSalesData = [
    {'productName': 'Nike Air Max 270', 'salesCount': 342, 'growthPercent': 28},
    {'productName': 'Adidas Ultraboost 22', 'salesCount': 289, 'growthPercent': 22},
    {'productName': 'Puma RS-X', 'salesCount': 216, 'growthPercent': 18},
    {'productName': 'Nike Dunk Low', 'salesCount': 198, 'growthPercent': 15},
    {'productName': 'New Balance 574', 'salesCount': 167, 'growthPercent': 12},
  ];

  // fake inventory data for restock prediction
  final List<Map<String, dynamic>> _fakeInventoryData = [
    {
      'productName': 'New Balance 574',
      'currentStock': 15,
      'maxStock': 100,
      'dailySalesRate': 1.8,
    },
    {
      'productName': 'Nike Dunk Low',
      'currentStock': 22,
      'maxStock': 100,
      'dailySalesRate': 1.7,
    },
    {
      'productName': 'Adidas Samba',
      'currentStock': 8,
      'maxStock': 100,
      'dailySalesRate': 1.6,
    },
  ];

  // fake discontinued products for replacement
  final List<Map<String, dynamic>> _fakeDiscontinued = [
    {'productName': 'Nike React Infinity Run', 'brand': 'Nike'},
    {'productName': 'Adidas NMD R1', 'brand': 'Adidas'},
    {'productName': 'Puma Ignite', 'brand': 'Puma'},
  ];

  // available brands
  final List<String> _availableBrands = [
    'Nike', 'Adidas', 'Puma', 'New Balance',
  ];

  // ================================================
  // INIT STATE — load all AI data
  // ================================================
  @override
  void initState() {
    super.initState();
    _loadAllAiData();
  }

  // ================================================
  // LOAD ALL AI DATA
  // calls all Groq predictions at once
  // ================================================
  Future<void> _loadAllAiData() async {
    // run all AI calls in parallel
    await Future.wait([
      _loadSalesTrend(),
      _loadTrendingShoes(),
      _loadRestockPrediction(),
      _loadProductReplacements(),
    ]);
  }

  // ================================================
  // LOAD SALES TREND PREDICTION
  // ================================================
  Future<void> _loadSalesTrend() async {
    try {
      setState(() => _isTrendLoading = true);

      final predicted = await _groqService.getSalesTrendPrediction(
        monthlySales: _actualSales,
      );

      if (mounted) {
        setState(() {
          _predictedSales = predicted.isNotEmpty
              ? predicted
              : [2600000, 2750000, 2900000];
          _aiInsight =
              'Sales are projected to increase by 18% over the next two months. '
              'Consider increasing inventory for high-demand brands.';
          _isTrendLoading = false;
        });
      }
    } catch (error) {
      print('_loadSalesTrend error: $error');
      if (mounted) {
        setState(() {
          _predictedSales = [2600000, 2750000, 2900000];
          _aiInsight = 'Unable to load AI prediction. Showing estimated data.';
          _isTrendLoading = false;
        });
      }
    }
  }

  // ================================================
  // LOAD TRENDING SHOES
  // ================================================
  Future<void> _loadTrendingShoes() async {
    try {
      setState(() => _isTrendingLoading = true);

      final trending = await _groqService.getTrendingShoes(
        salesData: _fakeSalesData,
      );

      if (mounted) {
        setState(() {
          _trendingShoes = trending.isNotEmpty
              ? trending
              : _fakeSalesData.take(3).toList();
          _isTrendingLoading = false;
        });
      }
    } catch (error) {
      print('_loadTrendingShoes error: $error');
      if (mounted) {
        setState(() {
          _trendingShoes = _fakeSalesData.take(3).toList();
          _isTrendingLoading = false;
        });
      }
    }
  }

  // ================================================
  // LOAD RESTOCK PREDICTION
  // ================================================
  Future<void> _loadRestockPrediction() async {
    try {
      setState(() => _isRestockLoading = true);

      final restock = await _groqService.getRestockPrediction(
        inventoryData: _fakeInventoryData,
      );

      if (mounted) {
        setState(() {
          _restockItems = restock.isNotEmpty
              ? restock
              : _fakeInventoryData;
          _isRestockLoading = false;
        });
      }
    } catch (error) {
      print('_loadRestockPrediction error: $error');
      if (mounted) {
        setState(() {
          _restockItems = _fakeInventoryData;
          _isRestockLoading = false;
        });
      }
    }
  }

  // ================================================
  // LOAD PRODUCT REPLACEMENTS
  // ================================================
  Future<void> _loadProductReplacements() async {
    try {
      setState(() => _isReplacementLoading = true);

      final replacements = await _groqService.getProductReplacements(
        discontinuedProducts: _fakeDiscontinued,
        availableBrands: _availableBrands,
      );

      if (mounted) {
        setState(() {
          _replacements = replacements.isNotEmpty
              ? replacements
              : [
                  {
                    'discontinuedProduct': 'Nike React Infinity Run',
                    'recommendedReplacement': 'Nike Vomero 17',
                    'brand': 'Nike',
                  },
                  {
                    'discontinuedProduct': 'Adidas NMD R1',
                    'recommendedReplacement': 'Adidas Gazelle',
                    'brand': 'Adidas',
                  },
                  {
                    'discontinuedProduct': 'Puma Ignite',
                    'recommendedReplacement': 'Puma Velocity Nitro 2',
                    'brand': 'Puma',
                  },
                ];
          _isReplacementLoading = false;
        });
      }
    } catch (error) {
      print('_loadProductReplacements error: $error');
      if (mounted) {
        setState(() {
          _replacements = [
            {
              'discontinuedProduct': 'Nike React Infinity Run',
              'recommendedReplacement': 'Nike Vomero 17',
              'brand': 'Nike',
            },
            {
              'discontinuedProduct': 'Adidas NMD R1',
              'recommendedReplacement': 'Adidas Gazelle',
              'brand': 'Adidas',
            },
            {
              'discontinuedProduct': 'Puma Ignite',
              'recommendedReplacement': 'Puma Velocity Nitro 2',
              'brand': 'Puma',
            },
          ];
          _isReplacementLoading = false;
        });
      }
    }
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── TITLE ──
            const Text(
              'Analytics Dashboard',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),

            const SizedBox(height: 4),

            const Text(
              'Sneaker Retail Admin Panel',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
            ),

            const SizedBox(height: 24),

            // ── 4 STATS CARDS ──
            Row(
              children: [

                Expanded(
                  child: SuperStatsCard(
                    icon: Icons.attach_money,
                    iconBackgroundColor: const Color(0xFFF5F3FF),
                    iconColor: const Color(0xFF7C3AED),
                    title: 'Monthly Revenue',
                    value: _monthlyRevenue,
                    badge: '+12.5%',
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
                    value: _totalOrders,
                    badge: '+8.2%',
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
                    value: _lowStockItems,
                    badge: 'Needs attention',
                    badgeColor: const Color(0xFF92400E),
                    isWarning: true,
                  ),
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: SuperStatsCard(
                    icon: Icons.people_outline,
                    iconBackgroundColor: const Color(0xFFF0FDF4),
                    iconColor: const Color(0xFF16A34A),
                    title: 'Active Customers',
                    value: _activeCustomers,
                    badge: '+5.3%',
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

                  // sales trend — takes more space
                  Expanded(
                    flex: 3,
                    child: SalesTrendCard(
                      actualSales: _actualSales,
                      predictedSales: _predictedSales,
                      months: _months,
                      aiInsight: _aiInsight,
                      isLoading: _isTrendLoading,
                    ),
                  ),

                  const SizedBox(width: 16),

                  // brand performance pie chart
                  Expanded(
                    flex: 2,
                    child: BrandPerformanceCard(
                      brands: _brands,
                    ),
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

                  // AI trending shoes
                  Expanded(
                    child: AiTrendingCard(
                      trendingShoes: _trendingShoes,
                      isLoading: _isTrendingLoading,
                    ),
                  ),

                  const SizedBox(width: 16),

                  // restock prediction
                  Expanded(
                    child: RestockPredictionCard(
                      restockItems: _restockItems,
                      isLoading: _isRestockLoading,
                    ),
                  ),

                  const SizedBox(width: 16),

                  // product replacement
                  Expanded(
                    child: ProductReplacementCard(
                      replacements: _replacements,
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