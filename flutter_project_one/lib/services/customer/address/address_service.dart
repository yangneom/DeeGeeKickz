import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/customer_address.dart';

class AddressService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<CustomerAddress>> getMyAddresses() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await _supabase
          .from('address')
          .select()
          .eq('user_id', user.id)
          .order('is_default', ascending: false)
          .order('created_at');

      return (response as List)
          .map((row) => CustomerAddress.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('AddressService.getMyAddresses error: $e');
      return [];
    }
  }

  /// Adds a new address. If [address.isDefault] is true, or this is the
  /// user's very first address, it's saved as the default.
  /// Adds a new address. If [address.isDefault] is true, or this is the
  /// user's very first address, it's saved as the default.
  ///
  /// FIX #15: uses the upsert_address RPC so "unset old default" +
  /// "insert new row" happen in a single DB transaction. Previously
  /// these were two separate calls — if the second one failed after
  /// the first succeeded, a user could be left with no default
  /// address at all, with no way to recover from the app.
   // FIX #16/#19: returns a specific message on failure instead of a
  // plain bool, matching deleteAddress's pattern — so the UI can show
  // the user why it failed instead of one generic string for every
  // possible cause.
  Future<String?> addAddress(CustomerAddress address) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 'You must be signed in to save an address.';

    try {
      final existing = await getMyAddresses();
      final shouldBeDefault = address.isDefault || existing.isEmpty;

            await _supabase.rpc('upsert_address', params: {
        'p_address_id': null,
        'p_user_id': user.id,
        'p_street': address.street,
        'p_barangay': address.barangay,
        'p_city': address.city,
        'p_province': address.province,
        'p_region': address.region,
        'p_zip_code': address.zipCode,
        'p_landmark': address.landmark,
        'p_is_default': shouldBeDefault,
        'p_lat': address.lat,
        'p_lng': address.lng,
        'p_city_psgc_code': address.cityPsgcCode,
        'p_barangay_psgc_code': address.barangayPsgcCode,
      });
      return null;
    } on PostgrestException catch (e) {
      print('AddressService.addAddress error: $e');
      return 'Could not save address. Please try again.';
    } catch (e) {
      print('AddressService.addAddress error: $e');
      return 'Could not save address. Please try again.';
    }
  }

  /// FIX #15: same atomicity fix as addAddress — the default-unset
  /// and the actual update now happen in one transaction via RPC.
    // FIX #16/#19: same bool → String? change as addAddress.
  Future<String?> updateAddress(CustomerAddress address) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 'You must be signed in to save changes.';

    try {
            await _supabase.rpc('upsert_address', params: {
        'p_address_id': int.parse(address.id),
        'p_user_id': user.id,
        'p_street': address.street,
        'p_barangay': address.barangay,
        'p_city': address.city,
        'p_province': address.province,
        'p_region': address.region,
        'p_zip_code': address.zipCode,
        'p_landmark': address.landmark,
        'p_is_default': address.isDefault,
        'p_lat': address.lat,
        'p_lng': address.lng,
        'p_city_psgc_code': address.cityPsgcCode,
        'p_barangay_psgc_code': address.barangayPsgcCode,
      });
      return null;
    } on PostgrestException catch (e) {
      print('AddressService.updateAddress error: $e');
      return 'Could not save changes. Please try again.';
    } catch (e) {
      print('AddressService.updateAddress error: $e');
      return 'Could not save changes. Please try again.';
    }
  }
/// Returns null on success, or a user-facing error message on failure.
  Future<String?> deleteAddress(CustomerAddress address) async {
    try {
      await _supabase.from('address').delete().eq('address_id', int.parse(address.id));

      if (address.isDefault) {
        final remaining = await getMyAddresses();
        if (remaining.isNotEmpty) {
          await setDefault(remaining.first.id);
        }
      }

      return null;
    } on PostgrestException catch (e) {
      print('AddressService.deleteAddress error: $e');
      if (e.code == '23503') {
        // Foreign key violation — this address is attached to an
        // existing order and can't be removed without breaking that
        // order's shipping record.
        return 'This address is used in an existing order and can\'t be deleted.';
      }
      return 'Could not delete address. Please try again.';
    } catch (e) {
      print('AddressService.deleteAddress error: $e');
      return 'Could not delete address. Please try again.';
    }
  }

  Future<bool> setDefault(String addressId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
      await _supabase
          .from('address')
          .update({'is_default': false})
          .eq('user_id', user.id);

      await _supabase
          .from('address')
          .update({'is_default': true})
          .eq('address_id', int.parse(addressId));
      return true;
    } catch (e) {
      print('AddressService.setDefault error: $e');
      return false;
    }
  }
}