/// Represents a single product (shoe) shown across the
/// DeeGeeKickz customer-facing website.
///
/// NOTE: Mock/fake data only — no Supabase / API integration yet.
class ProductModel {
  final String id;
  final String name;
  final String brand;
  final String category;
  final double price;
  final double? originalPrice;      // set when discounted
  final int? discountPercent;       // e.g. 20 means 20% off
  final String imageUrl;
  final double rating;
  final bool inStock;
  final String? badge;
  final String? releaseDate;

  const ProductModel({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.price,
    required this.imageUrl,
    this.originalPrice,
    this.discountPercent,
    this.rating = 4.5,
    this.inStock = true,
    this.badge,
    this.releaseDate,
  });

  bool get isDiscounted => discountPercent != null && discountPercent! > 0;

  String get formattedPrice => '\$${price.toStringAsFixed(0)}';
  String get formattedOriginalPrice =>
      originalPrice != null ? '\$${originalPrice!.toStringAsFixed(0)}' : '';

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      name: json['name'] as String,
      brand: json['brand'] as String,
      category: json['category'] as String,
      price: (json['price'] as num).toDouble(),
      originalPrice: (json['originalPrice'] as num?)?.toDouble(),
      discountPercent: json['discountPercent'] as int?,
      imageUrl: json['imageUrl'] as String,
      rating: (json['rating'] as num?)?.toDouble() ?? 4.5,
      inStock: json['inStock'] as bool? ?? true,
      badge: json['badge'] as String?,
      releaseDate: json['releaseDate'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'brand': brand,
        'category': category,
        'price': price,
        'originalPrice': originalPrice,
        'discountPercent': discountPercent,
        'imageUrl': imageUrl,
        'rating': rating,
        'inStock': inStock,
        'badge': badge,
        'releaseDate': releaseDate,
      };
}

// ─────────────────────────────────────────────
// FILTER CONSTANTS
// ─────────────────────────────────────────────

const List<String> kShopBrands = ['Nike', 'Jordan', 'Adidas'];

const List<String> kShopCategories = [
  'Basketball',
  'Sneakers',
  'Running Shoes',
  'Rubber Shoes',
];

const List<String> kShopSizes = [
  '6', '7', '8', '9', '10', '11', '12',
];

// ─────────────────────────────────────────────
// MOCK DATA — SHOP (9 products)
// ─────────────────────────────────────────────

