import 'package:flutter/material.dart';
import '../../../models/customer_account.dart';
import '../../../services/super/customer_management/customer_account_service.dart';

// ================================================
// CUSTOMER VIEW DIALOG
//
// Admin has NO manual disable capability here — the automated
// abuse-detection system is the only thing that disables customer
// accounts. This dialog is pure view: profile info, flag evidence,
// and the full violation/warning timeline.
// ================================================

void showCustomerEditDialog({
  required BuildContext context,
  required CustomerAccount account,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return CustomerEditDialog(account: account);
    },
  );
}

class CustomerEditDialog extends StatefulWidget {
  final CustomerAccount account;

  const CustomerEditDialog({super.key, required this.account});

  @override
  State<CustomerEditDialog> createState() => _CustomerEditDialogState();
}

class _CustomerEditDialogState extends State<CustomerEditDialog> {
  final CustomerAccountService _service = CustomerAccountService();

  CustomerFlagSummary? _flagSummary;
  List<CustomerViolation> _violations = [];
  bool _isLoadingExtras = true;

  @override
  void initState() {
    super.initState();
    _loadExtras();
  }

  Future<void> _loadExtras() async {
    try {
      final results = await Future.wait([
        _service.getCustomerFlagSummary(widget.account.id),
        _service.getViolationHistory(widget.account.id),
      ]);
      if (mounted) {
        setState(() {
          _flagSummary = results[0] as CustomerFlagSummary;
          _violations = results[1] as List<CustomerViolation>;
          _isLoadingExtras = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingExtras = false);
    }
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty || raw == '-') return '-';
    final DateTime? parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final DateTime local = parsed.toLocal();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    int hour12 = local.hour % 12;
    if (hour12 == 0) hour12 = 12;
    final String minute = local.minute.toString().padLeft(2, '0');
    final String period = local.hour >= 12 ? 'PM' : 'AM';
    return '${months[local.month - 1]} ${local.day}, ${local.year}, $hour12:$minute $period';
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        const SizedBox(height: 2),
        Text(value.isEmpty ? '-' : value,
            style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
      ],
    );
  }
  Widget _buildStatChip(String label, int count) {
    final bool hasFlag = count > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: hasFlag ? const Color(0xFFFEF3C7) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: hasFlag ? const Color(0xFFFCD34D) : const Color(0xFFE5E7EB)),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: hasFlag ? const Color(0xFF92400E) : const Color(0xFF6B7280),
        ),
      ),
    );
  }

  Widget _buildTierBadge() {
    final int tier = widget.account.banTier;
    final Color color = tier == 0
        ? const Color(0xFF16A34A)
        : tier == 1
            ? const Color(0xFFF59E0B)
            : const Color(0xFFDC2626);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        widget.account.banTierLabel,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildEvidenceAndHistory() {
    if (_isLoadingExtras) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    final summary = _flagSummary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Account Standing',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
            const SizedBox(width: 8),
            _buildTierBadge(),
          ],
        ),
        const SizedBox(height: 4),
        Text('Warnings issued: ${widget.account.warningCount}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        if (_violations.isNotEmpty) ...[
          const Text('Violation Timeline',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
          const SizedBox(height: 8),
          ..._violations.map((v) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFFDC2626), shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${v.label} — Tier ${v.tierApplied} — ${v.detectedAt}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 540, maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('View Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                  SizedBox(height: 2),
                  Text('Customer account details (view only)', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildInfoRow('First Name', widget.account.firstName)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildInfoRow('Last Name', widget.account.lastName)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('Contact Number', widget.account.phone),
                    const SizedBox(height: 12),
                    _buildInfoRow('Email', widget.account.email),
                    const SizedBox(height: 12),
                    _buildInfoRow('Address', widget.account.address),
                    const SizedBox(height: 12),
                    _buildInfoRow('Landmark', widget.account.landmark),
                    const SizedBox(height: 12),
                    _buildInfoRow('Status', widget.account.status),
                    const SizedBox(height: 12),
                    _buildInfoRow('Last Login', _formatDate(widget.account.lastLogin)),
                    const SizedBox(height: 12),
                    _buildInfoRow('Registered On', _formatDate(widget.account.registeredOn)),                    if (widget.account.isDisabled) ...[
                      const SizedBox(height: 12),
                      _buildInfoRow('Disable Reason', widget.account.disableReason ?? '-'),
                    ],
                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFFE5E7EB)),
                    const SizedBox(height: 16),
                    _buildEvidenceAndHistory(),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF374151),
                            side: const BorderSide(color: Color(0xFFD1D5DB)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Close', style: TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}