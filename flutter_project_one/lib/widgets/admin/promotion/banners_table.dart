import 'package:flutter/material.dart';
import '../../common/dialog/confirm_dialog.dart';
import '../../common/buttons/table_pill_button.dart';
import 'add_banner_dialog.dart';
import 'edit_banner_dialog.dart';
import '../../../models/promotion_banner_model.dart';
import '../../../services/admin/promotionDiscount/banner_service.dart';
import '../../common/dialog/app_toast.dart'; 
class BannersTable extends StatefulWidget {
  const BannersTable({super.key});

  @override
  State<BannersTable> createState() => _BannersTableState();
}

class _BannersTableState extends State<BannersTable> {
  final BannerService _bannerService = BannerService();
  List<PromotionBanner> _banners = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBanners();
  }

  Future<void> _fetchBanners() async {
    setState(() => _isLoading = true);
    final List<PromotionBanner> result = await _bannerService.fetchBanners();
    if (!mounted) return;
    setState(() {
      _banners = result;
      _isLoading = false;
    });
  }

  String _formatDate(DateTime date) {
    const List<String> months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _handleAddBanner() async {
    final bool? result = await showAddBannerDialog(context);
    if (result != true) return;
    await _fetchBanners();
  }

  Future<void> _handleEditBanner(PromotionBanner banner) async {
    final bool? result = await showEditBannerDialog(context, banner: banner);
    if (result != true) return;
    await _fetchBanners();
  }

  Future<void> _handleDelete(PromotionBanner banner) async {
    final bool? confirmed = await showConfirmDialog(
      context: context,
      title: 'Delete this banner?',
      message: 'This banner will be permanently removed from the homepage slider.',
      confirmLabel: 'Delete',
      confirmColor: const Color(0xFFDC2626),
    );
    if (confirmed != true) return;

    final String? error = await _bannerService.deleteBanner(
      bannerId: banner.bannerId,
      imageUrl: banner.imageUrl,
    );

    if (!mounted) return;
    if (error != null) {
      AppToast.error(
        context,
        'We could not delete the banner. Please try again.',
        title: 'Banner not deleted',
      );
      return;
    }
    await _fetchBanners();
  }

  Widget _buildStatusBadge(String status) {
    final bool isActive = status == 'Active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isActive ? const Color(0xFF86EFAC) : const Color(0xFFD1D5DB)),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isActive ? const Color(0xFF16A34A) : const Color(0xFF6B7280),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Homepage Promotion Banners',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                    SizedBox(height: 4),
                    Text('Upload banner images that appear in the landing page slider.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                  ],
                ),
                ElevatedButton(
                  onPressed: _handleAddBanner,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Add Banner', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFFE5E7EB), height: 1),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Expanded(flex: 4, child: _HeaderCell('Banner Preview')),
                Expanded(flex: 2, child: _HeaderCell('Upload Date')),
                Expanded(flex: 2, child: _HeaderCell('Status')),
                Expanded(flex: 2, child: _HeaderCell('Actions')),
              ],
            ),
          ),
          const Divider(color: Color(0xFFE5E7EB), height: 1),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else if (_banners.isEmpty)
            const _EmptyMessage('No banners yet.')
          else
            for (int i = 0; i < _banners.length; i++)
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                _banners[i].imageUrl,
                                width: 160, height: 80, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 160, height: 80,
                                  decoration: BoxDecoration(color: const Color(0xFF1a1a2e), borderRadius: BorderRadius.circular(6)),
                                  child: const Center(child: Icon(Icons.image_outlined, color: Colors.white54, size: 24)),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(_formatDate(_banners[i].uploadDate),
                              style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
                        ),
                        Expanded(
                          flex: 2,
                          child: Align(alignment: Alignment.centerLeft, child: _buildStatusBadge(_banners[i].status)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TablePillButton.edit(
                                onPressed: () => _handleEditBanner(_banners[i]),
                              ),
                              const SizedBox(width: 8),
                              TablePillButton.delete(
                                onPressed: () => _handleDelete(_banners[i]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i < _banners.length - 1) const Divider(color: Color(0xFFE5E7EB), height: 1),
                ],
              ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  const _HeaderCell(this.label);
  @override
  Widget build(BuildContext context) {
    return Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)));
  }
}

class _EmptyMessage extends StatelessWidget {
  final String message;
  const _EmptyMessage(this.message);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(child: Text(message, style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)))),
    );
  }
}