const List<ProductModel> mockShopProducts = [
  // ── NIKE ──────────────────────────────────
  ProductModel(
    id: 'shop_001',
    name: 'Aero-Blast V2',
    brand: 'Nike',
    category: 'Running Shoes',
    price: 180,
    rating: 4.8,
    inStock: true,
    badge: 'New Release',
    imageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuA5hhQQkf98ZPGRevCpxk2RmqHKB2yK9gGICDG6wXeDP7OZ73pRwAXIRCkoSlodQEyqY72QzRAmor9vhcDcxnYZh3CUhKLna2epjbIiyXxOUDJ9qbRz3MYWP9ajDZqg0yIDYpcnigfvfx9cI21ZRXrnc2Qvi2gXD7rtc7rX_KCUu6SuyXf5uzc7RAFNyByOx7FTfEqP-ZH0rFICvTxPeWyC9WuNroyJa68N3mByqnSK7i-V1egekoQbbeSGyV7stL3IrcH6aDeSahY',
  ),
  ProductModel(
    id: 'shop_002',
    name: 'Urban Drift X',
    brand: 'Nike',
    category: 'Sneakers',
    price: 140,
    rating: 4.5,
    inStock: false,
    badge: 'Sold Out',
    imageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuCxoljnkSZCgb8gyooJu8wCpO7SnzcyfKiLDXI_rU5ijCkFpKZLCTzfpIzTv18UJztRhDEDlcCDTeG0mPxICAjfdYBmuFovrW4daVPgVtdPOFNn8MSQ-eJI3OOaeJeBYa4za35M_9O5xEOdWRMEB5d-dd-K4Y57ksgw8BHM1loDKXRDFytdKoa87TtMJfz9HoPr3eQD2smZlerqZru9nev4F-0EATH12gXNRGfkCRs1598idJ4H6m-f2zGj7-lWBeoJ1Q2hGXitdBw',
  ),
  ProductModel(
    id: 'shop_003',
    name: 'Core Trainer Pro',
    brand: 'Nike',
    category: 'Rubber Shoes',
    price: 130,
    rating: 4.6,
    inStock: true,
    imageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuBOvXdlmmTOP7GElQLdzV1e7uDJv1_MFu9MHzypGWov2ebrGcKHZZxTcR8nWpjoBjLMEo93ZKuSOOJfdnp_YwYaHQCIITaupGg8bVF8hp20h1zJ-juDp-tZwuA-l_TP1kC7Vij8wiE9FAgEYubJCN5JoDDCAXhyr23E78ZaS7KS39j6MHATZm6A5PVCiRrw6c3iFQksEVvieOgB7bnxYEwJmd1MNojxSo1hHez_us-KlZ1hm3V8dEcTpp7-8wPwBYxLjdCzxyQfr9w',
  ),

  // ── JORDAN ────────────────────────────────
  ProductModel(
    id: 'shop_004',
    name: 'Legacy High-Top',
    brand: 'Jordan',
    category: 'Basketball',
    price: 195,
    rating: 4.7,
    inStock: true,
    imageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuBElbiQmvNg1JU4yGhMeJtMzbhFmpGDaAuJ_lnPcE88RwMgXWGxk0PZDOble88-_-yj1QaEa0BB4XVVyaVoqsUeDB9Pq2JppVB8sL0uSSzULwcIfvcKW7ig18Jm3oL8f7180rjZ2PmPnsH9Jlq4sN7Oev__wATsROkBmvnZ-awicaDUdBV_Mmegmc2M1sfYFlAAK2CRRcOqi9r7MoubAt4n_k0f0kN1QyAGfj4n2b9gyoJLIFbk2zYsZurlNriQgiksnGrohhjmGuE',
  ),
  ProductModel(
    id: 'shop_005',
    name: 'Titan Flow Low',
    brand: 'Jordan',
    category: 'Sneakers',
    price: 165,
    rating: 4.9,
    inStock: true,
    imageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuAHaCH267TS1AdbGxLpw8usA6pCdQIXAxXYeTJUIE3_03txmOPn5w_zpUhlDBIyyh4-ILkE0yperMxtb5uCdjmZ5FIIQ3MyoiiYjOQOgS_k8r3aDEdnQH2yPAOPs9pb2DpcJOUGUDxSZwmmojnT68gHxvhpwmKzbCc82KqE0q4i6eok6tXvE_Dmvhx1sdW7E-Zd6qgbH8Y4XkZKEmPyDv6laX7sXgotl5E45yO_0Lb--XVOnD9l7qGm39IOw-LmbJvURwjok_OSrZ8',
  ),
  ProductModel(
    id: 'shop_006',
    name: 'Nova Future 01',
    brand: 'Jordan',
    category: 'Basketball',
    price: 350,
    rating: 4.9,
    inStock: true,
    badge: 'Member Exclusive',
    imageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuDPW2pO9n3x3E0NHiJ1bUHvNkXxirfQQHYVB7NuuwvzBTdeKB54o3PUcVyMEZFlLeI67aFOzwJsy8AN16EwREwFOAp9vigAnh0tMAG2YSNtuyvadD5_JSdzmr-Hp_Dw2FsXAvXDzSlea5fNawJhuUMBBzmly2fLJuBAbYtL2fKmOhJABPcsVxfplBydZXtVuSMCnW_W3LHgYMEuvVL4XJqI91Tjaw8drvHuKYR42_-F04XTU4imrhQNLv_ZBSgFUlcb9csRtMxWB6E',
  ),

  // ── ADIDAS ────────────────────────────────
  ProductModel(
    id: 'shop_007',
    name: 'Quantum Runner',
    brand: 'Adidas',
    category: 'Running Shoes',
    price: 210,
    rating: 5.0,
    inStock: true,
    imageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuB4MclUg90M4lNhMdNwkHJkXQ5Yt8bVajMh5zgE-C3a2CV3wgown0TsFELU2KW_LKIW6CNs4MInvV1ZcBQyTGBwcP8QQtsNftAQVzaMIyPmxg-orGHsqke_n093wcpsotvmwrcVz9qV_IFEgMUBt0G56O__zZlkqIyL_X_X-1uP7a8sJUNdpNpjxFitYBiNnLgs6Rqb37RX2Hrf1UxUKnya0x4Ngf-hL949qvJVdic9qwkCjDXQs_KNXtxbgg1ZAn7qOhSIx74W22w',
  ),
  ProductModel(
    id: 'shop_008',
    name: 'Ignite Hoops',
    brand: 'Adidas',
    category: 'Basketball',
    price: 225,
    rating: 4.8,
    inStock: true,
    imageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuCgjk0b38p6riMEtvxEc4J4pdI6z8BBgTzDRM5EHSC1UhxvzIxNbm6_RMOD3vXaBvmqm9nol5ATzw3jn0P42B61VEkZ5dq_1siSwyBgZsRPr3WlL085qbepPhi5QsOhQXQSZ13uZaLSfCVzZssuv9Jfk1APmqWQSjSf5pl_vnB9APF0CmRauExFE87wxbOrk4SOaT4788F9P5bw9umKd_tYJo65qCfE8ANUSToifDqlATOeWq1qKJVVWUATy0JRs7Lr_9Ap7tKLytxY',
  ),
  ProductModel(
    id: 'shop_009',
    name: 'UltraBoost Pro X1',
    brand: 'Adidas',
    category: 'Running Shoes',
    price: 220,
    rating: 4.8,
    inStock: true,
    imageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuCAINt4ITBjTnSFOCxeJmt_SCa8fuBnnyaN5u0WuNwWZg9I4asBFKDaJfEXmVzY1qklJw8yxEcMFZfraVPsNmV9e5JNlcawjjoWRgdyswaE79qpqC84u9FWq1qxQsROb393w48fY4lOAQijQfyTOQLPZB88UJHYLJIUup-TJh7RQBnCEeRJ2EgH7iejkVg3i6k66jgBANYNyXwxjXBFUIJgi-0bFlIMtOcF2EuMN3W9FL7W6o7QX4wNN1qyRHwdXkn-ImRhjFY_mZc',
  ),
];

