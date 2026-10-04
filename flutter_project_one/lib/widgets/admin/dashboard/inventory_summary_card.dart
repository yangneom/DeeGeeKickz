import 'package:flutter/material.dart';

// ================================================
// INVENTORY SUMMARY CARD
//
// Shows a summary of inventory status, with a simple
// Inventory Health bar built from the same counts.
//
// ┌─────────────────────────────┐
// │ Inventory Summary  View all→│
// │                             │
// │ Inventory Health   97% in stock
// │ [███████████████░░░]        │
// │                             │
// │ ● Total Products      120   │
// │ ● In Stock             97   │
// │ ● Low Stock            12   │
// │ ● Out of Stock          3   │
// │                             │
// │ [ restock note ]            │
// └─────────────────────────────┘
//
// NOTE: this card is placed in a Row with
// CrossAxisAlignment.stretch (see AdminDashboardScreen), so it
// always has a bounded height — the Spacer pushes the note to the
// bottom instead of leaving a dead gap.
// ================================================
class InventorySummaryCard extends StatelessWidget {

  // the counts to show
  final int totalProducts;
  final int inStock;
  final int lowStock;
  final int outOfStock;

  // what happens when user clicks view all
  final VoidCallback onViewAll;

  const InventorySummaryCard({
    super.key,
    required this.totalProducts,
    required this.inStock,
    required this.lowStock,
    required this.outOfStock,
    required this.onViewAll,
  });

  static const Color _green = Color(0xFF16A34A);
  static const Color _amber = Color(0xFFF59E0B);
  static const Color _red = Color(0xFFEF4444);

  // ================================================
  // BUILD ONE SUMMARY ROW
  // example: • Total Products    120
  // ================================================
  Widget _buildSummaryRow(
    String label,
    int count,
    Color dotColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [

          // colored dot on the left
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),

          const SizedBox(width: 10),

          // label text
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF374151),
              ),
            ),
          ),

          // count number on the right
          Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  // ================================================
  // INVENTORY HEALTH
  // A single proportional bar: in stock / low / out.
  // Uses only the counts this card already receives —
  // no new calculation of what counts as low/out of stock.
  // ================================================
  Widget _buildHealth() {
    final int segmentTotal = inStock + lowStock + outOfStock;
    final int healthyPercent = segmentTotal == 0
        ? 0
        : ((inStock / segmentTotal) * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Inventory Health · $totalProducts products',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151),
              ),
            ),
            const Spacer(),
            Text(
              segmentTotal == 0 ? '—' : '$healthyPercent% in stock',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: segmentTotal == 0
                ? Container(color: const Color(0xFFE5E7EB))
                : Row(
                    children: [
                      if (inStock > 0)
                        Expanded(
                          flex: inStock,
                          child: Container(color: _green),
                        ),
                      if (lowStock > 0)
                        Expanded(
                          flex: lowStock,
                          child: Container(color: _amber),
                        ),
                      if (outOfStock > 0)
                        Expanded(
                          flex: outOfStock,
                          child: Container(color: _red),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  // ================================================
  // NOTE AT THE BOTTOM
  // Only asks for a restock when there is something to restock.
  // ================================================
  Widget _buildNote() {
    final bool needsAttention = lowStock > 0 || outOfStock > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: needsAttention
            ? const Color(0xFFFFFBEB)
            : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            needsAttention
                ? Icons.warning_amber_outlined
                : Icons.check_circle_outline,
            size: 14,
            color: needsAttention
                ? const Color(0xFFB45309)
                : const Color(0xFF15803D),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              needsAttention
                  ? 'Please restock items that are low or out of stock.'
                  : 'All products are well stocked.',
              style: TextStyle(
                fontSize: 11,
                color: needsAttention
                    ? const Color(0xFF92400E)
                    : const Color(0xFF166534),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── HEADER ROW ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [

              // title with icon
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      size: 16,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Inventory Summary',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),

              // view all link
              GestureDetector(
                onTap: onViewAll,
                child: Row(
                  children: const [
                    Text(
                      'View all',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward,
                      size: 12,
                      color: Color(0xFF2563EB),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── INVENTORY HEALTH BAR ──
          _buildHealth(),

          const SizedBox(height: 16),

          // ── SUMMARY ROWS ──
          // (Total Products now lives in the health line above. The three
          // rows below always add up to it.)
          _buildSummaryRow(
            'In Stock',
            inStock,
            _green,
          ),

          _buildSummaryRow(
            'Low Stock',
            lowStock,
            _amber,
          ),

          _buildSummaryRow(
            'Out of Stock',
            outOfStock,
            _red,
          ),

          // pushes the note to the bottom of the card
          const Spacer(),

          const SizedBox(height: 12),

          // ── NOTE ──
          _buildNote(),
        ],
      ),
    );
  }
}