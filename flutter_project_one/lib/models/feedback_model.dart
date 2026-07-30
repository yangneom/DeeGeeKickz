// ================================================
// FEEDBACK MODEL
// Admin-facing moderation wrapper around ReviewModel.
//
// In DeeGeeKickz the `feedback` table IS the review table.
// FeedbackModel is a thin view on the same row, adding
// admin-specific helpers (badge colours, label text, etc.)
// so the Admin UI does not need to import ReviewModel directly.
//
// BUG FIX this round:
//   toAdminMap() never included imageUrls — so even after
//   review_model.dart was fixed to parse image_urls back from
//   Supabase, that data was dropped right here before it ever
//   reached the admin dialog. Photos/videos were correctly stored
//   and correctly parsed onto ReviewModel, but the admin-facing
//   map simply never carried them forward.
// ================================================

import 'review_model.dart';

export 'review_model.dart' show FeedbackReply;

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
  List<FeedbackReply> get replies => review.replies;
  // BUG FIX: was missing entirely — this is what toAdminMap() needed
  // to actually carry photo/video URLs through to the admin UI.
  List<String> get imageUrls => review.imageUrls;

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
      'replies':         replies,
      // BUG FIX: this key was missing — feedback_details_dialog.dart
      // now reads it to render the photo/video gallery.
      'imageUrls':       imageUrls,
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