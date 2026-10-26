// lib/widgets/common/forms/app_dropdown_field.dart

import 'package:flutter/material.dart';

// ================================================
// APP DROPDOWN FIELD
//
// ONE dropdown used everywhere, with two looks:
//
//   AppDropdownStyle.admin    (default)
//     Same language as the Discount and product dialogs: rounded corners
//     (radius 8), #D1D5DB border, #F9FAFB fill, 13px text, a blue (#2563EB)
//     border while open, and a menu with a #E5E7EB border, 40px rows, a
//     light hover, and the chosen row in blue with a tick.
//
//   AppDropdownStyle.customer
//     Matches the customer address sheet: square corners, #CFC4C5 border,
//     white fill, Inter 14px, a black border while open, and a menu with
//     the same square, flat look (the chosen row is bold with a tick).
//
// WHAT IT KEEPS FROM THE OLD DROPDOWNS
//   - the same inputs: hint, value, items, onChanged, validator
//   - validator errors show under the field, in red, and clear once a value is
//     chosen (just like DropdownButtonFormField did)
//   - onChanged == null (or enabled == false) greys the field out and
//     stops it opening
//
// WHY IT IS BUILT ON PopupMenuButton, NOT DropdownButton: Flutter's own
// DropdownButton menu cannot have a border and its rows cannot be shorter than
// 48px, so it could never match the Discount look. A popup menu opens on the
// app's top layer, so inside a dialog or a bottom sheet it is never clipped or
// hidden behind other widgets, and it moves up if there is no room below.
// ================================================

enum AppDropdownStyle { admin, customer }

class AppDropdownField<T> extends StatefulWidget {
  /// Shown when nothing is chosen.
  final String hint;

  /// The chosen item, or null.
  final T? value;

  final List<T> items;

  /// The text shown for an item.
  final String Function(T item) labelOf;

  /// Called with the new item. null makes the field read-only (greyed out).
  final ValueChanged<T?>? onChanged;

  /// Same idea as DropdownButtonFormField.validator. Needs a surrounding Form.
  final String? Function(T? value)? validator;

  final bool enabled;

  final AppDropdownStyle style;

  /// A smaller field (36px, 12px text) for filter bars. Admin look only.
  final bool dense;

  /// If set, the menu starts with an extra row of this text that sets the
  /// value back to null (for example "All" in a filter).
  final String? nullOptionLabel;

  /// Overrides, to match a neighbouring field in the same form.
  final Color? fillColor;
  final Color? borderColor;

  /// The tallest the open menu may be before it scrolls.
  final double menuMaxHeight;

  const AppDropdownField({
    super.key,
    required this.hint,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
    this.validator,
    this.enabled = true,
    this.style = AppDropdownStyle.admin,
    this.dense = false,
    this.nullOptionLabel,
    this.fillColor,
    this.borderColor,
    this.menuMaxHeight = 280,
  });

  @override
  State<AppDropdownField<T>> createState() => _AppDropdownFieldState<T>();
}

// A menu row's result. A PopupMenuButton treats a null result as "the menu was
// closed without a choice", so "choose nothing / All" is wrapped in an object
// that is never null.
class _Choice<T> {
  final T? value;
  const _Choice(this.value);
}

class _AppDropdownFieldState<T> extends State<AppDropdownField<T>> {
  bool _open = false;

  String? _labelForValue() {
    final T? current = widget.value;
    if (current == null) return null;
    return widget.labelOf(current);
  }