// ─────────────────────────────────────────────
// MOCK DATA — PROMO (discounted products)
// ─────────────────────────────────────────────

const List<ProductModel> mockPromoProducts = [
  ProductModel(
    id: 'promo_001',
    name: 'Aero-Blast V2',
    brand: 'Nike',
    category: 'Running Shoes',
    price: 144,           // 20% off
    originalPrice: 180,
    discountPercent: 20,
    rating: 4.8,
    inStock: true,
    badge: 'Sale',
    imageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuA5hhQQkf98ZPGRevCpxk2RmqHKB2yK9gGICDG6wXeDP7OZ73pRwAXIRCkoSlodQEyqY72QzRAmor9vhcDcxnYZh3CUhKLna2epjbIiyXxOUDJ9qbRz3MYWP9ajDZqg0yIDYpcnigfvfx9cI21ZRXrnc2Qvi2gXD7rtc7rX_KCUu6SuyXf5uzc7RAFNyByOx7FTfEqP-ZH0rFICvTxPeWyC9WuNroyJa68N3mByqnSK7i-V1egekoQbbeSGyV7stL3IrcH6aDeSahY',
  ),
  ProductModel(
    id: 'promo_002',
    name: 'Core Trainer Pro',
    brand: 'Nike',
    category: 'Rubber Shoes',
    price: 91,            // 30% off
    originalPrice: 130,
    discountPercent: 30,
    rating: 4.6,
    inStock: true,
    badge: 'Sale',
    imageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuBOvXdlmmTOP7GElQLdzV1e7uDJv1_MFu9MHzypGWov2ebrGcKHZZxTcR8nWpjoBjLMEo93ZKuSOOJfdnp_YwYaHQCIITaupGg8bVF8hp20h1zJ-juDp-tZwuA-l_TP1kC7Vij8wiE9FAgEYubJCN5JoDDCAXhyr23E78ZaS7KS39j6MHATZm6A5PVCiRrw6c3iFQksEVvieOgB7bnxYEwJmd1MNojxSo1hHez_us-KlZ1hm3V8dEcTpp7-8wPwBYxLjdCzxyQfr9w',
  ),
  ProductModel(
    id: 'promo_003',
    name: 'Legacy High-Top',
    brand: 'Jordan',
    category: 'Basketball',
    price: 137,           // 30% off
    originalPrice: 195,
    discountPercent: 30,
    rating: 4.7,
    inStock: true,
    badge: 'Sale',
    imageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuBElbiQmvNg1JU4yGhMeJtMzbhFmpGDaAuJ_lnPcE88RwMgXWGxk0PZDOble88-_-yj1QaEa0BB4XVVyaVoqsUeDB9Pq2JppVB8sL0uSSzULwcIfvcKW7ig18Jm3oL8f7180rjZ2PmPnsH9Jlq4sN7Oev__wATsROkBmvnZ-awicaDUdBV_Mmegmc2M1sfYFlAAK2CRRcOqi9r7MoubAt4n_k0f0kN1QyAGfj4n2b9gyoJLIFbk2zYsZurlNriQgiksnGrohhjmGuE',
  ),
  ProductModel(
    id: 'promo_004',
    name: 'Titan Flow Low',
    brand: 'Jordan',
    category: 'Sneakers',
    price: 116,           // 30% off
    originalPrice: 165,
    discountPercent: 30,
    rating: 4.9,
    inStock: true,
    badge: 'Sale',
    imageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuAHaCH267TS1AdbGxLpw8usA6pCdQIXAxXYeTJUIE3_03txmOPn5w_zpUhlDBIyyh4-ILkE0yperMxtb5uCdjmZ5FIIQ3MyoiiYjOQOgS_k8r3aDEdnQH2yPAOPs9pb2DpcJOUGUDxSZwmmojnT68gHxvhpwmKzbCc82KqE0q4i6eok6tXvE_Dmvhx1sdW7E-Zd6qgbH8Y4XkZKEmPyDv6laX7sXgotl5E45yO_0Lb--XVOnD9l7qGm39IOw-LmbJvURwjok_OSrZ8',
  ),
  ProductModel(
    id: 'promo_005',
    name: 'Quantum Runner',
    brand: 'Adidas',
    category: 'Running Shoes',
    price: 147,           // 30% off
    originalPrice: 210,
    discountPercent: 30,
    rating: 5.0,
    inStock: true,
    badge: 'Sale',
    imageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuB4MclUg90M4lNhMdNwkHJkXQ5Yt8bVajMh5zgE-C3a2CV3wgown0TsFELU2KW_LKIW6CNs4MInvV1ZcBQyTGBwcP8QQtsNftAQVzaMIyPmxg-orGHsqke_n093wcpsotvmwrcVz9qV_IFEgMUBt0G56O__zZlkqIyL_X_X-1uP7a8sJUNdpNpjxFitYBiNnLgs6Rqb37RX2Hrf1UxUKnya0x4Ngf-hL949qvJVdic9qwkCjDXQs_KNXtxbgg1ZAn7qOhSIx74W22w',
  ),
  ProductModel(
    id: 'promo_006',
    name: 'Ignite Hoops',
    brand: 'Adidas',
    category: 'Basketball',
    price: 158,           // 30% off
    originalPrice: 225,
    discountPercent: 30,
    rating: 4.8,
    inStock: true,
    badge: 'Sale',
    imageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuCgjk0b38p6riMEtvxEc4J4pdI6z8BBgTzDRM5EHSC1UhxvzIxNbm6_RMOD3vXaBvmqm9nol5ATzw3jn0P42B61VEkZ5dq_1siSwyBgZsRPr3WlL085qbepPhi5QsOhQXQSZ13uZaLSfCVzZssuv9Jfk1APmqWQSjSf5pl_vnB9APF0CmRauExFE87wxbOrk4SOaT4788F9P5bw9umKd_tYJo65qCfE8ANUSToifDqlATOeWq1qKJVVWUATy0JRs7Lr_9Ap7tKLytxY',
  ),
];

