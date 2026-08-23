// ================================================
// REVIEW MODEL
// Maps to the `feedback` table in Supabase.
//
// Current phase  : any logged-in customer can submit.
// Future phase   : only customers with a delivered
//                  order can submit (verified purchase).
//
// BUG FIX this round:
//   imageUrls previously hardcoded to `const []` with a "phase 2"
//   comment — but the `image_urls` column already exists in the
//   schema (it's selected in review_service.dart's _selectWithJoins)
//   and submitReview() already writes to it. This was purely a
//   read-side gap: uploaded photos/videos were being stored but
//   never read back into the model, so they never rendered.
// ================================================

class FeedbackReply {
  final int id;
  final String authorName;
  final String authorRole; // 'Admin' | 'Super Admin' | 'Customer'
  final String replyText;
  final DateTime createdAt;

  const FeedbackReply({
    required this.id,
    required this.authorName,
    required this.authorRole,
    required this.replyText,
    required this.createdAt,
  });

  bool get isStaff => authorRole == 'Admin' || authorRole == 'Super Admin';

  factory FeedbackReply.fromSupabase(Map<String, dynamic> row) {
    final userMap = row['user_public_profile'] as Map<String, dynamic>? ?? {};
    final String firstName = userMap['first_name'] as String? ?? '';
    final String lastName  = userMap['last_name']  as String? ?? '';
    final String role      = userMap['role'] as String? ?? 'Customer';
    final String fullName  = '$firstName $lastName'.trim().isEmpty
        ? (role == 'Admin' || role == 'Super Admin' ? 'Store' : 'Customer')
        : '$firstName $lastName'.trim();

    return FeedbackReply(
      id:         row['reply_id']  as int,
      authorName: fullName,
      authorRole: role,
      replyText:  row['reply_text'] as String? ?? '',
      createdAt:  DateTime.parse(row['created_at'] as String),
    );
  }
}

class ReviewModel {
  final int id;
  final String customerId;       // users.id (uuid)
  final String customerName;     // derived: first_name + last_name
  final int productId;           // feedback.product_id FK
  final String productName;      // snapshot joined from product table
  final double rating;           // 1-5  (stored as INT 1-5 in DB)
  final String reviewText;       // feedback.comment_message
  final List<String> imageUrls;  // feedback.image_urls — photo/video URLs
  final bool verifiedPurchase;   // always false until phase 2
  final String status;           // ENUM: 'Visible' | 'Flagged' | 'Hidden'
  final String? adminReply;      // feedback.admin_reply (legacy single-reply field, kept for backward compat)
  final List<FeedbackReply> replies; // full reply thread (feedback_replies table)
  final DateTime createdAt;
  final DateTime updatedAt;

  const ReviewModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.productId,
    required this.productName,
    required this.rating,
    required this.reviewText,
    this.imageUrls = const [],
    this.verifiedPurchase = false,
    required this.status,
    this.adminReply,
    this.replies = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  // ── Factory: build from Supabase row ──────────────────────────
  // Expected join:
  //   feedback row
  //     + users  (first_name, last_name)  via user_id FK
  //     + product (product_name)          via product_id FK
  //     + feedback_replies (reply thread) via feedback_id FK
  factory ReviewModel.fromSupabase(Map<String, dynamic> row) {
    // Join data comes in as nested maps
    final userMap = row['user_public_profile'] as Map<String, dynamic>? ?? {};
    final productMap = row['product'] as Map<String, dynamic>? ?? {};

    final String firstName = userMap['first_name'] as String? ?? '';
    final String lastName  = userMap['last_name']  as String? ?? '';
    final String fullName  =
        '$firstName $lastName'.trim().isEmpty ? 'Anonymous' : '$firstName $lastName'.trim();

    return ReviewModel(
      id:               row['feedback_id']     as int,
      customerId:       row['user_id']         as String,
      customerName:     fullName,
      productId:        row['product_id']      as int,
      productName:      productMap['product_name'] as String? ?? '',
      rating:           (row['rating']         as num).toDouble(),
      reviewText:       row['comment_message'] as String? ?? '',
      // BUG FIX: read image_urls back from the row instead of
      // hardcoding an empty list. The column already exists and
      // submitReview() already writes to it — this was the missing
      // read-side link.
      imageUrls:        (row['image_urls'] as List<dynamic>?)
                            ?.map((e) => e.toString())
                            .toList() ??
                          const [],
      verifiedPurchase: false,                 // phase 2
      status:           row['status']          as String? ?? 'Visible',
      adminReply:       row['admin_reply']     as String?,
      replies:          ((row['feedback_replies'] as List<dynamic>? ?? [])
          .map((r) => FeedbackReply.fromSupabase(r as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt))),
      createdAt:        DateTime.parse(row['created_at'] as String),
      updatedAt:        DateTime.parse(
                          (row['updated_at'] ?? row['created_at']) as String,
                        ),
    );
  }

  // ── Copy with ─────────────────────────────────────────────────
  // (replies are refreshed via refetch, not local mutation)
  ReviewModel copyWith({
    String? status,
    String? adminReply,
    DateTime? updatedAt,
  }) {
    return ReviewModel(
      id:               id,
      customerId:       customerId,
      customerName:     customerName,
      productId:        productId,
      productName:      productName,
      rating:           rating,
      reviewText:       reviewText,
      imageUrls:        imageUrls,
      verifiedPurchase: verifiedPurchase,
      status:           status         ?? this.status,
      adminReply:       adminReply     ?? this.adminReply,
      replies:          replies,
      createdAt:        createdAt,
      updatedAt:        updatedAt      ?? this.updatedAt,
    );
  }
}