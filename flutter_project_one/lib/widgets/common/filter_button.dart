import 'package:flutter/material.dart';
import 'filter_panel.dart';

// ================================================
// FILTER BUTTON — uses Overlay so the panel
// always appears on TOP of everything
// ================================================
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

  // overlay entry is what we insert on top of everything
  OverlayEntry? _overlayEntry;

  // key to get the position of the filter button
  final GlobalKey _buttonKey = GlobalKey();

  // ================================================
  // WHEN WIDGET UPDATES — rebuild overlay too
  // this is called when parent sends new selectedValue
  // ================================================
  @override
  void didUpdateWidget(FilterButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    // if panel is open and something changed rebuild overlay
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
    }
  }

  // ================================================
  // SHOW OVERLAY — creates panel on top of everything
  // ================================================
  void _showOverlay() {

    // get the position of the filter button on screen
    RenderBox renderBox =
        _buttonKey.currentContext!.findRenderObject() as RenderBox;

    // get the exact position on screen
    Offset position = renderBox.localToGlobal(Offset.zero);

    // create the overlay entry
    _overlayEntry = OverlayEntry(
      builder: (BuildContext context) {
        return Positioned(
          // position panel just below the button
          top: position.dy + renderBox.size.height + 6,
          left: position.dx,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              // prevent tap inside panel from closing it
              onTap: () {},
              child: FilterPanel(
                sections: widget.sections,
                selectedValue: widget.selectedValue,
                onValueChanged: (String? value) {
                  // update selected value in parent
                  widget.onValueChanged(value);

                  // rebuild overlay to show new selected state
                  _overlayEntry!.markNeedsBuild();
                },
                onClear: () {
                  // clear filters then close panel
                  widget.onClear();
                  _removeOverlay();
                },
                onApply: () {
                  // apply filters then close panel
                  widget.onApply();
                  _removeOverlay();
                },
              ),
            ),
          ),
        );
      },
    );

    // safely insert overlay AFTER the screen is fully drawn
    // this prevents the red screen crash!
    WidgetsBinding.instance.addPostFrameCallback((_) {

      // only insert if widget is still on screen
      if (mounted) {
        Overlay.of(context).insert(_overlayEntry!);
      }
    });
  }

  // ================================================
  // REMOVE OVERLAY — hides the panel
  // ================================================
  void _removeOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
  }

  // ================================================
  // TOGGLE — show or hide panel
  // ================================================
  void _toggle() {
    if (widget.isOpen == true) {
      _removeOverlay();
    } else {
      _showOverlay();
    }

    // tell parent to update isOpen state
    widget.onTap();
  }

  // remove overlay when widget is destroyed
  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _buttonKey,
      onTap: _toggle,
      child: Container(
        height: 42,
        width: 42,
        decoration: BoxDecoration(

          // blue background if open, white if closed
          color: widget.isOpen == true
              ? const Color(0xFFEFF6FF)
              : Colors.white,

          borderRadius: BorderRadius.circular(8),

          border: Border.all(
            // blue border if open, gray if closed
            color: widget.isOpen == true
                ? const Color(0xFF2563EB)
                : const Color(0xFFD1D5DB),
          ),
        ),
        child: Icon(
          Icons.filter_list,
          size: 18,
          // blue icon if open, gray if closed
          color: widget.isOpen == true
              ? const Color(0xFF2563EB)
              : const Color(0xFF6B7280),
        ),
      ),
    );
  }
}