# حالة المشروع — ورقة تسليم لجلسة جديدة

آخر تحديث: ٢٠٢٦-١٠-٢٢ (جلسة البناء والتشغيل) · المستودع: `taha-majdlawi/qwaed_feqhia_app` · الفرع: `main`

---

## ما هو المشروع

تطبيق Flutter للاستماع إلى سلسلة **القواعد الفقهية وتطبيقاتها** للشيخ د. عدنان بن عوض الرشيدي
(٤٢ حلقة من إذاعة القرآن الكريم — الكويت)، مع **عرض نصّ كل حلقة متزامناً مع الصوت**:
الفقرة الجارية تُظلَّل تلقائياً، والضغط على أي فقرة ينقل الصوت إلى بدايتها.

مشروع Flutter في المجلد **`app/`** داخل المستودع (وليس في الجذر).

---

## ✅ المنجَز (مرفوع على `main`)

### البنية
```
app/lib/
├── main.dart                     تهيئة الصوت حسب المنصّة + MultiProvider + RTL + locale ar
├── core/
│   ├── constants.dart            audioBaseUrl، مسارات الأصول، سرعات التشغيل
│   ├── arabic.dart               NormalizedText: تطبيع عربي للبحث + خريطة مواضع للتظليل
│   └── theme.dart                ثيم فاتح/داكن: أخضر #0B3B32 + ذهبي #C9A227 + كريمي #F7F3E8
├── models/
│   ├── episode.dart              Episode، EpisodeIndex، Paragraph، EpisodeTranscript (indexAt بحث ثنائي)
│   └── bookmark.dart             Bookmark، PlaybackProgress، SearchHit
├── services/
│   ├── data_repository.dart      تحميل episodes.json والنصوص الموقوتة + بحث شامل
│   ├── storage_service.dart      SharedPreferences: مفضلة/علامات/تقدّم/إعدادات/سجل بحث
│   ├── download_service.dart     dio: تحميل .m4a إلى مجلد التطبيق + تقدّم + إلغاء + حذف
│   └── player_controller.dart    just_audio + تتبّع الفقرة + تكرار + مؤقّت نوم + حفظ تلقائي كل 5ث
├── state/
│   ├── library_state.dart        الحلقات، المفضلة، العلامات، التقدّم، التصفية والفرز
│   └── settings_state.dart       المظهر، حجم الخط، التتبّع التلقائي، الأرقام العربية
├── screens/
│   ├── splash_screen.dart        غلاف السلسلة حتى تنتهي قراءة البيانات
│   ├── home_screen.dart          NavigationBar: الحلقات / البحث / محفوظاتي / الإعدادات + MiniPlayer
│   ├── episodes_screen.dart      متابعة الاستماع، إحصاءات، بحث بالعنوان، تصفية وفرز
│   ├── player_screen.dart        ⭐ النص المتتبِّع + لوحة التحكّم الكاملة
│   ├── search_screen.dart        بحث شامل مع تظليل المطابقة واقتراحات وسجل
│   ├── library_screen.dart       ثلاثة تبويبات: المفضلة / العلامات / المحمّلة
│   └── settings_screen.dart      الإعدادات والإحصاءات والتحميلات ومعلومات السلسلة
└── widgets/
    ├── mosque_background.dart    خلفية المسجد النبوي الخافتة + GoldDivider
    ├── episode_tile.dart         بطاقة الحلقة + DownloadButton
    └── mini_player.dart          شريط مصغّر فوق شريط التنقّل
```

### الأصول داخل `app/assets/`
- `data/episodes.json` + `data/sync/ep01..ep42.json` + `data/text/ep01..ep42.txt`
- `images/splash_bg.jpg` (غلاف المسجد — سبلاش وخلفية) و `images/app_icon.jpg`
  و`icon_square.png` (1024×1024) و`icon_foreground.png` (أيقونة تكيّفية)
- `fonts/` — Amiri (للنص) و Tajawal (للواجهة)

### الإعدادات الجاهزة
- أيقونات التطبيق مولَّدة (`flutter_launcher_icons`) لأندرويد و iOS وويندوز
- سبلاش أصلي مولَّد (`flutter_native_splash`) بخلفية `splash_bg.jpg` ولون `#0B3B32`
- `AndroidManifest.xml`: أذونات الإنترنت/الإشعارات/الخدمة الأمامية، وخدمة
  `com.ryanheise.audioservice.AudioService` و`MediaButtonReceiver`،
  والنشاط `AudioServiceActivity`، والاسم «القواعد الفقهية»
