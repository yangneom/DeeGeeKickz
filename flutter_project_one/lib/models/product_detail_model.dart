/// Extended detail model for the Product Detail Screen.
/// Kept separate from ProductModel so the shop card stays lightweight.
/// MOCK / FAKE DATA ONLY — no Supabase integration yet.

class ProductDetailModel {
  final String id;
  final String name;
  final String series;
  final String brand;
  final String category;
  final double price;
  final double rating;
  final int reviewCount;
  final List<String> imageUrls;
  final List<ProductSize> sizes;
  final ProductSpecs specs;
  final List<String> features;
  final String description;
  final List<ProductReview> reviews;
  final String? badge;

  const ProductDetailModel({
    required this.id,
    required this.name,
    required this.series,
    required this.brand,
    required this.category,
    required this.price,
    required this.rating,
    required this.reviewCount,
    required this.imageUrls,
    required this.sizes,
    required this.specs,
    required this.features,
    required this.description,
    required this.reviews,
    this.badge,
  });

  String get formattedPrice => '\$${price.toStringAsFixed(2)}';
}

class ProductSize {
  final String label;
  final bool available;
  const ProductSize({required this.label, this.available = true});
}

class ProductSpecs {
  final String weight;
  final String drop;
  final String terrain;
  const ProductSpecs({
    required this.weight,
    required this.drop,
    required this.terrain,
  });
}

class ProductReview {
  final String reviewer;
  final double rating;
  final String date;
  final String title;
  final String body;
  final String? photoUrl;
  const ProductReview({
    required this.reviewer,
    required this.rating,
    required this.date,
    required this.title,
    required this.body,
    this.photoUrl,
  });
}

// ─────────────────────────────────────────────
// MOCK DETAIL DATA
// ─────────────────────────────────────────────

