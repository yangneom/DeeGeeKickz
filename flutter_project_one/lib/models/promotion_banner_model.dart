// ================================================
// PROMOTION BANNER MODEL
//
// Maps to the `promotion_banner` table:
//   banner_id, banner_image_url, status, upload_date, created_at
// ================================================
class PromotionBanner {
  final int bannerId;
  final String imageUrl;
  final String status;
  final DateTime uploadDate;

  PromotionBanner({
    required this.bannerId,
    required this.imageUrl,
    required this.status,
    required this.uploadDate,
  });

  // ================================================
  // FROM MAP
  // Builds a PromotionBanner from a Supabase row
  // ================================================
  factory PromotionBanner.fromMap(Map<String, dynamic> map) {
    return PromotionBanner(
      bannerId: map['banner_id'] as int,
      imageUrl: map['banner_image_url'] as String,
      status: map['status'] as String,
      uploadDate: DateTime.parse(map['upload_date'] as String),
    );
  }

  // ================================================
  // TO MAP
  // Converts back into a Supabase-insertable map
  // ================================================
  Map<String, dynamic> toMap() {
    return {
      'banner_id': bannerId,
      'banner_image_url': imageUrl,
      'status': status,
      'upload_date': uploadDate.toIso8601String(),
    };
  }
}