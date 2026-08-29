import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;


class PsgcRegion {
  final String code;
  final String name;
  const PsgcRegion({required this.code, required this.name});
}

class PsgcProvince {
  final String code;
  final String name;
  final String regionCode; // derived
  const PsgcProvince({
    required this.code,
    required this.name,
    required this.regionCode,
  });
}

class PsgcCity {
  final String code;
  final String name;
  final String type; // "City", "Mun", "SubMun"
  final String zipCode;
  final String provinceCode; // derived
  const PsgcCity({
    required this.code,
    required this.name,
    required this.type,
    required this.zipCode,
    required this.provinceCode,
  });
}

class PsgcBarangay {
  final String code;
  final String name;
  const PsgcBarangay({required this.code, required this.name});
}

/// Loads the bundled PSGC region/province/city dataset once and keeps
/// it in memory. Barangays are NOT bundled here — fetched live per
/// selected city (see PsgcService.fetchBarangays), since the full
/// barangay list is 40,000+ entries and not worth shipping in-app.
class PsgcService {
  PsgcService._internal();
  static final PsgcService instance = PsgcService._internal();

  // Fixed 18-region list — small enough to hardcode directly rather
  // than bundling a third JSON file just for this.
  static const List<PsgcRegion> regions = [
    PsgcRegion(code: '01', name: 'Region I (Ilocos Region)'),
    PsgcRegion(code: '02', name: 'Region II (Cagayan Valley)'),
    PsgcRegion(code: '03', name: 'Region III (Central Luzon)'),
    PsgcRegion(code: '04', name: 'Region IV-A (CALABARZON)'),
    PsgcRegion(code: '17', name: 'MIMAROPA Region'),
    PsgcRegion(code: '05', name: 'Region V (Bicol Region)'),
    PsgcRegion(code: '06', name: 'Region VI (Western Visayas)'),
    PsgcRegion(code: '07', name: 'Region VII (Central Visayas)'),
    PsgcRegion(code: '08', name: 'Region VIII (Eastern Visayas)'),
    PsgcRegion(code: '09', name: 'Region IX (Zamboanga Peninsula)'),
    PsgcRegion(code: '10', name: 'Region X (Northern Mindanao)'),
    PsgcRegion(code: '11', name: 'Region XI (Davao Region)'),
    PsgcRegion(code: '12', name: 'Region XII (SOCCSKSARGEN)'),
    PsgcRegion(code: '13', name: 'National Capital Region (NCR)'),
    PsgcRegion(code: '14', name: 'Cordillera Administrative Region (CAR)'),
    PsgcRegion(code: '16', name: 'Region XIII (Caraga)'),
    PsgcRegion(code: '19', name: 'Bangsamoro Autonomous Region In Muslim Mindanao (BARMM)'),
  ];

  List<PsgcProvince> _provinces = [];
  List<PsgcCity> _cities = [];
  bool _loaded = false;

  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;

    final String provincesRaw =
        await rootBundle.loadString('assets/psgc/provinces.json');
    final String citiesRaw =
        await rootBundle.loadString('assets/psgc/cities.json');

    final List<dynamic> provincesJson = jsonDecode(provincesRaw) as List;
    final List<dynamic> citiesJson = jsonDecode(citiesRaw) as List;

    _provinces = provincesJson.map((p) {
      final String code = p['code'] as String;
      return PsgcProvince(
        code: code,
        name: p['name'] as String,
        regionCode: code.substring(0, 2),
      );
    }).toList();

    // Sort city codes' 4-digit prefixes against province codes to
    // find the owning province — confirmed correct against the live
    // PSGC data (e.g. Adams "0102801000" -> prefix "0102" matches
    // Ilocos Norte "0102800000" -> prefix "0102").
    final Map<String, String> provincePrefixToCode = {
      for (final p in _provinces) p.code.substring(0, 4): p.code,
    };

    _cities = citiesJson.map((c) {
      final String code = c['code'] as String;
      final String prefix = code.substring(0, 4);
      return PsgcCity(
        code: code,
        name: (c['name'] as String).trim(),
        type: c['type'] as String? ?? '',
        zipCode: c['zip_code'] as String? ?? '',
        provinceCode: provincePrefixToCode[prefix] ?? '',
      );
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    _loaded = true;
  }

  List<PsgcProvince> provincesForRegion(String regionCode) {
    return _provinces.where((p) => p.regionCode == regionCode).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

    List<PsgcCity> citiesForProvince(String provinceCode) {
    return _cities.where((c) => c.provinceCode == provinceCode).toList();
  }

  // NCR has no provinces at all (confirmed: provinces.json has zero
  // entries with a "13" region prefix) — its cities sit directly
  // under the region. The dropdown UI uses this instead of
  // citiesForProvince() specifically for NCR.
  List<PsgcCity> citiesForRegion(String regionCode) {
    return _cities.where((c) => c.code.substring(0, 2) == regionCode).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  // ── Barangays — live fetch per selected city ──
  //
  // Not bundled (40,000+ entries nationwide). This hits psgc.cloud
  // directly for just the barangays under one city/municipality code.
  // Returns an empty list on failure — the caller should fall back to
  // a free-text barangay field rather than block the form entirely.
    PsgcCity? cityByCode(String code) {
    for (final c in _cities) {
      if (c.code == code) return c;
    }
    return null;
  }

  // ── Barangays — live fetch per selected city ──
  //
  // Not bundled (40,000+ entries nationwide). This hits psgc.cloud
  // directly for just the barangays under one city/municipality code.
  // Returns an empty list on failure — the caller should fall back to
  // a free-text barangay field rather than block the form entirely.
  // Returns code+name (not just names) so barangay_psgc_code can
  // actually be stored when the customer picks from this list.
  Future<List<PsgcBarangay>> fetchBarangays(String cityCode) async {
    try {
      final response = await http.get(
        Uri.parse('https://psgc.cloud/api/cities-municipalities/$cityCode/barangays'),
      );
      if (response.statusCode != 200) return [];

      final List<dynamic> json = jsonDecode(response.body) as List;
      final List<PsgcBarangay> barangays = json
          .map((b) => PsgcBarangay(
                code: b['code'] as String,
                name: (b['name'] as String).trim(),
              ))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      return barangays;
    } catch (e) {
      print('PsgcService.fetchBarangays error: $e');
      return [];
    }
  }
}