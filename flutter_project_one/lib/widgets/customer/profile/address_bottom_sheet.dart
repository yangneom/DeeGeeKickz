import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter, TextInputFormatter;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import '../../../models/customer_address.dart';
import '../../../services/customer/address/address_service.dart';
import '../../common/dialog/confirm_dialog.dart';
import 'address_pin_picker.dart';
import '../../../services/customer/address/psgc_service.dart';

/// Shows a bottom sheet for adding a new address or editing an existing one.
///
/// Usage:
/// ```dart
/// final result = await showAddressBottomSheet(
///   context: context,
///   existing: address, // null = add new
/// );
/// if (result != null) { /* save result */ }
/// ```
Future<CustomerAddress?> showAddressBottomSheet({
  required BuildContext context,
  CustomerAddress? existing,
}) {
  return showModalBottomSheet<CustomerAddress>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AddressBottomSheet(existing: existing),
  );
}

/// Thrown by _geocode when the address itself is the problem — no
/// match found, or a match was found but rejected as too imprecise
/// to trust (see geocode-address's confidence threshold). This is
/// the ONE case where saving is blocked — a network hiccup or the
/// geocoding service being briefly down should NOT block a customer
/// from saving what may well be a perfectly real address.
class _AddressQualityException implements Exception {
  final String message;
  _AddressQualityException(this.message);
}

class AddressBottomSheet extends StatefulWidget {
  /// If null → Add New mode. If provided → Edit mode.
  final CustomerAddress? existing;

  const AddressBottomSheet({super.key, this.existing});

  @override
  State<AddressBottomSheet> createState() => _AddressBottomSheetState();
}

class _AddressBottomSheetState extends State<AddressBottomSheet> {
  final AddressService _addressService = AddressService();

  // ── Field length limits ─────────────────────────────────────
  static const int _maxStreetLength   = 150;
  static const int _maxBarangayLength = 100;
  static const int _maxCityLength     = 100;
  static const int _maxProvinceLength = 100;
  static const int _maxLandmarkLength = 150;

  // A text field is considered "meaningful" if it contains at least
  // one letter — rejects pure-number or pure-special-character junk
  // (e.g. "12345" or "!!!!!") while still allowing normal addresses
  // that legitimately mix letters and numbers ("123 Buendia Ave",
  // "Barangay 176").
    bool _hasAtLeastOneLetter(String text) =>
      RegExp(r'[a-zA-Z]').hasMatch(text);

  // FIX #1: many Metro Manila cities (Manila, Caloocan, Pasay, etc.)
  // use purely numbered barangays — "178", not "Barangay 178". The
  // generic letter-required check was rejecting these as invalid.
  bool _isValidBarangay(String text) =>
      _hasAtLeastOneLetter(text) || RegExp(r'^\d{1,4}$').hasMatch(text);

  // Philippine ZIP codes are exactly 4 digits.
  bool _isValidZip(String text) => RegExp(r'^\d{4}$').hasMatch(text);

    late final TextEditingController _streetCtrl;
  // Barangay stays as a controller ONLY for the fallback path — used
  // when the live barangay list fails to load or comes back empty
  // for the selected city. When a barangay IS picked from the
  // dropdown, _selectedBarangay is the source of truth instead.
  late final TextEditingController _barangayCtrl;
  late final TextEditingController _zipCodeCtrl;
  late final TextEditingController _landmarkCtrl;

  bool _isDefault = false;

  // ── PSGC structured selection state ──
  bool _isLoadingPsgc = true;
  PsgcRegion? _selectedRegion;
  PsgcProvince? _selectedProvince;
  PsgcCity? _selectedCity;
  PsgcBarangay? _selectedBarangay;

  List<PsgcProvince> _provinceOptions = [];
  List<PsgcCity> _cityOptions = [];
  List<PsgcBarangay> _barangayOptions = [];
  bool _isLoadingBarangays = false;
  // True once a barangay fetch has been attempted and failed/returned
  // empty for the current city — switches the barangay field to a
  // free-text fallback instead of blocking the form entirely.
  bool _barangayFetchFailed = false;

  bool get _isNcr => _selectedRegion?.code == '13';

  // True while geocode-address is running, so the Save button can
  // show a spinner and block double-taps.
  bool _isSaving = false;

