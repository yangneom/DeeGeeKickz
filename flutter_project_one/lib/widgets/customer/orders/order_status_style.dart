import 'package:flutter/material.dart';

// ================================================
// ORDER STATUS COLOUR
//
// ONE place that decides the colour of an order status, so the order list and
// the order details page can never disagree again.
//
// Before this file, the list showed PENDING in amber and CONFIRMED in blue,
// while the details page showed both in plain black. The same order looked
// like two different states depending on the screen.
//
// These are the colours the order list already used. Every one of them has at
// least 4.5:1 contrast against white (WCAG AA), so they work as white text on a
// filled badge and as coloured text on a white outlined badge.
//
// Status is also always written out as words in the badge. Colour is never the
// only thing that tells the customer the state.
// ================================================

Color orderStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'completed':
    case 'delivered':
      return const Color(0xFF1E8449);
    case 'shipped':
      return const Color(0xFF1A5276);
    case 'preparing':
      return const Color(0xFF7D6608);
    case 'confirmed':
      return const Color(0xFF1D4ED8);
    case 'pending':
      return const Color(0xFF92400E);
    case 'cancelled':
      return const Color(0xFF991B1B);
    default:
      return const Color(0xFF656464);
  }
}