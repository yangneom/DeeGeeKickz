import 'package:flutter/material.dart';

/// Shipping information form section.
/// Frontend only — no validation logic wired yet.
/// Supabase-ready: wire controllers to a checkout provider when ready.
class CheckoutShippingForm extends StatelessWidget {
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController streetController;
  final TextEditingController cityController;
  final TextEditingController postalController;
  final TextEditingController phoneController;
  final String selectedCountry;
  final ValueChanged<String?> onCountryChanged;

  const CheckoutShippingForm({
    super.key,
    required this.firstNameController,
    required this.lastNameController,
    required this.streetController,
    required this.cityController,
    required this.postalController,
    required this.phoneController,
    required this.selectedCountry,
    required this.onCountryChanged,
  });

  static const List<String> _countries = [
    'Philippines',
    'Singapore',
    'Malaysia',
    'Indonesia',
    'Thailand',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Shipping Information',
          style: TextStyle(
            fontFamily: 'Archivo Narrow',
            fontSize: 32,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 24),

        // First + Last name
        LayoutBuilder(builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 500;
          final fields = [
            _FormField(
                label: 'First Name',
                placeholder: 'John',
                controller: firstNameController),
            _FormField(
                label: 'Last Name',
                placeholder: 'Doe',
                controller: lastNameController),
          ];
          return isWide
              ? Row(
                  children: fields
                      .map((f) => Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                  right: f == fields.first ? 12 : 0),
                              child: f,
                            ),
                          ))
                      .toList(),
                )
              : Column(children: fields);
        }),

        const SizedBox(height: 24),

        // Street address
        _FormField(
          label: 'Street Address',
          placeholder: '123 Performance Way',
          controller: streetController,
        ),

        const SizedBox(height: 24),

        // City / Postal / Country
        LayoutBuilder(builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 500;
          if (isWide) {
            return Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _FormField(
                      label: 'City',
                      placeholder: 'Makati',
                      controller: cityController,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _FormField(
                      label: 'Postal Code',
                      placeholder: '1200',
                      controller: postalController,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: _CountryDropdown(
                      selected: selectedCountry,
                      countries: _countries,
                      onChanged: onCountryChanged,
                    ),
                  ),
                ),
              ],
            );
          }
          return Column(
            children: [
              _FormField(
                  label: 'City',
                  placeholder: 'Makati',
                  controller: cityController),
              const SizedBox(height: 24),
              _FormField(
                  label: 'Postal Code',
                  placeholder: '1200',
                  controller: postalController),
              const SizedBox(height: 24),
              _CountryDropdown(
                selected: selectedCountry,
                countries: _countries,
                onChanged: onCountryChanged,
              ),
            ],
          );
        }),

        const SizedBox(height: 24),

        // Phone
        _FormField(
          label: 'Phone Number',
          placeholder: '+63 917 123 4567',
          controller: phoneController,
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final String placeholder;
  final TextEditingController controller;
  final TextInputType keyboardType;

  const _FormField({
    required this.label,
    required this.placeholder,
    required this.controller,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF4C4546),
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Colors.black,
          ),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              color: Color(0xFF9E9E9E),
            ),
            border: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFCFC4C5)),
            ),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFCFC4C5)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.black, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

class _CountryDropdown extends StatelessWidget {
  final String selected;
  final List<String> countries;
  final ValueChanged<String?> onChanged;

  const _CountryDropdown({
    required this.selected,
    required this.countries,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Country',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF4C4546),
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: selected,
          onChanged: onChanged,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            color: Colors.black,
          ),
          decoration: const InputDecoration(
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFCFC4C5)),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFCFC4C5)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.black, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(vertical: 8),
            isDense: true,
          ),
          items: countries
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
        ),
      ],
    );
  }
}