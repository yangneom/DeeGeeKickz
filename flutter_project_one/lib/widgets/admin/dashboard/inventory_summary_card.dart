import 'package:flutter/material.dart';

// ================================================
// INVENTORY SUMMARY CARD
//
// Shows a summary of inventory status
//
// ┌─────────────────────────┐
// │ Inventory Summary View all→│
// │                         │
// │ Total Products      120  │
// │ In Stock             97  │
// │ Low Stock            12  │
// │ Out of Stock          3  │
// │                         │
// │ Please restock...       │
// └─────────────────────────┘
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

          const SizedBox(height: 16),

          // ── SUMMARY ROWS ──
          _buildSummaryRow(
            'Total Products',
            totalProducts,
            const Color(0xFF6B7280),
          ),

          _buildSummaryRow(
            'In Stock',
            inStock,
            const Color(0xFF16A34A),
          ),

          _buildSummaryRow(
            'Low Stock',
            lowStock,
            const Color(0xFFF59E0B),
          ),

          _buildSummaryRow(
            'Out of Stock',
            outOfStock,
            const Color(0xFFEF4444),
          ),

          const SizedBox(height: 16),

          // ── WARNING MESSAGE ──
          const Text(
            'Please restock items that are low or out of stock.',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}