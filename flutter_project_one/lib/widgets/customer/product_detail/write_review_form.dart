import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Stateful form for submitting a product review.
/// - Interactive star rating picker
/// - Review title + body text fields
/// - Photo attachment via file_picker (up to 3 photos)
/// - Submit triggers [onSubmit] callback with the collected data
class WriteReviewForm extends StatefulWidget {
  final String productName;
  final bool externalLoading; // true while Supabase submit is in flight
  final void Function({
    required double rating,
    required String title,
    required String body,
    required List<PlatformFile> photos,
  }) onSubmit;

  const WriteReviewForm({
    super.key,
    required this.productName,
    this.externalLoading = false,
    required this.onSubmit,
  });

  @override
  State<WriteReviewForm> createState() => _WriteReviewFormState();
}

class _WriteReviewFormState extends State<WriteReviewForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  double _rating = 0;
  double _hoverRating = 0;
  List<PlatformFile> _photos = [];
  bool _submitting = false;

  static const int _maxPhotos = 3;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  // ── Photo picker ─────────────────────────────────────────────

  Future<void> _pickPhotos() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: kIsWeb, // on web we need bytes; on mobile path is enough
    );
    if (result == null) return;

    final picked = result.files;
    final combined = [..._photos, ...picked];
    setState(() {
      // Cap at _maxPhotos
      _photos = combined.take(_maxPhotos).toList();
    });
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  // ── Submit ───────────────────────────────────────────────────

  void _submit() {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'PLEASE SELECT A STAR RATING',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          backgroundColor: Colors.black,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    // Simulate a short async save (replace with Supabase call later)
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() => _submitting = false);
      widget.onSubmit(
        rating: _rating,
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        photos: _photos,
      );
    });
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product name label
          Text(
            'Reviewing: ${widget.productName}'.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
              color: Color(0xFF4C4546),
            ),
          ),

          const SizedBox(height: 32),

          // ── Star rating picker ────────────────────────────────
          const _FieldLabel(text: 'YOUR RATING'),
          const SizedBox(height: 12),
          _StarPicker(
            rating: _rating,
            hoverRating: _hoverRating,
            onHover: (v) => setState(() => _hoverRating = v),
            onSelect: (v) => setState(() {
              _rating = v;
              _hoverRating = 0;
            }),
          ),
          if (_rating > 0) ...[
            const SizedBox(height: 8),
            Text(
              _ratingLabel(_rating),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
                color: Color(0xFF4C4546),
              ),
            ),
          ],

          const SizedBox(height: 32),

          // ── Review title ──────────────────────────────────────
          const _FieldLabel(text: 'REVIEW TITLE'),
          const SizedBox(height: 10),
          _StyledTextField(
            controller: _titleController,
            hint: 'Summarise your experience',
            maxLength: 80,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Please add a title';
              }
              return null;
            },
          ),

          const SizedBox(height: 24),

          // ── Review body ───────────────────────────────────────
          const _FieldLabel(text: 'YOUR REVIEW'),
          const SizedBox(height: 10),
          _StyledTextField(
            controller: _bodyController,
            hint:
                'What did you like or dislike? How does it fit? '
                'Would you recommend it?',
            maxLines: 6,
            maxLength: 800,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Please write your review';
              }
              if (v.trim().length < 20) {
                return 'Review must be at least 20 characters';
              }
              return null;
            },
          ),

          const SizedBox(height: 32),

          // ── Photo upload ──────────────────────────────────────
          const _FieldLabel(text: 'ADD PHOTOS (OPTIONAL)'),
          const SizedBox(height: 4),
          Text(
            'Up to $_maxPhotos photos • JPG, PNG',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: Color(0xFF4C4546),
            ),
          ),
          const SizedBox(height: 12),
          _PhotoPicker(
            photos: _photos,
            maxPhotos: _maxPhotos,
            onPickTap: _pickPhotos,
            onRemove: _removePhoto,
          ),

          const SizedBox(height: 40),

          // ── Submit button ─────────────────────────────────────
          _SubmitButton(
            submitting: _submitting || widget.externalLoading,
            onTap: _submit,
          ),

          const SizedBox(height: 16),

          // Disclaimer
          const Text(
            'Reviews are public and attributed to your display name. '
            'By submitting, you agree to our review guidelines.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              height: 1.6,
              color: Color(0xFF7E7576),
            ),
          ),
        ],
      ),
    );
  }

  String _ratingLabel(double r) {
    switch (r.toInt()) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }
}

