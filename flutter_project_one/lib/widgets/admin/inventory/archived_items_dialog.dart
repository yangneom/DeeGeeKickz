import 'package:flutter/material.dart';
import 'package:flutter_project_one/widgets/common/dialog/confirm_dialog.dart';
import 'package:flutter_project_one/widgets/common/tables/expandable_product_table.dart';
import 'package:flutter_project_one/models/product.dart';
import '../../../services/admin/inventory/archive_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/product/product_provider.dart';

void showArchivedItemsDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return const ArchivedItemsDialog();
    },
  );
}

class ArchivedItemsDialog extends ConsumerStatefulWidget {
  const ArchivedItemsDialog({super.key});

  @override
  ConsumerState<ArchivedItemsDialog> createState() => _ArchivedItemsDialogState();
}

class _ArchivedItemsDialogState extends ConsumerState<ArchivedItemsDialog> {

  final ArchiveService _service = ArchiveService();
  List<Product> _products = [];
  bool _isLoading = true;

  // ================================================
  // INIT STATE
  // ================================================
  @override
  void initState() {
    super.initState();
    _loadArchived();
  }

  // ================================================
  // LOAD ARCHIVED PRODUCTS FROM SUPABASE
  // ================================================
  Future<void> _loadArchived() async {
    setState(() => _isLoading = true);

    final List<Product> products = await _service.fetchArchivedProducts();

    setState(() {
      _products = products;
      _isLoading = false;
    });
  }

  // ================================================
  // HANDLE RESTORE
  // ================================================
  Future<void> _handleRestore(Product product) async {
    final bool? confirmed = await showConfirmDialog(
      context: context,
      title: 'Restore this product in the inventory?',
      message:
          'This product will be moved back to active inventory '
          'and will be available for transactions.',
      confirmLabel: 'Restore Product',
      confirmColor: const Color(0xFF2563EB),
    );

    if (confirmed != true) return;

    final String? error = await _service.restoreProduct(
      productId: product.productId,
    );

    if (error != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      }
      return;
    }

    // Restore just changed is_archived server-side — the cashier and
    // shop screens both read productsProvider, which has no idea this
    // happened. Force them to refetch instead of waiting for someone
    // to manually reload.
    ref.invalidate(productsProvider);

    await _loadArchived();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.productName} has been restored!'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    }
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: screenWidth < 1000 ? screenWidth * 0.90 : 900,
        height: screenHeight * 0.85,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── TITLE ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Archived Items',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'View and restore previously archived products.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  SizedBox(height: 16),
                  Divider(color: Color(0xFFE5E7EB), height: 1),
                ],
              ),
            ),

            // ── BODY ──
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF2563EB),
                        strokeWidth: 2,
                      ),
                    )
                  : _products.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 40,
                                color: Color(0xFF9CA3AF),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'No archived products.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                          child: ExpandableProductTable(
                            products: _products,
                            extraHeaderLabel: 'Archived Date',
                            extraValueBuilder: (Product product) {
                              return product.archivedDate ?? '';
                            },
                            actionBuilder: (Product product) {
                              return SizedBox(
                                height: 32,
                                child: ElevatedButton(
                                  onPressed: () => _handleRestore(product),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF16A34A),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Restore',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),

            // ── BACK BUTTON ──
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Back',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}