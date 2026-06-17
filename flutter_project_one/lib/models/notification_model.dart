// ================================================
// NOTIFICATION MODEL
//
// Defines what a notification looks like in code.
// Three types: drop, order, offer
//
// Replace fakeNotifications with real Supabase data later.
// ================================================

enum NotificationType { drop, order, offer }

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final String timeAgo;
  final bool isRead;
  final bool isUnread;

  // Drop-specific
  final String? imageUrl;
  final int? countdownSeconds; // null = ended
  final bool isSoldOut;

  // Order-specific
  final String? orderId;

  // Offer-specific (nothing extra needed)

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timeAgo,
    this.isRead = false,
    this.isUnread = true,
    this.imageUrl,
    this.countdownSeconds,
    this.isSoldOut = false,
    this.orderId,
  });

  AppNotification copyWith({bool? isRead, bool? isUnread}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      timeAgo: timeAgo,
      isRead: isRead ?? this.isRead,
      isUnread: isUnread ?? this.isUnread,
      imageUrl: imageUrl,
      countdownSeconds: countdownSeconds,
      isSoldOut: isSoldOut,
      orderId: orderId,
    );
  }
}

// ================================================
// MOCK NOTIFICATIONS
// ================================================

final List<AppNotification> fakeNotifications = [
  // ── Upcoming Drop (active countdown) ─────────
  AppNotification(
    id: 'notif_001',
    type: NotificationType.drop,
    title: "AeroMax V3 'Solar Red'",
    body:
        'The most anticipated performance drop of the season is almost here. Set your reminders.',
    timeAgo: '2 hours ago',
    isUnread: true,
    imageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuBzqgnwA9fEOT4tM8MVuePWlGB15rwCqHZyu4AdX5wt7GCLTTF5bkIcgn1EZLk2p4RnB95Y812Yodc_KDnt8FObXYkFwcl47OU-i4geIra2osGUVEwLlEo_pPWk1v_ZrnwuyXwZGxlvlKe7Vf0G8Gyt2MR3tUKmJOkdHYVcP8f8cXnKs7RCZZzW2brEIpQfm2wLgchWjS__xMcqQw-VpRKoohY-HJNZw289GEmOQ2Je0k3uNP8uvFoHJODeUbP-1t1vqMKfbToh87I',
    countdownSeconds: 18400,
    isSoldOut: false,
  ),

  // ── Order Update ──────────────────────────────
  AppNotification(
    id: 'notif_002',
    type: NotificationType.order,
    title: 'Your order #DG-9921 is out for delivery',
    body:
        'Our carrier is in your neighborhood. Your heat will arrive by 6:00 PM today.',
    timeAgo: '5 hours ago',
    isUnread: true,
    orderId: 'order_004',
  ),

  // ── Member Exclusive ──────────────────────────
  AppNotification(
    id: 'notif_003',
    type: NotificationType.offer,
    title: 'Early Access: Summer Collection',
    body:
        "Because you're a Top Tier member, we're giving you 24-hour early access to the 2024 Summer Series.",
    timeAgo: 'Yesterday',
    isUnread: false,
  ),

  // ── Upcoming Drop (ended / sold out) ─────────
  AppNotification(
    id: 'notif_004',
    type: NotificationType.drop,
    title: "Ghost Runner 'Neon Flux'",
    body:
        'Limited quantity restock. This is the final release for this colorway.',
    timeAgo: '2 days ago',
    isUnread: false,
    imageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuDsvN-KEDfagxGEaqLOeA1rzmNSEJJSg_gUb8D6PdV6vkB8zNOX03GCWgYNnjD_UBteCWQD7L4jWnp8be5ZotZCCn40XeWB-uKGPQAtl61lCKZ3JsDVr53N3lNym9bp4N-RHuS1gg4QTtfWA3BmZMU3zdG5MhN9yfxvEcN8Qhcwojbgmo_WHHsO57AXxAm3zOtpeGSZTj55dtZ0TIx6OKMTk4Z1NAzv5Xm0CqtRqqqlolnmfdC5F5VrS8m2EWK_3Hns-sI93enyoVA',
    countdownSeconds: null, // ended
    isSoldOut: true,
  ),
];