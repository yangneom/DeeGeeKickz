/// External links used across the customer website.
///
/// Keep them here so a link is changed in ONE place only.
class AppLinks {
  AppLinks._();

  /// Always points at the newest GitHub Release's Android app file.
  ///
  /// How it stays stable: GitHub redirects ".../releases/latest/download/<file>"
  /// to that file in the most recent PUBLISHED release. So for every new
  /// release, attach the APK with EXACTLY this file name (DeeGeeKickz.apk) and
  /// this link, the QR code and the buttons keep working without any edit.
  ///
  /// !! Check the owner / repository / file name below match yours.
  static const String androidApk =
      'https://github.com/yangneom/DeeGeeKickz/releases/latest/download/DeeGeeKickz.apk';

  static const String facebook = 'https://www.facebook.com/DeeGeeKickz';
}