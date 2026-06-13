import 'package:flutter/material.dart';

import '../../../models/product_detail_model.dart';

/// Technical description section.
/// - Mobile: stacked vertically (description → specs → features)
/// - Desktop: 2-column layout (label left / content right),
///   matching the HTML's `md:grid-cols-12` pattern.
class ProductSpecsSection extends StatelessWidget {
  final ProductDetailModel product;

  const ProductSpecsSection({super.key, required this.product});

  static const double _mdBreakpoint = 768;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= _mdBreakpoint;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 48),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Color(0xFFCFC4C5)),
            ),
          ),
          child: isDesktop
              ? _DesktopLayout(product: product)
              : _MobileLayout(product: product),
        );
      },
    );
  }
}

// ── Desktop: label col (4) + content col (8) ────────────────────

class _DesktopLayout extends StatelessWidget {
  final ProductDetailModel product;
  const _DesktopLayout({required this.product});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left label col
        const SizedBox(
          width: 240,
          child: Text(
            'TECHNICAL\nDESCRIPTION',
            style: TextStyle(
              fontFamily: 'Archivo Narrow',
              fontSize: 32,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
              height: 1.1,
              color: Colors.black,
            ),
          ),
        ),

        const SizedBox(width: 40),

        // Right content col
        Expanded(
          child: _SpecsContent(product: product),
        ),
      ],
    );
  }
}

// ── Mobile: stacked ─────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  final ProductDetailModel product;
  const _MobileLayout({required this.product});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TECHNICAL DESCRIPTION',
          style: TextStyle(
            fontFamily: 'Archivo Narrow',
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 20),
        _SpecsContent(product: product),
      ],
    );
  }
}

// ── Shared content ───────────────────────────────────────────────

class _SpecsContent extends StatelessWidget {
  final ProductDetailModel product;
  const _SpecsContent({required this.product});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Description paragraph
        Text(
          product.description,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            height: 28 / 18,
            color: Color(0xFF4C4546),
          ),
        ),

        const SizedBox(height: 32),

        // Specs + Features row (wraps on narrow screens)
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 480;
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SpecsTable(specs: product.specs),
                  const SizedBox(height: 24),
                  _FeaturesList(features: product.features),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _SpecsTable(specs: product.specs)),
                const SizedBox(width: 32),
                Expanded(child: _FeaturesList(features: product.features)),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SpecsTable extends StatelessWidget {
  final ProductSpecs specs;
  const _SpecsTable({required this.specs});

  @override
  Widget build(BuildContext context) {
    final rows = [
      _SpecRow(label: 'Weight', value: specs.weight),
      _SpecRow(label: 'Drop', value: specs.drop),
      _SpecRow(label: 'Terrain', value: specs.terrain),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SPECIFICATIONS',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.7,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        ...rows,
      ],
    );
  }
}

class _SpecRow extends StatelessWidget {
  final String label;
  final String value;
  const _SpecRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E2E2)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              color: Color(0xFF4C4546),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              color: Color(0xFF4C4546),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturesList extends StatelessWidget {
  final List<String> features;
  const _FeaturesList({required this.features});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'FEATURES',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.7,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        ...features.map(
          (f) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 18,
                  color: Colors.black,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    f,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      color: Color(0xFF4C4546),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}