final ProductDetailModel mockVortexApexV1 = ProductDetailModel(
  id: 'detail_001',
  name: 'Vortex Apex V1',
  series: 'Elite Performance Series',
  brand: 'Adidas',
  category: 'Running Shoes',
  price: 240.00,
  rating: 4.8,
  reviewCount: 245,
  badge: 'New Release',
  imageUrls: [
    'https://lh3.googleusercontent.com/aida-public/AB6AXuAYyCMQfLI6XzDH3YZ5YeqgfqQ2K_eY5md6c6J4GhexpDWaE89CPLXcdExd4xuXqx4EjADDHd_mYC6g_jTnGcz_rOybfk9vV4NHrT82Na_bInQCjz19HaF1kXcXnWNUqgmLguLuXFVkysOMIkl1UT4oLqgWgCtc81kHmMXlvyBRtxZiJ4kj5bjhgUy3uoTGuH8hbzcxKkwbvQXKqhUCkShZmobbr6yLNpbWI3s6Vfb7LYeldCGGd5LiCf2I6tGm6UXi8_rHtMxtUW0',
    'https://lh3.googleusercontent.com/aida-public/AB6AXuDSSqwrd6PzsYM9N26FSnyV_c9D9e-6wkpbGK46w-NlnkMZW4eCcrh7vOqjVk6-Xn_NtpAZLr3wFvxgRcBaZGAx3L6e8ZcKzx-GZGTafBBIDQsVVczai3N8vuflntPXlmzAUt68LQEJ9B74UPC4qsCe8jCNPokdL5Fl5pS9i11jdeql2gIRgn8ocelx5Ggm676nwtelHWvjhpMoH2vo9rKGdup7iVOm_amKIrrrufdc0JtOs5LYkHs4XrM0wmil9K2fmRaKRnE6AM4',
    'https://lh3.googleusercontent.com/aida-public/AB6AXuDj62OR6OaEo7uZUyZVi4SUb1d9w5iGkf-reeYsq0XObLeNc9IWYdiNse8hZxq_v15L_4q4x_zSAQWnpL_UPn7pYssZT_KCP0_wxMJjOvL3o9zMNSMZOTH15QHbBP-z3eOwyzERIcLC3G19FcsQEkk_430Mc6SRvu93PIhZ10bOrs1s7dv8GeA9_soYtfp4F23Vtzeq9H7XpatwPqWH4fl5FMWhBxosF1OVXwCjjiRTWMXySu3J3HK3nofwm8iN14MzPZimyK6AMMY',
    'https://lh3.googleusercontent.com/aida-public/AB6AXuBzsoBSCRqLaummIwVcGePbUM4OQ0QJ4iYixVuCd2D4_nW8NXm-_d69pCa31Gi8fLBX9EXxi4R8FO8m9klFsmkMaQaF2Hwre94tdDA1KH6w0Bxw3yK4DHhIwKmcxGsupPUsmSCR1tQkJVDerlN2ZmXdknldBei2p_fT0cbJdtdQIbsyXGhtALtNrQ4VDtgh-A2-W98qz2y-8fvxkxQP-TyGZL19zlMkNr6KN1yaWnSAxHsgbVCGeQHPSXbky7zkgd6aN-fmKtqfBEM',
  ],
  sizes: const [
    ProductSize(label: '7'),
    ProductSize(label: '8'),
    ProductSize(label: '9'),
    ProductSize(label: '10'),
    ProductSize(label: '11'),
    ProductSize(label: '12'),
    ProductSize(label: '13'),
    ProductSize(label: '14', available: false),
  ],
  specs: const ProductSpecs(
    weight: '210g (Size 9)',
    drop: '8mm',
    terrain: 'Track / Road',
  ),
  features: const [
    'Responsive Carbon Plate',
    'Engineered Fly-Mesh Upper',
    'High-Abrasion Traction Outsole',
  ],
  description:
      "The Vortex Apex V1 isn't just a shoe; it's a testament to precision engineering. "
      "Designed for the athlete who demands ultimate stability and energy return, it features "
      "our proprietary Carbon-Shield™ propulsion plate embedded within dual-density Phylon "
      "cushioning. The upper is constructed from a single thread of high-tenacity polyester, "
      "providing a seamless, glove-like fit that adapts to your foot's movement.",
  reviews: const [
    ProductReview(
      reviewer: 'Marcus T.',
      rating: 5,
      date: 'Oct 12, 2024',
      title: 'Incredible Energy Return',
      body:
          'Been running in these for two weeks now. The carbon plate really makes a difference '
          'during speed sessions. The fit is snug but breathable. Definitely worth the '
          'investment for serious runners.',
      photoUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuBzsoBSCRqLaummIwVcGePbUM4OQ0QJ4iYixVuCd2D4_nW8NXm-_d69pCa31Gi8fLBX9EXxi4R8FO8m9klFsmkMaQaF2Hwre94tdDA1KH6w0Bxw3yK4DHhIwKmcxGsupPUsmSCR1tQkJVDerlN2ZmXdknldBei2p_fT0cbJdtdQIbsyXGhtALtNrQ4VDtgh-A2-W98qz2y-8fvxkxQP-TyGZL19zlMkNr6KN1yaWnSAxHsgbVCGeQHPSXbky7zkgd6aN-fmKtqfBEM',
    ),
    ProductReview(
      reviewer: 'Sarah L.',
      rating: 4,
      date: 'Oct 08, 2024',
      title: 'Perfect for Road Racing',
      body:
          'Super lightweight and stable. I knocked 2 minutes off my 10k PR. The heel lockdown '
          'is the best I\'ve experienced in a while. Runs slightly small, might want to size '
          'up a half size.',
    ),
    ProductReview(
      reviewer: 'James R.',
      rating: 5,
      date: 'Sep 30, 2024',
      title: 'Best Running Shoe I\'ve Owned',
      body:
          'I\'ve tried a lot of performance shoes and these are by far the most responsive. '
          'The carbon plate is noticeable from the first stride. Will be buying another pair.',
    ),
    ProductReview(
      reviewer: 'Diana M.',
      rating: 4,
      date: 'Sep 22, 2024',
      title: 'Great but Runs Narrow',
      body:
          'Love the look and the feel on the road. If you have wide feet, size up. Otherwise '
          'the energy return is phenomenal and the upper breathes really well.',
    ),
  ],
);

