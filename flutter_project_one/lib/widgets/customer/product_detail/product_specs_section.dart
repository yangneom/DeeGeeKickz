import 'package:flutter/material.dart';
import '../../../models/product.dart';

class ProductSpecsSection extends StatelessWidget {
  final Product product;

  const ProductSpecsSection({super.key, required this.product});

  static const double _mdBreakpoint = 768;

  @override
  Widget build(BuildContext context) {
    // Nothing to show if description is empty
    if (product.description.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= _mdBreakpoint;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 48),
          decoration: const BoxDecoration(
            border: Border(
                top: BorderSide(color: Color(0xFFCFC4C5))),
          ),
          child: isDesktop
              ? _DesktopLayout(product: product)
              : _MobileLayout(product: product),
        );
      },
    );
  }
}

class _DesktopLayout extends StatelessWidget {
  final Product product;
  const _DesktopLayout({required this.product});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          width: 240,
          child: Text(
            'PRODUCT\nDESCRIPTION',
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
        Expanded(
          child: Text(
            product.description,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              height: 1.6,
              color: Color(0xFF4C4546),
            ),
          ),
        ),
      ],
    );
  }
}

class _MobileLayout extends StatelessWidget {
  final Product product;
  const _MobileLayout({required this.product});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PRODUCT DESCRIPTION',
          style: TextStyle(
            fontFamily: 'Archivo Narrow',
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          product.description,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            height: 1.6,
            color: Color(0xFF4C4546),
          ),
        ),
      ],
    );
  }
}