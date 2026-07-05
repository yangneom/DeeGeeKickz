import 'package:flutter/material.dart';

class ShopFilterState {
  final Set<String> brands;
  final Set<String> categories;
  final String? size;
  final double maxPrice;

  const ShopFilterState({
    this.brands = const {},
    this.categories = const {},
    this.size,
    this.maxPrice = 5000,
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
      brands.isEmpty && categories.isEmpty && size == null && maxPrice == 5000;
}

Future<ShopFilterState?> showShopFilterDrawer(
  BuildContext context,
  ShopFilterState current, {
  required List<String> availableBrands,
  required List<String> availableCategories,
}) {
  return showModalBottomSheet<ShopFilterState>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FilterSheet(
      current: current,
      availableBrands: availableBrands,
      availableCategories: availableCategories,
    ),
  );
}

class _FilterSheet extends StatefulWidget {
  final ShopFilterState current;
  final List<String> availableBrands;
  final List<String> availableCategories;

  const _FilterSheet({
    required this.current,
    required this.availableBrands,
    required this.availableCategories,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late Set<String> _brands;
  late Set<String> _categories;
  late String? _size;
  late double _maxPrice;

  static const List<String> _sizes = [
    '6', '6.5', '7', '7.5', '8', '8.5', '9',
    '9.5', '10', '10.5', '11', '12',
  ];

  @override
  void initState() {
    super.initState();
    _brands = Set.from(widget.current.brands);
    _categories = Set.from(widget.current.categories);
    _size = widget.current.size;
    _maxPrice = widget.current.maxPrice;
  }

  void _clear() => setState(() {
        _brands = {};
        _categories = {};
        _size = null;
        _maxPrice = 5000;
      });

  void _apply() => Navigator.of(context).pop(ShopFilterState(
        brands: _brands,
        categories: _categories,
        size: _size,
        maxPrice: _maxPrice,
      ));

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
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCFC4C5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
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
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    _SectionLabel('Brand'),
                    const SizedBox(height: 12),
                    _ChipRow(
                      options: widget.availableBrands,
                      selected: _brands,
                      onToggle: (v) => setState(() => _brands.contains(v)
                          ? _brands.remove(v)
                          : _brands.add(v)),
                    ),
                    const SizedBox(height: 24),
                    _SectionLabel('Category'),
                    const SizedBox(height: 12),
                    _ChipRow(
                      options: widget.availableCategories,
                      selected: _categories,
                      onToggle: (v) => setState(() =>
                          _categories.contains(v)
                              ? _categories.remove(v)
                              : _categories.add(v)),
                    ),
                    const SizedBox(height: 24),
                    _SectionLabel('Size (US)'),
                    const SizedBox(height: 12),
                    _SizeGrid(
                      sizes: _sizes,
                      selected: _size,
                      onSelect: (v) =>
                          setState(() => _size = (_size == v) ? null : v),
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
              const Divider(height: 1, color: Color(0xFFCFC4C5)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Row(
                  children: [
                    Expanded(
                        child: _ActionButton(
                            label: 'CLEAR', filled: false, onTap: _clear)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _ActionButton(
                            label: 'APPLY', filled: true, onTap: _apply)),
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

// ── Sub-widgets ──────────────────────────────────────────────────

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

  const _ChipRow(
      {required this.options,
      required this.selected,
      required this.onToggle});

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
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isOn ? Colors.black : Colors.transparent,
              border: Border.all(
                  color: isOn ? Colors.black : const Color(0xFFCFC4C5)),
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

class _SizeGrid extends StatelessWidget {
  final List<String> sizes;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _SizeGrid(
      {required this.sizes, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: sizes.map((s) {
        final isOn = selected == s;
        return GestureDetector(
          onTap: () => onSelect(s),
          child: Container(
            width: 48,
            height: 40,
            decoration: BoxDecoration(
              color: isOn ? Colors.black : Colors.transparent,
              border: Border.all(
                  color: isOn ? Colors.black : const Color(0xFFCFC4C5)),
            ),
            alignment: Alignment.center,
            child: Text(
              s,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
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
            max: 5000,
            value: value,
            onChanged: onChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('₱0', style: _priceStyle),
              Text('₱${value.toStringAsFixed(0)}',
                  style:
                      _priceStyle.copyWith(fontWeight: FontWeight.w700)),
              Text('₱5000+', style: _priceStyle),
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

  const _ActionButton(
      {required this.label, required this.filled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: filled ? Colors.black : Colors.transparent,
          border: Border.all(
              color: filled ? Colors.black : const Color(0xFFCFC4C5)),
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