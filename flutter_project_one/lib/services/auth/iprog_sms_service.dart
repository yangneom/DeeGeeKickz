import 'package:supabase_flutter/supabase_flutter.dart';

class IprogSmsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<bool> sendOtp(String phoneNumber) async {
    try {
      final response = await _supabase.functions.invoke(
        'sms-otp',
        body: {'action': 'send', 'phone_number': phoneNumber},
      );
      // Don't log response.data — it contains the raw OTP code in
      // plaintext (data.otp_code). Only log status, never the payload.
      print('sendOtp status: ${response.data?['status']}');
      return response.data['status'] == 'success';
    } catch (error) {
      print('sendOtp error: $error');
      return false;
    }
  }

  Future<bool> verifyOtp(String phoneNumber, String otp) async {
    try {
      final response = await _supabase.functions.invoke(
        'sms-otp',
        body: {'action': 'verify', 'phone_number': phoneNumber, 'otp': otp},
      );
      print('verifyOtp status: ${response.data?['status']}');
      return response.data['status'] == 'success';
    } catch (error) {
      print('verifyOtp error: $error');
      return false;
    }
  }
}