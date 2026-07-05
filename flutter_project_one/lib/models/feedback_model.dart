// ================================================
// FEEDBACK MODEL
// Admin-facing moderation wrapper around ReviewModel.
//
// In DeeGeeKickz the `feedback` table IS the review table.
// FeedbackModel is a thin view on the same row, adding
// admin-specific helpers (badge colours, label text, etc.)
// so the Admin UI does not need to import ReviewModel directly.
// ================================================

import 'review_model.dart';

class FeedbackModel {
  final ReviewModel review; // the underlying review data

  const FeedbackModel({required this.review});

  // ── Convenience pass-throughs ─────────────────────────────────
  int    get id           => review.id;
  String get customerName => review.customerName;
  String get productName  => review.productName;
  double get rating       => review.rating;
  String get comment      => review.reviewText;
  String get status       => review.status;
  String get datePosted   =>
      '${review.createdAt.month.toString().padLeft(2, '0')}/'
      '${review.createdAt.day.toString().padLeft(2, '0')}/'
      '${review.createdAt.year.toString().substring(2)}';
  String? get adminReply  => review.adminReply;

  // ── Factory: build from Supabase row ─────────────────────────
  factory FeedbackModel.fromSupabase(Map<String, dynamic> row) {
    return FeedbackModel(review: ReviewModel.fromSupabase(row));
  }

  // ── Convert to the plain Map the existing Admin UI widgets
  //    already expect (drops-in without changing widget code) ───
  Map<String, dynamic> toAdminMap() {
    return {
      'customerName':    customerName,
      'productReviewed': productName,
      'comment':         comment,
      'rating':          rating.round(),
      'datePosted':      datePosted,
      'status':          status,
      'adminReply':      adminReply ?? '',
      // keep original model accessible for service calls
      '_feedbackId':     id,
    };
  }

  // ── Copy with ─────────────────────────────────────────────────
  FeedbackModel copyWith({String? status, String? adminReply}) {
    return FeedbackModel(
      review: review.copyWith(
        status:     status,
        adminReply: adminReply,
        updatedAt:  DateTime.now(),
      ),
    );
  }
}