  PopupMenuItem<_Choice<T>> _menuItem(
    _Skin s,
    T? item,
    String label,
    bool selected,
  ) {
    return PopupMenuItem<_Choice<T>>(
      value: _Choice<T>(item),
      height: s.rowHeight,
      padding: EdgeInsets.zero,
      child: Container(
        height: s.rowHeight,
        padding: EdgeInsets.symmetric(horizontal: s.hPad),
        color: selected ? s.selectedBg : null,
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: selected ? s.selectedStyle : s.itemStyle,
              ),
            ),
            if (selected) Icon(Icons.check, size: 16, color: s.accent),
          ],
        ),
      ),
    );
  }

  List<PopupMenuEntry<_Choice<T>>> _buildEntries(_Skin s) {
    final List<PopupMenuEntry<_Choice<T>>> entries =
        <PopupMenuEntry<_Choice<T>>>[];
    final T? current = widget.value;

    if (widget.nullOptionLabel != null) {
      entries.add(_menuItem(s, null, widget.nullOptionLabel!, current == null));
    }

    for (final T item in widget.items) {
      entries.add(
        _menuItem(s, item, widget.labelOf(item), current != null && item == current),
      );
    }

    if (entries.isEmpty) {
      entries.add(
        PopupMenuItem<_Choice<T>>(
          enabled: false,
          height: s.rowHeight,
          padding: EdgeInsets.zero,
          child: Container(
            height: s.rowHeight,
            padding: EdgeInsets.symmetric(horizontal: s.hPad),
            alignment: Alignment.centerLeft,
            child: Text('No options available', style: s.hintStyle),
          ),
        ),
      );
    }

    return entries;
  }

  Widget _buildBox(_Skin s, bool hasError, bool isEnabled) {
    final String? selectedLabel = _labelForValue();
    final bool hasValue = selectedLabel != null;

    final Color borderColor = hasError
        ? s.errorBorder
        : (_open ? s.focusBorder : (widget.borderColor ?? s.border));
    final double borderWidth = (_open && !hasError) ? s.focusWidth : 1;

    final TextStyle textStyle = !hasValue
        ? s.hintStyle
        : (isEnabled
            ? s.valueStyle
            : s.valueStyle.copyWith(color: s.hintStyle.color));

    return Container(
      height: s.boxHeight,
      padding: EdgeInsets.symmetric(horizontal: s.hPad),
      decoration: BoxDecoration(
        color: isEnabled ? (widget.fillColor ?? s.fill) : s.disabledFill,
        borderRadius: BorderRadius.circular(s.radius),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              hasValue ? selectedLabel : widget.hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
          Icon(
            _open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            size: 20,
            color: s.arrow,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final _Skin s = _Skin.of(widget.style, widget.dense);
    final bool isEnabled = widget.enabled && widget.onChanged != null;

    return FormField<T>(
      initialValue: widget.value,
      // Judge the value the parent holds RIGHT NOW (not a stale copy kept
      // inside the form field), the same way DropdownButtonFormField did.
      validator: widget.validator == null
          ? null
          : (T? _) => widget.validator!(widget.value),
      builder: (FormFieldState<T> field) {
        final String? errorText = field.errorText;
        final bool hasError = errorText != null;

        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // The menu is exactly as wide as the field.
            final double width =
                constraints.maxWidth.isFinite ? constraints.maxWidth : 260;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Theme(
                  data: Theme.of(context).copyWith(
                    hoverColor: s.hover,
                    highlightColor: Colors.transparent,
                    splashColor: s.hover,
                  ),
                  child: PopupMenuButton<_Choice<T>>(
                    enabled: isEnabled,
                    tooltip: '',
                    padding: EdgeInsets.zero,
                    position: PopupMenuPosition.under,
                    offset: const Offset(0, 4),
                    color: Colors.white,
                    surfaceTintColor: Colors.transparent,
                    shadowColor: Colors.black.withOpacity(0.2),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(s.menuRadius),
                      side: BorderSide(color: s.menuBorder),
                    ),
                    constraints: BoxConstraints(
                      minWidth: width,
                      maxWidth: width,
                      maxHeight: widget.menuMaxHeight,
                    ),
                    onOpened: () => setState(() => _open = true),
                    onCanceled: () => setState(() => _open = false),
                    onSelected: (_Choice<T> choice) {
                      setState(() => _open = false);
                      widget.onChanged?.call(choice.value);
                      field.didChange(choice.value);
                      // After the parent has rebuilt with the new value, clear
                      // a leftover error (only if one is showing).
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && field.mounted && field.hasError) {
                          field.validate();
                        }
                      });
                    },
                    itemBuilder: (BuildContext _) => _buildEntries(s),
                    child: _buildBox(s, hasError, isEnabled),
                  ),
                ),
                if (hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(errorText, style: s.errorStyle),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

// ================================================
// LOOKS
// ================================================
class _Skin {
  final double radius;
  final double menuRadius;
  final double boxHeight;
  final double rowHeight;
  final double hPad;
  final double focusWidth;

  final Color fill;
  final Color disabledFill;
  final Color border;
  final Color focusBorder;
  final Color errorBorder;
  final Color menuBorder;
  final Color selectedBg;
  final Color hover;
  final Color accent;
  final Color arrow;

  final TextStyle hintStyle;
  final TextStyle valueStyle;
  final TextStyle itemStyle;
  final TextStyle selectedStyle;
  final TextStyle errorStyle;

  const _Skin({
    required this.radius,
    required this.menuRadius,
    required this.boxHeight,
    required this.rowHeight,
    required this.hPad,
    required this.focusWidth,
    required this.fill,
    required this.disabledFill,
    required this.border,
    required this.focusBorder,
    required this.errorBorder,
    required this.menuBorder,
    required this.selectedBg,
    required this.hover,
    required this.accent,
    required this.arrow,
    required this.hintStyle,
    required this.valueStyle,
    required this.itemStyle,
    required this.selectedStyle,
    required this.errorStyle,
  });

  static _Skin of(AppDropdownStyle style, bool dense) {
    if (style == AppDropdownStyle.customer) return _customer;
    return dense ? _adminDense : _admin;
  }

  // Values come from the Discount dialog and the product dialogs.
  static const _Skin _admin = _Skin(
    radius: 8,
    menuRadius: 8,
    boxHeight: 40,
    rowHeight: 40,
    hPad: 12,
    focusWidth: 1,
    fill: Color(0xFFF9FAFB),
    disabledFill: Color(0xFFF3F4F6),
    border: Color(0xFFD1D5DB),
    focusBorder: Color(0xFF2563EB),
    errorBorder: Color(0xFFDC2626),
    menuBorder: Color(0xFFE5E7EB),
    selectedBg: Color(0xFFEFF6FF),
    hover: Color(0xFFF3F4F6),
    accent: Color(0xFF2563EB),
    arrow: Color(0xFF9CA3AF),
    hintStyle: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
    valueStyle: TextStyle(fontSize: 13, color: Color(0xFF374151)),
    itemStyle: TextStyle(fontSize: 13, color: Color(0xFF374151)),
    selectedStyle: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Color(0xFF2563EB),
    ),
    errorStyle: TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
  );

  // The Stock Adjustment filter bar: 36px high, 12px text, 6px corners.
  static const _Skin _adminDense = _Skin(
    radius: 6,
    menuRadius: 6,
    boxHeight: 36,
    rowHeight: 36,
    hPad: 10,
    focusWidth: 1,
    fill: Colors.white,
    disabledFill: Color(0xFFF3F4F6),
    border: Color(0xFFD1D5DB),
    focusBorder: Color(0xFF2563EB),
    errorBorder: Color(0xFFDC2626),
    menuBorder: Color(0xFFE5E7EB),
    selectedBg: Color(0xFFEFF6FF),
    hover: Color(0xFFF3F4F6),
    accent: Color(0xFF2563EB),
    arrow: Color(0xFF9CA3AF),
    hintStyle: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
    valueStyle: TextStyle(fontSize: 12, color: Color(0xFF374151)),
    itemStyle: TextStyle(fontSize: 12, color: Color(0xFF374151)),
    selectedStyle: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Color(0xFF2563EB),
    ),
    errorStyle: TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
  );

  // Values come from the customer address sheet (square, #CFC4C5, Inter).
  static const _Skin _customer = _Skin(
    radius: 0,
    menuRadius: 0,
    boxHeight: 48,
    rowHeight: 44,
    hPad: 12,
    focusWidth: 1.5,
    fill: Colors.white,
    disabledFill: Color(0xFFF3F3F4),
    border: Color(0xFFCFC4C5),
    focusBorder: Colors.black,
    errorBorder: Color(0xFFBA1A1A),
    menuBorder: Color(0xFFCFC4C5),
    selectedBg: Color(0xFFF3F3F4),
    hover: Color(0xFFF9F9F9),
    accent: Colors.black,
    arrow: Color(0xFF656464),
    hintStyle: TextStyle(
      fontFamily: 'Inter',
      fontSize: 14,
      color: Color(0xFFCFC4C5),
    ),
    valueStyle: TextStyle(
      fontFamily: 'Inter',
      fontSize: 14,
      color: Colors.black,
    ),
    itemStyle: TextStyle(
      fontFamily: 'Inter',
      fontSize: 14,
      color: Colors.black,
    ),
    selectedStyle: TextStyle(
      fontFamily: 'Inter',
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: Colors.black,
    ),
    errorStyle: TextStyle(
      fontFamily: 'Inter',
      fontSize: 12,
      color: Color(0xFFBA1A1A),
    ),
  );
}