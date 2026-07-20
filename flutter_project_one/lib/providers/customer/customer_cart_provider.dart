import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/customer_cart_item.dart';

class CustomerCartNotifier extends Notifier<List<CustomerCartItem>> {
  static const String _guestCartKey = 'guest_cart_items';

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  List<CustomerCartItem> build() {
    return [];
  }

  bool get _isLoggedIn => _supabase.auth.currentUser != null;
  String? get _userId => _supabase.auth.currentUser?.id;

  // ── GUEST LOCAL STORAGE ─────────────────────────────────────────
  Future<void> _saveGuestCartLocally() async {
    if (_isLoggedIn) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = state.map((item) => item.toLocalJson()).toList();
      await prefs.setString(_guestCartKey, jsonEncode(jsonList));
    } catch (error) {
      print('CustomerCartNotifier._saveGuestCartLocally error: $error');
    }
  }

  Future<void> loadGuestCartFromLocal() async {
    if (_isLoggedIn) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_guestCartKey);
      if (raw == null || raw.isEmpty) return;

      final decoded = jsonDecode(raw) as List;
      state = decoded
          .map((e) => CustomerCartItem.fromLocalJson(e as Map<String, dynamic>))
          .toList();
    } catch (error) {
      print('CustomerCartNotifier.loadGuestCartFromLocal error: $error');
    }
  }

  Future<void> _clearGuestLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_guestCartKey);
    } catch (error) {
      print('CustomerCartNotifier._clearGuestLocalStorage error: $error');
    }
  }

  // ── LOAD (logged-in user, from Supabase) ────────────────────────
  Future<void> loadFromSupabase() async {
    final userId = _userId;
    if (userId == null) return;

    try {
      final response = await _supabase
          .from('cart_item')
          .select()
          .eq('user_id', userId)
          .order('created_at');

      state = (response as List)
          .map((row) => CustomerCartItem.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (error) {
      print('CustomerCartNotifier.loadFromSupabase error: $error');
    }
  }

  // ── MERGE (guest → account, called right after login) ──────────────
  Future<void> mergeGuestCartIntoAccount() async {
    final userId = _userId;
    if (userId == null) return;

    final guestItems = state;

    if (guestItems.isNotEmpty) {
      try {
        for (final item in guestItems) {
          await _supabase.from('cart_item').upsert(
            item.toJson(userId: userId),
            onConflict: 'user_id,product_id,size_id',
          );
        }
      } catch (error) {
        print('CustomerCartNotifier.mergeGuestCartIntoAccount error: $error');
      }
    }

    await _clearGuestLocalStorage();
    await loadFromSupabase();
  }

  // ── ADD ──────────────────────────────────────────────────────────
  Future<void> addItem(CustomerCartItem item) async {
    final existingIndex = state.indexWhere(
      (e) => e.productId == item.productId && e.sizeId == item.sizeId,
    );

    if (existingIndex != -1) {
      final merged = state[existingIndex].copyWith(
        quantity: state[existingIndex].quantity + item.quantity,
      );
      await _writeItem(merged, existingIndex);
    } else {
      await _writeItem(item, null);
    }
  }

  Future<void> _writeItem(CustomerCartItem item, int? existingIndex) async {
    if (existingIndex != null) {
      final updated = [...state];
      updated[existingIndex] = item;
      state = updated;
    } else {
      state = [...state, item];
    }

    if (!_isLoggedIn) {
      await _saveGuestCartLocally();
      return;
    }

    try {
      final userId = _userId!;
      final response = await _supabase
          .from('cart_item')
          .upsert(
            item.toJson(userId: userId),
            onConflict: 'user_id,product_id,size_id',
          )
          .select()
          .single();

      final savedItem = CustomerCartItem.fromJson(response);

      final idx = state.indexWhere(
        (e) => e.productId == savedItem.productId && e.sizeId == savedItem.sizeId,
      );
      if (idx != -1) {
        final updated = [...state];
        updated[idx] = savedItem;
        state = updated;
      }
    } catch (error) {
      print('CustomerCartNotifier._writeItem error: $error');
    }
  }

  // ── REMOVE ───────────────────────────────────────────────────────
  Future<void> removeItem(int index) async {
    final item = state[index];

    final updated = [...state];
    updated.removeAt(index);
    state = updated;

    if (!_isLoggedIn) {
      await _saveGuestCartLocally();
      return;
    }

    if (item.cartItemId == null) return;

    try {
      await _supabase.from('cart_item').delete().eq('cart_item_id', item.cartItemId!);
    } catch (error) {
      print('CustomerCartNotifier.removeItem error: $error');
    }
  }

  // ── INCREMENT / DECREMENT ───────────────────────────────────────
  Future<void> increment(int index) async {
    final item = state[index];
    await _updateQuantity(index, item.quantity + 1);
  }

  Future<void> decrement(int index) async {
    final item = state[index];
    if (item.quantity <= 1) return;
    await _updateQuantity(index, item.quantity - 1);
  }

  Future<void> _updateQuantity(int index, int newQuantity) async {
    final item = state[index];
    final updatedItem = item.copyWith(quantity: newQuantity);

    final updated = [...state];
    updated[index] = updatedItem;
    state = updated;

    if (!_isLoggedIn) {
      await _saveGuestCartLocally();
      return;
    }

    if (item.cartItemId == null) return;

    try {
      await _supabase
          .from('cart_item')
          .update({'quantity': newQuantity})
          .eq('cart_item_id', item.cartItemId!);
    } catch (error) {
      print('CustomerCartNotifier._updateQuantity error: $error');
    }
  }

  // ── CLEAR (after successful order placement) ────────────────────
  Future<void> clearCart() async {
    final userId = _userId;
    state = [];

    if (userId == null) {
      await _clearGuestLocalStorage();
      return;
    }

    try {
      await _supabase.from('cart_item').delete().eq('user_id', userId);
    } catch (error) {
      print('CustomerCartNotifier.clearCart error: $error');
    }
  }

  // ── LOGOUT ───────────────────────────────────────────────────────
  Future<void> clearLocalOnly() async {
    state = [];
    await _clearGuestLocalStorage();
  }

  double get subtotal => state.fold(0, (sum, item) => sum + item.subtotal);
  int get totalItems => state.fold(0, (sum, item) => sum + item.quantity);
}

final customerCartProvider =
    NotifierProvider<CustomerCartNotifier, List<CustomerCartItem>>(
  CustomerCartNotifier.new,
);