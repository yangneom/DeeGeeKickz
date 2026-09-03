import 'package:flutter/material.dart';
import '../../../screens/super/dashboard/dashboard_theme.dart';
import '../../../services/super/groq_service.dart';

class ProductReplacementCard extends StatefulWidget {
  final List<Map<String, dynamic>> replacements;
  final List<String> availableBrands;
  final bool isLoading;

  const ProductReplacementCard({
    super.key,
    required this.replacements,
    required this.availableBrands,
    this.isLoading = false,
  });

  @override
  State<ProductReplacementCard> createState() => _ProductReplacementCardState();
}

class _ProductReplacementCardState extends State<ProductReplacementCard> {
  final GroqService _groqService = GroqService();

  // Keyed by discontinuedProduct — per-row state, since each row's
  // "Suggest New Product" action is independent of the others.
  final Map<String, bool> _isSuggesting = {};
  final Map<String, String?> _suggestionErrors = {};

  Future<void> _handleSuggestNewProduct(String discontinuedProduct, String brand) async {
    setState(() {
      _isSuggesting[discontinuedProduct] = true;
      _suggestionErrors[discontinuedProduct] = null;
    });

    final result = await _groqService.getNewProductSuggestion(
      discontinuedProduct: discontinuedProduct,
      brand: brand,
      availableBrands: widget.availableBrands,
    );

    if (!mounted) return;

    setState(() => _isSuggesting[discontinuedProduct] = false);

    if (result == null) {
      setState(() => _suggestionErrors[discontinuedProduct] =
          'Could not generate a suggestion — try again.');
      return;
    }

    _showSuggestionDialog(
      discontinuedProduct: discontinuedProduct,
      recommendedReplacement: result['recommendedReplacement'] ?? 'Unknown',
      reasoning: result['reasoning'] ?? '',
    );
  }

  void _showSuggestionDialog({
    required String discontinuedProduct,
    required String recommendedReplacement,
    required String reasoning,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.storefront_outlined, size: 18, color: Color(0xFF4F46E5)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Stocking Suggestion',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CONSIDER STOCKING',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4F46E5),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      recommendedReplacement,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    if (reasoning.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        reasoning,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF4C4546), height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Replaces: $discontinuedProduct',
                style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: DashboardTheme.cardPadding,
      decoration: DashboardTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardTheme.cardTitle('Product Replacement'),

          const SizedBox(height: 16),

          if (widget.isLoading)
            const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (widget.replacements.isEmpty)
            const SizedBox(
              height: 200,
              child: Center(
                child: Text(
                  'No archived products need a replacement suggestion',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                ),
              ),
            )
                    else
              SizedBox(
              height: 280,
              child: ListView.builder(
                  itemCount: widget.replacements.length,
                  itemBuilder: (context, i) {
                    return Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: i < widget.replacements.length - 1
                      ? const Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('ARCHIVED',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF), letterSpacing: 0.5)),
                              const SizedBox(height: 2),
                              Text(widget.replacements[i]['discontinuedProduct'] ?? '',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
                            ],
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.arrow_forward, size: 16, color: Color(0xFF9CA3AF)),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('RECOMMENDED FOR CUSTOMERS',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: DashboardTheme.success, letterSpacing: 0.5)),
                              const SizedBox(height: 2),
                              Text(widget.replacements[i]['recommendedReplacement'] ?? '',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: DashboardTheme.success)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Builder(builder: (context) {
                      final String productKey = widget.replacements[i]['discontinuedProduct'] ?? '';
                      final String brand = widget.replacements[i]['brand'] ?? '';
                      final bool isLoadingRow = _isSuggesting[productKey] ?? false;
                      final String? errorText = _suggestionErrors[productKey];

                      return Row(
                        children: [
                          TextButton.icon(
                            onPressed: isLoadingRow
                                ? null
                                : () => _handleSuggestNewProduct(productKey, brand),
                            icon: isLoadingRow
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)),
                                  )
                                : const Icon(Icons.storefront_outlined, size: 14, color: Color(0xFF4F46E5)),
                            label: Text(
                              isLoadingRow ? 'Searching...' : 'Suggest New Product',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4F46E5)),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          if (errorText != null) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorText,
                                style: const TextStyle(fontSize: 10, color: DashboardTheme.danger),
                              ),
                            ),
                          ],
                        ],
                      );
                    }),
                        ],
                      ),
                    );
                                    },
              ),
            ),

          if (widget.replacements.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8)),
              child: const Text(
                'Green = suggested replacement to show customers. "Suggest New Product" = a separate, admin-only pick for what to consider stocking next.',
                style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}