import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/store_location.dart';
import '../../../models/customer_address.dart';

// ================================================
// LALAMOVE SERVICE
//
// Thin wrapper around the two Lalamove Edge Functions, following
// the same pattern as PaymentService's calls to refund-payment
// (Supabase.instance.client.functions.invoke).
//
// getShippingQuote() — called at checkout (Step 1), once a
//   customer selects an address with coordinates. Returns a
//   price only — does NOT book a courier.
//
// createDeliveryOrder() — called by admin (OrderManagementService
//   .markAsShipped) when marking an order "Shipped". Actually
//   books the courier and returns a tracking link. Internally the
//   Edge Function re-quotes right before booking (Lalamove
//   quotations expire in ~5 minutes), so this is safe to call
//   however long after checkout.
//
//   Takes raw lat/lng/address rather than a CustomerAddress,
//   since the admin side only has an Order (which carries its
//   own copy of the dropoff coordinates), not a CustomerAddress
//   instance.
// ================================================

class LalamoveQuoteResult {
  final String quotationId;
  final double priceTotal;
  final String currency;

  LalamoveQuoteResult({
    required this.quotationId,
    required this.priceTotal,
    required this.currency,
  });

  factory LalamoveQuoteResult.fromMap(Map<String, dynamic> map) {
    return LalamoveQuoteResult(
      quotationId: map['quotationId'] as String,
      priceTotal: (map['priceTotal'] as num).toDouble(),
      currency: map['currency'] as String? ?? 'PHP',
    );
  }
}

class LalamoveOrderResult {
  final String lalamoveOrderId;
  final String trackingUrl;
  final double priceTotal;
  final String status;

  LalamoveOrderResult({
    required this.lalamoveOrderId,
    required this.trackingUrl,
    required this.priceTotal,
    required this.status,
  });

  factory LalamoveOrderResult.fromMap(Map<String, dynamic> map) {
    return LalamoveOrderResult(
      lalamoveOrderId: map['lalamoveOrderId'] as String,
      trackingUrl: map['trackingUrl'] as String,
      priceTotal: (map['priceTotal'] as num).toDouble(),
      status: map['status'] as String? ?? '',
    );
  }
}

/// Thrown when Lalamove can't quote/book a delivery for this address —
/// usually because the address is too vague, incomplete, or outside
/// Lalamove's coverage, even though it technically has coordinates on
/// file (geocoding guessed *something*, just not somewhere Lalamove
/// can actually route to).
class DeliveryQuoteFailedException implements Exception {
  final String message;
  DeliveryQuoteFailedException([
    this.message = 'We couldn\'t get a delivery quote for this address. '
        'This usually means the saved address is incomplete or unclear '
        '(e.g. missing street/barangay, or not a real, deliverable location). '
        'Ask the customer to update their address, or paste a Lalamove '
        'tracking link manually below.',
  ]);

  @override
  String toString() => message;
}

/// Thrown when a quote/order can't be requested because the
/// address has no coordinates yet (geocoding failed or was
/// never run — e.g. an address saved before this feature existed).
class MissingCoordinatesException implements Exception {
  final String message;
  MissingCoordinatesException([
    this.message = 'This address is missing map coordinates. '
        'Please edit and re-save it to enable delivery pricing.',
  ]);

  @override
  String toString() => message;
}

class LalamoveService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ================================================
  // GET SHIPPING QUOTE (checkout)
  // ================================================
 Future<LalamoveQuoteResult> getShippingQuote({
    required CustomerAddress dropoffAddress,
    int itemQuantity = 1,
    String weightClass = 'LESS_THAN_3_KG',
  }) async {
    if (!dropoffAddress.hasCoordinates) {
      throw MissingCoordinatesException();
    }

    try {
      final response = await _supabase.functions.invoke(
        'get-delivery-quote',
        body: {
          'pickup': {
            'lat': StoreLocation.lat,
            'lng': StoreLocation.lng,
            'address': StoreLocation.address,
          },
          'dropoff': {
            'lat': dropoffAddress.lat,
            'lng': dropoffAddress.lng,
            'address': dropoffAddress.fullAddress,
          },
          'item': {
            'quantity': itemQuantity.toString(),
            'weight': weightClass,
            'categories': ['OTHERS'],
          },
        },
      );

      final data = response.data as Map<String, dynamic>;

      if (data['error'] != null) {
        throw Exception(data['error']);
      }

      return LalamoveQuoteResult.fromMap(data);
    } catch (e) {
      print('LalamoveService.getShippingQuote error: $e');
      rethrow;
    }
  }

  // ================================================
  // CREATE DELIVERY ORDER (admin — "Mark as Shipped")
  // ================================================
Future<LalamoveOrderResult> createDeliveryOrder({
    required int orderId,
    required double dropoffLat,
    required double dropoffLng,
    required String dropoffAddressText,
    required String recipientName,
    required String recipientPhone,
    int itemQuantity = 1,
    String weightClass = 'LESS_THAN_3_KG',
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'create-delivery-order',
        body: {
          'orderId': orderId,
          'pickup': {
            'lat': StoreLocation.lat,
            'lng': StoreLocation.lng,
            'address': StoreLocation.address,
          },
          'dropoff': {
            'lat': dropoffLat,
            'lng': dropoffLng,
            'address': dropoffAddressText,
          },
          'sender': {
            'name': StoreLocation.contactName,
            'phone': StoreLocation.contactPhone,
          },
          'recipient': {
            'name': recipientName,
            'phone': recipientPhone,
          },
          'item': {
            'quantity': itemQuantity.toString(),
            'weight': weightClass,
            'categories': ['OTHERS'],
          },
        },
      );

      final data = response.data as Map<String, dynamic>;

      if (data['error'] != null) {
        throw Exception(data['error']);
      }

      return LalamoveOrderResult.fromMap(data);
    } catch (e) {
      print('LalamoveService.createDeliveryOrder error: $e');

      final String raw = e.toString();
      final bool isQuoteFailure = raw.contains('502') ||
          raw.toLowerCase().contains('fresh quotation') ||
          raw.toLowerCase().contains('could not get');

      if (isQuoteFailure) {
        throw DeliveryQuoteFailedException();
      }
      rethrow;
    }
  }
}