import 'package:flutter/material.dart';

/// Styled search input field matching DeeGeeKickz monochrome theme.
/// Shows a clear (X) button when text is present.
class SearchBarField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const SearchBarField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFCFC4C5), width: 1),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Icon(Icons.search, size: 22, color: Color(0xFF656464)),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              autofocus: true,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                color: Colors.black,
              ),
              decoration: const InputDecoration(
                hintText: 'Search shoes, brands, categories...',
                hintStyle: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  color: Color(0xFFCFC4C5),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          // Clear button
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) {
              if (value.text.isEmpty) return const SizedBox(width: 48);
              return GestureDetector(
                onTap: onClear,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Icon(Icons.close, size: 20, color: Color(0xFF656464)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}