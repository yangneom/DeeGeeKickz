import 'package:flutter/material.dart';

// ════════════════════════════════════════════════
// COLUMN DEFINITION
// ════════════════════════════════════════════════
class AppTableColumn {
  final String label;

  /// Relative width weight (like flex in Row).
  /// Defaults to 1.5.
  final double flex;

  /// Centres the header label and aligns action
  /// cells to the centre. Use for icon/button columns.
  final bool isAction;

  final TextAlign alignment;

  const AppTableColumn({
    required this.label,
    this.flex = 1.5,
    this.isAction = false,
    this.alignment = TextAlign.left,
  });
}

// ════════════════════════════════════════════════
// CELL  (plain text  OR  custom widget)
// ════════════════════════════════════════════════
class AppTableCell {
  final String? text;
  final Widget? widget;

  const AppTableCell.text(String value)
      : text = value,
        widget = null;

  const AppTableCell.widget(Widget child)
      : widget = child,
        text = null;
}

// ════════════════════════════════════════════════
// ROW DATA
// ════════════════════════════════════════════════
class AppTableRow {
  final List<AppTableCell> cells;

  /// Optional child rows — rendered as an indented,
  /// collapsible section beneath this row.
  final List<AppTableRow>? children;

  const AppTableRow({
    required this.cells,
    this.children,
  });
}

// ════════════════════════════════════════════════
// APP DATA TABLE  (reusable)
// ════════════════════════════════════════════════
///
/// A clean, scrollable data table used across the app.
/// Supports expandable rows (pass [AppTableRow.children]).
///
/// USAGE — Products / Inventory:
/// ```dart
/// AppDataTable(
///   columns: const [
///     AppTableColumn(label: 'Product Name', flex: 3),
///     AppTableColumn(label: 'Brand'),
///     AppTableColumn(label: 'Category'),
///     AppTableColumn(label: 'Total Stock'),
///     AppTableColumn(label: 'Average Price'),
///     AppTableColumn(label: 'Actions', isAction: true, flex: 1),
///   ],
///   rows: myRows,
/// )
/// ```
///
/// USAGE — Sales / Orders:
/// ```dart
/// AppDataTable(
///   columns: const [
///     AppTableColumn(label: 'Reference Number', flex: 2),
///     AppTableColumn(label: 'Date & Time', flex: 2),
///     AppTableColumn(label: 'Total'),
///     AppTableColumn(label: 'Payment Method', flex: 2),
///     AppTableColumn(label: 'Status', flex: 1.5),
///     AppTableColumn(label: 'Action', flex: 1),
///   ],
///   rows: myRows,
/// )
/// ```
class AppDataTable extends StatefulWidget {
  final List<AppTableColumn> columns;
  final List<AppTableRow> rows;
  final String emptyMessage;

  const AppDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.emptyMessage = 'No data available.',
  });

  @override
  State<AppDataTable> createState() => _AppDataTableState();
}

class _AppDataTableState extends State<AppDataTable> {
  final Set<int> _expanded = {};

  // ── Design tokens ─────────────────────────────
  static const Color _headerBg   = Color(0xFFF9FAFB);
  static const Color _rowBg      = Colors.white;
  static const Color _childBg    = Color(0xFFF3F4F6);
  static const Color _divider    = Color(0xFFE5E7EB);
  static const Color _headerText = Color(0xFF6B7280);
  static const Color _bodyText   = Color(0xFF111827);

  static const TextStyle _headerStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: _headerText,
  );

  static const TextStyle _cellStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: _bodyText,
  );

  // ── Helpers ───────────────────────────────────
  int _flex(AppTableColumn col) => (col.flex * 10).round();

  Widget _resolveCell(AppTableCell cell, AppTableColumn col) {
    if (cell.widget != null) return cell.widget!;
    return Text(
      cell.text ?? '—',
      style: _cellStyle,
      overflow: TextOverflow.ellipsis,
      textAlign: col.alignment,
    );
  }

  // ── Header ────────────────────────────────────
  Widget _header() {
    return Container(
      color: _headerBg,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: widget.columns.map((col) {
          return Expanded(
            flex: _flex(col),
            child: Text(
              col.label,
              style: _headerStyle,
              textAlign: col.isAction ? TextAlign.center : col.alignment,
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Data row ──────────────────────────────────
  Widget _row(AppTableRow row, int index, {bool isChild = false}) {
    final bool hasChildren =
        row.children != null && row.children!.isNotEmpty;
    final bool expanded = _expanded.contains(index);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Row itself
        InkWell(
          onTap: hasChildren
              ? () => setState(() =>
                  expanded ? _expanded.remove(index) : _expanded.add(index))
              : null,
          child: Container(
            color: isChild ? _childBg : _rowBg,
            padding: EdgeInsets.symmetric(
              horizontal: isChild ? 36 : 20,
              vertical: 16,
            ),
            child: Row(
              children: List.generate(widget.columns.length, (ci) {
                final col  = widget.columns[ci];
                final cell = ci < row.cells.length
                    ? row.cells[ci]
                    : const AppTableCell.text('—');

                // First col gets expand chevron when expandable
                Widget content = _resolveCell(cell, col);
                if (ci == 0 && hasChildren && !isChild) {
                  content = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedRotation(
                        turns: expanded ? 0.0 : -0.25,
                        duration: const Duration(milliseconds: 180),
                        child: const Icon(Icons.expand_more,
                            size: 16, color: Color(0xFF6B7280)),
                      ),
                      const SizedBox(width: 6),
                      Expanded(child: content),
                    ],
                  );
                }

                return Expanded(flex: _flex(col), child: content);
              }),
            ),
          ),
        ),

        const Divider(height: 1, thickness: 1, color: _divider),

        // ── Child rows (expanded)
        if (expanded && hasChildren)
          ...row.children!
              .map((child) => _row(child, index, isChild: true)),
      ],
    );
  }

  // ── Empty state ───────────────────────────────
  Widget _empty() {
    return Container(
      color: _rowBg,
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined,
                size: 40, color: Color(0xFFD1D5DB)),
            const SizedBox(height: 12),
            Text(widget.emptyMessage,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF9CA3AF))),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _divider),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            const Divider(height: 1, thickness: 1, color: _divider),
            if (widget.rows.isEmpty)
              _empty()
            else
              ...List.generate(
                widget.rows.length,
                (i) => _row(widget.rows[i], i),
              ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// APP STATUS BADGE  (re-exported from common)
// ════════════════════════════════════════════════
/// Coloured pill badge for status columns.
///
/// ```dart
/// AppStatusBadge(label: 'Shipped',   color: Color(0xFFF59E0B))
/// AppStatusBadge(label: 'Pending',   color: Color(0xFF6B7280))
/// AppStatusBadge(label: 'Confirmed', color: Color(0xFF2563EB))
/// AppStatusBadge(label: 'Preparing', color: Color(0xFF7C3AED))
/// AppStatusBadge(label: 'Cancelled', color: Color(0xFFDC2626))
/// ```
class AppStatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const AppStatusBadge({
    super.key,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}