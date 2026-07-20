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
  Future<bool> addAddress(CustomerAddress address) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
      final existing = await getMyAddresses();
      final shouldBeDefault = address.isDefault || existing.isEmpty;

      if (shouldBeDefault) {
        await _supabase
            .from('address')
            .update({'is_default': false})
            .eq('user_id', user.id);
      }

      await _supabase.from('address').insert(
            address.copyWith(isDefault: shouldBeDefault).toJson(userId: user.id),
          );
      return true;
    } catch (e) {
      print('AddressService.addAddress error: $e');
      return false;
    }
  }

  Future<bool> updateAddress(CustomerAddress address) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
      if (address.isDefault) {
        await _supabase
            .from('address')
            .update({'is_default': false})
            .eq('user_id', user.id);
      }

      await _supabase
          .from('address')
          .update(address.toJson(userId: user.id))
          .eq('address_id', int.parse(address.id));
      return true;
    } catch (e) {
      print('AddressService.updateAddress error: $e');
      return false;
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