// ─────────────────────────────────────────────
// EXISTING MOCK DATA (kept for home screen)
// ─────────────────────────────────────────────

const List<ProductModel> mockTrendingProducts = [
  ProductModel(
    id: 'trend_001',
    name: 'UltraBoost Pro X1',
    brand: 'Adidas',
    category: 'Running Shoes',
    price: 220,
    imageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuCAINt4ITBjTnSFOCxeJmt_SCa8fuBnnyaN5u0WuNwWZg9I4asBFKDaJfEXmVzY1qklJw8yxEcMFZfraVPsNmV9e5JNlcawjjoWRgdyswaE79qpqC84u9FWq1qxQsROb393w48fY4lOAQijQfyTOQLPZB88UJHYLJIUup-TJh7RQBnCEeRJ2EgH7iejkVg3i6k66jgBANYNyXwxjXBFUIJgi-0bFlIMtOcF2EuMN3W9FL7W6o7QX4wNN1qyRHwdXkn-ImRhjFY_mZc',
  ),
  ProductModel(
    id: 'trend_002',
    name: 'Court Master V3',
    brand: 'Jordan',
    category: 'Basketball',
    price: 190,
    imageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuCmf0AUJpkNANbtl94D-BID5h0Ib9wmugjPUBWNiHi4j41Sbj7Fa2lzMnDvE97HqVA-bYsXtfhz0k9A2P09QHWrAWvPt1s9sG365pglbCmPyL6Lsr_El-daPHaXJtSqv9GcF7-FqRMXHgHc3QxK4GstzbQyX6Ydw8j5bu59O057wl97zeNTGfuR6p3IwQypmp81vt4ZvmxzbnPfFFJL1YPejelpmW0amxMJfiotqA_uXcuqjSWjQ5GyQX8UfdW3cUXKifzUJKZV4vQ',
  ),
  ProductModel(
    id: 'trend_003',
    name: 'Aero Runner Lite',
    brand: 'Nike',
    category: 'Running Shoes',
    price: 160,
    imageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuAb6OvIJG-zWewOLMpJafNFIhqTyaGXx80gADIltcK-PfuUiB0kqHYfdTsrQKLyYmiqnY_0HR5RrhGzDfDpgyFzdldcPERG3oeY2LDkl5YOx70RLct2ymDtVzk4HOSKMvuTgEqMv-gwV0nj6EV-QMAZjviVPQySOwCZiMX-s-W96C7Dde0_wKJgVE9miPlCjXKQkb_YuW7vIrtiN7MQOiNFxpS-SuxRnLyeULjt6IW3NVbZbY6qMrczZ_vM8KRu2SyZVKNBb6xgEC8',
  ),
];

