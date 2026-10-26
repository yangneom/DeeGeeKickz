import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shows a full-screen map so the customer can confirm (or correct,
/// by tapping) the pin location before an address is saved.
///
/// Returns the confirmed LatLng, or null if the user cancelled.
///
/// New and OPTIONAL: [resolvedAddress] is the address text the geocoder matched
/// (the "formattedAddress" it returns). If given, it is shown as the closest
/// match. Existing callers keep working without it.
Future<LatLng?> showAddressPinPicker({
  required BuildContext context,
  required double initialLat,
  required double initialLng,
  bool showMismatchWarning = false,
  bool isLocalityAnchorOnly = false,
  String? resolvedAddress,
}) {
  return Navigator.of(context).push<LatLng>(
    MaterialPageRoute(
      builder: (_) => _AddressPinPickerScreen(
        initialLat: initialLat,
        initialLng: initialLng,
        showMismatchWarning: showMismatchWarning,
        isLocalityAnchorOnly: isLocalityAnchorOnly,
        resolvedAddress: resolvedAddress,
      ),
      fullscreenDialog: true,
    ),
  );
}

// ================================================
// WHAT THE PANEL SAYS ABOUT THE PIN
//
// Kept as a plain function so the wording rules can be tested without a map.
//
// THE RULE: this screen never says "verified" or "exact". A geocoder's
// "confidence" is a distance estimate, not a check that the house is there, and
// a barangay-level fallback is only the general area. The only statement of
// certainty is the customer's own: "Pin placed by you".
// ================================================

enum PinTone { neutral, caution }

class PinStatus {
  final String title;
  final String detail;

  /// A second, shorter line that applies on top of the main message, or null.
  final String? extra;
  final PinTone tone;

  const PinStatus({
    required this.title,
    required this.detail,
    required this.tone,
    this.extra,
  });
}

PinStatus describePin({
  required bool movedByCustomer,
  required bool anchorOnly,
  required bool mismatch,
  bool? hasAddress,
  String? detectedArea,
  String? matchedAddress,
}) {
  const String noAddressExtra =
      'This spot does not seem to have an address nearby.';
  final bool noAddress = hasAddress == false;

  if (movedByCustomer) {
    if (noAddress) {
      return const PinStatus(
        title: 'No address found near this pin',
        detail: 'Please double-check the pin before you confirm. '
            'You can still confirm it.',
        tone: PinTone.caution,
      );
    }
    final String area = (detectedArea != null && detectedArea.trim().isNotEmpty)
        ? 'Area: ${detectedArea.trim()}. '
        : '';
    return PinStatus(
      title: 'Pin placed by you',
      detail: '${area}Make sure it is on your exact house or building.',
      tone: PinTone.neutral,
    );
  }

  if (anchorOnly) {
    return PinStatus(
      title: 'Approximate location',
      detail: 'We could not find your exact street, so this pin only marks '
          'the general area of your barangay. Tap the map to place your '
          'exact address.',
      tone: PinTone.caution,
      extra: noAddress ? noAddressExtra : null,
    );
  }

  if (mismatch) {
    return PinStatus(
      title: 'Location may not match',
      detail: 'This pin may not match the city or barangay you entered. '
          'Check it, or tap the map to correct it.',
      tone: PinTone.caution,
      extra: noAddress ? noAddressExtra : null,
    );
  }

  final String closest =
      (matchedAddress != null && matchedAddress.trim().isNotEmpty)
          ? 'Closest match: ${matchedAddress.trim()}. '
          : '';
  return PinStatus(
    title: 'Pin placed near your address',
    detail: '${closest}Check that it is the right spot, or tap the map to '
        'move the pin.',
    tone: noAddress ? PinTone.caution : PinTone.neutral,
    extra: noAddress ? noAddressExtra : null,
  );
}

// ================================================
// THE SCREEN
// ================================================

class _AddressPinPickerScreen extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final bool showMismatchWarning;
  final bool isLocalityAnchorOnly;
  final String? resolvedAddress;

  const _AddressPinPickerScreen({
    required this.initialLat,
    required this.initialLng,
    required this.showMismatchWarning,
    required this.isLocalityAnchorOnly,
    this.resolvedAddress,
  });

  @override
  State<_AddressPinPickerScreen> createState() =>
      _AddressPinPickerScreenState();
}

class _AddressPinPickerScreenState extends State<_AddressPinPickerScreen> {
  static const Color _border = Color(0xFFCFC4C5);
  static const Color _muted  = Color(0xFF656464);
  static const Color _amber  = Color(0xFF92400E);

  late LatLng _pin;
  final MapController _mapController = MapController();

  // Set to false when the pin lands somewhere with no real address nearby
  // (open water, empty land). Null = haven't checked yet / check in progress.
  // Doesn't hard-block confirming; the customer can still proceed, this is
  // just a heads-up.
  bool? _pinHasAddress;

  // True once the customer has tapped the map to move the pin.
  bool _movedByCustomer = false;

  // The city the reverse-geocoder reports for the CURRENT pin, if it says.
  String? _detectedArea;

  @override
  void initState() {
    super.initState();
    _pin = LatLng(widget.initialLat, widget.initialLng);
    _checkPinLocation(_pin);
  }

