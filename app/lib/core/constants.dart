/// ثوابت التطبيق العامة.
class AppConstants {
  AppConstants._();

  static const String appName = 'القواعد الفقهية';
  static const String appSubtitle = 'وتطبيقاتها';
  static const String author = 'الشيخ الدكتور عدنان بن عوض الرشيدي';
  static const String authorTitle = 'عضو هيئة التدريس بكلية الشريعة — جامعة الكويت';
  static const String source = 'إذاعة القرآن الكريم — دولة الكويت';

  /// نسخة التطبيق المعروضة في الإعدادات.
  /// تُحدَّث مع `version` في pubspec.yaml.
  static const String appVersion = '1.0.4';

  /// مصدر الملفات الصوتية (GitHub Releases).
  /// الرابط الكامل للحلقة = audioBaseUrl + 'ep01.m4a'
  ///
  /// يمكن تبديله وقت البناء للاختبار على خادم محلي:
  /// flutter run --dart-define=AUDIO_BASE_URL=http://10.0.2.2:8099/
  static const String audioBaseUrl = String.fromEnvironment(
    'AUDIO_BASE_URL',
    defaultValue:
        'https://github.com/taha-majdlawi/qwaed_feqhia_app/releases/download/audio-v1/',
  );

  static const String repoUrl =
      'https://github.com/taha-majdlawi/qwaed_feqhia_app';

  // ===== التواصل مع الشيخ =====
  /// الرقم بالصيغة الدولية بلا رموز، كما يطلبه wa.me.
  static const String sheikhPhone = '96551117119';

  /// صيغة العرض؛ نحيطها بعلامات LTR كي لا ينقلبها اتجاه الصفحة.
  static const String sheikhPhoneDisplay = '\u202A+965 5111 7119\u202C';

  static Uri get sheikhCallUri => Uri.parse('tel:+$sheikhPhone');
  static Uri get sheikhWhatsAppUri => Uri.parse('https://wa.me/$sheikhPhone');

  // مسارات الأصول
  static const String episodesAsset = 'assets/data/episodes.json';
  static String syncAsset(String id) => 'assets/data/sync/$id.json';
  static String textAsset(String id) => 'assets/data/text/$id.txt';
  static const String splashImage = 'assets/images/splash_bg.jpg';

  /// شاشة البداية والترحيب: صورة الشيخ مع عنوان السلسلة.
  static const String introImage = 'assets/images/intro.jpg';

  /// مصغّر الشيخ في رأس الشاشة الرئيسية.
  static const String sheikhImage = 'assets/images/sheikh.jpg';
  static const String iconImage = 'assets/images/app_icon.jpg';
  static const String iconSquare = 'assets/images/icon_square.png';

  /// غلاف مربّع للإشعار وشاشة القفل.
  static const String artworkImage = 'assets/images/artwork.jpg';

  /// سرعات التشغيل المتاحة.
  static const List<double> speeds = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
}
