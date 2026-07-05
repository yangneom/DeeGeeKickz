import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ================================================
// QR PAYMENT DIALOG
//
// Uses a plain Dialog (not AlertDialog) because
// AlertDialog tries to measure intrinsic dimensions,
// and qr_flutter's QrImageView uses a LayoutBuilder
// internally — that combination throws "LayoutBuilder
// does not support returning intrinsic dimensions."
// A fixed-width Dialog avoids that measurement path
// entirely.
// ================================================

class QrPaymentDialog extends StatefulWidget {
  final int orderId;
  final String checkoutUrl;
  final double amount;
  final VoidCallback onPaymentConfirmed;
  final VoidCallback onCancelled;

  const QrPaymentDialog({
    super.key,
    required this.orderId,
    required this.checkoutUrl,
    required this.amount,
    required this.onPaymentConfirmed,
    required this.onCancelled,
  });

  @override
  State<QrPaymentDialog> createState() => _QrPaymentDialogState();
}

class _QrPaymentDialogState extends State<QrPaymentDialog> {
  static const _timeoutSeconds = 180;
  int _secondsLeft = _timeoutSeconds;
  Timer? _countdown;
  RealtimeChannel? _channel;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _listenForPayment();
    _startCountdown();
  }

  void _listenForPayment() {
    _channel = Supabase.instance.client
        .channel('order-status-${widget.orderId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'order_id',
            value: widget.orderId,
          ),
          callback: (payload) {
            final status = payload.newRecord['order_status'];
            if (status == 'Completed' && !_resolved) {
              _resolved = true;
              widget.onPaymentConfirmed();
            }
          },
        )
        .subscribe();
  }

  void _startCountdown() {
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        if (!_resolved) {
          _resolved = true;
          widget.onCancelled();
        }
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  void _handleCancelPressed() {
    if (!_resolved) {
      _resolved = true;
      widget.onCancelled();
    }
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');

    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: SizedBox(
          width: 320,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Scan to Pay',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SizedBox(
                    width: 220,
                    height: 220,
                    child: QrImageView(
                      data: widget.checkoutUrl,
                      size: 220,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '₱${widget.amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ask the customer to scan with GCash or their banking app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Waiting for payment · expires in $minutes:$seconds',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _handleCancelPressed,
                  child: const Text('Cancel Payment'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}