  void _onMapTap(TapPosition _, LatLng point) {
    setState(() {
      _pin = point;
      _movedByCustomer = true;
      _pinHasAddress = null; // checking again
      _detectedArea = null;
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
        final dynamic city = data is Map ? data['detectedCity'] : null;
        setState(() {
          _pinHasAddress = data is Map && data['hasAddress'] == false ? false : true;
          _detectedArea = city is String && city.trim().isNotEmpty ? city : null;
        });
      }
    } catch (e) {
      // Network hiccup — don't show a false warning, just skip it.
      print('AddressPinPicker._checkPinLocation error: $e');
      if (!mounted) return;
      // Same staleness guard the success path has — don't let a slow, failed
      // OLDER check overwrite a newer, successful check's result.
      if (_pin.latitude == point.latitude && _pin.longitude == point.longitude) {
        setState(() => _pinHasAddress = true);
      }
    }
  }

  void _recenter() {
    _mapController.move(_pin, 16);
  }

  @override
  Widget build(BuildContext context) {
    final PinStatus status = describePin(
      movedByCustomer: _movedByCustomer,
      anchorOnly: widget.isLocalityAnchorOnly,
      mismatch: widget.showMismatchWarning,
      hasAddress: _pinHasAddress,
      detectedArea: _detectedArea,
      matchedAddress: widget.resolvedAddress,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // A phone turned sideways has little height: put the panel beside
            // the map instead of under it, so the map keeps its size.
            final bool sideBySide = constraints.maxWidth > constraints.maxHeight &&
                constraints.maxHeight < 560;

            final Widget map = _buildMap();
            final Widget panel = _buildPanel(
              status,
              maxHeight: sideBySide
                  ? constraints.maxHeight - 56
                  : constraints.maxHeight * 0.45,
            );

            return Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: sideBySide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: map),
                            Container(
                              width: 340,
                              decoration: const BoxDecoration(
                                border: Border(left: BorderSide(color: _border)),
                              ),
                              child: panel,
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Expanded(child: map),
                            panel,
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Compact header: title and close on one aligned 56px line ──────────────
  Widget _buildHeader() {
    return Container(
      height: 56,
      padding: const EdgeInsets.only(left: 20, right: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'CONFIRM LOCATION',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily:    'Archivo Narrow',
                fontSize:      20,
                fontWeight:    FontWeight.w700,
                letterSpacing: -0.2,
                color:         Colors.black,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // ── The map: the main thing on the screen ─────────────────────────────────
  Widget _buildMap() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _pin,
            initialZoom: 16,
            onTap: _onMapTap,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.deegeekickz.app',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _pin,
                  width: 44,
                  height: 44,
                  // The pin icon's TIP is at the bottom of its box, but a marker
                  // is centred on its point. Lifting the icon by about half its
                  // height puts the tip exactly on the chosen spot.
                  child: Transform.translate(
                    offset: const Offset(0, -20),
                    child: const Icon(
                      Icons.location_pin,
                      color: Color(0xFFBA1A1A),
                      size: 44,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        // One short line telling the customer how to move the pin.
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Align(
            alignment: Alignment.topLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xF0FFFFFF), // white at about 94%
                border: Border.all(color: _border),
              ),
              child: const Text(
                'Tap the map to place the pin. Drag to look around.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize:   12,
                  height:     1.3,
                  color:      Colors.black,
                ),
              ),
            ),
          ),
        ),

        // Recenter on the current pin. Sits inside the map, so it never covers
        // the confirm button.
        Positioned(
          right: 12,
          bottom: 28,
          child: Semantics(
            button: true,
            label: 'Center the map on the pin',
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _recenter,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _border),
                ),
                child: const Icon(Icons.my_location,
                    size: 20, color: Colors.black),
              ),
            ),
          ),
        ),

        // Required by the map tile provider's usage policy.
        Positioned(
          left: 8,
          bottom: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            color: const Color(0xCCFFFFFF), // white at about 80%
            child: const Text(
              '© OpenStreetMap contributors',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize:   10,
                color:      Color(0xFF4C4546),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── The panel: what we know about the pin, and the confirm button, together,
  // inside the safe area, never over the map controls ───────────────────────
  Widget _buildPanel(PinStatus status, {required double maxHeight}) {
    final bool caution = status.tone == PinTone.caution;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: _border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Semantics(
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F3F4),
                      border: Border(
                        left: BorderSide(
                          color: caution ? _amber : _border,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          caution
                              ? Icons.info_outline
                              : Icons.place_outlined,
                          size: 18,
                          color: caution ? _amber : Colors.black,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                status.title,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize:   13,
                                  fontWeight: FontWeight.w700,
                                  color: caution ? _amber : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                status.detail,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize:   12,
                                  height:     1.4,
                                  color:      Color(0xFF4C4546),
                                ),
                              ),
                              if (status.extra != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  status.extra!,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize:   12,
                                    height:     1.4,
                                    color:      _muted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              button: true,
              label: _pinHasAddress == false
                  ? 'Confirm anyway'
                  : 'Confirm this location',
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(_pin),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: Text(
                    _pinHasAddress == false
                        ? 'CONFIRM ANYWAY'
                        : 'CONFIRM THIS LOCATION',
                    style: const TextStyle(
                      fontFamily:    'Inter',
                      fontSize:      14,
                      fontWeight:    FontWeight.w600,
                      letterSpacing: 2.0,
                      color:         Colors.white,
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