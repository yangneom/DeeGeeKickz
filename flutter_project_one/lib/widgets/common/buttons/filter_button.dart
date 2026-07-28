import 'package:flutter/material.dart';
import 'filter_panel.dart';

class FilterButton extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onTap;
  final List<FilterSection> sections;
  final Map<String, String?> selectedValues;
  final void Function(String sectionTitle, String? value) onValueChanged;
  final VoidCallback onClear;
  final VoidCallback onApply;

  const FilterButton({
    super.key,
    required this.isOpen,
    required this.onTap,
    required this.sections,
    required this.selectedValues,
    required this.onValueChanged,
    required this.onClear,
    required this.onApply,
  });

  @override
  State<FilterButton> createState() => _FilterButtonState();
}

class _FilterButtonState extends State<FilterButton> {
  final OverlayPortalController _controller = OverlayPortalController();
  final LayerLink _layerLink = LayerLink();

  @override
  void didUpdateWidget(FilterButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isOpen != widget.isOpen) {
      // Defer to after this build completes — calling show()/hide()
      // synchronously here (mid-build) is what caused
      // "setState() or markNeedsBuild() called during build".
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.isOpen && !_controller.isShowing) {
          _controller.show();
        } else if (!widget.isOpen && _controller.isShowing) {
          _controller.hide();
        }
      });
    }
  }

  void _toggle() {
    // Only flip the parent's state. The controller is kept in sync
    // exclusively through didUpdateWidget above — toggling it here
    // too caused a double-toggle race (source of the layout/assertion
    // crashes when tapped quickly).
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: OverlayPortal(
        controller: _controller,
        overlayChildBuilder: (BuildContext overlayContext) {
          // Positioned.fill — NOT Positioned(width: ...). A Positioned
          // inside the Overlay's Stack needs full constraints or the
          // layout pass runs inconsistently ("Each child must be laid
          // out exactly once" / box.dart:2251). CompositedTransformFollower
          // does the actual placement inside this full-size area.
          return Positioned.fill(
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 48),
              child: Align(
                alignment: Alignment.topLeft,
                child: Material(
                  color: Colors.transparent,
                  child: FilterPanel(
                    sections: widget.sections,
                    selectedValues: widget.selectedValues,
                    onValueChanged: widget.onValueChanged,
                    onClear: () {
                      widget.onClear();
                      _controller.hide();
                    },
                    onApply: () {
                      widget.onApply();
                      _controller.hide();
                    },
                  ),
                ),
              ),
            ),
          );
        },
        child: GestureDetector(
          onTap: _toggle,
          child: Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: widget.isOpen
                  ? const Color(0xFFEFF6FF)
                  : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.isOpen
                    ? const Color(0xFF2563EB)
                    : const Color(0xFFD1D5DB),
              ),
            ),
            child: Icon(
              Icons.filter_list,
              size: 18,
              color: widget.isOpen
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF6B7280),
            ),
          ),
        ),
      ),
    );
  }
}