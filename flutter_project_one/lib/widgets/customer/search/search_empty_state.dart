import 'package:flutter/material.dart';

/// Shown when search returns no results.
class SearchEmptyState extends StatelessWidget {
  final String query;

  const SearchEmptyState({super.key, required this.query});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          const Icon(
            Icons.search_off_outlined,
            size: 56,
            color: Color(0xFFCFC4C5),
          ),
          const SizedBox(height: 16),
          Text(
            'No results for "$query"',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Archivo Narrow',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try a different name, brand, or category.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: Color(0xFF656464),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when search field is empty — trending / recent suggestions.
class SearchIdleState extends StatelessWidget {
  const SearchIdleState({super.key});

  static const List<String> _suggestions = [
    'Nike Running',
    'Jordan Basketball',
    'Adidas Ultraboost',
    'New Releases',
    'Sale',
    'Sneakers',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'POPULAR SEARCHES',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: Color(0xFF656464),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _suggestions
              .map(
                (s) => _SuggestionChip(label: s),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  const _SuggestionChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Chips are decorative in mock — wire to search controller if needed
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFCFC4C5)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}