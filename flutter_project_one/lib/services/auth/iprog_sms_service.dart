import 'package:supabase_flutter/supabase_flutter.dart';

/// What happened when a phone code was requested.
///   sent         - the text message was handed to the SMS provider
///   rateLimited    - too many codes were requested; wait and try again
///   sessionExpired - the person's login has expired; they must sign in again
///   failed         - anything else (bad number, provider error, no connection)
enum OtpSendResult { sent, rateLimited, sessionExpired, failed }

class IprogSmsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Same as sendOtp, but says WHY it failed so a screen can show the right
  // message. (A "too many requests" answer used to look exactly like any
  // other failure.)
  Future<OtpSendResult> sendOtpDetailed(String phoneNumber) async {
    try {
      final response = await _supabase.functions.invoke(
        'sms-otp',
        body: {'action': 'send', 'phone_number': phoneNumber},
      );
      // Only the status is read. The reply never carries the code itself.
      final dynamic data = response.data;
      final bool ok = data is Map && data['status'] == 'success';
      return ok ? OtpSendResult.sent : OtpSendResult.failed;
    } on FunctionException catch (error) {
      // The sms-otp function answers 429 when a number or an account has
      // asked for too many codes.
      if (error.status == 429) return OtpSendResult.rateLimited;
      // 401: the login behind the request is missing or has expired. That is
      // not a problem with the phone number, so say so instead of "check the
      // number".
      if (error.status == 401) return OtpSendResult.sessionExpired;
      print('sendOtp error: status ${error.status}');
      return OtpSendResult.failed;
    } catch (error) {
      print('sendOtp error: $error');
      return OtpSendResult.failed;
    }
  }

  Future<bool> sendOtp(String phoneNumber) async {
    return (await sendOtpDetailed(phoneNumber)) == OtpSendResult.sent;
  }

  Future<bool> verifyOtp(String phoneNumber, String otp) async {
    try {
      final response = await _supabase.functions.invoke(
        'sms-otp',
        body: {'action': 'verify', 'phone_number': phoneNumber, 'otp': otp},
      );
      final dynamic data = response.data;
      return data is Map && data['status'] == 'success';
    } catch (error) {
      print('verifyOtp error: $error');
      return false;
    }
  }
}