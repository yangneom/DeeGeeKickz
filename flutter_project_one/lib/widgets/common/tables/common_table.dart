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

  // headers = list of column titles
  // example: ['Reference Number', 'Date & Time', 'Total']
  final List<String> headers;

  // rows = list of rows
  // each row is a list of widgets (not just text!)
  // so we can put anything inside a cell —
  // text, badges, buttons, icons, etc.
  // example: [[Text('123456'), Text('Feb 13'), Text('5,500')]]
  final List<List<Widget>> rows;

  const CommonTable({
    super.key,
    required this.headers,
    required this.rows,
  });

  // ================================================
  // BUILD HEADER ROW
  // This builds the top row with column titles
  // ================================================
  Widget _buildHeaderRow() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Row(
        children: headers.map((String header) {

          // each header takes equal space
          return Expanded(
            child: Text(
              header,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ================================================
  // BUILD ONE DATA ROW
  // This builds one row of data in the table
  // ================================================
  Widget _buildDataRow(List<Widget> rowCells, int rowIndex) {

    // alternate row background color
    // even rows = white, odd rows = light gray
    Color rowColor = Colors.white;
    if (rowIndex % 2 != 0) {
      rowColor = const Color(0xFFF9FAFB);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: rowColor,
        border: const Border(
          bottom: BorderSide(
            color: Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Row(
        children: rowCells.map((Widget cell) {

          // each cell takes equal space
          return Expanded(
            child: cell,
          );
        }).toList(),
      ),
    );
  }

  // ================================================
  // BUILD — puts everything together
  // ================================================
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [

          // build the header row first
          _buildHeaderRow(),

          // then build each data row
          // we use a normal for loop so it is easy to understand
          for (int i = 0; i < rows.length; i = i + 1)
            _buildDataRow(rows[i], i),

          // show empty message if no data
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