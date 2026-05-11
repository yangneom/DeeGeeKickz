import 'package:flutter/material.dart';
import 'filter_panel.dart';

class FilterButton extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onTap;
  final List<FilterSection> sections;
  final String? selectedValue;
  final Function(String?) onValueChanged;
  final VoidCallback onClear;
  final VoidCallback onApply;

  const FilterButton({
    super.key,
    required this.isOpen,
    required this.onTap,
    required this.sections,
    required this.selectedValue,
    required this.onValueChanged,
    required this.onClear,
    required this.onApply,
  });

  @override
  State<FilterButton> createState() => _FilterButtonState();
}

class _FilterButtonState extends State<FilterButton> {
  OverlayEntry? _overlayEntry;
  final GlobalKey _buttonKey = GlobalKey();

  @override
  void didUpdateWidget(FilterButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
    }
  }

  void _showOverlay() {
    try {
      // get the position of the filter button on screen
      final keyContext = _buttonKey.currentContext;
      if (keyContext == null) {
        debugPrint('FilterButton: _buttonKey context is null, skipping overlay');
        return;
      }

      final renderBox = keyContext.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.attached) {
        debugPrint('FilterButton: RenderBox is null or detached, skipping overlay');
        return;
      }

      final position = renderBox.localToGlobal(Offset.zero);

      _overlayEntry = OverlayEntry(
        builder: (BuildContext context) {
          return Positioned(
            top: position.dy + renderBox.size.height + 6,
            left: position.dx,
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: () {},
                child: FilterPanel(
                  sections: widget.sections,
                  selectedValue: widget.selectedValue,
                  onValueChanged: (String? value) {
                    try {
                      widget.onValueChanged(value);
                      _overlayEntry?.markNeedsBuild();
                    } catch (e) {
                      debugPrint('FilterButton: error on value changed: $e');
                    }
                  },
                  onClear: () {
                    try {
                      widget.onClear();
                      _removeOverlay();
                    } catch (e) {
                      debugPrint('FilterButton: error on clear: $e');
                      _removeOverlay();
                    }
                  },
                  onApply: () {
                    try {
                      widget.onApply();
                      _removeOverlay();
                    } catch (e) {
                      debugPrint('FilterButton: error on apply: $e');
                      _removeOverlay();
                    }
                  },
                ),
              ),
            ),
          );
        },
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          if (mounted) {
            Overlay.of(context).insert(_overlayEntry!);
          }
        } catch (e) {
          debugPrint('FilterButton: error inserting overlay: $e');
          _overlayEntry = null;
        }
      });

    } catch (e) {
      debugPrint('FilterButton: unexpected error in _showOverlay: $e');
      _overlayEntry = null;
    }
  }

  void _removeOverlay() {
    try {
      if (_overlayEntry != null) {
        _overlayEntry!.remove();
        _overlayEntry = null;
      }
    } catch (e) {
      debugPrint('FilterButton: error removing overlay: $e');
      _overlayEntry = null; // still null it out even if remove() fails
    }
  }

  void _toggle() {
    try {
      if (widget.isOpen == true) {
        _removeOverlay();
      } else {
        _showOverlay();
      }
      widget.onTap();
    } catch (e) {
      debugPrint('FilterButton: error in _toggle: $e');
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _buttonKey,
      onTap: _toggle,
      child: Container(
        height: 42,
        width: 42,
        decoration: BoxDecoration(
          color: widget.isOpen == true
              ? const Color(0xFFEFF6FF)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.isOpen == true
                ? const Color(0xFF2563EB)
                : const Color(0xFFD1D5DB),
          ),
        ),
        child: Icon(
          Icons.filter_list,
          size: 18,
          color: widget.isOpen == true
              ? const Color(0xFF2563EB)
              : const Color(0xFF6B7280),
        ),
      ),
    );
  }
}