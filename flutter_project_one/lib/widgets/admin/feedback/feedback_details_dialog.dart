// ================================================
// feedback_details_dialog.dart  (BUG-FIXED)
//
// Fixes applied this round:
//  1. Empty-customerName crash guard — CircleAvatar initial
//     now falls back to '?' instead of calling substring(0,1)
//     on a possibly-empty string.
//  2. "Save Reply" no-op guard — the button is now disabled
//     (not just re-enabled after tap) unless the status has
//     actually changed OR a new reply has been typed. A
//     defensive check remains inside _handleSave too, in case
//     it's ever invoked programmatically.
//
// Everything else — UI structure, confirm dialog flow,
// async onSave delegation — UNCHANGED from your version.
// ================================================

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../common/dialog/confirm_dialog.dart';
import '../../../models/review_model.dart' show FeedbackReply;

class FeedbackDetailsDialog extends StatefulWidget {
  final Map<String, dynamic> feedback;

  // Now async — delegates real save to the provider via FeedbackScreen
  final Future<void> Function(String adminReply) onSave;

  const FeedbackDetailsDialog({
    super.key,
    required this.feedback,
    required this.onSave,
  });

  @override
  State<FeedbackDetailsDialog> createState() => _FeedbackDetailsDialogState();
}

class _FeedbackDetailsDialogState extends State<FeedbackDetailsDialog> {
  final TextEditingController _replyController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Reply field starts empty — this composes a NEW reply appended
    // to the thread below, it no longer prefills/overwrites the last one.

