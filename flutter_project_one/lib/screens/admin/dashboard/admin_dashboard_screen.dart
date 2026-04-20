// Basic Flutter import
import 'package:flutter/material.dart';


// ================================================
// ADMIN DASHBOARD SCREEN
//
// This is a temporary placeholder screen
// We will build the real dashboard later
// For now it just shows "Dashboard" text
// so the app can compile and run
// ================================================
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: const Center(
        child: Text(
          'Dashboard',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}