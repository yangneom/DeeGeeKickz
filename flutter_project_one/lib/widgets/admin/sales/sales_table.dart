import 'package:flutter/material.dart';
import 'package:flutter_project_one/models/sales_order.dart';
import 'package:flutter_project_one/widgets/common/app_data_table.dart';

// ================================================
// SALES TABLE
//
// This widget builds the sales table shown on the
// Sales Management screen.
//
// It takes a list of SalesOrder objects and converts
// them into rows that AppDataTable can display.
//
// AppDataTable handles all the UI drawing.
// This file just prepares the data/rows.
// ================================================
class SalesTable extends StatelessWidget {

  // the list of orders to show in the table
  final List<SalesOrder> orders;

  // called when the user taps the View button on a row
  final void Function(SalesOrder order)? onView;

  const SalesTable({
    super.key,
    required this.orders,
    this.onView,
  });

  // ================================================
  // FORMAT DATE
  // Converts DateTime to: "Feb 13, 2026 - 2:45 PM"
  // ================================================
  String _formatDate(DateTime dt) {
    List<String> months = [
      'Jan', 'Feb', 'Mar', 'Apr',
      'May', 'Jun', 'Jul', 'Aug',
      'Sep', 'Oct', 'Nov', 'Dec',
    ];

    // convert 24 hour to 12 hour format
    int hour = dt.hour;
    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour = hour - 12;
    }

    String minute = dt.minute.toString().padLeft(2, '0');
    String amPm   = dt.hour >= 12 ? 'PM' : 'AM';
    String month  = months[dt.month - 1];

    return '$month ${dt.day}, ${dt.year} – $hour:$minute $amPm';
  }

  // ================================================
  // FORMAT TOTAL
  // Converts 5500.0 to "5,500"
  // ================================================
  String _formatTotal(double amount) {
    String raw    = amount.toStringAsFixed(0);
    String result = '';
    int count     = 0;

    for (int i = raw.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        result = ',$result';
      }
      result = raw[i] + result;
      count++;
    }

    return result;
  }

  // ================================================
  // GET STATUS LABEL
  // Converts the enum value to a display string
  // ================================================
  String _getStatusLabel(SalesOrderStatus status) {
    if (status == SalesOrderStatus.cancelled) {
      return 'Cancelled';
    } else if (status == SalesOrderStatus.pending) {
      return 'Pending';
    } else if (status == SalesOrderStatus.confirmed) {
      return 'Confirmed';
    } else if (status == SalesOrderStatus.preparing) {
      return 'Preparing';
    } else if (status == SalesOrderStatus.shipped) {
      return 'Shipped';
    } else {
      return 'Unknown';
    }
  }

  // ================================================
  // GET STATUS COLOR
  // Returns the matching color for each status
  // ================================================
  Color _getStatusColor(SalesOrderStatus status) {
    if (status == SalesOrderStatus.cancelled) {
      return const Color(0xFFDC2626);
    } else if (status == SalesOrderStatus.pending) {
      return const Color(0xFF6B7280);
    } else if (status == SalesOrderStatus.confirmed) {
      return const Color(0xFF2563EB);
    } else if (status == SalesOrderStatus.preparing) {
      return const Color(0xFF7C3AED);
    } else if (status == SalesOrderStatus.shipped) {
      return const Color(0xFFF59E0B);
    } else {
      return const Color(0xFF6B7280);
    }
  }

  // ================================================
  // BUILD ROWS
  // Converts each SalesOrder into one AppTableRow
  // ================================================
  List<AppTableRow> _buildRows() {
    List<AppTableRow> rows = [];

    for (SalesOrder order in orders) {

      // prepare the cell values
      String dateStr     = _formatDate(order.dateTime);
      String totalStr    = _formatTotal(order.total);
      String statusLabel = _getStatusLabel(order.status);
      Color  statusColor = _getStatusColor(order.status);

      // -- status badge cell
      AppTableCell statusCell = AppTableCell.widget(
        AppStatusBadge(
          label: statusLabel,
          color: statusColor,
        ),
      );

      // -- view button cell
      AppTableCell actionCell = AppTableCell.widget(
        OutlinedButton(
          onPressed: () {
            if (onView != null) {
              onView!(order);
            }
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF374151),
            side: const BorderSide(color: Color(0xFFD1D5DB)),
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'View',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );

      // -- assemble all cells into one row
      AppTableRow row = AppTableRow(
        cells: [
          AppTableCell.text(order.referenceNumber),
          AppTableCell.text(dateStr),
          AppTableCell.text(totalStr),
          AppTableCell.text(order.paymentMethod),
          statusCell,
          actionCell,
        ],
      );

      rows.add(row);
    }

    return rows;
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {

    // -- column definitions for the sales table
    List<AppTableColumn> columns = const [
      AppTableColumn(label: 'Reference Number', flex: 2),
      AppTableColumn(label: 'Date & Time',      flex: 2.5),
      AppTableColumn(label: 'Total',            flex: 1.5),
      AppTableColumn(label: 'Payment Method',   flex: 2),
      AppTableColumn(label: 'Status',           flex: 1.5),
      AppTableColumn(label: 'Action',           flex: 1, isAction: true),
    ];

    // -- build the rows from the orders list
    List<AppTableRow> rows = _buildRows();

    return AppDataTable(
      columns: columns,
      rows: rows,
      emptyMessage: 'No orders found.',
    );
  }
}