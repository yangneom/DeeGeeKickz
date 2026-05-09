import 'package:flutter/material.dart';

// ================================================
// COMMON SEARCH BAR
// reusable search bar used in all pages
// ================================================
class CommonSearchBar extends StatelessWidget {

  // things this widget needs from the parent screen
  final TextEditingController controller; // controls the text input
  final String hintText;                  // placeholder text
  final Function(String) onChanged;       // called when user types

  const CommonSearchBar({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 42,
      child: TextField(
        controller: controller,

        // every time user types, call onChanged
        onChanged: onChanged,

        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(

          // placeholder text
          hintText: hintText,
          hintStyle: const TextStyle(
            fontSize: 13,
            color: Color(0xFF9CA3AF),
          ),

          // search icon on the left
          prefixIcon: const Icon(
            Icons.search,
            size: 18,
            color: Color(0xFF9CA3AF),
          ),

          // white background
          filled: true,
          fillColor: Colors.white,

          // normal border
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: Color(0xFFD1D5DB),
            ),
          ),

          // border when not focused
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: Color(0xFFD1D5DB),
            ),
          ),

          // border when focused/clicked
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: Color(0xFF2563EB),
            ),
          ),

          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}