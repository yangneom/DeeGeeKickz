import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/admin/promotion/banners_table.dart';
import '../../../widgets/admin/promotion/discounts_table.dart';

class PromotionsScreen extends ConsumerWidget {
  const PromotionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Page title
            Text(
              'Promotion & Discounts',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Manage homepage banners and product discounts.',
              style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            ),

            SizedBox(height: 24),
            BannersTable(),
            SizedBox(height: 24),
            DiscountsTable(),
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}