import 'package:flutter/material.dart';

import '../../../models/product_model.dart';
import '../../../widgets/common/nav/bottom_nav_bar.dart';
import '../../../widgets/customer/search/search_bar_field.dart';
import '../../../widgets/customer/search/search_result_tile.dart';
import '../../../widgets/customer/search/search_empty_state.dart';

/// Full-screen search over all [mockShopProducts] + [mockPromoProducts].
/// Triggered by tapping the search icon in [AppTopBar].
/// Results update live as the user types.
/// Tapping a result navigates to its product detail screen.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _query = '';

  // All searchable products — shop + promo combined, de-duped by id
  static final List<ProductModel> _allProducts = [
    ...mockShopProducts,
    ...mockPromoProducts.where(
      (p) => !mockShopProducts.any((s) => s.name == p.name),
    ),
  ];

  List<ProductModel> get _results {
    if (_query.trim().isEmpty) return [];
    final q = _query.toLowerCase().trim();
    return _allProducts.where((p) {
      return p.name.toLowerCase().contains(q) ||
          p.brand.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q) ||
          (p.badge?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    setState(() => _query = '');
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    final hPad      = isDesktop ? 48.0 : 16.0;
    final results   = _results;
    final hasQuery  = _query.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Custom top bar with search field ───────────────
            Container(
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFF9F9F9),
                border: Border(
                  bottom: BorderSide(color: Color(0xFFCFC4C5), width: 1),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: Row(
                  children: [
                    // Back button
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: Icon(Icons.arrow_back,
                            size: 22, color: Colors.black),
                      ),
                    ),

                    // Search field — takes remaining space
                    Expanded(
                      child: SearchBarField(
                        controller: _controller,
                        focusNode: _focusNode,
                        onChanged: (v) => setState(() => _query = v),
                        onClear: _clear,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Results / idle area ────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(hPad, 24, hPad, 80),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 896),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Result count label
                        if (hasQuery) ...[
                          Text(
                            results.isEmpty
                                ? 'No results'
                                : '${results.length} result${results.length != 1 ? 's' : ''} for "$_query"',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              color: Color(0xFF656464),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Results list / empty / idle
                        if (!hasQuery)
                          const SearchIdleState()
                        else if (results.isEmpty)
                          SearchEmptyState(query: _query)
                        else
                          Column(
                            children: results
                                .map(
                                  (p) => SearchResultTile(
                                    product: p,
                                    query: _query,
                                    onTap: () {
                                      // TODO: navigate to ProductDetailScreen(product: p)
                                      // Uncomment when product detail is ready:
                                      // Navigator.of(context).push(MaterialPageRoute(
                                      //   builder: (_) => ProductDetailScreen(product: p),
                                      // ));
                                    },
                                  ),
                                )
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 1),
    );
  }
}