- `minSdk = 23`، و`android.overridePathCheck=true` في `gradle.properties`
  (كان لازماً لأن مجلد العمل المحلي اسمه عربي — لا يضرّ في بيئة سحابية)

### حالة الترجمة والبناء
- `flutter analyze` على **Flutter 3.47.7 / Dart 3.13.5**: `No issues found`.
- `flutter test`: **٣٤ اختباراً** تمرّ كلها (`test/arabic_test.dart`
  و`test/episode_test.dart`).
- `flutter build apk --debug`: **يكتمل** — `app-debug.apk` بحجم ١٦٧ م.ب،
  وتحقّقنا من الحزمة بـ`aapt2`: النشاط المُشغِّل
  `com.qawaid.qawaid_fiqhiyya.MainActivity`، والاسم «القواعد الفقهية»،
  وإذن `POST_NOTIFICATIONS` مُعلَن، وخدمة `AudioService` و`MediaButtonReceiver`
  في المانيفست المدمج، و٤٢ ملف `sync` و٤٢ ملف `text` والخطوط والصور
  داخل `flutter_assets`. بلا أي تحذير بناء.

آخر خطأين أُصلحا قبل ذلك: `PlaybackProgress.positionObject` المفقود،
وتعارض اسم `RepeatMode` مع `RepeatMode` في Flutter
(أُعيدت التسمية إلى `PlaybackRepeatMode`).

> **للبناء في جلسة سحابية جديدة:** الحاوية تأتي فارغة من Flutter و Android SDK،
> فنزِّل Flutter stable و`commandlinetools` ثم
> `sdkmanager --install "platform-tools" "platforms;android-36" "build-tools;36.1.0"`
> (لا يوجد `platforms;android-37`)، واكتب في `app/android/local.properties`
> سطرَي `flutter.sdk=` و`sdk.dir=`. ونزّلت Gradle نفسها NDK r28c و CMake 3.22.1
> تلقائياً.
>
> و`repo.maven.apache.org` يرُدّ **429 Too Many Requests** على مخرج الشبكة
> المشترك لهذه الحاويات، فيفشل البناء في حلّ الاعتماديات بلا أي علاقة بالكود.
> العلاج في `~/.gradle/gradle.properties` (إعداد بيئة، لا يُرفع):
> ```
> org.gradle.parallel=false
> org.gradle.workers.max=2
> systemProp.org.gradle.internal.repository.max.retries=10
> systemProp.org.gradle.internal.repository.max.tentatives=10
> systemProp.org.gradle.internal.repository.initial.backoff=3000
> ```
> ولا تُضِف مرآة Maven Central عبر init script: إضافتها إلى مستودعات المشاريع
> ترفضها AGP 9، وإضافتها إلى `dependencyResolutionManagement` تُهمِل `google()`
> المعلَنة في `android/build.gradle.kts` فينكسر حلّ AndroidX.

---

## ⬜ الباقي — رتّبها بهذا الترتيب

### 1. التشغيل على جهاز والتحقّق البصري (لم يحدث بعد — الأهم)
بناء الـAPK **صار يكتمل** (انظر «حالة الترجمة والبناء» أعلاه)، لكن التطبيق
**لم يُشغَّل على أي جهاز بعد** — لا جهاز ولا محاكي في البيئة السحابية.

```bash
cd app
flutter pub get
flutter build apk --debug      # يكتمل
flutter run -d <device>
```

تحقّق بصرياً من:
- السبلاش ثم شاشة الحلقات (٤٢ حلقة، أرقام عربية، اتجاه RTL سليم)
- فتح حلقة → ظهور النص كاملاً، والضغط على فقرة ينقل الصوت
- التظليل يتحرّك مع الصوت، والتمرير التلقائي يتبعه
- البحث الشامل: جرّب «الضرر يزال» و«المشقة تجلب التيسير»
- الوضع الداكن، وتكبير الخط من الإعدادات

