import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shows a full-screen map so the customer can confirm (or correct,
/// by tapping) the pin location before an address is saved.
///
/// Returns the confirmed LatLng, or null if the user cancelled.
Future<LatLng?> showAddressPinPicker({
  required BuildContext context,
  required double initialLat,
  required double initialLng,
  bool showMismatchWarning = false,
}) {
  return Navigator.of(context).push<LatLng>(
    MaterialPageRoute(
      builder: (_) => _AddressPinPickerScreen(
        initialLat: initialLat,
        initialLng: initialLng,
        showMismatchWarning: showMismatchWarning,
      ),
      fullscreenDialog: true,
    ),
  );
}

class _AddressPinPickerScreen extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final bool showMismatchWarning;

  const _AddressPinPickerScreen({
    required this.initialLat,
    required this.initialLng,
    required this.showMismatchWarning,
  });

  @override
  State<_AddressPinPickerScreen> createState() =>
      _AddressPinPickerScreenState();
}

class _AddressPinPickerScreenState extends State<_AddressPinPickerScreen> {
  late LatLng _pin;
  final MapController _mapController = MapController();

  // NEW — set to false when the pin lands somewhere with no real
  // address nearby (open water, empty land). Null = haven't checked
  // yet / check in progress. Doesn't hard-block confirming — the
  // customer can still proceed, this is just a heads-up.
  bool? _pinHasAddress;

  @override
  void initState() {
    super.initState();
    _pin = LatLng(widget.initialLat, widget.initialLng);
    _checkPinLocation(_pin);
  }

  void _onMapTap(TapPosition _, LatLng point) {
    setState(() {
      _pin = point;
      _pinHasAddress = null; // checking again
    });
    _checkPinLocation(point);
  }

  Future<void> _checkPinLocation(LatLng point) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'reverse-geocode-address',
        body: {'lat': point.latitude, 'lng': point.longitude},
      );
      final data = response.data;
      if (!mounted) return;
      // Only apply the result if the pin hasn't moved again since
      // this check started (avoids a slow older check overwriting
      // a newer one's result).
      if (_pin.latitude == point.latitude && _pin.longitude == point.longitude) {
        setState(() {
          _pinHasAddress = data is Map && data['hasAddress'] == false ? false : true;
        });
      }
    } catch (e) {
      // Network hiccup — don't show a false warning, just skip it.
      print('AddressPinPicker._checkPinLocation error: $e');
      if (mounted) setState(() => _pinHasAddress = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'CONFIRM LOCATION',
                    style: TextStyle(
                      fontFamily: 'Archivo Narrow',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            if (widget.showMismatchWarning)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, size: 16, color: Color(0xFFBA1A1A)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This pin looks far from the city you entered — '
                        'please double-check it, or tap the map to correct it.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Color(0xFF7A1212),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  'Is this the right spot? Tap anywhere on the map to move the pin.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: Color(0xFFCFC4C5),
                  ),
                ),
              ),

            // ── Map ─────────────────────────────────────────────
            Expanded(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _pin,
                  initialZoom: 16,
                  onTap: _onMapTap,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.deegeekickz.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _pin,
                        width: 44,
                        height: 44,
                        child: const Icon(
                          Icons.location_pin,
                          color: Color(0xFFBA1A1A),
                          size: 44,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Confirm button ──────────────────────────────────
                       // ── "No address here" heads-up ───────────────────────
            if (_pinHasAddress == false)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, size: 16, color: Color(0xFFBA1A1A)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This spot doesn\'t seem to have an address nearby — '
                        'please double-check the pin before confirming.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Color(0xFF7A1212),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Confirm button ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(_pin),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  color: Colors.white,
                  alignment: Alignment.center,
                  child: Text(
                    _pinHasAddress == false
                        ? 'CONFIRM ANYWAY'
                        : 'CONFIRM THIS LOCATION',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.0,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}