import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/common/tables/common_table.dart';
import '../../../widgets/common/buttons/search_bar.dart';
import '../../../widgets/common/buttons/filter_button.dart';
import '../../../widgets/common/buttons/filter_panel.dart';
import '../../../widgets/admin/feedback/feedback_details_dialog.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {

  // ================================================
  // CONTROLLERS AND STATE
  // ================================================

  // controls the search text field
  final TextEditingController _searchController = TextEditingController();

  // controls if filter panel is visible
  bool _showFilterPanel = false;

  // currently selected filter value
  String? _selectedStatus;

  // ================================================
  // FAKE DATA — just for testing
  // later this will come from Firebase
  // ================================================
  final List<Map<String, dynamic>> _allFeedback = [
    {
      'customerName': 'Angel Tuazon',
      'productReviewed': 'Sneakers',
      'comment': 'Pangit niyu',
      'rating': 3,
      'datePosted': '05/06/25',
      'status': 'Flagged',
    },
    {
      'customerName': 'Jay Galang',
      'productReviewed': 'Sneakers',
      'comment': 'Ang ganda nmn',
      'rating': 4,
      'datePosted': '05/06/25',
      'status': 'Visible',
    },
    {
      'customerName': 'Maria Santos',
      'productReviewed': 'Running Shoes',
      'comment': 'Very comfortable!',
      'rating': 5,
      'datePosted': '05/07/25',
      'status': 'Visible',
    },
    {
      'customerName': 'Carlo Reyes',
      'productReviewed': 'Basketball Shoes',
      'comment': 'Medyo mahal pero ok naman',
      'rating': 3,
      'datePosted': '05/08/25',
      'status': 'Flagged',
    },
  ];

  // filtered list shown in the table
  List<Map<String, dynamic>> _filteredFeedback = [];

  // ================================================
  // INIT STATE — runs when screen first loads
  // ================================================
  @override
  void initState() {
    super.initState();

    // show all feedback at the start
    _filteredFeedback = _allFeedback;
  }

  // ================================================
  // DISPOSE — clean up controller when screen closes
  // ================================================
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ================================================
  // APPLY FILTERS
  // filters the list based on search text and status
  // ================================================
  void _applyFilters() {

    // get search text and make it lowercase
    String searchQuery = _searchController.text.toLowerCase();

    // this will hold our filtered results
    List<Map<String, dynamic>> results = [];

    // loop through all feedback
    for (int i = 0; i < _allFeedback.length; i = i + 1) {

      // get current feedback item
      Map<String, dynamic> item = _allFeedback[i];

      // check if item matches search query
      bool matchesSearch = true;

      if (searchQuery.isNotEmpty) {

        // check if customer name contains search text
        bool nameMatch = item['customerName']!
            .toString()
            .toLowerCase()
            .contains(searchQuery);

        // check if product name contains search text
        bool productMatch = item['productReviewed']!
            .toString()
            .toLowerCase()
            .contains(searchQuery);

        // matches if either name or product matches
        matchesSearch = nameMatch || productMatch;
      }

      // if search does not match skip this item
      if (matchesSearch == false) {
        continue;
      }

      // check if item matches selected status
      bool matchesStatus = true;

      if (_selectedStatus != null) {
        matchesStatus = item['status'] == _selectedStatus;
      }

      // if status does not match skip this item
      if (matchesStatus == false) {
        continue;
      }

      // if both match add to results
      results.add(item);
    }

    // update the filtered list
    setState(() {
      _filteredFeedback = results;
    });
  }

  // ================================================
  // CLEAR FILTERS — resets everything
  // ================================================
  void _clearFilters() {
    setState(() {
      _selectedStatus = null;
      _searchController.clear();
      _filteredFeedback = _allFeedback;
      _showFilterPanel = false;
    });
  }

  // ================================================
  // BUILD STATUS BADGE
  // red badge for Flagged, blue badge for Visible
  // ================================================
  Widget _buildStatusBadge(String status) {

    // default colors
    Color backgroundColor = Colors.grey.shade100;
    Color textColor = Colors.grey;
    Color borderColor = Colors.grey.shade300;

    if (status == 'Flagged') {
      backgroundColor = const Color(0xFFFEE2E2);
      textColor = const Color(0xFFDC2626);
      borderColor = const Color(0xFFFCA5A5);
    }

    if (status == 'Visible') {
      backgroundColor = const Color(0xFFEFF6FF);
      textColor = const Color(0xFF2563EB);
      borderColor = const Color(0xFFBFDBFE);
    }

    // Align keeps badge its natural size
    // without Align it stretches to full column width
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          status,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
      ),
    );
  }

  // ================================================
  // BUILD STAR RATING
  // shows filled and empty stars based on rating
  // ================================================
  Widget _buildStarRating(int rating) {

    // we always show 5 stars total
    int totalStars = 5;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalStars, (int index) {

        // if index is less than rating show filled star
        // otherwise show empty star
        if (index < rating) {
          return const Icon(
            Icons.star,
            size: 16,
            color: Color(0xFFF59E0B), // amber/yellow
          );
        } else {
          return const Icon(
            Icons.star_border,
            size: 16,
            color: Color(0xFFD1D5DB), // gray
          );
        }
      }),
    );
  }

  // ================================================
  // BUILD TABLE ROWS
  // converts filtered feedback into table rows
  // ================================================
  List<List<Widget>> _buildRows() {

    // this will hold all our rows
    List<List<Widget>> tableRows = [];

    // loop through each filtered feedback item
    for (int i = 0; i < _filteredFeedback.length; i = i + 1) {

      // get the current feedback item
      Map<String, dynamic> item = _filteredFeedback[i];

      // build one row — each entry is one cell
      List<Widget> oneRow = [

        // column 1 — customer name
        Text(
          item['customerName'],
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF111827),
          ),
        ),

        // column 2 — product reviewed
        Text(
          item['productReviewed'],
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF111827),
          ),
        ),

        // column 3 — comment message
        // gray text to look less prominent
        Text(
          item['comment'],
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF6B7280),
          ),
          // if comment is too long cut it off with ...
          overflow: TextOverflow.ellipsis,
        ),

        // column 4 — star rating widget
        _buildStarRating(item['rating']),

        // column 5 — date posted
        Text(
          item['datePosted'],
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF111827),
          ),
        ),

        // column 6 — status badge
        _buildStatusBadge(item['status']),

        // column 7 — view button
        // Align keeps button its natural size
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            // View button onPressed
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext dialogContext) {
                  return FeedbackDetailsDialog(
                    // pass the feedback data in
                    feedback: item,

                    // called when admin clicks Save Reply
                    onSave: (String newStatus, String adminReply) {

                      // update the item in the main list
                      setState(() {
                        for (int j = 0; j < _allFeedback.length; j = j + 1) {
                          if (_allFeedback[j]['customerName'] == item['customerName']) {
                            _allFeedback[j]['status'] = newStatus;
                            _allFeedback[j]['adminReply'] = adminReply;
                            break;
                          }
                        }

                        // re-apply filters so table reflects changes
                        _applyFilters();
                      });
                    },
                  );
                },
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF374151),
              side: const BorderSide(
                color: Color(0xFFD1D5DB),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text(
              'View',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ),
      ];

      // add this row to the list
      tableRows.add(oneRow);
    }

    return tableRows;
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: GestureDetector(

        // close filter panel when tapping outside
        onTap: () {
          if (_showFilterPanel == true) {
            setState(() {
              _showFilterPanel = false;
            });
          }
        },

        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ================================================
              // TOP ROW — TITLE
              // ================================================
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // main title
                  Text(
                    'Feedback Management',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),

                  SizedBox(height: 4),

                  // subtitle
                  Text(
                    'View and manage customer feedback and reviews.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ================================================
              // SECOND ROW — SEARCH + FILTER
              // ================================================
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [

                  // search bar — reusable common widget
                  CommonSearchBar(
                    controller: _searchController,
                    hintText: 'Search feedback...',
                    onChanged: (String value) {
                      // filter every time user types
                      _applyFilters();
                    },
                  ),

                  const SizedBox(width: 8),

                  // filter button — reusable common widget
                  FilterButton(
                    isOpen: _showFilterPanel,

                    // toggle open and close
                    onTap: () {
                      setState(() {
                        _showFilterPanel = !_showFilterPanel;
                      });
                    },

                    // pass current selected value
                    selectedValue: _selectedStatus,

                    // when user picks an option
                    onValueChanged: (String? value) {
                      setState(() {
                        _selectedStatus = value;
                      });
                    },

                    // when user clicks clear
                    onClear: _clearFilters,

                    // when user clicks apply
                    onApply: () {
                      _applyFilters();
                      setState(() {
                        _showFilterPanel = false;
                      });
                    },

                    // feedback filter sections
                    sections: [
                      FilterSection(
                        title: 'Status',
                        options: [
                          FilterOption(
                            label: 'Visible',
                            value: 'Visible',
                          ),
                          FilterOption(
                            label: 'Flagged',
                            value: 'Flagged',
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ================================================
              // FEEDBACK TABLE
              // ================================================
              Expanded(
                child: SingleChildScrollView(
                  child: CommonTable(
                    headers: const [
                      'Customer Name',
                      'Product Reviewed',
                      'Comment Message',
                      'Rating',
                      'Date Posted',
                      'Status',
                      'Action',
                    ],
                    rows: _buildRows(),
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