// Additional mock detail products (for navigation from shop cards)
final ProductDetailModel mockAeroBlastV2 = ProductDetailModel(
  id: 'detail_002',
  name: 'Aero-Blast V2',
  series: 'Nike Performance Series',
  brand: 'Nike',
  category: 'Running Shoes',
  price: 180.00,
  rating: 4.8,
  reviewCount: 312,
  badge: 'New Release',
  imageUrls: [
    'https://lh3.googleusercontent.com/aida-public/AB6AXuA5hhQQkf98ZPGRevCpxk2RmqHKB2yK9gGICDG6wXeDP7OZ73pRwAXIRCkoSlodQEyqY72QzRAmor9vhcDcxnYZh3CUhKLna2epjbIiyXxOUDJ9qbRz3MYWP9ajDZqg0yIDYpcnigfvfx9cI21ZRXrnc2Qvi2gXD7rtc7rX_KCUu6SuyXf5uzc7RAFNyByOx7FTfEqP-ZH0rFICvTxPeWyC9WuNroyJa68N3mByqnSK7i-V1egekoQbbeSGyV7stL3IrcH6aDeSahY',
    'https://lh3.googleusercontent.com/aida-public/AB6AXuDSSqwrd6PzsYM9N26FSnyV_c9D9e-6wkpbGK46w-NlnkMZW4eCcrh7vOqjVk6-Xn_NtpAZLr3wFvxgRcBaZGAx3L6e8ZcKzx-GZGTafBBIDQsVVczai3N8vuflntPXlmzAUt68LQEJ9B74UPC4qsCe8jCNPokdL5Fl5pS9i11jdeql2gIRgn8ocelx5Ggm676nwtelHWvjhpMoH2vo9rKGdup7iVOm_amKIrrrufdc0JtOs5LYkHs4XrM0wmil9K2fmRaKRnE6AM4',
    'https://lh3.googleusercontent.com/aida-public/AB6AXuDj62OR6OaEo7uZUyZVi4SUb1d9w5iGkf-reeYsq0XObLeNc9IWYdiNse8hZxq_v15L_4q4x_zSAQWnpL_UPn7pYssZT_KCP0_wxMJjOvL3o9zMNSMZOTH15QHbBP-z3eOwyzERIcLC3G19FcsQEkk_430Mc6SRvu93PIhZ10bOrs1s7dv8GeA9_soYtfp4F23Vtzeq9H7XpatwPqWH4fl5FMWhBxosF1OVXwCjjiRTWMXySu3J3HK3nofwm8iN14MzPZimyK6AMMY',
  ],
  sizes: const [
    ProductSize(label: '7'),
    ProductSize(label: '8'),
    ProductSize(label: '9'),
    ProductSize(label: '10'),
    ProductSize(label: '11'),
    ProductSize(label: '12'),
    ProductSize(label: '13', available: false),
  ],
  specs: const ProductSpecs(
    weight: '198g (Size 9)',
    drop: '6mm',
    terrain: 'Road',
  ),
  features: const [
    'ZoomX Foam Midsole',
    'Flyknit Upper Construction',
    'Waffle Traction Outsole',
  ],
  description:
      'The Aero-Blast V2 is Nike\'s answer to elite road performance. Built for speed and '
      'daily training alike, it features a full-length ZoomX foam midsole for maximum energy '
      'return with every stride. The Flyknit upper wraps your foot in a seamless, sock-like '
      'fit that moves with you mile after mile.',
  reviews: const [
    ProductReview(
      reviewer: 'Kevin D.',
      rating: 5,
      date: 'Nov 01, 2024',
      title: 'Fast and Comfortable',
      body:
          'These are my go-to for tempo runs. The ZoomX foam is incredibly responsive and the '
          'Flyknit upper keeps my feet cool. Best Nike running shoe in years.',
    ),
    ProductReview(
      reviewer: 'Priya S.',
      rating: 4,
      date: 'Oct 20, 2024',
      title: 'Great Daily Trainer',
      body:
          'Comfortable enough for easy days and fast enough for workouts. Only minor complaint '
          'is the upper could be a bit more durable for high-mileage training.',
    ),
  ],
);

/// Map for quick lookup by product ID from shop screen
final Map<String, ProductDetailModel> mockProductDetails = {
  'detail_001': mockVortexApexV1,
  'detail_002': mockAeroBlastV2,
  'shop_001': mockAeroBlastV2,
  'shop_007': mockVortexApexV1,
  'shop_009': mockVortexApexV1,
  'trend_001': mockVortexApexV1,
};