// ================================================
// recent_feedback_card.dart  (UPDATED)
//
// Changes from fake-data version:
//  1. Reads recentFeedbackProvider (Supabase)
//     instead of accepting a List<FeedbackItem> param
//  2. FeedbackItem class REMOVED (replaced by FeedbackModel)
//  3. UI/layout/styling: UNCHANGED
// ================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/customer/review_providers.dart';
import '../../../models/feedback_model.dart';

class RecentFeedbackCard extends ConsumerWidget {
  final VoidCallback onViewAll;

  const RecentFeedbackCard({
    super.key,
    required this.onViewAll,
  });

  // ── Stars — UNCHANGED ──────────────────────────────────────
  Widget _buildStarRating(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (int index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          size: 12,
          color: index < rating
              ? const Color(0xFFF59E0B)
              : const Color(0xFFD1D5DB),
        );
      }),
    );
  }

  // ── Badge — UNCHANGED ──────────────────────────────────────
  Widget _buildStatusBadge(String status) {
    Color backgroundColor = Colors.grey.shade100;
    Color textColor       = Colors.grey;

    if (status == 'Flagged') {
      backgroundColor = const Color(0xFFFEE2E2);
      textColor       = const Color(0xFFDC2626);
    }
    if (status == 'Visible') {
      backgroundColor = const Color(0xFFDCFCE7);
      textColor       = const Color(0xFF16A34A);
    }
    if (status == 'Hidden') {
      backgroundColor = const Color(0xFFF3F4F6);
      textColor       = const Color(0xFF6B7280);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  // ── Table header — UNCHANGED ───────────────────────────────
  Widget _buildTableHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('Customer Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)))),
          Expanded(flex: 2, child: Text('Product',       style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)))),
          Expanded(flex: 2, child: Text('Rating',        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)))),
          Expanded(flex: 1, child: Text('Status',        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)))),
          Expanded(flex: 1, child: Text('Date',          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)))),
        ],
      ),
    );
  }

  // ── One row from FeedbackModel ─────────────────────────────
  Widget _buildFeedbackRow(FeedbackModel item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(item.customerName, style: const TextStyle(fontSize: 12, color: Color(0xFF111827)))),
          Expanded(flex: 2, child: Text(item.productName,  style: const TextStyle(fontSize: 12, color: Color(0xFF111827)), overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: _buildStarRating(item.rating.round())),
          Expanded(flex: 1, child: _buildStatusBadge(item.status)),
          Expanded(flex: 1, child: Text(item.datePosted, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentFeedbackProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── HEADER ROW — UNCHANGED ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline,
                      size: 16,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Recent Feedback',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
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
                    Icon(Icons.arrow_forward, size: 12, color: Color(0xFF2563EB)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Divider(color: Colors.grey.shade200, height: 1),
          const SizedBox(height: 8),
          _buildTableHeader(),
          Divider(color: Colors.grey.shade200, height: 1),

          // ── ROWS — from Supabase ──
          recentAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Could not load feedback.',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No feedback yet.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                );
              }

              return Column(
                children: [
                  for (int i = 0; i < items.length; i++)
                    Column(
                      children: [
                        _buildFeedbackRow(items[i]),
                        if (i < items.length - 1)
                          Divider(color: Colors.grey.shade100, height: 1),
                      ],
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}