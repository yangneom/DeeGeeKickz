import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/cashier/sidebar/cashier_sidebar.dart';
import '../../widgets/cashier/topbar/cashier_top_bar.dart';
import 'cashierModule/cashier_screen.dart';
import '../../screens/cashier/inventory/cashier_inventory_screen.dart';
// ================================================
// CASHIER LAYOUT
//
// Wrapper for the cashier role — same structure
// as AdminLayout
//
// ┌──────────────────────────────────┐
// │          TOP BAR          👤    │
// ├─────────┬────────────────────────┤
// │         │                        │
// │ SIDEBAR │       CONTENT          │
// │         │                        │
// └─────────┴────────────────────────┘
// ================================================
class CashierLayout extends ConsumerStatefulWidget {
  const CashierLayout({super.key});

  @override
  ConsumerState<CashierLayout> createState() => _CashierLayoutState();
}

class _CashierLayoutState extends ConsumerState<CashierLayout> {

  // ================================================
  // CURRENT INDEX
  // 0 = Cashier (POS)
  // More screens added here later
  // ================================================
  int _currentIndex = 0;

  // ================================================
  // GET CURRENT SCREEN
  // ================================================
  Widget _getCurrentScreen() {

    if (_currentIndex == 0) {
      return const CashierScreen();
    }

    // inventory
    if (_currentIndex == 1) {
      return const CashierInventoryScreen();
    }

    // Default
    return const CashierScreen();
    
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Row(
        children: [

          // ── SIDEBAR on the LEFT ──
          CashierSidebar(
            currentIndex: _currentIndex,
            onItemSelected: (int index) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),

          // ── RIGHT SIDE — TOP BAR + CONTENT ──
          Expanded(
            child: Column(
              children: [

                // Top bar
                const CashierTopBar(),

                // Content
                Expanded(
                  child: _getCurrentScreen(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}