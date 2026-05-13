import 'package:flutter/material.dart';
import 'customer_list_item.dart';

// ================================================
// CUSTOMER MODEL
// blueprint for one customer in the list
// ================================================
class CustomerChat {

  // unique id for this customer
  String customerId;

  // customer name
  String customerName;

  // last message in the chat
  String lastMessage;

  // time of last message
  String time;

  // number of unread messages
  int unreadCount;

  CustomerChat({
    required this.customerId,
    required this.customerName,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
  });
}

// ================================================
// CUSTOMER LIST
//
// This is the LEFT side of the messages screen
//
// Shows:
//   - Search bar at the top
//   - List of customers below
// ================================================
class CustomerList extends StatefulWidget {

  // list of customers to show
  final List<CustomerChat> customers;

  // which customer is currently selected
  final String? selectedCustomerId;

  // what happens when user taps a customer
  final Function(CustomerChat customer) onCustomerSelected;

  const CustomerList({
    super.key,
    required this.customers,
    required this.selectedCustomerId,
    required this.onCustomerSelected,
  });

  @override
  State<CustomerList> createState() {
    return _CustomerListState();
  }
}

class _CustomerListState extends State<CustomerList> {

  // controls the search text field
  final TextEditingController _searchController = TextEditingController();

  // filtered list based on search
  List<CustomerChat> _filteredCustomers = [];

  @override
  void initState() {
    super.initState();

    // show all customers at start
    _filteredCustomers = widget.customers;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ================================================
  // APPLY SEARCH
  // filters customers by name
  // ================================================
  void _applySearch(String query) {

    // make query lowercase for comparison
    String searchQuery = query.toLowerCase();

    // this will hold filtered results
    List<CustomerChat> results = [];

    // loop through all customers
    for (int i = 0; i < widget.customers.length; i = i + 1) {

      CustomerChat customer = widget.customers[i];

      // check if name contains search query
      bool matchesName = customer.customerName
          .toLowerCase()
          .contains(searchQuery);

      // if matches add to results
      if (matchesName == true) {
        results.add(customer);
      }
    }

    setState(() {
      _filteredCustomers = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(
            color: Colors.grey.shade200,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── HEADER ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade200,
                  width: 0.5,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // title
                const Text(
                  'Messages',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),

                const SizedBox(height: 10),

                // search bar
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    border: Border.all(
                      color: const Color(0xFFE5E7EB),
                      width: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [

                      // search icon
                      const Icon(
                        Icons.search,
                        size: 16,
                        color: Color(0xFF9CA3AF),
                      ),

                      const SizedBox(width: 8),

                      // search text field
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (String value) {
                            _applySearch(value);
                          },
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF374151),
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Search customers...',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF9CA3AF),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── CUSTOMER LIST ──
          Expanded(
            child: ListView.builder(
              itemCount: _filteredCustomers.length,
              itemBuilder: (BuildContext context, int index) {

                CustomerChat customer = _filteredCustomers[index];

                return CustomerListItem(
                  customerName: customer.customerName,
                  lastMessage: customer.lastMessage,
                  time: customer.time,
                  unreadCount: customer.unreadCount,
                  isSelected: widget.selectedCustomerId == customer.customerId,
                  onTap: () {
                    widget.onCustomerSelected(customer);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}