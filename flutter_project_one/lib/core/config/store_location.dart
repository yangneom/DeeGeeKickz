// ================================================
// STORE PICKUP LOCATION
//
// Fixed pickup point for every Lalamove quotation/order —
// this is your store, not the customer's address.
//
// PLACEHOLDER VALUES — replace lat/lng with your real store's
// coordinates (get them privately via the geocode-address Edge
// Function from your own terminal, never paste the real address
// into chat). Keep `address` generic if you don't want the real
// text in your codebase either — it's just a display label shown
// to the driver, Lalamove routes using lat/lng regardless.
// ================================================
class StoreLocation {
  static const double lat = 14.737393;
  static const double lng = 120.96065;
  static const String address = '2nd Floor, Aliw Complex, Meycauayan, Bulacan';

  // Shown to the courier + used as sender contact for create-delivery-order
  static const String contactName = 'DeeGee Kickz';
  static const String contactPhone = '+639171234567'; // replace with real store contact number
}