### 2. رفع الملفات الصوتية (خطوة يدوية على جهاز المالك)
الصوتيات (٤٢ ملف، ٢٥٢ م.ب) **ليست في المستودع** (مستثناة في `.gitignore`).
التطبيق يبني الرابط من `AppConstants.audioBaseUrl`:

```
https://github.com/taha-majdlawi/qwaed_feqhia_app/releases/download/audio-v1/ep01.m4a
```

فالمطلوب: إصدار (release) وسمه **`audio-v1`** بالضبط، ومرفقاته `ep01.m4a` … `ep42.m4a`.

```bash
gh release create audio-v1 audio/*.m4a --title "ملفات الصوت" --notes "صوت الحلقات 1-42"
```

قبل الرفع، كل تشغيل سيُظهر رسالة «تعذّر الوصول إلى ملف الصوت» — وهذا متوقَّع.
لاختبار التزامن قبل الرفع: ضع أي ملف صوتي باسم `ep01.m4a` على خادم وغيّر `audioBaseUrl` مؤقتاً.

### 3. نواقص تقنية
#### ✅ أُنجزت
- **iOS**: أُضيف `UIBackgroundModes: audio` إلى `app/ios/Runner/Info.plist`،
  وصار `CFBundleDisplayName` = «القواعد الفقهية» بدل "Qawaid Fiqhiyya".
- **أندرويد ١٣+**: `POST_NOTIFICATIONS` يُطلب الآن وقت التشغيل.
  `MainActivity` صار يمتدّ `AudioServiceActivity` ويوفّر قناة
  `com.qawaid.fiqhiyya/permissions`، و`services/notification_permission.dart`
  يطلب الإذن مرّة واحدة من `PlayerController.open()` — وهو المَعبر الوحيد
  لكل مواضع بدء التشغيل. بلا حزمة خارجية.
- **الاختبارات**: `test/arabic_test.dart` و`test/episode_test.dart` — ٣٤ اختباراً.
- **`flutter analyze`**: يعمل في البيئة السحابية بلا مشاكل (الانهيار على جهاز
  المالك سببه خلل `perf_witness`: `Cannot delete file … AppData\Local\Dart\perf`).

#### ⬜ باقية
- **ويندوز**: البناء يحتاج Visual Studio بحزمة «Desktop development with C++»
  (غير مثبّتة على جهاز المالك، ولا تُثبَّت في بيئة لينكس السحابية).
- **`keepAwake` كود ميّت**: يُحفظ في `storage_service.dart` ويُقرأ في
  `settings_state.dart`، لكن لا مفتاح له في شاشة الإعدادات ولا أثر له في
  المشغّل (لا حزمة wakelock في المشروع). فإمّا تُوصَل وإمّا تُحذف.
- **البحث برقم الحلقة لا يقبل الأرقام العربية**: `LibraryState.visibleEpisodes`
  يطابق `'${e.number}'.contains(q)` بأرقام لاتينية، والأرقام العربية مفعّلة
  افتراضياً — فمن يرى «الحلقة ١» ويكتب «١» لا يجد شيئاً.
- **رابط المستودع في الإعدادات**: `url_launcher` على أندرويد ١١+ يحتاج
  `<queries><intent><action VIEW/><data android:scheme="https"/></intent></queries>`
  في المانيفست؛ غير موجود حالياً.

### 4. أفكار للتحسين (اختيارية، بعد ما سبق)
- تصدير العلامات والمفضلة إلى ملف نصّي للمشاركة
- فهرس القواعد الفقهية نفسها (استخراج «القاعدة» من كل حلقة وعرضها كقائمة مستقلة)
- مشاركة مقطع: صورة اقتباس من فقرة
- إحصاء كلمات: أكثر القواعد تكراراً في السلسلة

---

## اتفاقيات العمل في هذا المشروع

- **كومت بعد كل ميزة أو تعديل**، ورسائل الكومت بالعربية بصيغة
  `feat: …` / `fix: …` / `chore: …` ثم أسطر تفصيلية.
- واجهة التطبيق ونصوصه كلها بالعربية، والتعليقات في الكود بالعربية أيضاً.
- الاتجاه RTL في كل الشاشات، والأرقام عربية-هندية عند تفعيل الخيار.
- لا تُرفع الصوتيات إلى Git أبداً.