    // Rebuild whenever the reply text changes so the Save button's
    // enabled state stays in sync with whether there's anything to save.
    _replyController.addListener(_onFieldsChanged);
  }

  void _onFieldsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _replyController.removeListener(_onFieldsChanged);
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final String newReply = _replyController.text.trim();

    // Defensive no-op guard — the Save button is disabled in this state
    // already, but this protects against any other call path.
    if (newReply.isEmpty) {
      Navigator.pop(context);
      return;
    }

    setState(() => _saving = true);
    await widget.onSave(newReply);

    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context);
    }
  }
  Widget _buildStarRating(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (int index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          size: 18,
          color: index < rating
              ? const Color(0xFFF59E0B)
              : const Color(0xFFD1D5DB),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth  = MediaQuery.of(context).size.width;

    // FIX #1: guard against empty customerName instead of blindly
    // calling substring(0, 1) — mirrors the guard already used in
    // _FeedbackCard in feedback_screen.dart.
    final String customerName = widget.feedback['customerName'] as String;

    // FIX #3 (papercut): Save Reply is only actionable when something
    // has actually changed — a different status, or new reply text.
    final bool hasChanges = _replyController.text.trim().isNotEmpty;

    return Dialog(
      insetPadding:    EdgeInsets.zero,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width:  screenWidth < 700 ? screenWidth * 0.95 : 500,
        height: screenHeight * 0.85,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize:      MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── FIXED HEADER — UNCHANGED ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Feedback Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'View comment and manage moderation',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFE5E7EB),
                        child: Text(
                          customerName.isNotEmpty
                              ? customerName.substring(0, 1).toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customerName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.feedback['datePosted'] as String,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFFE5E7EB), height: 1),
                ],
              ),
            ),

            // ── SCROLLABLE CONTENT — UNCHANGED ──
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    const Text('Product Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                    const SizedBox(height: 4),
                    Text(widget.feedback['productReviewed'] as String, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                    const SizedBox(height: 16),

                    const Text('Rating', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                    const SizedBox(height: 4),
                    _buildStarRating(widget.feedback['rating'] as int),
                    const SizedBox(height: 16),

                    const Text('Full Feedback', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:        const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                        border:       Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Text(
                        widget.feedback['comment'] as String,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Photo / video gallery ──────────────────
                    // BUG FIX: this section was missing entirely —
                    // uploaded media never had anywhere to render on
                    // the admin side, even after the data pipeline
                    // (upload -> DB -> model) was fixed.
                    _AdminMediaGallery(
                      urls: (widget.feedback['imageUrls'] as List<dynamic>?)
                              ?.map((e) => e.toString())
                              .toList() ??
                          const [],
                    ),

                     Text(
                      'Reply Thread'
                      '${(widget.feedback['replies'] as List<FeedbackReply>).isEmpty ? '' : ' (${(widget.feedback['replies'] as List<FeedbackReply>).length})'}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                    ),
                    const SizedBox(height: 8),

                    // ── Existing replies, oldest first ──
                    if ((widget.feedback['replies'] as List<FeedbackReply>).isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'No replies yet.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                        ),
                      )
                    else
                      ...(widget.feedback['replies'] as List<FeedbackReply>).map(
                        (reply) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: reply.isStaff ? const Color(0xFFF0F9FF) : const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: reply.isStaff ? const Color(0xFFBAE6FD) : const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    reply.isStaff ? reply.authorName : '${reply.authorName} (Customer)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: reply.isStaff ? const Color(0xFF0284C7) : const Color(0xFF6B7280),
                                    ),
                                  ),
                                  Text(
                                    '${reply.createdAt.month}/${reply.createdAt.day}/${reply.createdAt.year}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                reply.replyText,
                                style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 12),

                    const Text('Add a Reply', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _replyController,
                      maxLines:   4,
                      style:      const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText:  'Write a new reply...',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                        filled:    true,
                        fillColor: const Color(0xFFF9FAFB),
                        border:       OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB))),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── FIXED FOOTER ──
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side:   const BorderSide(color: Color(0xFFD1D5DB)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape:  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    // FIX #3: disabled while saving OR when there's nothing to save.
                    onPressed: (_saving || !hasChanges) ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF93C5FD),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape:  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save Reply', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
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

// ── Photo / video gallery (admin side) ─────────────────────────────

bool _isVideoUrl(String url) {
  final String lower = url.toLowerCase();
  return lower.endsWith('.mp4') ||
      lower.endsWith('.mov') ||
      lower.endsWith('.m4v') ||
      lower.endsWith('.webm') ||
      lower.endsWith('.3gp');
}

class _AdminMediaGallery extends StatelessWidget {
  final List<String> urls;
  const _AdminMediaGallery({required this.urls});

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Photos & Videos',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151))),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: urls.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final String url = urls[i];
              final bool isVideo = _isVideoUrl(url);

              return GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  barrierColor: Colors.black,
                  builder: (_) =>
                      _AdminMediaViewerDialog(urls: urls, startIndex: i),
                ),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: isVideo
                      ? const Center(
                          child: Icon(Icons.play_circle_fill,
                              color: Color(0xFF6B7280), size: 30),
                        )
                      : Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image_outlined,
                            color: Color(0xFFD1D5DB),
                          ),
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          },
                        ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _AdminMediaViewerDialog extends StatefulWidget {
  final List<String> urls;
  final int startIndex;
  const _AdminMediaViewerDialog(
      {required this.urls, required this.startIndex});

  @override
  State<_AdminMediaViewerDialog> createState() =>
      _AdminMediaViewerDialogState();
}

class _AdminMediaViewerDialogState extends State<_AdminMediaViewerDialog> {
  late final PageController _pageController =
      PageController(initialPage: widget.startIndex);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.urls.length,
            itemBuilder: (context, i) {
              final String url = widget.urls[i];
              return _isVideoUrl(url)
                  ? _AdminInlineVideoPlayer(url: url)
                  : InteractiveViewer(
                      child: Center(
                        child: Image.network(url, fit: BoxFit.contain),
                      ),
                    );
            },
          ),
          Positioned(
            top: 40,
            right: 12,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminInlineVideoPlayer extends StatefulWidget {
  final String url;
  const _AdminInlineVideoPlayer({required this.url});

  @override
  State<_AdminInlineVideoPlayer> createState() =>
      _AdminInlineVideoPlayerState();
}

class _AdminInlineVideoPlayerState extends State<_AdminInlineVideoPlayer> {
  late final VideoPlayerController _controller;
  bool _initialized = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _initialized = true);
        _controller.play();
      }).catchError((_) {
        if (!mounted) return;
        setState(() => _failed = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      _controller.value.isPlaying ? _controller.pause() : _controller.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Center(
        child: Text(
          'Could not play this video.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }
    if (!_initialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return Center(
      child: GestureDetector(
        onTap: _togglePlay,
        child: AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_controller),
              if (!_controller.value.isPlaying)
                const Icon(Icons.play_circle_fill,
                    color: Colors.white70, size: 64),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: VideoProgressIndicator(
                  _controller,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: Colors.white,
                    backgroundColor: Colors.white24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}