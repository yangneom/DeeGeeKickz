import 'package:flutter/material.dart';
import '../../../screens/super/dashboard/dashboard_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/super/groq_service.dart';

// The web-search answer can carry inline citation markup, e.g.
// "([newbalance.com](https://www.newbalance.com/...?utm_source=openai))".
// This pulls those links out of the sentence so they can be shown as a
// clean Source line instead of raw text.
class _CleanedText {
  final String text;
  final List<Uri> links;
  const _CleanedText(this.text, this.links);
}

_CleanedText _cleanSuggestionText(String raw) {
  final List<Uri> links = [];
  final Set<String> seenHosts = {};

  void collect(String url) {
    final String trimmed = url.replaceAll(RegExp(r'[.,;:)\]]+$'), '');
    final Uri? uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return;

    final String host = uri.host.replaceFirst(RegExp(r'^www\.'), '');
    if (!seenHosts.add(host)) return;

    // Drop tracking params such as utm_source=openai.
    final Map<String, String> kept = {
      for (final e in uri.queryParameters.entries)
        if (!e.key.toLowerCase().startsWith('utm_')) e.key: e.value,
    };

    links.add(Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
      queryParameters: kept.isEmpty ? null : kept,
    ));
  }

  String removeAndCollect(String input, RegExp pattern) {
    return input.replaceAllMapped(pattern, (Match m) {
      collect(m.groupCount >= 1 ? (m.group(1) ?? '') : m.group(0)!);
      return '';
    });
  }

  String text = raw;
  // ([domain](https://...))
  text = removeAndCollect(
      text, RegExp(r'\(\s*\[[^\]]*\]\((https?://[^)\s]+)\)\s*\)'));
  // [domain](https://...)
  text = removeAndCollect(text, RegExp(r'\[[^\]]*\]\((https?://[^)\s]+)\)'));
  // (domain)(https://...)
  text = removeAndCollect(text,
      RegExp(r'\(\s*[\w.-]+\.[A-Za-z]{2,}\s*\)\s*\((https?://[^)\s]+)\)'));
  // any bare URL left over
  text = removeAndCollect(text, RegExp(r'https?://[^\s)\]]+'));

  text = text
      .replaceAll(RegExp(r'\(\s*\)'), '')
      .replaceAllMapped(RegExp(r'\s+([.,;:])'), (Match m) => m.group(1)!)
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();

  return _CleanedText(text, links);
}
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
      brand: brand,
      recommendedReplacement: result['recommendedReplacement'] ?? 'Unknown',
      reasoning: result['reasoning'] ?? '',
    );
  }

  void _showSuggestionDialog({
    required String discontinuedProduct,
    required String brand,
    required String recommendedReplacement,
    required String reasoning,
  }) {
    final _CleanedText cleaned = _cleanSuggestionText(reasoning);
    final String brandName = brand.trim();
    final String tileSource =
        brandName.isNotEmpty ? brandName : recommendedReplacement.trim();
    final String initial =
        tileSource.isEmpty ? '?' : tileSource[0].toUpperCase();

    const TextStyle sectionLabel = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: Color(0xFF6B7280),
      letterSpacing: 0.5,
    );

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 640),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.auto_awesome, size: 18, color: Color(0xFF4F46E5)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Product Recommendation',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            brandName.isEmpty
                                ? 'Based on a web search of the current lineup'
                                : 'Based on a web search of $brandName\'s current lineup',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close, size: 18, color: Color(0xFF6B7280)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // ── The recommended product ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          initial,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'RECOMMENDED PRODUCT',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5), letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              recommendedReplacement,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                            ),
                            if (brandName.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(brandName, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Why ──
                const Text('WHY THIS PRODUCT', style: sectionLabel),
                const SizedBox(height: 6),
                Text(
                  cleaned.text.isNotEmpty ? cleaned.text : 'No explanation was provided.',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.5),
                ),
                const SizedBox(height: 18),

                // ── Relationship to the archived product ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.swap_horiz, size: 18, color: Color(0xFF9CA3AF)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'MODERN ALTERNATIVE TO',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF), letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              discontinuedProduct,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Source (clean links, never raw URLs) ──
                if (cleaned.links.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Text('SOURCE', style: sectionLabel),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Wrap(
                          spacing: 14,
                          runSpacing: 4,
                          children: cleaned.links.map((link) {
                            return InkWell(
                              onTap: () => launchUrl(link, mode: LaunchMode.externalApplication),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    link.host.replaceFirst(RegExp(r'^www\.'), ''),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF2563EB)),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.open_in_new, size: 12, color: Color(0xFF2563EB)),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFF374151)),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
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