// ── Star picker ──────────────────────────────────────────────────

class _StarPicker extends StatelessWidget {
  final double rating;
  final double hoverRating;
  final ValueChanged<double> onHover;
  final ValueChanged<double> onSelect;

  const _StarPicker({
    required this.rating,
    required this.hoverRating,
    required this.onHover,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final display = hoverRating > 0 ? hoverRating : rating;

    return MouseRegion(
      onExit: (_) => onHover(0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          final starValue = (i + 1).toDouble();
          final filled = display >= starValue;

          return MouseRegion(
            onEnter: (_) => onHover(starValue),
            child: GestureDetector(
              onTap: () => onSelect(starValue),
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 120),
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    key: ValueKey('$i-$filled'),
                    size: 40,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Photo picker strip ───────────────────────────────────────────

class _PhotoPicker extends StatelessWidget {
  final List<PlatformFile> photos;
  final int maxPhotos;
  final VoidCallback onPickTap;
  final ValueChanged<int> onRemove;

  const _PhotoPicker({
    required this.photos,
    required this.maxPhotos,
    required this.onPickTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        // Existing photo thumbnails
        ...List.generate(photos.length, (i) {
          final file = photos[i];
          return _PhotoThumb(
            file: file,
            onRemove: () => onRemove(i),
          );
        }),

        // Add button — only show if under the limit
        if (photos.length < maxPhotos)
          GestureDetector(
            onTap: onPickTap,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFFCFC4C5),
                  style: BorderStyle.solid,
                ),
                color: const Color(0xFFF3F3F4),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      size: 24, color: Color(0xFF4C4546)),
                  SizedBox(height: 4),
                  Text(
                    'ADD',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: Color(0xFF4C4546),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  final PlatformFile file;
  final VoidCallback onRemove;

  const _PhotoThumb({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 80,
          height: 80,
          color: const Color(0xFFEEEEEE),
          child: kIsWeb
              ? (file.bytes != null
                  ? Image.memory(file.bytes!, fit: BoxFit.cover)
                  : const Icon(Icons.image_outlined,
                      color: Color(0xFFCFC4C5)))
              : (file.path != null
                  ? Image.file(File(file.path!), fit: BoxFit.cover)
                  : const Icon(Icons.image_outlined,
                      color: Color(0xFFCFC4C5))),
        ),
        // Remove button
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shared sub-widgets ───────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.7,
        color: Colors.black,
      ),
    );
  }
}

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final int? maxLength;
  final String? Function(String?)? validator;

  const _StyledTextField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.maxLength,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      validator: validator,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        color: Colors.black,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          color: Color(0xFFCFC4C5),
        ),
        filled: true,
        fillColor: const Color(0xFFF3F3F4),
        counterStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          color: Color(0xFF7E7576),
        ),
        contentPadding: const EdgeInsets.all(16),
        // Sharp corners — matches the monochrome theme
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(0),
          borderSide: const BorderSide(color: Color(0xFFCFC4C5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(0),
          borderSide: const BorderSide(color: Color(0xFFCFC4C5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(0),
          borderSide: const BorderSide(color: Colors.black, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(0),
          borderSide: const BorderSide(color: Color(0xFFBA1A1A)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(0),
          borderSide: const BorderSide(color: Color(0xFFBA1A1A), width: 2),
        ),
        errorStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          color: Color(0xFFBA1A1A),
        ),
      ),
    );
  }
}

class _SubmitButton extends StatefulWidget {
  final bool submitting;
  final VoidCallback onTap;

  const _SubmitButton({required this.submitting, required this.onTap});

  @override
  State<_SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<_SubmitButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        if (!widget.submitting) widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          color: Colors.black,
          alignment: Alignment.center,
          child: widget.submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'SUBMIT REVIEW',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}