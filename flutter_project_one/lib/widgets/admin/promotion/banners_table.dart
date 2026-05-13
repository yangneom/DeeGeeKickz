import 'package:flutter/material.dart';
import '../../common/confirm_dialog.dart';
import 'add_banner_dialog.dart'; // 👈 import the dialog

class BannersTable extends StatefulWidget {
  const BannersTable({super.key});

  @override
  State<BannersTable> createState() => _BannersTableState();
}

class _BannersTableState extends State<BannersTable> {

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
  // OPEN ADD BANNER DIALOG
  // Waits for the result and adds it to the list
  // ================================================
  Future<void> _handleAddBanner() async {
    final Map<String, dynamic>? result = await showAddBannerDialog(context);

    // if user cancelled, result is null — do nothing
    if (result == null) return;

    // add the new banner to the list
    setState(() {
      _banners.add(result);
    });
  }

  Widget _buildStatusBadge(String status) {
    final bool isActive = status == 'Active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? const Color(0xFF86EFAC) : const Color(0xFFD1D5DB),
        ),
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

  Widget _buildActions({
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onEdit,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_outlined, size: 15, color: Color(0xFF2563EB)),
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
        GestureDetector(
          onTap: onDelete,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_outline, size: 15, color: Color(0xFFDC2626)),
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

  Future<void> _handleDelete(int index) async {
    final bool? confirmed = await showConfirmDialog(
      context: context,
      title: 'Delete this banner?',
      message: 'This banner will be permanently removed from the homepage slider.',
      confirmLabel: 'Delete',
      confirmColor: const Color(0xFFDC2626),
    );
    if (confirmed != true) return;
    setState(() => _banners.removeAt(index));
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

          // ---- HEADER ----
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
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
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: _handleAddBanner, // 👈 connected
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Add Banner',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Color(0xFFE5E7EB), height: 1),

          // ---- COLUMN HEADERS ----
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

          // ---- ROWS ----
          if (_banners.isEmpty)
            const _EmptyMessage('No banners yet.')
          else
            for (int i = 0; i < _banners.length; i++)
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [

                        // Banner Preview
                        Expanded(
                          flex: 4,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                _banners[i]['imageUrl'],
                                width: 160,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
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
                                ),
                              ),
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
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _buildStatusBadge(_banners[i]['status']),
                          ),
                        ),

                        // Actions
                        Expanded(
                          flex: 2,
                          child: _buildActions(
                            onEdit: () {
                              // TODO: open edit banner dialog
                            },
                            onDelete: () => _handleDelete(i),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i < _banners.length - 1)
                    const Divider(color: Color(0xFFE5E7EB), height: 1),
                ],
              ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ---- Private helpers ----

class _HeaderCell extends StatelessWidget {
  final String label;
  const _HeaderCell(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF374151),
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  final String message;
  const _EmptyMessage(this.message);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
        ),
      ),
    );
  }
}