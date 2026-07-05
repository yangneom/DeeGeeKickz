import 'package:flutter/material.dart';
import 'shop_filter_drawer.dart';

class ShopFilterSidebar extends StatefulWidget {
  final ShopFilterState state;
  final ValueChanged<ShopFilterState> onChanged;
  final List<String> availableBrands;
  final List<String> availableCategories;

  const ShopFilterSidebar({
    super.key,
    required this.state,
    required this.onChanged,
    required this.availableBrands,
    required this.availableCategories,
  });

  @override
  State<ShopFilterSidebar> createState() => _ShopFilterSidebarState();
}

class _ShopFilterSidebarState extends State<ShopFilterSidebar> {
  late Set<String> _brands;
  late Set<String> _categories;
  late String? _size;
  late double _maxPrice;

  // Common shoe sizes
  static const List<String> _sizes = [
    '6', '6.5', '7', '7.5', '8', '8.5', '9',
    '9.5', '10', '10.5', '11', '12',
  ];

  @override
  void initState() {
    super.initState();
    _sync(widget.state);
  }

  @override
  void didUpdateWidget(ShopFilterSidebar old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) _sync(widget.state);
  }

  void _sync(ShopFilterState s) {
    _brands = Set.from(s.brands);
    _categories = Set.from(s.categories);
    _size = s.size;
    _maxPrice = s.maxPrice;
  }

  void _emit() {
    widget.onChanged(ShopFilterState(
      brands: _brands,
      categories: _categories,
      size: _size,
      maxPrice: _maxPrice,
    ));
  }

  void _clear() {
    setState(() {
      _brands = {};
      _categories = {};
      _size = null;
      _maxPrice = 5000;
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'FILTERS',
                style: TextStyle(
                  fontFamily: 'Archivo Narrow',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Colors.black,
                ),
              ),
              if (!widget.state.isEmpty)
                GestureDetector(
                  onTap: _clear,
                  child: const Text(
                    'CLEAR ALL',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: Color(0xFF4C4546),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: Color(0xFFCFC4C5)),
          const SizedBox(height: 16),

          // Brand
          _SidebarSection(
            label: 'Brand',
            child: Column(
              children: widget.availableBrands.map((b) {
                final isOn = _brands.contains(b);
                return _CheckRow(
                  label: b,
                  checked: isOn,
                  onTap: () {
                    setState(() =>
                        isOn ? _brands.remove(b) : _brands.add(b));
                    _emit();
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // Category
          _SidebarSection(
            label: 'Category',
            child: Column(
              children: widget.availableCategories.map((c) {
                final isOn = _categories.contains(c);
                return _CheckRow(
                  label: c,
                  checked: isOn,
                  onTap: () {
                    setState(() =>
                        isOn ? _categories.remove(c) : _categories.add(c));
                    _emit();
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // Size
          _SidebarSection(
            label: 'Size (US)',
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _sizes.map((s) {
                final isOn = _size == s;
                return GestureDetector(
                  onTap: () {
                    setState(() => _size = isOn ? null : s);
                    _emit();
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isOn ? Colors.black : Colors.transparent,
                      border: Border.all(
                        color: isOn
                            ? Colors.black
                            : const Color(0xFFCFC4C5),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      s,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isOn ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // Price
          _SidebarSection(
            label: 'Max Price',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                    value: _maxPrice,
                    onChanged: (v) {
                      setState(() => _maxPrice = v);
                      _emit();
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('₱0', style: _priceStyle),
                    Text(
                      '₱${_maxPrice.toStringAsFixed(0)}',
                      style: _priceStyle.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.black),
                    ),
                    const Text('₱5000+', style: _priceStyle),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _priceStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: Color(0xFF656464),
  );
}

class _SidebarSection extends StatelessWidget {
  final String label;
  final Widget child;

  const _SidebarSection({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  final String label;
  final bool checked;
  final VoidCallback onTap;

  const _CheckRow(
      {required this.label, required this.checked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: checked,
                onChanged: (_) => onTap(),
                activeColor: Colors.black,
                side: const BorderSide(color: Colors.black, width: 1.5),
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}