import 'package:flutter/material.dart';

// ================================================
// COMMON TABLE
//
// This is a reusable table widget.
// Any page can use this table by passing:
//   - headers = the column titles
//   - rows    = the data to show
//
// Think of it like a blank spreadsheet.
// You give it the column names and the data,
// and it handles the design automatically!
// ================================================
class CommonTable extends StatelessWidget {

  final List<String> headers;
  final List<List<Widget>> rows;

  // Optional — lets a screen give some columns more room than others
  // (e.g. a long "Action" description vs. a short "Role"). Falls back
  // to equal width (flex: 1) for every column if not provided, so
  // every other screen using this table is unaffected.
  final List<int>? columnFlex;

  const CommonTable({
    super.key,
    required this.headers,
    required this.rows,
    this.columnFlex,
  });

  int _flexFor(int index) {
    if (columnFlex != null && index < columnFlex!.length) {
      return columnFlex![index];
    }
    return 1;
  }

  // ================================================
  // BUILD HEADER ROW
  // ================================================
  Widget _buildHeaderRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
           child: Row(
        children: [
          for (int i = 0; i < headers.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            Expanded(
              flex: _flexFor(i),
              child: Text(
                headers[i],
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ================================================
  // BUILD ONE DATA ROW
  // Every column now gets a 16px gutter before it (except the
  // first) — previously cells were placed directly adjacent with
  // zero gap, so text from one column ran straight into the next
  // (e.g. "Preparing" touching "Orders").
  // ================================================
  Widget _buildDataRow(List<Widget> rowCells, int rowIndex) {
    Color rowColor = Colors.white;
    if (rowIndex % 2 != 0) {
      rowColor = const Color(0xFFF9FAFB);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: rowColor,
        border: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
                children: [
          for (int i = 0; i < rowCells.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            Expanded(flex: _flexFor(i), child: rowCells[i]),
          ],
        ],
      ),
    );
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeaderRow(),
          for (int i = 0; i < rows.length; i = i + 1)
            _buildDataRow(rows[i], i),
          if (rows.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: const Text(
                'No data found.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ),
        ],
      ),
    );
  }
}