const List<ProductModel> mockNewDrops = [
  ProductModel(
    id: 'drop_001',
    name: 'Shadow Racer IV',
    brand: 'Nike',
    category: 'Running Shoes',
    price: 0,
    imageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuA6bI0NgABSxgXFJxi7-JqcZpXitBppEOFh9o5uqNyoPXDbpuKibwr---Wt0MNzD40-l4lPFsfVkqSUV8bCncHwV3X9NvXyRNVlMSUci4JRvJOdgxcSwCF-Tz7ORZAdQ9yvuvhbwTzydcnsbFiBirQXft_cJoh-qxSTi0-aGlocnzBiHIPoUoDhjJipmFcY0a1H9TxSyrqRjPHiYT5uwS2yA8pDeOsxbmr2l4JRfh-gzHkwqe3shsqa4Ai0M3nA0xWFBmGEw7QRk6A',
    badge: 'Coming Soon',
    releaseDate: 'Releasing Oct 12',
  ),
  ProductModel(
    id: 'drop_002',
    name: 'Carbon Flux 80',
    brand: 'Adidas',
    category: 'Sneakers',
    price: 0,
    imageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuDLCv_ZaepaIBY7vAX0PBUXiplFtgGZDBM1WWaslwm3rKG6L3jALeQdfYGa4c9ICP24DJi2Tz22rT9wIkSEiYlYGDpfMymopK_bJen2jtvkHYDIOgEV1I5PdavmbPKhalA6lDCrnFQJffY72NJHeK6OJDJjmpuidCi3bhgCYSApjVJVCTTBnjJcje8O8gmlObabqOaibv8RbFhFB6jguZIKbFUBDIcuS8KxSnto81aw5gqdP7FzloxGeTO1eFzR8W5pvucrl9GId_M',
    badge: 'Limited',
    releaseDate: 'Releasing Oct 15',
  ),
  ProductModel(
    id: 'drop_003',
    name: 'Apex Prime 2.0',
    brand: 'Jordan',
    category: 'Basketball',
    price: 0,
    imageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuABFnhykp5VCi_ikULuyq_xh09kIOQegkFfRiProhIlaBbfy6tLAMqGVSLNdasOWr42hZk7E7N6VIw12iWwy1-H5S8F99_3paLeJZLdzdjKWDOPGp-dOh5mRtJ_wp02anLpEY8yMAxQHvqNmNhPh8PaEAfgsW3mI5nXVaUofUb1Dq9Ugo-EUmOtlvp_yXGqvp4wEH-Cq7-2_DxbfrU5ikIK0vycjf-gd7tS9GulDemiwYJ6f15Be5Ms_VX82tjNDjiXmseQzFoTPTU',
    badge: 'New',
    releaseDate: 'Releasing Oct 18',
  ),
  ProductModel(
    id: 'drop_004',
    name: 'Titan Mid OG',
    brand: 'Jordan',
    category: 'Basketball',
    price: 0,
    imageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuA8RfuVodbCSwercmGQz6ZS2evSmKAmInUR7NNz-PZhRGf62vVZBMOyu5wRsNGTFv_n0UJEFnVmuUybE9RQezB-6cEuHfpirzn8vCPQgTgpoNm2gDmiHzyE1gvAuiqU0CihNywjbgIkzY-5HHOLLzSOdVFrmWmNA4AMvQp3CKR5zLg2fxhjQdTBNPd9lPsXyBfkFSmEH0JonkxU_OikvTT4A5GL0WDH_DlNsRSC5VLktl_wEjKqL0D75QPQfUJBiv0rwRvmcDYbDz8',
    badge: 'Restock',
    releaseDate: 'Releasing Oct 20',
  ),
];