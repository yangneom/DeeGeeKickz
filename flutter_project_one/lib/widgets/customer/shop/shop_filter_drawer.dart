import 'package:flutter/material.dart';
import '../../../models/product_model.dart';

/// Filter state passed in and out of the drawer.
class ShopFilterState {
  final Set<String> brands;
  final Set<String> categories;
  final String? size;
  final double maxPrice;

  const ShopFilterState({
    this.brands = const {},
    this.categories = const {},
    this.size,
    this.maxPrice = 500,
  });

  ShopFilterState copyWith({
    Set<String>? brands,
    Set<String>? categories,
    String? size,
    double? maxPrice,
    bool clearSize = false,
  }) {
    return ShopFilterState(
      brands: brands ?? this.brands,
      categories: categories ?? this.categories,
      size: clearSize ? null : (size ?? this.size),
      maxPrice: maxPrice ?? this.maxPrice,
    );
  }

  bool get isEmpty =>
      brands.isEmpty && categories.isEmpty && size == null && maxPrice == 500;
}

/// Shows the filter bottom sheet on mobile.
/// Returns the updated [ShopFilterState] or null if dismissed.
Future<ShopFilterState?> showShopFilterDrawer(
  BuildContext context,
  ShopFilterState current,
) {
  return showModalBottomSheet<ShopFilterState>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FilterSheet(current: current),
  );
}

class _FilterSheet extends StatefulWidget {
  final ShopFilterState current;
  const _FilterSheet({required this.current});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late Set<String> _brands;
  late Set<String> _categories;
  late String? _size;
  late double _maxPrice;

  @override
  void initState() {
    super.initState();
    _brands = Set.from(widget.current.brands);
    _categories = Set.from(widget.current.categories);
    _size = widget.current.size;
    _maxPrice = widget.current.maxPrice;
  }

  void _clear() {
    setState(() {
      _brands = {};
      _categories = {};
      _size = null;
      _maxPrice = 500;
    });
  }

  void _apply() {
    Navigator.of(context).pop(
      ShopFilterState(
        brands: _brands,
        categories: _categories,
        size: _size,
        maxPrice: _maxPrice,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF9F9F9),
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCFC4C5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'FILTERS',
                      style: TextStyle(
                        fontFamily: 'Archivo Narrow',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Color(0xFFCFC4C5)),

              // Scrollable filter content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    _SectionLabel('Brand'),
                    const SizedBox(height: 12),
                    _ChipRow(
                      options: kShopBrands,
                      selected: _brands,
                      onToggle: (v) => setState(() {
                        _brands.contains(v)
                            ? _brands.remove(v)
                            : _brands.add(v);
                      }),
                    ),
                    const SizedBox(height: 24),

                    _SectionLabel('Category'),
                    const SizedBox(height: 12),
                    _CategoryGrid(
                      selected: _categories,
                      onToggle: (v) => setState(() {
                        _categories.contains(v)
                            ? _categories.remove(v)
                            : _categories.add(v);
                      }),
                    ),
                    const SizedBox(height: 24),

                    _SectionLabel('Size (US)'),
                    const SizedBox(height: 12),
                    _SizeGrid(
                      selected: _size,
                      onSelect: (v) => setState(
                          () => _size = (_size == v) ? null : v),
                    ),
                    const SizedBox(height: 24),

                    _SectionLabel('Max Price'),
                    const SizedBox(height: 12),
                    _PriceSlider(
                      value: _maxPrice,
                      onChanged: (v) => setState(() => _maxPrice = v),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // Action buttons
              const Divider(height: 1, color: Color(0xFFCFC4C5)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        label: 'CLEAR',
                        filled: false,
                        onTap: _clear,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        label: 'APPLY',
                        filled: true,
                        onTap: _apply,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Sub-widgets ─────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: Colors.black,
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const _ChipRow({
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isOn = selected.contains(opt);
        return GestureDetector(
          onTap: () => onToggle(opt),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isOn ? Colors.black : Colors.transparent,
              border: Border.all(
                color: isOn ? Colors.black : const Color(0xFFCFC4C5),
              ),
            ),
            child: Text(
              opt,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isOn ? Colors.white : Colors.black,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const _CategoryGrid({required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 3.5,
      children: kShopCategories.map((cat) {
        final isOn = selected.contains(cat);
        return GestureDetector(
          onTap: () => onToggle(cat),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isOn ? Colors.black : const Color(0xFFCFC4C5),
              ),
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: isOn,
                      onChanged: (_) => onToggle(cat),
                      activeColor: Colors.black,
                      side: const BorderSide(color: Colors.black, width: 1.5),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    cat,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SizeGrid extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelect;

  const _SizeGrid({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 6,
      mainAxisSpacing: 6,
      children: kShopSizes.map((s) {
        final isOn = selected == s;
        return GestureDetector(
          onTap: () => onSelect(s),
          child: Container(
            decoration: BoxDecoration(
              color: isOn ? Colors.black : Colors.transparent,
              border: Border.all(
                color: isOn ? Colors.black : const Color(0xFFCFC4C5),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              s,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isOn ? Colors.white : Colors.black,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PriceSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _PriceSlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.black,
            inactiveTrackColor: const Color(0xFFCFC4C5),
            thumbColor: Colors.black,
            overlayColor: Colors.black12,
            trackHeight: 2,
          ),
          child: Slider(
            min: 0,
            max: 500,
            value: value,
            onChanged: onChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('\$0',
                  style: _priceStyle),
              Text('\$${value.toStringAsFixed(0)}',
                  style: _priceStyle.copyWith(fontWeight: FontWeight.w700)),
              Text('\$500+',
                  style: _priceStyle),
            ],
          ),
        ),
      ],
    );
  }

  static const _priceStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: Color(0xFF656464),
  );
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: filled ? Colors.black : Colors.transparent,
          border: Border.all(
            color: filled ? Colors.black : const Color(0xFFCFC4C5),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.7,
            color: filled ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}