  // Set when the last save attempt was blocked — either by local
  // field validation, or because the address couldn't be verified
  // as real. Shown inline at the TOP of the modal (not a snackbar)
  // so it's impossible to miss, on mobile or desktop.
  String? _addressErrorMessage;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final CustomerAddress? a = widget.existing;
    _streetCtrl   = TextEditingController(text: a?.street   ?? '');
    _barangayCtrl = TextEditingController(text: a?.barangay ?? '');
    _zipCodeCtrl  = TextEditingController(text: a?.zipCode  ?? '');
    _landmarkCtrl = TextEditingController(text: a?.landmark ?? '');
    _isDefault    = a?.isDefault ?? false;
    _initPsgc(a);
  }

  // Loads the bundled PSGC dataset, then — if editing an existing
  // address — tries to pre-select Region/Province/City/Barangay from
  // it. Preference order: match by the stored PSGC code (reliable,
  // exact) if present, otherwise best-effort match by name (for
  // addresses saved before this feature existed, which only have
  // free-text city/barangay names, no codes).
  Future<void> _initPsgc(CustomerAddress? existing) async {
    await PsgcService.instance.load();
    if (!mounted) return;

    PsgcCity? matchedCity;

    if (existing?.cityPsgcCode != null) {
      matchedCity = PsgcService.instance.cityByCode(existing!.cityPsgcCode!);
    }
    if (matchedCity == null && existing != null && existing.city.isNotEmpty) {
      // Best-effort fallback for legacy addresses with no stored code.
      // Ambiguous if multiple cities share a name nationwide — picks
      // the first match, which the customer can correct via the
      // dropdowns if it's wrong.
     final String wanted = existing.city.trim().toLowerCase();
      matchedCity = _findCityByName(wanted);
    }

    if (matchedCity != null) {
      final String regionCode = matchedCity.code.substring(0, 2);
      _selectedRegion = PsgcService.regions
          .where((r) => r.code == regionCode)
          .cast<PsgcRegion?>()
          .firstWhere((r) => true, orElse: () => null);

      if (_selectedRegion != null) {
        if (_isNcrCode(regionCode)) {
          _cityOptions = PsgcService.instance.citiesForRegion(regionCode);
        } else {
          _provinceOptions = PsgcService.instance.provincesForRegion(regionCode);
          _selectedProvince = _provinceOptions
              .where((p) => p.code == matchedCity!.provinceCode)
              .cast<PsgcProvince?>()
              .firstWhere((p) => true, orElse: () => null);
          if (_selectedProvince != null) {
            _cityOptions =
                PsgcService.instance.citiesForProvince(_selectedProvince!.code);
          }
        }
        _selectedCity = matchedCity;
        await _loadBarangaysForSelectedCity();

        if (existing?.barangayPsgcCode != null) {
          _selectedBarangay = _barangayOptions
              .where((b) => b.code == existing!.barangayPsgcCode)
              .cast<PsgcBarangay?>()
              .firstWhere((b) => true, orElse: () => null);
        } else if (existing != null && existing.barangay.isNotEmpty) {
          final String wantedBrgy = existing.barangay.trim().toLowerCase();
          _selectedBarangay = _barangayOptions
              .where((b) => b.name.trim().toLowerCase() == wantedBrgy)
              .cast<PsgcBarangay?>()
              .firstWhere((b) => true, orElse: () => null);
        }
      }
    }

    if (mounted) setState(() => _isLoadingPsgc = false);
  }

  bool _isNcrCode(String regionCode) => regionCode == '13';

  PsgcCity? _findCityByName(String lowerName) {
    for (final region in PsgcService.regions) {
      final Iterable<PsgcCity> candidates = _isNcrCode(region.code)
          ? PsgcService.instance.citiesForRegion(region.code)
          : PsgcService.instance
              .provincesForRegion(region.code)
              .expand((p) => PsgcService.instance.citiesForProvince(p.code));
      for (final c in candidates) {
        if (c.name.trim().toLowerCase() == lowerName) return c;
      }
    }
    return null;
  }

  Future<void> _loadBarangaysForSelectedCity() async {
    if (_selectedCity == null) return;
    setState(() {
      _isLoadingBarangays = true;
      _barangayFetchFailed = false;
      _barangayOptions = [];
    });

    final List<PsgcBarangay> barangays =
        await PsgcService.instance.fetchBarangays(_selectedCity!.code);

    if (!mounted) return;
    setState(() {
      _barangayOptions = barangays;
      _isLoadingBarangays = false;
      _barangayFetchFailed = barangays.isEmpty;
    });
  }

  void _onRegionChanged(PsgcRegion? region) {
    setState(() {
      _selectedRegion = region;
      _selectedProvince = null;
      _selectedCity = null;
      _selectedBarangay = null;
      _barangayOptions = [];
      _barangayFetchFailed = false;
      _provinceOptions = region == null
          ? []
          : PsgcService.instance.provincesForRegion(region.code);
      _cityOptions = region != null && _isNcrCode(region.code)
          ? PsgcService.instance.citiesForRegion(region.code)
          : [];
    });
  }

  void _onProvinceChanged(PsgcProvince? province) {
    setState(() {
      _selectedProvince = province;
      _selectedCity = null;
      _selectedBarangay = null;
      _barangayOptions = [];
      _barangayFetchFailed = false;
      _cityOptions = province == null
          ? []
          : PsgcService.instance.citiesForProvince(province.code);
    });
  }

  void _onCityChanged(PsgcCity? city) {
    setState(() {
      _selectedCity = city;
      _selectedBarangay = null;
      // Auto-fill zip as a starting point — the city API only returns
      // one zip per city, so different barangays may legitimately
      // need a different one. Kept editable, never locked.
      if (city != null && city.zipCode.isNotEmpty) {
        _zipCodeCtrl.text = city.zipCode;
      }
    });
    if (city != null) _loadBarangaysForSelectedCity();
  }

  @override
  void dispose() {
    _streetCtrl.dispose();
    _barangayCtrl.dispose();
    _zipCodeCtrl.dispose();
    _landmarkCtrl.dispose();
    super.dispose();
  }
  // ================================================
  // GEOCODE — calls the geocode-address Edge Function.
  //
  // Returns {lat, lng} on success.
  // Returns null on a service-side hiccup (network error, function
  //   down, unexpected response shape) — does NOT block saving,
  //   since a temporary outage isn't the address's fault.
  // Throws _AddressQualityException when the function explicitly
  //   says this isn't a real, deliverable address (no match found,
  //   or a match was found but confidence was too low to trust) —
  //   THIS case blocks saving, since it's not a transient problem,
  //   it's the address itself.
  // ================================================

  // Carries the mismatch flag alongside coords, so _save() knows
  // whether to show a warning on the confirmation map.
    // Carries the mismatch flag alongside coords, so _save() knows
  // whether to show a warning on the confirmation map.
  bool _lastGeocodeWasMismatch = false;
  // True when the pin shown is only a barangay/city-level anchor
  // (the full street match was rejected as untrustworthy) rather
  // than a real attempt at the exact house/building location.
  bool _lastGeocodeWasLocalityOnly = false;

  Future<Map<String, double>?> _geocode() async {
    late final dynamic responseData;

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'geocode-address',
        body: {
          'street': _streetCtrl.text.trim(),
          'barangay': _selectedBarangay?.name ?? _barangayCtrl.text.trim(),
          'city': _selectedCity?.name ?? '',
          'province': _isNcr ? 'Metro Manila' : (_selectedProvince?.name ?? ''),
          'zipCode': _zipCodeCtrl.text.trim(),
        },
      );
      responseData = response.data;
    } on FunctionException catch (e) {
      // The Supabase client throws for some non-2xx statuses (422,
      // 404) instead of returning them in response.data — so check
      // e.details for the SAME error text geocode-address returns,
      // to catch a genuine "no results / too imprecise" address and
      // still block saving, instead of misfiling it as a transient
      // network hiccup.
      // FIX #4: was `details['error'] as String?`, which throws if
      // details is a Map but 'error' isn't a String — an uncaught
      // TypeError that used to escape this whole try/catch.
      final dynamic details = e.details;
      String? errorText;
      if (details is Map) {
        final dynamic rawError = details['error'];
        errorText = rawError is String ? rawError : null;
      }

      if (errorText != null) {
        final String lower = errorText.toLowerCase();
        final bool isAddressQualityIssue =
            lower.contains('no results found') ||
            lower.contains('too imprecise') ||
            lower.contains('no address fields');

        if (isAddressQualityIssue) {
          throw _AddressQualityException(
            'We couldn\'t verify this as a real, deliverable address. '
            'Please check the street, barangay, and city and try again.',
          );
        }
      }

      // Anything else (unexpected status, missing details) — treat
      // as a transient hiccup, don't block.
      print('AddressBottomSheet._geocode error: $e');
      return null;
    } catch (e) {
      // Genuine network error, function completely unreachable, etc.
      print('AddressBottomSheet._geocode error: $e');
      return null;
    }

    if (responseData == null) {
      print('AddressBottomSheet._geocode: null response data');
      return null;
    }

    final Map<String, dynamic> data = responseData is Map<String, dynamic>
        ? responseData
        : {};

    // The edge function returns a body even on 404/422/502 — check
    // for its 'error' field rather than relying on the client
    // throwing, since Supabase's functions.invoke doesn't always
    // throw for non-2xx (same pattern used in LalamoveService).
    final String? errorText = data['error'] as String?;

    if (errorText != null) {
      final String lower = errorText.toLowerCase();
      final bool isAddressQualityIssue =
          lower.contains('no results found') ||
          lower.contains('too imprecise') ||
          lower.contains('no address fields');

      if (isAddressQualityIssue) {
        throw _AddressQualityException(
          'We couldn\'t verify this as a real, deliverable address. '
          'Please check the street, barangay, and city and try again.',
        );
      }

      // Some other server-side error (e.g. geocoding provider down,
      // status 502) — treat like a network hiccup, don't block.
      print('AddressBottomSheet._geocode: service error — $errorText');
      return null;
    }

    if (data['lat'] == null || data['lng'] == null) {
      print('AddressBottomSheet._geocode: no coordinates in response — $data');
      return null;
    }

    _lastGeocodeWasMismatch = data['locationMismatch'] == true;
    _lastGeocodeWasLocalityOnly = data['localityAnchorOnly'] == true;

    return {
      'lat': (data['lat'] as num).toDouble(),
      'lng': (data['lng'] as num).toDouble(),
    };
  }

  // Checks whether the customer already has another saved address
  // with the same street+barangay+city+province (case-insensitive,
  // whitespace-trimmed). If editing an existing address, that same
  // address is excluded from the comparison — editing something
  // back to its own unchanged text shouldn't trigger a duplicate
  // warning against itself.
  Future<bool> _isDuplicate() async {
    final String street   = _streetCtrl.text.trim().toLowerCase();
    final String barangay =
        (_selectedBarangay?.name ?? _barangayCtrl.text.trim()).toLowerCase();
    final String city     = (_selectedCity?.name ?? '').toLowerCase();
    final String province =
        (_isNcr ? 'Metro Manila' : (_selectedProvince?.name ?? '')).toLowerCase();

    final List<CustomerAddress> existingAddresses =
        await _addressService.getMyAddresses();

    return existingAddresses.any((a) =>
        a.id != (widget.existing?.id ?? '__new__') &&
        a.street.trim().toLowerCase()   == street &&
        a.barangay.trim().toLowerCase() == barangay &&
        a.city.trim().toLowerCase()     == city &&
        a.province.trim().toLowerCase() == province);
  }

  // Returns a specific, user-facing message if any field fails
  // validation, or null if everything checks out. Centralizing this
  // means _save() can show ONE clear reason instead of a generic
  // "fill in required fields" message that doesn't say what's wrong.
    String? _validationError() {
    final String street   = _streetCtrl.text.trim();
    final String zip      = _zipCodeCtrl.text.trim();
    final String landmark = _landmarkCtrl.text.trim();

    if (street.isEmpty) {
      return 'Please fill in the street address.';
    }
    if (!_hasAtLeastOneLetter(street)) {
      return 'Street address doesn\'t look valid — please check it.';
    }
    if (street.length > _maxStreetLength) {
      return 'Street address is too long (max $_maxStreetLength characters).';
    }
    if (_selectedRegion == null) {
      return 'Please select a region.';
    }
    if (!_isNcr && _selectedProvince == null) {
      return 'Please select a province.';
    }
    if (_selectedCity == null) {
      return 'Please select a city/municipality.';
    }
    final String barangay = _selectedBarangay?.name ?? _barangayCtrl.text.trim();
    if (barangay.isEmpty) {
      return 'Please select or enter a barangay.';
    }
    if (_barangayFetchFailed && !_isValidBarangay(barangay)) {
      return 'Barangay doesn\'t look valid — please check it.';
    }
    if (barangay.length > _maxBarangayLength) {
      return 'Barangay is too long (max $_maxBarangayLength characters).';
    }
    if (zip.isEmpty) {
      return 'Please fill in the ZIP code.';
    }
    if (!_isValidZip(zip)) {
      return 'ZIP code must be exactly 4 digits.';
    }
    if (landmark.length > _maxLandmarkLength) {
      return 'Landmark is too long (max $_maxLandmarkLength characters).';
    }
    return null;
  }

    Future<void> _save() async {
    // FIX #3: guard set synchronously, before any await, so a fast
    // double-tap can't slip through the gap between this check and
    // the flag actually taking effect.
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _addressErrorMessage = null;
    });

    final String? validationError = _validationError();
    if (validationError != null) {
      setState(() {
        _isSaving = false;
        _addressErrorMessage = validationError;
      });
      return;
    }

    // Check for a duplicate BEFORE burning a geocoding request on
    // an address that might not even need saving again.
    final bool duplicate = await _isDuplicate();

    // FIX #6: this mounted check now runs unconditionally after the
    // await — the widget can just as easily be disposed while
    // duplicate is false, not only inside the true branch.
    if (!mounted) return;

    if (duplicate) {
      final bool? proceedAnyway = await showConfirmDialog(
        context: context,
        title: 'You already have this address',
        message: 'This exact address is already saved. Save it again anyway?',
        confirmLabel: 'Save Anyway',
      );
      if (!mounted) return;
      if (proceedAnyway != true) {
        setState(() => _isSaving = false);
        return;
      }
    }

    // Only re-geocode if the address text actually changed (or this
    // is a brand-new address) — no point burning a request re-geocoding
    // an unchanged address when editing just the "default" checkbox.
       final String finalBarangay =
        _selectedBarangay?.name ?? _barangayCtrl.text.trim();
    final String finalCity = _selectedCity!.name;
    final String finalProvince = _isNcr
        ? 'Metro Manila'
        : (_selectedProvince?.name ?? '');
    final String finalZip = _zipCodeCtrl.text.trim();

    // Only re-geocode if the address text actually changed (or this
    // is a brand-new address) — no point burning a request re-geocoding
    // an unchanged address when editing just the "default" checkbox.
    final CustomerAddress? existing = widget.existing;
    final bool addressTextChanged = existing == null ||
        existing.street   != _streetCtrl.text.trim() ||
        existing.barangay != finalBarangay            ||
        existing.city     != finalCity                ||
        existing.province != finalProvince             ||
        existing.zipCode  != finalZip;

        double? lat = existing?.lat;
    double? lng = existing?.lng;

    // Re-geocode ONLY if the address text actually changed — no
    // point burning an API call re-verifying text that's identical
    // to what's already saved.
    if (addressTextChanged) {
      try {
        final coords = await _geocode();
        if (coords != null) {
          lat = coords['lat'];
          lng = coords['lng'];
        }
      } on _AddressQualityException catch (e) {
        // BLOCKED — no match at all found for this address text.
        if (mounted) {
          setState(() {
            _isSaving = false;
            _addressErrorMessage = e.message;
          });
        }
        return;
      } catch (e) {
        // FIX #4: catch-all safety net — anything unexpected in the
        // geocode flow resets the button instead of leaving it stuck
        // spinning forever with no way to retry.
        print('AddressBottomSheet._save geocode error: $e');
        if (mounted) {
          setState(() {
            _isSaving = false;
            _addressErrorMessage = 'Something went wrong. Please try again.';
          });
        }
        return;
      }
    } else {
      // Text unchanged — these flags only have meaning as the output
      // of a fresh _geocode() call above, so reset them rather than
      // let a stale value from a previous attempt in this same
      // session leak into the picker below.
      _lastGeocodeWasMismatch = false;
      _lastGeocodeWasLocalityOnly = false;
    }

    // Show the pin picker whenever we have coordinates to confirm —
    // whether they came from a fresh geocode above, OR from an
    // existing saved address whose TEXT didn't change but whose PIN
    // the customer still wants to manually reposition. This used to
    // be nested inside `if (addressTextChanged)`, which meant
    // dragging the pin on an address with otherwise-unchanged text
    // had nowhere to save to and was silently discarded — this was
    // the actual bug (confirmed: editing only the map pin never
    // persisted, while editing the street/barangay/city text did).
    if (lat != null && lng != null) {
      if (!mounted) return;
      setState(() => _isSaving = false); // hide spinner while map is up

      final LatLng? confirmed = await showAddressPinPicker(
        context: context,
        initialLat: lat,
        initialLng: lng,
        showMismatchWarning: _lastGeocodeWasMismatch,
        isLocalityAnchorOnly: _lastGeocodeWasLocalityOnly,
      );

      if (confirmed == null) {
        // User cancelled at the map step — don't save yet.
        if (mounted) {
          setState(() {
            _addressErrorMessage =
                'Location wasn\'t confirmed. Please try saving again.';
          });
        }
        return;
      }

      lat = confirmed.latitude;
      lng = confirmed.longitude;

      if (!mounted) return;
      setState(() => _isSaving = true); // resume spinner for actual save
    }

    if (!mounted) return;

       final CustomerAddress result = CustomerAddress(
      id:        widget.existing?.id ?? '',   // '' = new, not yet in Supabase
      street:    _streetCtrl.text.trim(),
      barangay:  finalBarangay,
      city:      finalCity,
      province:  finalProvince,
      region:    _selectedRegion!.name,  // validated non-null above
      zipCode:   finalZip,
      landmark:  _landmarkCtrl.text.trim(),
      isDefault: _isDefault,
      lat: lat,
      lng: lng,
      cityPsgcCode:     _selectedCity!.code,
      barangayPsgcCode: _selectedBarangay?.code,
    );

    setState(() => _isSaving = false);
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final double maxHeight = MediaQuery.of(context).size.height * 0.92;
    final double bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Color(0xFFF9F9F9),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // ── Drag handle ──────────────────────────────────────────
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFCFC4C5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Header ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isEditing ? 'EDIT ADDRESS' : 'ADD NEW ADDRESS',
                  style: const TextStyle(
                    fontFamily: 'Archivo Narrow',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: Colors.black,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFCFC4C5)),

          // ── Scrollable form ──────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPad + 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Error message — shown at the very top, so it's
                  // impossible to miss whether validation blocked the
                  // save or the address itself couldn't be verified.
                  // No snackbar per project requirement.
                  if (_addressErrorMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 16, color: Color(0xFFBA1A1A)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _addressErrorMessage!,
                              style: const TextStyle(
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
                    const SizedBox(height: 20),
                  ],

                  // ── Street Address ──────────────────────────────
                   _FormField(
                    label: 'Street Address *',
                    controller: _streetCtrl,
                    hint: 'House no., Street name',
                    maxLength: _maxStreetLength,
                    enabled: !_isSaving,
                  ),
                  const SizedBox(height: 16),

                  // ── Province ────────────────────────────────────
                    if (_isLoadingPsgc)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.black),
                      ),
                    )
                  else ...[
                    // ── Region dropdown ─────────────────────────
                    _label('Region *'),
                    const SizedBox(height: 6),
                    _PsgcDropdown<PsgcRegion>(
                      value: _selectedRegion,
                      hint: 'Select a region',
                      items: PsgcService.regions,
                      labelOf: (r) => r.name,
                      enabled: !_isSaving,
                      onChanged: _onRegionChanged,
                    ),
                    const SizedBox(height: 16),

                    // ── Province dropdown — hidden for NCR, which
                    // has no provinces at all ──
                    if (!_isNcr) ...[
                      _label('Province *'),
                      const SizedBox(height: 6),
                      _PsgcDropdown<PsgcProvince>(
                        value: _selectedProvince,
                        hint: _selectedRegion == null
                            ? 'Select a region first'
                            : 'Select a province',
                        items: _provinceOptions,
                        labelOf: (p) => p.name,
                        enabled: !_isSaving && _selectedRegion != null,
                        onChanged: _onProvinceChanged,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── City / Municipality dropdown ────────────
                    _label('City / Municipality *'),
                    const SizedBox(height: 6),
                    _PsgcDropdown<PsgcCity>(
                      value: _selectedCity,
                      hint: (_isNcr ? _selectedRegion == null : _selectedProvince == null)
                          ? (_isNcr ? 'Select a region first' : 'Select a province first')
                          : 'Select a city/municipality',
                      items: _cityOptions,
                      labelOf: (c) => c.name,
                      enabled: !_isSaving && _cityOptions.isNotEmpty,
                      onChanged: _onCityChanged,
                    ),
                    const SizedBox(height: 16),

                    // ── Barangay — dropdown when available, free
                    // text fallback when the live fetch fails/empty ──
                    _label('Barangay *'),
                    const SizedBox(height: 6),
                    if (_isLoadingBarangays)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFCFC4C5)),
                        ),
                        child: const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (_barangayFetchFailed || _selectedCity == null)
                      _FormField(
                        label: '', // label already shown above
                        controller: _barangayCtrl,
                        hint: _selectedCity == null
                            ? 'Select a city first'
                            : 'e.g. Barangay 178, or Poblacion',
                        maxLength: _maxBarangayLength,
                        enabled: !_isSaving && _selectedCity != null,
                      )
                    else
                      _PsgcDropdown<PsgcBarangay>(
                        value: _selectedBarangay,
                        hint: 'Select a barangay',
                        items: _barangayOptions,
                        labelOf: (b) => b.name,
                        enabled: !_isSaving,
                        onChanged: (b) => setState(() => _selectedBarangay = b),
                      ),
                    const SizedBox(height: 16),

                    // ── Zip Code ─────────────────────────────────
                       _FormField(
                      label: 'Zip Code *',
                      controller: _zipCodeCtrl,
                      hint: 'e.g. 1200',
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      enabled: !_isSaving,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Landmark (optional) ─────────────────────────
                  _FormField(
                    label: 'Landmark (optional)',
                    controller: _landmarkCtrl,
                    hint: 'e.g. Near SM Megamall',
                    maxLength: _maxLandmarkLength,
                    enabled: !_isSaving,
                  ),
                  const SizedBox(height: 20),

                  

                  // ── Set as default toggle ───────────────────────
                  Row(
                    children: [
                       Checkbox(
                        value: _isDefault,
                        activeColor: Colors.black,
                        onChanged: _isSaving
                            ? null
                            : (bool? v) => setState(() => _isDefault = v ?? false),
                      ),
                      const Text(
                        'Set as default address',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Save button ─────────────────────────────────
                  GestureDetector(
                    onTap: _isSaving ? null : _save,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      color: _isSaving ? const Color(0xFF4C4546) : Colors.black,
                      alignment: Alignment.center,
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isEditing ? 'SAVE CHANGES' : 'SAVE ADDRESS',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2.0,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Cancel button ───────────────────────────────
                  GestureDetector(
                    onTap: _isSaving ? null : () => Navigator.of(context).pop(),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCFC4C5)),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'CANCEL',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.0,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

Widget _label(String text) => Text(
  text.toUpperCase(),
  style: const TextStyle(
    fontFamily: 'Inter',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
    color: Color(0xFF656464),
  ),
);

class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType keyboardType;
  final int? maxLength;
  final bool enabled; // FIX #10 — disabled while saving
  final List<TextInputFormatter>? inputFormatters;

  const _FormField({
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType = TextInputType.text,
    this.maxLength,
    this.enabled = true,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          enabled: enabled,
          inputFormatters: inputFormatters,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            color: Colors.black,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: Color(0xFFCFC4C5),
            ),
            counterText: maxLength != null ? null : '', // hide counter unless a limit is set
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: Color(0xFFCFC4C5)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: Colors.black, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}


class _PsgcDropdown<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final List<T> items;
  final String Function(T) labelOf;
  final bool enabled;
  final ValueChanged<T?> onChanged;

  const _PsgcDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.labelOf,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: enabled ? Colors.white : const Color(0xFFF3F3F4),
        border: Border.all(color: const Color(0xFFCFC4C5)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Text(
            hint,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: Color(0xFFCFC4C5),
            ),
          ),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: Colors.black,
          ),
          items: items
              .map((T item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(labelOf(item)),
                  ))
              .toList(),
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}