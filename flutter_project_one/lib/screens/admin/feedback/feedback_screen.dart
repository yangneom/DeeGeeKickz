import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/feedback_model.dart';
import '../../../providers/customer/review_providers.dart';
import '../../../widgets/common/buttons/search_bar.dart';
import '../../../widgets/common/buttons/filter_button.dart';
import '../../../widgets/common/buttons/filter_panel.dart';
import '../../../widgets/admin/feedback/feedback_details_dialog.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() =>
      _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final TextEditingController _searchController =
      TextEditingController();
  bool _showFilterPanel = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredAsync = ref.watch(filteredFeedbackProvider);
    final filterState = ref.watch(feedbackFilterProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: GestureDetector(
        onTap: () {
          if (_showFilterPanel) {
            setState(() => _showFilterPanel = false);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Title ──
              const Text(
                'Feedback Management',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'View and manage customer feedback and reviews.',
                style: TextStyle(
                    fontSize: 13, color: Color(0xFF9CA3AF)),
              ),

              const SizedBox(height: 24),

              // ── Search + Filter ──
              Row(
                children: [
                  CommonSearchBar(
                    controller: _searchController,
                    hintText: 'Search feedback...',
                    onChanged: (value) => ref
                        .read(feedbackFilterProvider.notifier)
                        .setSearch(value),
                  ),
                  const SizedBox(width: 8),
                  FilterButton(
                    isOpen: _showFilterPanel,
                    onTap: () => setState(
                        () => _showFilterPanel = !_showFilterPanel),
                    selectedValue: filterState.selectedStatus,
                    onValueChanged: (value) => ref
                        .read(feedbackFilterProvider.notifier)
                        .setStatus(value),
                    onClear: () {
                      _searchController.clear();
                      ref
                          .read(feedbackFilterProvider.notifier)
                          .clear();
                      setState(() => _showFilterPanel = false);
                    },
                    onApply: () =>
                        setState(() => _showFilterPanel = false),
                    sections: [
                      FilterSection(
                        title: 'Status',
                        options: [
                          FilterOption(
                              label: 'Visible', value: 'Visible'),
                          FilterOption(
                              label: 'Flagged', value: 'Flagged'),
                          FilterOption(
                              label: 'Hidden', value: 'Hidden'),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Content ──
              Expanded(
                child: filteredAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF2563EB)),
                  ),
                  error: (e, _) => Center(
                    child: Text(
                      'Failed to load feedback: $e',
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280)),
                    ),
                  ),
                  data: (feedbackList) {
                    if (feedbackList.isEmpty) {
                      return const _EmptyState();
                    }
                    return ListView.separated(
                      itemCount: feedbackList.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = feedbackList[index];
                        return _FeedbackCard(
                          feedback: item,
                          onView: () => showDialog(
                            context: context,
                            builder: (_) => FeedbackDetailsDialog(
                              feedback: item.toAdminMap(),
                              onSave:
                                  (newStatus, adminReply) async {
                                await ref
                                    .read(
                                        feedbackModerationProvider
                                            .notifier)
                                    .saveReply(
                                      feedbackId: item.id,
                                      newStatus: newStatus,
                                      currentStatus: item.status,
                                      adminReply: adminReply,
                                    );
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Feedback Card ─────────────────────────────────────────────────

class _FeedbackCard extends StatelessWidget {
  final FeedbackModel feedback;
  final VoidCallback onView;

  const _FeedbackCard({
    required this.feedback,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Top row: avatar + name + date + status ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFE5E7EB),
                child: Text(
                  feedback.customerName.isNotEmpty
                      ? feedback.customerName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feedback.customerName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      feedback.datePosted,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: feedback.status),
            ],
          ),

          const SizedBox(height: 12),

          // ── Product name ──
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined,
                  size: 14, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  feedback.productName,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Star rating — rating is double, round it ──
          _StarRating(rating: feedback.rating.round()),

          const SizedBox(height: 10),

          // ── Comment preview ──
          Text(
            feedback.comment,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF374151),
              height: 1.5,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),

          // ── Admin reply preview ──
          // ── Latest reply preview (full thread lives in the dialog) ──
          if (feedback.replies.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.reply,
                      size: 14, color: Color(0xFF0284C7)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          feedback.replies.last.isStaff
                              ? (feedback.replies.length > 1
                                  ? 'Store Reply (${feedback.replies.length})'
                                  : 'Store Reply')
                              : (feedback.replies.length > 1
                                  ? '${feedback.replies.last.authorName} Replied (${feedback.replies.length})'
                                  : '${feedback.replies.last.authorName} Replied'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0284C7),
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          feedback.replies.last.replyText,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF374151),
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // ── Bottom: action button ──
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: onView,
                icon: const Icon(Icons.edit_outlined,
                    size: 14),
                label: const Text('Manage'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF374151),
                  side: const BorderSide(
                      color: Color(0xFFD1D5DB)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg, text, border;

    switch (status) {
      case 'Flagged':
        bg = const Color(0xFFFEE2E2);
        text = const Color(0xFFDC2626);
        border = const Color(0xFFFCA5A5);
        break;
      case 'Hidden':
        bg = const Color(0xFFF3F4F6);
        text = const Color(0xFF6B7280);
        border = const Color(0xFFD1D5DB);
        break;
      default:
        bg = const Color(0xFFEFF6FF);
        text = const Color(0xFF2563EB);
        border = const Color(0xFFBFDBFE);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: text,
        ),
      ),
    );
  }
}

// ── Star rating ───────────────────────────────────────────────────

class _StarRating extends StatelessWidget {
  final int rating;
  const _StarRating({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < rating
              ? Icons.star_rounded
              : Icons.star_outline_rounded,
          size: 16,
          color: i < rating
              ? const Color(0xFFF59E0B)
              : const Color(0xFFD1D5DB),
        );
      }),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 32,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No feedback yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Customer reviews will appear here once submitted.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF9CA3AF),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}