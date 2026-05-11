import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/common/confirm_dialog.dart';

class PromotionsScreen extends ConsumerStatefulWidget {
  const PromotionsScreen({super.key});

  @override
  ConsumerState<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends ConsumerState<PromotionsScreen> {

  // ================================================
  // FAKE DATA — banners
  // later this will come from Firebase
  // ================================================
  final List<Map<String, dynamic>> _banners = [
    {
      'imageUrl': 'https://via.placeholder.com/160x80/1a1a1a/ff0000?text=SALE+50%25',
      'uploadDate': 'Mar 1, 2026',
      'status': 'Active',
    },
    {
      'imageUrl': 'https://via.placeholder.com/160x80/0a0a2e/ffffff?text=SALE',
      'uploadDate': 'Feb 28, 2026',
      'status': 'Inactive',
    },
  ];

  // ================================================
  // FAKE DATA — product discounts
  // later this will come from Firebase
  // ================================================
  final List<Map<String, dynamic>> _discounts = [
    {
      'productName': 'Nike Air Max 270',
      'originalPrice': '₱5,500',
      'discount': '20%',
      'discountType': 'percent',   // percent or fixed
      'finalPrice': '₱4,400',
      'duration': 'Jun 1 – Jun 30',
      'status': 'Active',
    },
    {
      'productName': 'Jordan 1 Retro High',
      'originalPrice': '₱8,500',
      'discount': '15%',
      'discountType': 'percent',
      'finalPrice': '₱7,225',
      'duration': 'Mar 10 – Apr 10',
      'status': 'Active',
    },
    {
      'productName': 'Adidas Ultraboost 22',
      'originalPrice': '₱7,200',
      'discount': '₱1000',
      'discountType': 'fixed',     // fixed amount discount
      'finalPrice': '₱6,200',
      'duration': 'Feb 15 – Mar 15',
      'status': 'Inactive',
    },
  ];

  // ================================================
  // BUILD STATUS BADGE
  // green for Active, gray for Inactive
  // ================================================
  Widget _buildStatusBadge(String status) {

    Color backgroundColor = const Color(0xFFF3F4F6);
    Color textColor = const Color(0xFF6B7280);
    Color borderColor = const Color(0xFFD1D5DB);

    if (status == 'Active') {
      backgroundColor = const Color(0xFFDCFCE7);
      textColor = const Color(0xFF16A34A);
      borderColor = const Color(0xFF86EFAC);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  // ================================================
  // BUILD EDIT + DELETE ACTIONS
  // reusable row of Edit and Delete buttons
  // used in both banner and discount tables
  // ================================================
  Widget _buildActions({
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [

        // Edit button — blue icon + text
        GestureDetector(
          onTap: onEdit,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.edit_outlined,
                size: 15,
                color: Color(0xFF2563EB),
              ),
              SizedBox(width: 4),
              Text(
                'Edit',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 16),

        // Delete button — red icon + text
        GestureDetector(
          onTap: onDelete,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.delete_outline,
                size: 15,
                color: Color(0xFFDC2626),
              ),
              SizedBox(width: 4),
              Text(
                'Delete',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ================================================
  // HANDLE DELETE BANNER
  // shows confirm dialog then removes from list
  // ================================================
  Future<void> _handleDeleteBanner(int index) async {

    final bool? confirmed = await showConfirmDialog(
      context: context,
      title: 'Delete this banner?',
      message: 'This banner will be permanently removed '
          'from the homepage slider.',
      confirmLabel: 'Delete',
      confirmColor: const Color(0xFFDC2626), // red
    );

    // user cancelled — do nothing
    if (confirmed != true) {
      return;
    }

    // remove the banner from the list
    setState(() {
      _banners.removeAt(index);
    });
  }

  // ================================================
  // HANDLE DELETE DISCOUNT
  // shows confirm dialog then removes from list
  // ================================================
  Future<void> _handleDeleteDiscount(int index) async {

    final bool? confirmed = await showConfirmDialog(
      context: context,
      title: 'Delete this discount?',
      message: 'This discount will be permanently removed '
          'and the product will return to its original price.',
      confirmLabel: 'Delete',
      confirmColor: const Color(0xFFDC2626), // red
    );

    // user cancelled — do nothing
    if (confirmed != true) {
      return;
    }

    // remove the discount from the list
    setState(() {
      _discounts.removeAt(index);
    });
  }

  // ================================================
  // BUILD BANNERS SECTION
  // the top card with banner table
  // ================================================
  Widget _buildBannersSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ---- SECTION HEADER ----
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [

                // title + subtitle
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Homepage Promotion Banners',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Upload banner images that appear in the landing page slider.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),

                // Add Banner button
                ElevatedButton(
                  onPressed: () {
                    // TODO: open add banner dialog later
                    print('Add Banner clicked');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Add Banner',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // divider between header and table
          const Divider(color: Color(0xFFE5E7EB), height: 1),

          // ---- TABLE HEADER ROW ----
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
            child: Row(
              children: const [

                // Banner Preview column — widest
                Expanded(
                  flex: 4,
                  child: Text(
                    'Banner Preview',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),

                // Upload Date column
                Expanded(
                  flex: 2,
                  child: Text(
                    'Upload Date',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),

                // Status column
                Expanded(
                  flex: 2,
                  child: Text(
                    'Status',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),

                // Actions column
                Expanded(
                  flex: 2,
                  child: Text(
                    'Actions',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // divider under table header
          const Divider(color: Color(0xFFE5E7EB), height: 1),

          // ---- TABLE DATA ROWS ----
          for (int i = 0; i < _banners.length; i = i + 1)
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [

                      // Banner Preview — image thumbnail
                      Expanded(
                        flex: 4,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            _banners[i]['imageUrl'],
                            width: 160,
                            height: 80,
                            fit: BoxFit.cover,

                            // show gray box if image fails to load
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 160,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1a1a2e),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.image_outlined,
                                    color: Colors.white54,
                                    size: 24,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      // Upload Date
                      Expanded(
                        flex: 2,
                        child: Text(
                          _banners[i]['uploadDate'],
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),

                      // Status badge
                      Expanded(
                        flex: 2,
                        child: _buildStatusBadge(_banners[i]['status']),
                      ),

                      // Edit + Delete actions
                      Expanded(
                        flex: 2,
                        child: _buildActions(
                          onEdit: () {
                            // TODO: open edit banner dialog later
                            print('Edit banner $i');
                          },
                          onDelete: () {
                            _handleDeleteBanner(i);
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // divider between rows
                if (i < _banners.length - 1)
                  const Divider(
                    color: Color(0xFFE5E7EB),
                    height: 1,
                  ),
              ],
            ),

          // show empty message if no banners
          if (_banners.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No banners yet.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ================================================
  // BUILD DISCOUNTS SECTION
  // the bottom card with discounts table
  // ================================================
  Widget _buildDiscountsSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ---- SECTION HEADER ----
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [

                // title + subtitle
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Product Discounts',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Create limited-time discounts for specific shoes.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),

                // Create Discount button
                ElevatedButton(
                  onPressed: () {
                    // TODO: open create discount dialog later
                    print('Create Discount clicked');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Create Discount',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // divider between header and table
          const Divider(color: Color(0xFFE5E7EB), height: 1),

          // ---- TABLE HEADER ROW ----
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
            child: Row(
              children: const [

                // Product Name — widest
                Expanded(
                  flex: 3,
                  child: Text(
                    'Product',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),

                // Original Price
                Expanded(
                  flex: 2,
                  child: Text(
                    'Original Price',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),

                // Discount
                Expanded(
                  flex: 2,
                  child: Text(
                    'Discount',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),

                // Final Price
                Expanded(
                  flex: 2,
                  child: Text(
                    'Final Price',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),

                // Duration
                Expanded(
                  flex: 2,
                  child: Text(
                    'Duration',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),

                // Status
                Expanded(
                  flex: 2,
                  child: Text(
                    'Status',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),

                // Actions
                Expanded(
                  flex: 2,
                  child: Text(
                    'Actions',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // divider under table header
          const Divider(color: Color(0xFFE5E7EB), height: 1),

          // ---- TABLE DATA ROWS ----
          for (int i = 0; i < _discounts.length; i = i + 1)
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [

                      // Product Name only — no image
                      Expanded(
                        flex: 3,
                        child: Text(
                          _discounts[i]['productName'],
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),

                      // Original Price
                      Expanded(
                        flex: 2,
                        child: Text(
                          _discounts[i]['originalPrice'],
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),

                      // Discount — blue text
                      Expanded(
                        flex: 2,
                        child: Text(
                          _discounts[i]['discount'],
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2563EB), // blue
                          ),
                        ),
                      ),

                      // Final Price — bold
                      Expanded(
                        flex: 2,
                        child: Text(
                          _discounts[i]['finalPrice'],
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),

                      // Duration
                      Expanded(
                        flex: 2,
                        child: Text(
                          _discounts[i]['duration'],
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),

                      // Status badge
                      Expanded(
                        flex: 2,
                        child: _buildStatusBadge(_discounts[i]['status']),
                      ),

                      // Edit + Delete actions
                      Expanded(
                        flex: 2,
                        child: _buildActions(
                          onEdit: () {
                            // TODO: open edit discount dialog later
                            print('Edit discount $i');
                          },
                          onDelete: () {
                            _handleDeleteDiscount(i);
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // divider between rows
                if (i < _discounts.length - 1)
                  const Divider(
                    color: Color(0xFFE5E7EB),
                    height: 1,
                  ),
              ],
            ),

          // show empty message if no discounts
          if (_discounts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No discounts yet.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ================================================
            // PAGE TITLE
            // ================================================
            const Text(
              'Promotion & Discounts',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),

            const SizedBox(height: 4),

            const Text(
              'Manage homepage banners and product discounts.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF9CA3AF),
              ),
            ),

            const SizedBox(height: 24),

            // ================================================
            // BANNERS SECTION
            // ================================================
            _buildBannersSection(),

            const SizedBox(height: 24),

            // ================================================
            // DISCOUNTS SECTION
            // ================================================
            _buildDiscountsSection(),

            // bottom padding so content doesn't get cut off
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}